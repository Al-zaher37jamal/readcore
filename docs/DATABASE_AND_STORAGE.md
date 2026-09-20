# ReadMesh Phase 2: SQLite Database & Local Storage Architecture

## 1. Overview
ReadMesh Phase 2 establishes the persistence and local storage foundation for the peer-to-peer collaborative PDF reading application. Built on top of **Drift** (an SQLite abstraction layer for Dart/Flutter) and native file system storage, this layer ensures deterministic write operations, verified file integrity, efficient memory utilization, and zero binary bloat inside the database.

---

## 2. Local Database Schema (Strict 12 Tables)

In compliance with the simplified MVP scope, the database contains **strictly 12 tables**. All voice-related tables (`voice_messages`, `book_transfers`, audio models) have been completely excluded.

| # | Table Name | Description | Primary Key | Key Foreign Constraints |
|---|------------|-------------|-------------|-------------------------|
| 1 | `device_profile` | Local device identity and display name | `id` | None |
| 2 | `sessions` | Collaborative reading room session metadata | `id` | `book_id` -> `books(id)` (CASCADE) |
| 3 | `session_members` | Participants in a session with role and status | `id` | `session_id` -> `sessions(id)` (CASCADE) |
| 4 | `session_events` | Log of chronological session actions (page turns, sync) | `id` | `session_id` -> `sessions(id)` (CASCADE) |
| 5 | `outbox` | Resilient message delivery queue | `id` | `session_id` -> `sessions(id)` (CASCADE) |
| 6 | `reading_progress` | User reading location, page progress, and percentage | `id` | `session_id` -> `sessions(id)` (CASCADE), `book_id` -> `books(id)` (CASCADE) |
| 7 | `participant_reading_time` | Cumulative active time spent reading | `id` | `session_id` -> `sessions(id)` (CASCADE) |
| 8 | `page_activity` | Granular time spent per page for analytics | `id` | `session_id` -> `sessions(id)` (CASCADE), `book_id` -> `books(id)` (CASCADE) |
| 9 | `messages` | In-session chat messages | `id` | `session_id` -> `sessions(id)` (CASCADE) |
| 10 | `notes` | Annotations, bookmarks, and highlights on pages | `id` | `book_id` -> `books(id)` (CASCADE) |
| 11 | `books` | Book metadata, page count, SHA-256 hash, and local file path | `id` | Unique index on `sha256_hash` |
| 12 | `kvs` | Key-value store for app settings and state | `key` | None |

### Zero Binary Data Rule
**No PDF or media binaries are ever stored in SQLite**. The `books` table contains exclusively metadata and a string reference `file_path` pointing to the physical file on disk.

---

## 3. High-Performance Configuration

### 3.1 Write-Ahead Logging (WAL) Mode
ReadMesh configures SQLite into Write-Ahead Logging mode upon connection:
```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;
```
- **Concurrency**: WAL mode decouples readers from writers. Multiple readers can query the database simultaneously without blocking the single writer.
- **Speed**: In WAL mode, writes append to the `-wal` file sequentially rather than performing in-place page writes to the main DB, drastically improving write throughput on flash storage.
- **Safety**: With `PRAGMA synchronous = NORMAL;`, WAL provides ACID compliance with negligible overhead.

### 3.2 Single-Writer Strategy
SQLite allows multiple concurrent readers but strictly one writer per database connection. To eliminate `SQLITE_BUSY` errors and race conditions across asynchronous Dart execution frames, ReadMesh implements the `SingleWriterLock`:
- All modifying transactions (`writeTx`) pass through an asynchronous FIFO queue.
- This ensures operations are serialized in memory before reaching the SQLite engine.
- Reads proceed unblocked across concurrent futures.

### 3.3 Startup Integrity Check
During the database opening lifecycle (`beforeOpen` callback in `SchemaMigrations`):
- `PRAGMA integrity_check;` is automatically executed.
- If the result is not `ok`, a `DatabaseCorruptionException` is thrown, preventing corrupt data from compromising application state.

---

## 4. Local File System & PDF Import Pipeline

### 4.1 Storage Directory Layout
```
<app_documents_directory>/
├── readmesh.db             # Main SQLite database
├── readmesh.db-wal         # Write-ahead log file
├── readmesh.db-shm         # Shared-memory index for WAL
├── books/                  # Managed PDF storage (<book_id>.pdf)
├── cache/                  # Ephemeral renders and thumbnails
└── temp/                   # Atomic import staging area
```

### 4.2 PDF Import Pipeline Workflow
Importing a PDF document adheres to a multi-stage validation pipeline (`PdfImportPipeline`):

1. **Pre-flight File Size Check**:
   Files exceeding **300 MB** (`314,572,800 bytes`) are immediately rejected with `FileTooLargeException`.
2. **Available Storage Validation**:
   Checks whether the volume has enough free storage space: `requiredSpace = fileSize + 50 MB buffer`. If storage is insufficient, throws `InsufficientStorageException`.
