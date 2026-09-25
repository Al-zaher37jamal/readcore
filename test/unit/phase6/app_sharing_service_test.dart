import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/features/session_content/app_sharing_service.dart';

void main() {
  test('room-code Share Sheet text carries only LAN join instructions', () {
    final ar = AppSharingService.roomCodeText('RM-3721', arabic: true);
    final en = AppSharingService.roomCodeText('RM-3721', arabic: false);
    expect(ar, contains('رمز الجلسة:\nRM-3721'));
    expect(ar, contains('الانضمام إلى جلسة'));
    expect(en, contains('Session code:\nRM-3721'));
    expect(en, contains('Join Session'));
    expect(ar.toLowerCase(), isNot(contains('https://')));
    expect(en.toLowerCase(), isNot(contains('https://')));
  });

  test('desktop does not pretend it can share an Android installed APK', () async {
    if (!Platform.isAndroid) {
      await expectLater(AppSharingService.shareInstalledApk(),
          throwsUnsupportedError);
    }
  });
}
