import 'dart:io';
import 'package:flutter/material.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/core/widgets/app_icon.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_ip_helper.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';
import 'package:readmesh/features/room/room_detail_screen.dart';

/// My Sessions screen – Phase 6: Session History and Resumable Local Reading
/// Shows saved and ended sessions with book title, page X of Y, last activity, status, resume, delete
class MySessionsScreen extends StatefulWidget {
  final SessionRepository? sessionRepository;
  final BookRepository? bookRepository;
  final ReadingProgressRepository? progressRepository;
  final DeviceService? deviceService;

  const MySessionsScreen({
    super.key,
    this.sessionRepository,
    this.bookRepository,
    this.progressRepository,
    this.deviceService,
  });

  @override
  State<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends State<MySessionsScreen> {
  late final SessionRepository _sessionRepo;
  late final BookRepository _bookRepo;
  late final ReadingProgressRepository _progressRepo;
  late final DeviceService _deviceService;

  @override
  void initState() {
    super.initState();
    _sessionRepo = widget.sessionRepository ?? getIt<SessionRepository>();
    _bookRepo = widget.bookRepository ?? getIt<BookRepository>();
    _progressRepo = widget.progressRepository ?? getIt<ReadingProgressRepository>();
    _deviceService = widget.deviceService ?? getIt<DeviceService>();
  }

  String _formatLastActivity(DateTime dt, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.sinceMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.sinceHours(diff.inHours);
    return l10n.sinceDays(diff.inDays);
  }

  Future<Map<String, dynamic>> _getSessionDisplayData(Session session) async {
    final book = await _bookRepo.getBookById(session.bookId);
    final profile = await _deviceService.getOrCreateCurrentProfile();
    final progress = await _progressRepo.getProgress(session.id, profile.id) ??
        await _progressRepo.getLatestBookProgress(session.bookId, profile.id);

    int currentPage = progress?.currentPage ?? 1;
    int totalPages = progress?.totalPages ?? book?.pageCount ?? 1;

    // Try to get from sessions table new columns via raw query
    try {
      final db = getIt<AppDatabase>();
      final rows = await db.customSelect(
        'SELECT last_page, total_pages FROM sessions WHERE id = ?',
        variables: [Variable.withString(session.id)],
      ).get();
      if (rows.isNotEmpty) {
        final data = rows.first.data;
        final lp = data['last_page'] as int?;
        final tp = data['total_pages'] as int?;
        if (lp != null && lp > 0) currentPage = lp;
        if (tp != null && tp > 0) totalPages = tp;
      }
    } catch (_) {}

    return {
      'book': book,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'progress': progress,
      'isGroup': !session.id.startsWith('solo_'),
    };
  }

  Future<void> _confirmDelete(Session session) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('confirm_delete_dialog'),
        title: Text(l10n.confirmDeleteTitle),
        content: Text(l10n.confirmDeleteBody),
        actions: [
          TextButton(
            key: const Key('cancel_delete_button'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_button'),
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text(l10n.deleteHistory),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _sessionRepo.deleteSessionHistoryOnly(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deleted(session.title))),
        );
      }
    }
  }

  Future<void> _resumeSession(Session session) async {
    final l10n = AppLocalizations.of(context);
    try {
      final book = await _bookRepo.getBookById(session.bookId);
      if (book == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.roomNotFound), backgroundColor: Colors.red),
          );
        }
        return;
      }
      final file = File(book.filePath);
      if (!file.existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF file not found: ${book.filePath}'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final isGroup = !session.id.startsWith('solo_');
      final profile = await _deviceService.getOrCreateCurrentProfile();
      final isHost = session.hostDeviceId == profile.id;

      if (isGroup && isHost && session.status == 'saved') {
        // Resume as Host: create fresh LAN server with new IP/port, do NOT reuse old socket
        // We will navigate to RoomDetailScreen which will start fresh server
        if (mounted) {
          // First, mark session as active again for resume
          await _sessionRepo.updateSessionStatus(session.id, 'active');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoomDetailScreen(sessionId: session.id),
            ),
          );
        }
      } else if (isGroup && !isHost) {
        // Participant resuming saved group session – should go to room detail, but participant needs host IP
        // For Phase 6, we treat saved group participant as solo resume if host not available
        // Show dialog to enter host IP or just open as solo reading with saved page
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfReaderScreen(
                book: book,
                sessionId: session.id,
                isHost: false,
              ),
            ),
          );
        }
      } else {
        // Solo session resume: open PDF at saved page
        if (mounted) {
          // Mark as active on resume
          if (session.status == 'saved') {
            await _sessionRepo.updateSessionStatus(session.id, 'active');
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfReaderScreen(
                book: book,
                sessionId: session.id,
                isHost: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resume failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mySessions),
      ),
      body: StreamBuilder<List<Session>>(
        stream: _sessionRepo.watchSavedSessions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return _buildEmptyState(l10n);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return FutureBuilder<Map<String, dynamic>>(
                future: _getSessionDisplayData(session),
                builder: (context, dataSnap) {
                  if (!dataSnap.hasData) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(width: 12),
                            Text(session.title),
                          ],
                        ),
                      ),
                    );
                  }
                  final data = dataSnap.data!;
                  final book = data['book'] as Book?;
                  final currentPage = data['currentPage'] as int;
                  final totalPages = data['totalPages'] as int;
                  final isGroup = data['isGroup'] as bool;
                  final lastActivity = _formatLastActivity(session.updatedAt, l10n);
                  final isSaved = session.status == 'saved';
                  final isEnded = session.status == 'ended';

                  return Card(
                    key: Key('session_card_${session.id}'),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  book?.title ?? session.title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSaved ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSaved ? const Color(0xFFBFDBFE) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Text(
                                  isSaved ? l10n.savedStatus : l10n.ended,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSaved ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              AppIcon.bookmark(size: 16, color: const Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                l10n.pageXofY(currentPage, totalPages),
                                key: Key('page_display_${session.id}'),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                              ),
                              const SizedBox(width: 12),
                              AppIcon.history(size: 16, color: const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${l10n.lastReadingPrefix}: $lastActivity',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                isGroup ? Icons.group : Icons.person,
                                size: 14,
                                color: const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isGroup ? l10n.groupSession : l10n.soloSession,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                              const Spacer(),
                              Text(
                                session.id,
                                style: const TextStyle(fontSize: 10, color: Color(0xFFCBD5E1)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                key: Key('delete_session_${session.id}'),
                                onPressed: () => _confirmDelete(session),
                                icon: AppIcon.delete(size: 18),
                                label: Text(l10n.deleteHistory),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  side: const BorderSide(color: Color(0xFFFECACA)),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                key: Key('resume_session_${session.id}'),
                                onPressed: isEnded
                                    ? null
                                    : () => _resumeSession(session),
                                icon: AppIcon.play(size: 18),
                                label: Text(l10n.resumeUpper),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSaved ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          if (isEnded)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                l10n.endedNotJoinable,
                                style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon.history(size: 72, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(
              l10n.noSavedSessions,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noSavedSessionsHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
