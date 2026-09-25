import 'package:drift/drift.dart' show Variable;
import 'package:readmesh/data/database/app_database.dart';

// A content ID is also used as the voice filename. Never accept path fragments
// from a peer or construct a file path directly from a LAN payload.
final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]{1,100}$');

int _asInt(Object? value, String name) {
  if (value is int) return value;
  throw FormatException('Invalid $name');
}

String _asString(Object? value, String name, {int maxLength = 2000}) {
  if (value is! String || value.length > maxLength) {
    throw FormatException('Invalid $name');
  }
  return value;
}

DateTime _readDate(Object? value) => DateTime.fromMillisecondsSinceEpoch(
    _asInt(value, 'date') * 1000, isUtc: true);
int _writeDate(DateTime value) => value.toUtc().millisecondsSinceEpoch ~/ 1000;

/// Session- and page-scoped personal/shared note or normalized highlight.
/// Existing book-level Notes (null session_id) remain untouched.
class SessionAnnotation {
  final String id;
  final String sessionId;
  final String bookId;
  final int pageNumber;
  final String authorId;
  final String authorName;
  final String content;
  final String color;
  final String kind; // note | highlight
  final String visibility; // personal | shared
  final bool isPinned;
  final double? x, y, width, height; // normalized PDF viewer region [0,1]
  final DateTime createdAt, updatedAt;

  const SessionAnnotation({
    required this.id,
    required this.sessionId,
    required this.bookId,
    required this.pageNumber,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.color,
    required this.kind,
    required this.visibility,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    this.x,
    this.y,
    this.width,
    this.height,
  });

  SessionAnnotation pin(bool pinned) => SessionAnnotation(
        id: id, sessionId: sessionId, bookId: bookId,
        pageNumber: pageNumber, authorId: authorId, authorName: authorName,
        content: content, color: color, kind: kind, visibility: visibility,
        isPinned: pinned, x: x, y: y, width: width, height: height,
        createdAt: createdAt, updatedAt: DateTime.now().toUtc(),
      );

  void validate() {
    if (!_safeId.hasMatch(id) || sessionId.isEmpty || bookId.isEmpty ||
        pageNumber < 1 || pageNumber > 10000 || authorId.isEmpty ||
        authorId.length > 100 || authorName.length > 100 || content.length > 2000 ||
        (kind != 'note' && kind != 'highlight') ||
        (visibility != 'personal' && visibility != 'shared') ||
        !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) {
      throw const FormatException('Invalid session annotation');
    }
    if (kind == 'highlight') {
      if (x == null || y == null || width == null || height == null ||
          !x!.isFinite || !y!.isFinite || !width!.isFinite || !height!.isFinite ||
          x! < 0 || y! < 0 || width! <= 0 || height! <= 0 ||
          x! + width! > 1.001 || y! + height! > 1.001) {
        throw const FormatException('Invalid highlight region');
      }
    } else if (content.trim().isEmpty) {
      throw const FormatException('Empty note');
    }
  }

  Map<String, dynamic> toWire() => {
        'kind': kind, 'id': id, 'sessionId': sessionId,
        'pageNumber': pageNumber, 'authorId': authorId,
        'authorName': authorName, 'content': content, 'color': color,
        'visibility': visibility, 'isPinned': isPinned,
        'x': x, 'y': y, 'width': width, 'height': height,
        'createdAt': _writeDate(createdAt),
        'updatedAt': _writeDate(updatedAt),
      };

