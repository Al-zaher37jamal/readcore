import 'dart:io';

import 'package:flutter/services.dart';

/// Platform interface so repository/UI tests can use a fake recorder without
/// asking a desktop test runner for Android microphone permission.
abstract class VoiceAudioService {
  Future<bool> start(String absolutePath);
  Future<int> stop(); // recorded duration in milliseconds
  Future<void> cancel();
  Future<void> play(String absolutePath);
  Future<void> stopPlayback();
}

class AndroidVoiceAudioService implements VoiceAudioService {
  static const MethodChannel _channel = MethodChannel('readmesh/phase6_audio');

  static bool get isAvailable => Platform.isAndroid;

  @override
  Future<bool> start(String absolutePath) async {
    if (!isAvailable) throw UnsupportedError('Android microphone required');
    return await _channel.invokeMethod<bool>('startRecording',
        {'path': absolutePath}) ?? false;
  }

  @override
  Future<int> stop() async =>
      await _channel.invokeMethod<int>('stopRecording') ?? 0;

  @override
  Future<void> cancel() async {
    if (isAvailable) await _channel.invokeMethod<void>('cancelRecording');
  }

  @override
  Future<void> play(String absolutePath) async {
    if (!isAvailable) throw UnsupportedError('Android playback required');
    await _channel.invokeMethod<void>('playRecording', {'path': absolutePath});
  }

  @override
  Future<void> stopPlayback() async {
    if (isAvailable) await _channel.invokeMethod<void>('stopPlayback');
  }
}
