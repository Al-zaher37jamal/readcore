import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Session-scoped AAC/M4A files under the app's private documents directory.
/// Only paths derived from a hash of the session and a checked message ID are
/// used; a LAN peer can never specify a filesystem path.
class SessionVoiceStore {
  static const int maxVoiceBytes = 1500000;
  final Directory? _injectedRoot;
  SessionVoiceStore([this._injectedRoot]);

  String _folderName(String sessionId) =>
      sha256.convert(utf8.encode(sessionId)).toString().substring(0, 32);

  Future<Directory> sessionDirectory(String sessionId) async {
    if (sessionId.isEmpty || sessionId.length > 150) {
      throw const FormatException('Invalid session ID');
    }
    final root = _injectedRoot ?? await getApplicationDocumentsDirectory();
    return Directory(p.join(root.path, 'readmesh_voice', _folderName(sessionId)));
  }

  Future<File> fileFor(String sessionId, String messageId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(messageId)) {
      throw const FormatException('Invalid voice ID');
    }
    final directory = await sessionDirectory(sessionId);
    await directory.create(recursive: true);
    return File(p.join(directory.path, '$messageId.m4a'));
  }

  Future<({int bytes, String sha256})> inspect(File file) async {
    final length = await file.length();
    if (length < 1 || length > maxVoiceBytes) {
      throw const FormatException('Voice recording exceeds the allowed size');
    }
    final digest = await sha256.bind(file.openRead()).first;
    return (bytes: length, sha256: digest.toString());
  }

  /// Verify before publishing, then atomically install a received voice file.
  Future<File> saveVerified(String sessionId, String messageId,
      Uint8List bytes, String expectedHash) async {
    if (bytes.isEmpty || bytes.length > maxVoiceBytes ||
        sha256.convert(bytes).toString() != expectedHash) {
      throw const FormatException('Voice transfer integrity check failed');
    }
    final target = await fileFor(sessionId, messageId);
    final temp = File('${target.path}.part');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      if (await target.exists()) await target.delete();
      return await temp.rename(target.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  /// A message file is always derived from the session and its checked ID.
  /// Never trust a database path when deleting or replacing a recording.
  Future<bool> isMessageFile(String sessionId, String messageId,
      String absolutePath) async {
    final expected = await fileFor(sessionId, messageId);
    return p.normalize(expected.absolute.path) ==
        p.normalize(File(absolutePath).absolute.path);
  }

  /// Recovers from app termination between recording/rename and SQLite commit.
  /// Only Phase 7's own file names are considered: older voice/Notes files are
  /// not touched, even when they are in the same session-scoped directory.
  Future<int> pruneUnreferencedAudio(Set<String> referencedPaths) async {
    final root = _injectedRoot ?? await getApplicationDocumentsDirectory();
    final voiceRoot = Directory(p.join(root.path, 'readmesh_voice'));
    if (!await voiceRoot.exists()) return 0;
    final referenced = referencedPaths
        .map((path) => p.normalize(File(path).absolute.path)).toSet();
    var removed = 0;
    await for (final entity in voiceRoot.list(recursive: true,
        followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!RegExp(r'^(draft_)?audio_[A-Za-z0-9_-]+\.m4a$').hasMatch(name)) {
        continue;
      }
      if (!referenced.contains(p.normalize(entity.absolute.path))) {
        await entity.delete();
        removed++;
      }
    }
    return removed;
  }

  Future<void> deleteSessionFiles(String sessionId) async {
    final folder = await sessionDirectory(sessionId);
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}
