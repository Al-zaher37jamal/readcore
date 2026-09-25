package com.example.readmesh

import android.Manifest
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Uses Android's own recorder, player and Sharesheet. No network or media plugin. */
class MainActivity : FlutterActivity() {
    private val audioPermissionRequest = 6046
    private var permissionResult: MethodChannel.Result? = null
    private var permissionFile: File? = null
    private var recorder: MediaRecorder? = null
    private var recordingFile: File? = null
    private var recordingStarted = 0L
    private var recordingPausedAt = 0L
    private var pausedDuration = 0L
    private var completedDuration: Int? = null
    private var player: MediaPlayer? = null
    private var playingFile: File? = null
    private var playbackPath: String? = null
    private var playbackResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "readmesh/phase6_share")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "shareText" -> {
                            val text = call.argument<String>("text") ?: ""
                            if (text.isBlank()) throw IllegalArgumentException("Empty room code")
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            startActivity(Intent.createChooser(intent, "Share ReadMesh room code"))
                            result.success(null)
                        }
                        "shareInstalledApk" -> {
                            val apk = File(applicationInfo.sourceDir)
                            // A split install is not a standalone APK; do not
                            // send an incomplete base.apk as a working installer.
                            if (!applicationInfo.splitSourceDirs.isNullOrEmpty() ||
                                !apk.isFile || apk.length() == 0L) {
                                result.success(false)
                            } else {
                                val uri = Uri.parse("content://$packageName.apkprovider/installed.apk")
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = "application/vnd.android.package-archive"
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    clipData = ClipData.newRawUri("ReadMesh.apk", uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                startActivity(Intent.createChooser(intent, "Share ReadMesh APK"))
                                result.success(true)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("SHARE_FAILED", error.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "readmesh/phase6_audio")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "startRecording" -> {
                            val file = privateVoiceFile(call.argument<String>("path"))
                            if (file == null || recorder != null || permissionResult != null) {
                                result.error("RECORD_FAILED", "Invalid recording location or active recording", null)
                            } else if (Build.VERSION.SDK_INT >= 23 &&
                                checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                                permissionResult = result
                                permissionFile = file
                                requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), audioPermissionRequest)
                            } else {
                                beginRecording(file, result)
                            }
                        }
                        "stopRecording" -> {
                            val duration = finishRecording()
                            if (duration == null) {
                                result.error("RECORD_FAILED", "No valid recording", null)
                            } else {
                                completedDuration = null
                                recordingFile = null
                                result.success(duration)
                            }
                        }
                        "pauseRecording" -> {
                            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
                                result.error("PAUSE_UNSUPPORTED", "Recording pause requires Android 7+", null)
                            } else {
                                val active = recorder ?: throw IllegalStateException("No recording")
                                if (recordingPausedAt == 0L) {
                                    active.pause()
                                    recordingPausedAt = SystemClock.elapsedRealtime()
                                }
                                result.success(null)
                            }
                        }
                        "resumeRecording" -> {
                            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
                                result.error("PAUSE_UNSUPPORTED", "Recording resume requires Android 7+", null)
                            } else {
                                val active = recorder ?: throw IllegalStateException("No recording")
                                if (recordingPausedAt == 0L) {
                                    throw IllegalStateException("Recording is not paused")
                                }
                                active.resume()
                                pausedDuration += SystemClock.elapsedRealtime() - recordingPausedAt
                                recordingPausedAt = 0L
                                result.success(null)
                            }
                        }
                        "cancelRecording" -> {
                            cancelRecording()
                            result.success(null)
                        }
                        "playRecording" -> {
                            val requestedPath = call.argument<String>("path")
                            val file = privateVoiceFile(requestedPath)
                            if (file == null || !file.isFile) {
                                result.error("PLAY_FAILED", "Audio file not found", null)
                            } else {
                                // Legacy caller expects this Future to complete when playback ends.
                                beginPlayback(file, result, requestedPath ?: file.absolutePath)
                            }
                        }
                        "startMessagePlayback" -> {
                            val requestedPath = call.argument<String>("path")
                            val file = privateVoiceFile(requestedPath)
                            if (file == null || !file.isFile) {
                                result.error("PLAY_FAILED", "Audio file not found", null)
                            } else {
                                // Phase 7 returns immediately for progress/pause controls.
                                beginPlayback(file, null, requestedPath ?: file.absolutePath)
                                result.success(null)
                            }
                        }
                        "pauseMessagePlayback" -> {
                            val active = player ?: throw IllegalStateException("No audio playing")
                            if (active.isPlaying) active.pause()
                            result.success(null)
                        }
                        "resumeMessagePlayback" -> {
                            val active = player ?: throw IllegalStateException("No audio to resume")
                            if (!active.isPlaying) active.start() // same MediaPlayer, same position
                            result.success(null)
                        }
                        "messagePlaybackState" -> {
                            val active = player
                            result.success(mapOf(
                                "path" to playbackPath,
                                "positionMs" to (active?.currentPosition ?: 0),
                                "durationMs" to (active?.duration ?: 0),
                                "isPlaying" to (active?.isPlaying ?: false)
                            ))
                        }
                        "stopMessagePlayback" -> {
                            val file = privateVoiceFile(call.argument<String>("path"))
                            if (file != null && playingFile == file) stopPlayer()
                            result.success(null)
                        }
                        "stopPlayback" -> {
                            stopPlayer()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    if (playbackResult === result) {
                        playbackResult = null
                        player?.release()
                        player = null
                        playingFile = null
                        playbackPath = null
                    }
                    result.error("AUDIO_FAILED", error.message, null)
                }
            }
    }

    private fun privateVoiceFile(raw: String?): File? {
        if (raw.isNullOrBlank()) return null
        val root = File(applicationInfo.dataDir, "app_flutter/readmesh_voice").canonicalFile
        val file = File(raw).canonicalFile
        return if (file.path.startsWith(root.path + File.separator) &&
            file.name.endsWith(".m4a")) file else null
    }

    @Suppress("DEPRECATION")
    private fun newRecorder(): MediaRecorder =
        if (Build.VERSION.SDK_INT >= 31) MediaRecorder(this) else MediaRecorder()

    private fun beginRecording(file: File, result: MethodChannel.Result) {
        try {
            if (!file.parentFile!!.isDirectory) file.parentFile!!.mkdirs()
            completedDuration = null
            val current = newRecorder()
            recorder = current
            recordingFile = file
            current.setAudioSource(MediaRecorder.AudioSource.MIC)
            current.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            current.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            current.setAudioChannels(1)
            current.setAudioSamplingRate(22050)
            current.setAudioEncodingBitRate(48000)
            current.setOutputFile(file.absolutePath)
            current.setMaxDuration(65000)
            current.setOnInfoListener { _, what, _ ->
                if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                    completedDuration = finishRecording()
                }
            }
            current.prepare()
            current.start()
            recordingStarted = SystemClock.elapsedRealtime()
            recordingPausedAt = 0L
            pausedDuration = 0L
            result.success(true)
        } catch (error: Exception) {
            recorder?.release()
            recorder = null
            recordingFile?.delete()
            recordingFile = null
            result.error("RECORD_FAILED", error.message, null)
        }
    }

    private fun finishRecording(): Int? {
        val current = recorder ?: return completedDuration
        val now = SystemClock.elapsedRealtime()
        val lastPause = if (recordingPausedAt > 0L) now - recordingPausedAt else 0L
        val duration = (now - recordingStarted - pausedDuration - lastPause)
            .coerceIn(1L, 65000L).toInt()
        return try {
            current.stop()
            duration
        } catch (_: Exception) {
            recordingFile?.delete()
            null
        } finally {
            current.release()
            recorder = null
            recordingPausedAt = 0L
            pausedDuration = 0L
        }
    }

    private fun cancelRecording() {
        // A permission dialog may outlive the Flutter widget that requested it.
        permissionResult?.success(false)
        permissionResult = null
        permissionFile = null
        if (recorder != null) finishRecording()
        recordingFile?.delete()
        recordingFile = null
        completedDuration = null
    }

    private fun beginPlayback(file: File, waiting: MethodChannel.Result?,
            requestedPath: String) {
        stopPlayer()
        val current = MediaPlayer()
        player = current
        playingFile = file
        // Report the same path Dart supplied even if /data/user/0 has a
        // different canonical alias on this device.
        playbackPath = requestedPath
        playbackResult = waiting
        try {
            current.setDataSource(file.absolutePath)
            current.setOnCompletionListener { stopPlayer() }
            current.setOnErrorListener { _, _, _ ->
                val pending = playbackResult
                playbackResult = null
                player?.release()
                player = null
                playingFile = null
                playbackPath = null
                pending?.error("PLAY_FAILED", "Cannot play recording", null)
                true
            }
            current.prepare()
            current.start()
        } catch (error: Exception) {
            current.release()
            player = null
            playingFile = null
            playbackPath = null
            playbackResult = null
            throw error
        }
    }

    private fun stopPlayer() {
        val waiting = playbackResult
        playbackResult = null
        player?.release()
        player = null
        playingFile = null
        playbackPath = null
        waiting?.success(null)
    }

    override fun onRequestPermissionsResult(requestCode: Int,
            permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != audioPermissionRequest) return
        val pending = permissionResult
        val file = permissionFile
        permissionResult = null
        permissionFile = null
        if (pending != null && file != null && grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            beginRecording(file, pending)
        } else {
            pending?.success(false)
        }
    }

    override fun onDestroy() {
        cancelRecording()
        stopPlayer()
        super.onDestroy()
    }
}
