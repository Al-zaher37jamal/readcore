/// Base exception class for ReadMesh
abstract class ReadMeshException implements Exception {
  final String message;
  final dynamic cause;

  const ReadMeshException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Thrown when a PDF exceeds the 300 MB maximum size limit
class FileTooLargeException extends ReadMeshException {
  final int fileSizeBytes;
  final int maxAllowedBytes;

  const FileTooLargeException(this.fileSizeBytes, this.maxAllowedBytes)
      : super('File size ($fileSizeBytes bytes) exceeds maximum limit ($maxAllowedBytes bytes)');
}

/// Thrown when a PDF exceeds the ~10,000 page limit
class PageCountExceededException extends ReadMeshException {
  final int pageCount;
  final int maxAllowedPages;

  const PageCountExceededException(this.pageCount, this.maxAllowedPages)
      : super('PDF page count ($pageCount) exceeds maximum allowed limit ($maxAllowedPages)');
}

/// Thrown when there is insufficient disk space to complete an import
class InsufficientStorageException extends ReadMeshException {
  final int requiredBytes;
  final int availableBytes;

  const InsufficientStorageException(this.requiredBytes, this.availableBytes)
      : super('Insufficient storage space: requires $requiredBytes bytes, but only $availableBytes bytes available');
}

/// Thrown when a file is corrupted or not a valid PDF format
class InvalidPdfException extends ReadMeshException {
  const InvalidPdfException(super.message, [super.cause]);
}

/// Thrown when SHA-256 integrity verification fails
class IntegrityCheckFailedException extends ReadMeshException {
  final String expectedHash;
  final String actualHash;

  const IntegrityCheckFailedException(this.expectedHash, this.actualHash)
      : super('SHA-256 integrity verification failed: expected $expectedHash, got $actualHash');
}

/// Thrown when a database integrity check (PRAGMA integrity_check) fails
class DatabaseCorruptionException extends ReadMeshException {
  const DatabaseCorruptionException(super.message, [super.cause]);
}

/// Thrown when an entity is not found in database or storage
class NotFoundException extends ReadMeshException {
  const NotFoundException(super.message);
}

/// Thrown when duplicate book is being imported
class DuplicateBookException extends ReadMeshException {
  final String sha256;
  const DuplicateBookException(this.sha256)
      : super('A book with SHA-256 hash $sha256 already exists');
}

/// Thrown when database operation fails
class DatabaseOperationException extends ReadMeshException {
  const DatabaseOperationException(super.message, [super.cause]);
}
