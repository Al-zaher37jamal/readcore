import 'dart:async';

import 'package:flutter/material.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/features/audio_messages/data/local_audio_service.dart';

String formatAudioDuration(int milliseconds) {
  final seconds = (milliseconds ~/ 1000).clamp(0, 359999);
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}

/// A local clip's controls rebuild in isolation; neither the message list's
/// stream nor the PDF viewer is refreshed as playback progress advances.
class AudioClipPlayer extends StatefulWidget {
  final String id;
  final String path;
  final int durationMs;
  final LocalAudioService? audio;
  final ValueChanged<Object>? onError;

  const AudioClipPlayer({super.key, required this.id, required this.path,
    required this.durationMs, this.audio, this.onError});

  @override
  State<AudioClipPlayer> createState() => _AudioClipPlayerState();
}

enum _PlaybackMode { idle, playing, paused }

class _AudioClipPlayerState extends State<AudioClipPlayer> {
  _PlaybackMode _mode = _PlaybackMode.idle;
  Timer? _ticker;
  bool _busy = false;
  bool _polling = false;
  int _positionMs = 0;
  int _epoch = 0;

  @override
  void didUpdateWidget(covariant AudioClipPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.audio != widget.audio) {
      _epoch++;
      _ticker?.cancel();
      if (_mode != _PlaybackMode.idle && oldWidget.audio != null) {
        unawaited(oldWidget.audio!.stopPlayback(oldWidget.path)
            .catchError((_) {}));
      }
      _mode = _PlaybackMode.idle;
      _positionMs = 0;
    }
  }

  @override
  void dispose() {
    _epoch++;
    _ticker?.cancel();
    if (_mode != _PlaybackMode.idle && widget.audio != null) {
      unawaited(widget.audio!.stopPlayback(widget.path).catchError((_) {}));
    }
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) =>
        unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    final audio = widget.audio;
    if (_polling || !mounted || audio == null || _mode == _PlaybackMode.idle) {
      return;
    }
    _polling = true;
    final epoch = _epoch;
    try {
      final state = await audio.playbackState();
      if (!mounted || epoch != _epoch) return;
      if (state.path != widget.path) {
        _ticker?.cancel();
        setState(() {
          _mode = _PlaybackMode.idle;
          _positionMs = 0;
        });
      } else {
        setState(() {
          _positionMs = state.positionMs.clamp(0, widget.durationMs).toInt();
          if (_mode == _PlaybackMode.playing && !state.isPlaying) {
            // Android releases a finished player; an externally paused player
            // is represented by the same path and is kept at its position.
            _mode = _PlaybackMode.paused;
            _ticker?.cancel();
          }
        });
      }
    } catch (error) {
      widget.onError?.call(error);
      _ticker?.cancel();
      if (mounted) setState(() => _mode = _PlaybackMode.idle);
    } finally {
      _polling = false;
    }
  }

  Future<void> _toggle() async {
    final audio = widget.audio;
    if (audio == null || _busy) return;
    _epoch++;
    setState(() => _busy = true);
    try {
      if (_mode == _PlaybackMode.idle) {
        await audio.play(widget.path);
      } else if (_mode == _PlaybackMode.playing) {
        await audio.pausePlayback();
      } else {
        final current = await audio.playbackState();
        if (current.path == widget.path) {
          // Resume the same native MediaPlayer and its preserved position.
          await audio.resumePlayback();
        } else {
          // Another tile may have taken over the single native player.
          // Never inadvertently resume that other person's recording.
          await audio.play(widget.path);
          _positionMs = 0;
        }
      }
      if (!mounted) return;
      setState(() => _mode = _mode == _PlaybackMode.playing
          ? _PlaybackMode.paused : _PlaybackMode.playing);
      if (_mode == _PlaybackMode.playing) {
        _startTicker();
      } else {
        _ticker?.cancel();
      }
      await _refresh();
    } catch (error) {
      widget.onError?.call(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    final audio = widget.audio;
    if (audio == null || _busy || _mode == _PlaybackMode.idle) return;
    _epoch++;
    setState(() => _busy = true);
    _ticker?.cancel();
    try {
      await audio.stopPlayback(widget.path);
      if (mounted) setState(() {
        _mode = _PlaybackMode.idle;
        _positionMs = 0;
      });
    } catch (error) {
      widget.onError?.call(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.durationMs;
    final l10n = AppLocalizations.of(context);
    return Row(children: [
      IconButton(
        key: Key('audio_play_${widget.id}'),
        icon: Icon(_mode == _PlaybackMode.playing
            ? Icons.pause : Icons.play_arrow),
        tooltip: l10n.tr(_mode == _PlaybackMode.playing ? 'audioPausePlayback' :
            _mode == _PlaybackMode.paused ? 'audioResumePlayback' :
                'audioPlay'),
        onPressed: widget.audio == null || _busy ? null : _toggle,
      ),
      Expanded(child: LinearProgressIndicator(
        key: Key('audio_progress_${widget.id}'),
        value: duration < 1 ? 0.0 :
            (_positionMs / duration).clamp(0.0, 1.0).toDouble(),
        minHeight: 5,
        backgroundColor: const Color(0xFFE2E8F0),
      )),
      const SizedBox(width: 8),
      Text(formatAudioDuration(duration), key: Key('audio_duration_${widget.id}'),
          style: const TextStyle(fontSize: 12)),
      if (_mode != _PlaybackMode.idle)
        IconButton(key: Key('audio_stop_${widget.id}'),
          icon: const Icon(Icons.stop, size: 20),
          tooltip: l10n.tr('audioStopPlayback'),
          onPressed: _busy ? null : _stop),
    ]);
  }
}
