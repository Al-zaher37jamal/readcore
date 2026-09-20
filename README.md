# ReadMesh

A peer-to-peer collaborative PDF reading application built with Flutter.

## Status

- **Phase 1**: Clean Architecture, Core Theme, Models, Error Hierarchy (Complete).
- **Phase 2**: SQLite Database + Local Storage Layer (Complete).

---

## Phase 2 Features

1. **Drift + SQLite Database Engine**:
   - Strictly 12 core tables (no voice/audio/transfers).
   - Foreign key constraints with cascade deletion.
   - Comprehensive query and reactive stream repositories.
2. **High-Performance Database Configuration**:
   - Write-Ahead Logging (`WAL`) mode enabled.
   - `PRAGMA synchronous = NORMAL;` and 5000ms busy timeout.
   - Single-Writer concurrency strategy using `SingleWriterLock`.
   - Automatic startup integrity checks (`PRAGMA integrity_check;`).
3. **Robust Storage & PDF Import Pipeline**:
   - Pre-flight file size validation (max 300 MB).
   - Page count validation (max ~10,000 pages).
   - Available disk space check (+50 MB safety margin).
   - Streaming SHA-256 calculation and duplicate prevention.
   - Atomic copy-and-rename import workflow with automatic rollback on error.
   - **Zero binary storage in SQLite**: Only metadata and local file references are stored.
4. **Storage Auditing**:
   - Reports disk usage for **Books**, **Cache**, **Database**, **Total**, and **Available** storage.
5. **Orphan Reconciliation**:
   - Bi-directional detection and cleanup of unindexed disk files and missing database records.
6. **Dependency Injection**:
   - Modular service locator configured using `GetIt`.

---

## Project Structure

```
lib/
├── core/
│   ├── constants/       # App constants and storage limits
│   ├── di/              # Dependency injection (GetIt locator)
│   ├── errors/          # Custom exceptions and failures
│   └── theme/           # App theme and styling
├── data/
│   ├── database/        # Drift database, migrations, single-writer lock
│   │   ├── connection/  # Native database connection
│   │   ├── migrations/  # Schema migrations & integrity check
│   │   └── tables/      # 12 Drift table definitions
│   ├── repositories/    # 12 Repository implementations
│   └── storage/         # BookFileManager, PdfImportPipeline, StorageManager, OrphanReconciler
└── main.dart            # Flutter application entry point
```

---

## Running Tests & Static Analysis

```bash
# Run all Phase 2 tests (unit and integration)
flutter test

# Run Dart static analysis
flutter analyze

# Regenerate Drift code (if schema is modified)
dart run build_runner build --delete-conflicting-outputs
```

---

## Documentation

For full architectural details, schema diagrams, and developer guides, see:
- [docs/DATABASE_AND_STORAGE.md](docs/DATABASE_AND_STORAGE.md)
