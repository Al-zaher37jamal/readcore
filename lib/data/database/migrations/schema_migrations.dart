import 'package:drift/drift.dart';
import 'package:readmesh/core/errors/exceptions.dart';

class SchemaMigrations {
  static const int currentSchemaVersion = 3;

  /// Builds the Drift migration strategy with startup integrity checks,
  /// WAL configuration, foreign key enforcement, and version upgrades.
  static MigrationStrategy createStrategy({
    required GeneratedDatabase db,
    bool runIntegrityCheckOnStartup = true,
  }) {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Create indexes on initial creation as well
        await _createVersion2Indexes(db);
        // Phase 6: ensure new columns exist even if g.dart not regenerated yet
        await _migrateToVersion3(db);
        await _createVersion3Indexes(db);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Upgrade step from v1 to v2: create performance indices
          await _createVersion2Indexes(db);
        }
        if (from < 3) {
          // Phase 6: Session History and Resumable Local Reading
          // Add new columns to sessions table for saved/ended lifecycle
          await _migrateToVersion3(db);
          await _createVersion3Indexes(db);
        }
      },
      beforeOpen: (OpeningDetails details) async {
        try {
          // Enforce Foreign Keys
          await db.customStatement('PRAGMA foreign_keys = ON;');

          // Configure WAL (Write-Ahead Logging) for concurrent reads + single writer
          await db.customStatement('PRAGMA journal_mode = WAL;');

          // Configure synchronous pragma for optimal SSD/Flash balance of speed and safety
          await db.customStatement('PRAGMA synchronous = NORMAL;');

          // Set busy timeout to 5 seconds to handle contention gracefully
          await db.customStatement('PRAGMA busy_timeout = 5000;');

          // Run startup integrity check
          if (runIntegrityCheckOnStartup) {
            final rows = await db.customSelect('PRAGMA integrity_check;').get();
            if (rows.isEmpty || rows.first.data.values.first != 'ok') {
              final errorDetails = rows.map((r) => r.data.values.join(' ')).join('; ');
              throw DatabaseCorruptionException(
                'SQLite startup integrity check failed: $errorDetails',
              );
            }
          }
        } on DatabaseCorruptionException {
          rethrow;
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('malformed') ||
              errStr.contains('corrupt') ||
              errStr.contains('not a database')) {
            throw DatabaseCorruptionException('Database corruption detected on startup: $e', e);
          }
          rethrow;
        }
      },
    );
  }

  static Future<void> _createVersion2Indexes(GeneratedDatabase db) async {
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_books_sha256 ON books(sha256_hash);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sessions_book_id ON sessions(book_id);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_session_members_session_id ON session_members(session_id);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_session_events_session_seq ON session_events(session_id, sequence_number);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_outbox_status ON outbox(status);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_reading_progress_session ON reading_progress(session_id, book_id);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_page_activity_session ON page_activity(session_id, book_id);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_book_page ON notes(book_id, page_number);',
    );
  }

  static Future<void> _migrateToVersion3(GeneratedDatabase db) async {
    // Add Phase 6 columns to sessions table if they don't exist
    // Use ALTER TABLE with IF NOT EXISTS workaround via try-catch
    try {
      await db.customStatement('ALTER TABLE sessions ADD COLUMN last_page INTEGER;');
    } catch (_) {}
    try {
      await db.customStatement('ALTER TABLE sessions ADD COLUMN total_pages INTEGER;');
    } catch (_) {}
    try {
      await db.customStatement('ALTER TABLE sessions ADD COLUMN last_activity_at INTEGER;');
    } catch (_) {}
    try {
      await db.customStatement("ALTER TABLE sessions ADD COLUMN session_type TEXT NOT NULL DEFAULT 'solo';");
    } catch (_) {}
    try {
      await db.customStatement('ALTER TABLE sessions ADD COLUMN timer_enabled INTEGER NOT NULL DEFAULT 0 CHECK (timer_enabled IN (0,1));');
    } catch (_) {}
    try {
      await db.customStatement('ALTER TABLE sessions ADD COLUMN stats_enabled INTEGER NOT NULL DEFAULT 0 CHECK (stats_enabled IN (0,1));');
    } catch (_) {}
  }

  static Future<void> _createVersion3Indexes(GeneratedDatabase db) async {
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sessions_last_activity ON sessions(last_activity_at);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sessions_type ON sessions(session_type);',
    );
  }
}
