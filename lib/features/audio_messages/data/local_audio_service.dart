import 'dart:io';

import 'package:flutter/services.dart';

/// A snapshot from the local Android MediaPlayer, used to paint progress.
class AudioPlaybackSnapshot {
  final String? path;
  final int positionMs;
  final int durationMs;
  final bool isPlaying;

  const AudioPlaybackSnapshot({
    required this.path,
    required this.positionMs,
    required this.durationMs,
    required this.isPlaying,
  });

  factory AudioPlaybackSnapshot.fromMap(Map<String, dynamic>? values) =>
      AudioPlaybackSnapshot(
        path: values?['path'] as String?,
        positionMs: values?['positionMs'] as int? ?? 0,
        durationMs: values?['durationMs'] as int? ?? 0,
        isPlaying: values?['isPlaying'] as bool? ?? false,
      );
}

/// Only local microphone/file/player operations; no LAN, upload or sync.
/// Kept separate from the earlier SessionContentPanel voice interface so that
/// its legacy behavior and fake audio tests remain unchanged.
abstract class LocalAudioService {
  Future<bool> start(String absolutePath);
  Future<void> pauseRecording();
  Future<void> resumeRecording();
  Future<int> stop();
  Future<void> cancel();
  Future<void> play(String absolutePath);
  Future<void> pausePlayback();
  Future<void> resumePlayback();
  /// Stop only this file, so disposing another tile cannot stop the new one.
  Future<void> stopPlayback(String absolutePath);
  Future<AudioPlaybackSnapshot> playbackState();
}

class AndroidLocalAudioService implements LocalAudioService {
  // Extend the pre-existing Android recorder/player channel; no media package,
  // new permission or network service is introduced for Phase 7.
  static const MethodChannel _channel = MethodChannel('readmesh/phase6_audio');
  static bool get isAvailable => Platform.isAndroid;

  @override
  Future<bool> start(String absolutePath) async {
    if (!isAvailable) throw UnsupportedError('Android microphone required');
    return await _channel.invokeMethod<bool>(
      'startRecording', {'path': absolutePath}) ?? false;
  }

  @override
  Future<void> pauseRecording() =>
      _channel.invokeMethod<void>('pauseRecording');

  @override
  Future<void> resumeRecording() =>
      _channel.invokeMethod<void>('resumeRecording');

  @override
  Future<int> stop() async =>
      await _channel.invokeMethod<int>('stopRecording') ?? 0;

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancelRecording');

  @override
  Future<void> play(String absolutePath) => _channel.invokeMethod<void>(
      'startMessagePlayback', {'path': absolutePath});

  @override
  Future<void> pausePlayback() =>
      _channel.invokeMethod<void>('pauseMessagePlayback');

  @override
  Future<void> resumePlayback() =>
      _channel.invokeMethod<void>('resumeMessagePlayback');

  @override
  Future<void> stopPlayback(String absolutePath) => _channel.invokeMethod<void>(
      'stopMessagePlayback', {'path': absolutePath});

  @override
  Future<AudioPlaybackSnapshot> playbackState() async =>
      AudioPlaybackSnapshot.fromMap(
        await _channel.invokeMapMethod<String, dynamic>(
            'messagePlaybackState'),
      );
}
