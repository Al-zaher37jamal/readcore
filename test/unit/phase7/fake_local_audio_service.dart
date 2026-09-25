import 'dart:io';

import 'package:readmesh/features/audio_messages/data/local_audio_service.dart';

class FakeLocalAudioService implements LocalAudioService {
  String? recordingPath;
  String? playbackPath;
  bool recordingPaused = false;
  bool playing = false;
  int positionMs = 0;
  int cancelCalls = 0;
  int resumeCalls = 0;

  @override
  Future<bool> start(String path) async {
    recordingPath = path;
    recordingPaused = false;
    await File(path).writeAsBytes(List<int>.filled(256, 41), flush: true);
    return true;
  }

  @override
  Future<void> pauseRecording() async { recordingPaused = true; }

  @override
  Future<void> resumeRecording() async {
    resumeCalls++;
    recordingPaused = false;
    // Simulate Android's continued writing to the *same* .m4a file.
    await File(recordingPath!).writeAsBytes(List<int>.filled(64, 42),
        mode: FileMode.append, flush: true);
  }

  @override
  Future<int> stop() async { recordingPaused = false; return 2500; }

  @override
  Future<void> cancel() async { cancelCalls++; recordingPaused = false; }

  @override
  Future<void> play(String path) async {
    playbackPath = path;
    positionMs = 0;
    playing = true;
  }

  @override
  Future<void> pausePlayback() async { playing = false; }

  @override
  Future<void> resumePlayback() async { playing = true; }

  @override
  Future<void> stopPlayback(String path) async {
    if (playbackPath == path) {
      playbackPath = null;
      positionMs = 0;
      playing = false;
    }
  }

  @override
  Future<AudioPlaybackSnapshot> playbackState() async {
    if (playing) positionMs += 300;
    return AudioPlaybackSnapshot(path: playbackPath, positionMs: positionMs,
      durationMs: 2500, isPlaying: playing);
  }
}