3. **Chunked Streaming & SHA-256 Calculation**:
   Streams file bytes in memory-efficient chunks directly to a temporary file (`temp/import_<uuid>.tmp`) while piping through `crypto.sha256`.
4. **Duplicate Detection**:
   Queries SQLite for any existing book matching the computed SHA-256 hash. If found, aborts with `DuplicateBookException`.
5. **PDF Validation & Page Count Inspection**:
   - Validates `%PDF-` magic header in first 1024 bytes.
   - Parses the document catalog `/Pages` `/Count` to determine page count.
   - Documents with more than approximately **10,000 pages** are rejected with `PageCountExceededException`.
6. **Atomic Rename**:
   Moves `temp/import_<uuid>.tmp` to `books/<book_id>.pdf` using an atomic file system rename.
7. **Metadata Persistence**:
   Inserts the book record into SQLite using `BookRepository.createBook()`.
8. **Guaranteed Failure Cleanup**:
   If an exception occurs at any point, the temporary file is deleted in a `try-catch` block, ensuring no orphan files remain.

---

## 5. Storage Manager & Usage Reporting

ReadMesh provides complete storage auditing via `StorageManager.getStorageUsage()`.

### Categories Reported (No Audio!)
- **Books**: Total bytes occupied by files in `books/`.
- **Cache**: Total bytes occupied by files in `cache/`.
- **Database**: Total bytes occupied by SQLite files (`readmesh.db`, `readmesh.db-wal`, `readmesh.db-shm`).
- **Total**: Exact sum of `Books + Cache + Database`.
- **Available**: Available disk space on the host storage partition.

---

## 6. Orphan Reconciliation

Over time, application crashes or unexpected shutdowns could leave detached files on disk or invalid paths in SQLite. The `OrphanReconciler` performs bidirectional synchronization:
1. **Disk Orphans**: Deletes files located in `books/` that have no matching `filePath` in SQLite.
2. **Database Orphans**: Identifies records in the `books` table whose physical files are missing from disk, optionally purging the broken records.
3. **Stale Temp Cleanup**: Deletes any leftover `.tmp` files in `temp/`.

---

## 7. Educational Guide: Key Dart/Flutter Concepts

### 1. Drift & SQLite
Drift provides compile-time safe SQL code generation. By writing Dart tables (`BooksTable`, `SessionsTable`), Drift generates typed classes (`Book`, `BooksTableCompanion`) and query builders. Drift maps Dart types directly to SQLite primitives (Text, Int, Real, DateTime stored as epoch integer/ISO-8601).

### 2. Repositories
The Repository pattern isolates data storage details from application business logic. Domain components interact only with abstract interfaces (`BookRepository`, `SessionRepository`), making the app fully testable with mock or in-memory implementations.

### 3. Migrations
Drift's `MigrationStrategy` tracks `schemaVersion`. When migrating from version 1 to 2, `onUpgrade` executes incremental DDL statements (`CREATE INDEX IF NOT EXISTS ...`) without losing existing user data.

### 4. File System Access
Dart's `dart:io` library provides non-blocking asynchronous file APIs (`openRead()`, `openWrite()`, `rename()`, `delete()`). Streaming is vital for handling large files (up to 300 MB) without exhausting device RAM.

### 5. Async / Await
Dart is single-threaded with an event loop. File I/O and database operations return `Future` objects. `async/await` yields execution back to the event loop while waiting for the operating system to complete disk operations, keeping the UI smooth (60/120 FPS).

### 6. SHA-256
SHA-256 is a cryptographic hash producing a unique 256-bit (64 hex characters) digest. By streaming file chunks into `sha256.startChunkedConversion`, we compute the checksum on the fly during the copy phase without loading the entire 300 MB into memory.

### 7. Dependency Injection (GetIt)
`GetIt` is a service locator for Dart. It registers singletons (`AppDatabase`, `BookFileManager`, `PdfImportPipeline`) and allows unit tests to inject mocks or in-memory replacements without altering production code.

### 8. Error Handling
Domain-specific exceptions (`FileTooLargeException`, `DuplicateBookException`, `InsufficientStorageException`) extend `ReadMeshException`. This creates clear error boundaries that higher layers can catch and present as meaningful user feedback.

---

## 8. Developer Guide: Debugging and Modifying Database Code

### How to Modify Schema
1. Open the relevant table file in `lib/data/database/tables/`.
2. Add or modify the column definition.
3. If changing existing tables, increment `currentSchemaVersion` in `lib/data/database/migrations/schema_migrations.dart` and add the corresponding upgrade step in `onUpgrade`.
4. Re-run code generation:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
5. Run tests:
   ```bash
   flutter test
   ```

### How to Inspect SQLite Database Directly
Using SQLite CLI on Linux/macOS:
```bash
sqlite3 ~/.local/share/readmesh/readmesh.db
sqlite> .tables
sqlite> PRAGMA integrity_check;
sqlite> SELECT id, title, file_path, page_count FROM books;
```
