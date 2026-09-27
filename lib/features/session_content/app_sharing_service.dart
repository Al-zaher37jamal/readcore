import 'dart:io';

import 'package:flutter/services.dart';

/// Android Sharesheet for a plain room code or the actually installed APK.
/// No cloud URL, no fictional bundled installer and no third-party plugin.
class AppSharingService {
  static const MethodChannel _channel = MethodChannel('readmesh/phase6_share');

  static String roomCodeText(String code, {required bool arabic}) => arabic
      ? 'انضم إلى جلسة القراءة في ReadMesh\n\nرمز الجلسة:\n$code\n\n'
        'افتح ReadMesh ثم اختر "الانضمام إلى جلسة" وأدخل الرمز.'
      : 'Join a reading session in ReadMesh\n\nSession code:\n$code\n\n'
        'Open ReadMesh, choose Join Session and enter the code.';

  static Future<void> shareRoomCode(String code, {required bool arabic}) async {
    if (!Platform.isAndroid) throw UnsupportedError('Android Share Sheet required');
    await _channel.invokeMethod<void>('shareText', {
      'text': roomCodeText(code, arabic: arabic),
    });
  }

  /// Shares the app's own installed base.apk using a read-only content URI.
  /// Returns false if no installed file is available; never claims success in
  /// that case. The receiver controls unknown-app installation permissions.
  static Future<bool> shareInstalledApk() async {
    if (!Platform.isAndroid) throw UnsupportedError('Android APK required');
    return await _channel.invokeMethod<bool>('shareInstalledApk') ?? false;
  }
}
