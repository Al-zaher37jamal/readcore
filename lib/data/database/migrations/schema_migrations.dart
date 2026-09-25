import 'package:drift/drift.dart';
import 'package:readmesh/core/errors/exceptions.dart';

class SchemaMigrations {
  static const int currentSchemaVersion = 5;

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
        await _migrateToVersion4(db);
        await _migrateToVersion5(db);
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
        if (from < 4) {
          // Preserve earlier Notes and Messages data; add only missing columns.
          await _migrateToVersion4(db);
        }
        if (from < 5) {
          await _migrateToVersion5(db);
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

  /// Phase 6 content lives in the existing 12-table SQLite database. The
  /// checked-in generated Drift schema predates the extra columns, so on a
  /// fresh database and on an upgrade we add only columns that are missing.
  /// Regenerating app_database.g.dart later is safe: existing columns are
  /// detected instead of relying on swallowed ALTER errors.
  static Future<void> _migrateToVersion4(GeneratedDatabase db) async {
    await _addColumn(db, 'notes', 'session_id',
        'TEXT REFERENCES sessions(id) ON DELETE CASCADE');
    await _addColumn(db, 'notes', 'note_kind',
        "TEXT NOT NULL DEFAULT 'note' CHECK (note_kind IN ('note', 'highlight'))");
    await _addColumn(db, 'notes', 'visibility',
        "TEXT NOT NULL DEFAULT 'personal' CHECK (visibility IN ('personal', 'shared'))");
    await _addColumn(db, 'notes', 'is_pinned',
        'INTEGER NOT NULL DEFAULT 0 CHECK (is_pinned IN (0, 1))');
    await _addColumn(db, 'notes', 'region_width', 'REAL');
    await _addColumn(db, 'notes', 'region_height', 'REAL');
    await _addColumn(db, 'messages', 'page_number',
        'INTEGER NOT NULL DEFAULT 1');
    await _addColumn(db, 'messages', 'voice_path', 'TEXT');
    await _addColumn(db, 'messages', 'duration_ms', 'INTEGER');
    await _addColumn(db, 'messages', 'voice_sha256', 'TEXT');
    await _addColumn(db, 'messages', 'voice_bytes', 'INTEGER');
    await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_notes_session_page ON notes(session_id, page_number);');
    await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_messages_session_page ON messages(session_id, page_number);');
  }

  /// Text-message metadata on the existing messages table. A nullable
  /// updated_at is required for compatibility with older Drift-generated
  /// inserts; older rows are backfilled, and new text inserts always set it.
  static Future<void> _migrateToVersion5(GeneratedDatabase db) async {
    await _addColumn(db, 'messages', 'updated_at', 'INTEGER');
    await _addColumn(db, 'messages', 'status',
        "TEXT NOT NULL DEFAULT 'local'");
    await db.customStatement(
        'UPDATE messages SET updated_at = created_at WHERE updated_at IS NULL');
    await db.customStatement('CREATE INDEX IF NOT EXISTS '
        'idx_messages_session_page_created '
        'ON messages(session_id, page_number, created_at)');
  }

  static Future<void> _addColumn(GeneratedDatabase db, String table,
      String name, String declaration) async {
    final columns = await db.customSelect('PRAGMA table_info($table)').get();
    if (columns.any((row) => row.data['name'] == name)) return;
    await db.customStatement('ALTER TABLE $table ADD COLUMN $name $declaration');
  }
}