  factory SessionAnnotation.fromWire(Map<String, dynamic> map,
      {required String bookId}) {
    final annotation = SessionAnnotation(
      id: _asString(map['id'], 'id', maxLength: 100),
      sessionId: _asString(map['sessionId'], 'sessionId', maxLength: 150),
      bookId: bookId,
      pageNumber: _asInt(map['pageNumber'], 'pageNumber'),
      authorId: _asString(map['authorId'], 'authorId', maxLength: 100),
      authorName: _asString(map['authorName'], 'authorName', maxLength: 100),
      content: _asString(map['content'], 'content'),
      color: _asString(map['color'], 'color', maxLength: 7),
      kind: _asString(map['kind'], 'kind', maxLength: 12),
      visibility: _asString(map['visibility'], 'visibility', maxLength: 12),
      isPinned: map['isPinned'] == true,
      x: (map['x'] as num?)?.toDouble(),
      y: (map['y'] as num?)?.toDouble(),
      width: (map['width'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
    );
    annotation.validate();
    return annotation;
  }

  factory SessionAnnotation.fromRow(Map<String, dynamic> row) => SessionAnnotation(
        id: row['id'] as String, sessionId: row['session_id'] as String,
        bookId: row['book_id'] as String, pageNumber: row['page_number'] as int,
        authorId: row['device_id'] as String,
        authorName: row['author_name'] as String,
        content: row['content'] as String, color: row['color'] as String,
        kind: row['note_kind'] as String, visibility: row['visibility'] as String,
        isPinned: row['is_pinned'] == 1,
        x: (row['position_x'] as num?)?.toDouble(),
        y: (row['position_y'] as num?)?.toDouble(),
        width: (row['region_width'] as num?)?.toDouble(),
        height: (row['region_height'] as num?)?.toDouble(),
        createdAt: _readDate(row['created_at']),
        updatedAt: _readDate(row['updated_at']),
      );
}

/// A page-specific text/emoji message or local audio-file reference.
class SessionDiscussion {
  final String id, sessionId, authorId, authorName, content, kind;
  final int pageNumber;
  final DateTime createdAt;
  final String? voicePath, voiceSha256;
  final int? durationMs, voiceBytes;

  const SessionDiscussion({
    required this.id, required this.sessionId, required this.pageNumber,
    required this.authorId, required this.authorName, required this.content,
    required this.kind, required this.createdAt,
    this.voicePath, this.durationMs, this.voiceSha256, this.voiceBytes,
  });

  void validate() {
    if (!_safeId.hasMatch(id) || sessionId.isEmpty || pageNumber < 1 ||
        pageNumber > 10000 || authorId.isEmpty || authorId.length > 100 ||
        authorName.length > 100 || content.length > 2000 ||
        (kind != 'text' && kind != 'voice')) {
      throw const FormatException('Invalid discussion message');
    }
    if (kind == 'text' && content.trim().isEmpty) {
      throw const FormatException('Empty message');
    }
    if (kind == 'voice' && (voicePath == null || durationMs == null ||
        durationMs! < 1 || durationMs! > 65000 ||
        voiceBytes == null || voiceBytes! < 1 || voiceBytes! > 1500000 ||
        voiceSha256 == null ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(voiceSha256!))) {
      throw const FormatException('Invalid voice metadata');
    }
  }

  Map<String, dynamic> toWire() => {
        'kind': kind, 'id': id, 'sessionId': sessionId,
        'pageNumber': pageNumber, 'authorId': authorId,
        'authorName': authorName, 'content': content,
        'createdAt': _writeDate(createdAt),
        if (kind == 'voice') 'durationMs': durationMs,
        if (kind == 'voice') 'voiceBytes': voiceBytes,
        if (kind == 'voice') 'voiceSha256': voiceSha256,
        // Never send a device-private absolute file path over LAN.
      };

  factory SessionDiscussion.fromWire(Map<String, dynamic> map,
      {String? localVoicePath}) {
    final discussion = SessionDiscussion(
      id: _asString(map['id'], 'id', maxLength: 100),
      sessionId: _asString(map['sessionId'], 'sessionId', maxLength: 150),
      pageNumber: _asInt(map['pageNumber'], 'pageNumber'),
      authorId: _asString(map['authorId'], 'authorId', maxLength: 100),
      authorName: _asString(map['authorName'], 'authorName', maxLength: 100),
      content: _asString(map['content'], 'content'),
      kind: _asString(map['kind'], 'kind', maxLength: 12),
      createdAt: _readDate(map['createdAt']),
      voicePath: localVoicePath,
      durationMs: map['durationMs'] as int?,
      voiceBytes: map['voiceBytes'] as int?,
      voiceSha256: map['voiceSha256'] as String?,
    );
    discussion.validate();
    return discussion;
  }

  factory SessionDiscussion.fromRow(Map<String, dynamic> row) => SessionDiscussion(
        id: row['id'] as String, sessionId: row['session_id'] as String,
        pageNumber: row['page_number'] as int,
        authorId: row['sender_id'] as String,
        authorName: row['sender_name'] as String,
        content: row['content'] as String,
        kind: row['message_type'] as String,
        createdAt: _readDate(row['created_at']),
        voicePath: row['voice_path'] as String?,
        durationMs: row['duration_ms'] as int?,
        voiceSha256: row['voice_sha256'] as String?,
        voiceBytes: row['voice_bytes'] as int?,
      );
}

/// Uses the existing Drift database and writer lock. Raw queries bridge the
/// checked-in Phase 2 generated schema until build_runner can be run with the
/// required Flutter SDK; the Phase 4 upgrade creates all referenced columns.
class SessionContentRepository {
  final AppDatabase _db;
  SessionContentRepository(this._db);

  Future<bool> saveAnnotation(SessionAnnotation note) async {
    note.validate();
    return _db.writeTx(() async {
      final existing = await _db.customSelect(
        'SELECT session_id, device_id, visibility FROM notes WHERE id = ?',
        variables: [Variable.withString(note.id)],
      ).getSingleOrNull();
      if (existing != null &&
          (existing.data['session_id'] != note.sessionId ||
           existing.data['device_id'] != note.authorId ||
           existing.data['visibility'] != note.visibility)) {
        throw const FormatException('Annotation identity conflict');
      }
      final count = await _db.customUpdate('''
INSERT INTO notes (id, book_id, page_number, device_id, author_name,
  content, color, position_x, position_y, created_at, updated_at,
  session_id, note_kind, visibility, is_pinned, region_width, region_height)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET content=excluded.content,
  color=excluded.color, position_x=excluded.position_x,
  position_y=excluded.position_y, is_pinned=excluded.is_pinned,
  region_width=excluded.region_width, region_height=excluded.region_height,
  updated_at=excluded.updated_at
WHERE notes.session_id=excluded.session_id AND notes.device_id=excluded.device_id
  AND notes.visibility=excluded.visibility AND excluded.updated_at >= notes.updated_at
''', variables: [
        Variable.withString(note.id), Variable.withString(note.bookId),
        Variable.withInt(note.pageNumber), Variable.withString(note.authorId),
        Variable.withString(note.authorName), Variable.withString(note.content),
        Variable.withString(note.color), Variable<double>(note.x),
        Variable<double>(note.y), Variable.withInt(_writeDate(note.createdAt)),
        Variable.withInt(_writeDate(note.updatedAt)),
        Variable.withString(note.sessionId), Variable.withString(note.kind),
        Variable.withString(note.visibility), Variable.withInt(note.isPinned ? 1 : 0),
        Variable<double>(note.width), Variable<double>(note.height),
      ], updates: {_db.notesTable});
      return count > 0;
    });
  }

  Future<bool> saveDiscussion(SessionDiscussion message) async {
    message.validate();
    return _db.writeTx(() async {
      final existing = await getDiscussionById(message.id);
      if (existing != null &&
          (existing.sessionId != message.sessionId ||
           existing.authorId != message.authorId ||
           existing.kind != message.kind ||
           existing.pageNumber != message.pageNumber ||
           existing.content != message.content ||
           existing.voiceSha256 != message.voiceSha256 ||
           existing.voiceBytes != message.voiceBytes)) {
        throw const FormatException('Discussion identity conflict');
      }
      final count = await _db.customUpdate('''
INSERT INTO messages (id, session_id, sender_id, sender_name, content,
  message_type, created_at, page_number, voice_path, duration_ms,
  voice_sha256, voice_bytes)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO NOTHING
''', variables: [
        Variable.withString(message.id), Variable.withString(message.sessionId),
        Variable.withString(message.authorId), Variable.withString(message.authorName),
        Variable.withString(message.content), Variable.withString(message.kind),
        Variable.withInt(_writeDate(message.createdAt)),
        Variable.withInt(message.pageNumber), Variable<String>(message.voicePath),
        Variable<int>(message.durationMs), Variable<String>(message.voiceSha256),
        Variable<int>(message.voiceBytes),
      ], updates: {_db.messagesTable});
      return count > 0;
    });
  }

  Future<SessionDiscussion?> getDiscussionById(String id) async {
    final row = await _db.customSelect('SELECT * FROM messages WHERE id = ?',
        variables: [Variable.withString(id)]).getSingleOrNull();
    return row == null ? null : SessionDiscussion.fromRow(row.data);
  }

  Stream<List<SessionAnnotation>> watchAnnotations(
      String sessionId, int pageNumber, String viewerId, {String kind = 'note'}) {
    return _db.customSelect('''
SELECT * FROM notes WHERE session_id = ? AND page_number = ? AND note_kind = ?
AND (visibility = 'shared' OR device_id = ?)
ORDER BY is_pinned DESC, created_at ASC
''', variables: [Variable.withString(sessionId), Variable.withInt(pageNumber),
      Variable.withString(kind), Variable.withString(viewerId)],
      readsFrom: {_db.notesTable}).watch().map((rows) =>
        rows.map((row) => SessionAnnotation.fromRow(row.data)).toList());
  }

  Stream<List<SessionDiscussion>> watchDiscussion(String sessionId, int pageNumber) {
    return _db.customSelect('''
SELECT * FROM messages WHERE session_id = ? AND page_number = ?
AND message_type IN ('text', 'voice') ORDER BY created_at ASC
''', variables: [Variable.withString(sessionId), Variable.withInt(pageNumber)],
      readsFrom: {_db.messagesTable}).watch().map((rows) =>
        rows.map((row) => SessionDiscussion.fromRow(row.data)).toList());
  }

  Future<List<SessionAnnotation>> sharedAnnotations(String sessionId) async {
    final rows = await _db.customSelect(
      "SELECT * FROM notes WHERE session_id = ? AND visibility = 'shared' ORDER BY created_at ASC",
      variables: [Variable.withString(sessionId)],
    ).get();
    return rows.map((row) => SessionAnnotation.fromRow(row.data)).toList();
  }

  Future<List<SessionDiscussion>> sessionDiscussion(String sessionId) async {
    final rows = await _db.customSelect(
      "SELECT * FROM messages WHERE session_id = ? AND message_type IN ('text', 'voice') ORDER BY created_at ASC",
      variables: [Variable.withString(sessionId)],
    ).get();
    return rows.map((row) => SessionDiscussion.fromRow(row.data)).toList();
  }
}
