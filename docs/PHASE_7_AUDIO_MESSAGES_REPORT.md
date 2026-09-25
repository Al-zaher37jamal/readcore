# Phase 7 — رسائل صوتية محلية في Discussion

**الحالة: نُفّذ الكود والاختبارات المستهدفة، لكن قبول المرحلة غير مُتحقَّق بعد.** لا تتوفر أدوات Flutter/Dart/Java/Android SDK في بيئة العمل الحالية؛ لذلك لم تُشغَّل اختبارات Flutter فعليًا ولم يُنتَج APK. لم يُدفَع هذا العمل إلى GitHub.

## الملفات

- **جديد:** `lib/features/audio_messages/domain/audio_message.dart`، `lib/data/repositories/audio_message_repository.dart`، `lib/features/audio_messages/data/local_audio_service.dart`، `lib/features/audio_messages/presentation/audio_clip_player.dart`.
- **معدّل:** `lib/features/text_messages/presentation/text_messages_panel.dart` (نفس Composer النص/الصوت ونفس قائمة الصفحة)، `lib/features/text_messages/domain/text_message.dart`، `lib/data/repositories/message_repository.dart` (ترتيب الرسائل المختلطة عند تساوي الثانية)، `lib/data/storage/session_voice_store.dart` (فحص المسار وتنظيف ملفات Phase 7 غير المشار إليها)، `lib/data/database/tables/messages_table.dart` (تعليق النوع)، `lib/features/reader/pdf_reader_screen.dart` (حقن الاعتمادات للوحة الحالية)، `lib/core/di/injection.dart`، `lib/core/l10n/app_localizations.dart`، `android/app/src/main/kotlin/com/example/readmesh/MainActivity.kt`، وتعليق `android/app/src/main/AndroidManifest.xml`.
- **اختبارات جديدة:** `test/unit/phase7/audio_message_repository_test.dart`، `audio_message_panel_test.dart`، `audio_reader_integration_test.dart`، مع `fake_local_audio_service.dart` للاختبارات. لم تُغيَّر أذونات التطبيق أو اعتماداته.

## البيانات ومسار الملف

- يستخدم المستودع **جدول `messages` الحالي**: `message_type='audio'`، و`session_id`، و`page_number`، و`sender_id`/`sender_name`، و`created_at`/`updated_at`، و`voice_path`/`duration_ms`/`voice_sha256`/`voice_bytes`. لا جدول جديد، ولا تغيير لإصدار الهجرة 5، ولا كتابة للرسالة أثناء التسجيل أو المعاينة.
- مسار المسودة: `<Documents>/readmesh_voice/<أول 32 خانة من SHA-256(sessionId)>/draft_audio_<uuid>.m4a`؛ ومسار الرسالة بعد التأكيد: `.../audio_<uuid>.m4a`. الاسم والمسار مشتقان محليًا ويُتحقَّق منهما قبل الاستبدال/الحذف؛ الملف نفسه ليس داخل SQLite.
- تظهر رسائل النص والصوت من الجلسة والصفحة المحددتين فقط. الترتيب بـ`created_at` ثم `rowid` المشترك بين النوعين؛ يبقى نص Phase 6 وعمليات إنشائه وتعديله وحذفه مستقلة. الصوتيات لا تدخل مسار إرسال LAN القديم (`voice`) أو أي خدمة سحابية.
- **Save & Leave** يحتفظ بصفوف الرسائل وملفاتها ليستعيدها Continue Reading مع صفحة الـPDF المحفوظة. حذف سجل الجلسة الصريح يمسح مجلد الجلسة الموجود أصلًا. عند بدء التطبيق يُحذف فقط `draft_audio_*` أو `audio_*` غير المشار إليه بصف صوتي؛ ملفات `voice_*` القديمة لا تُلمس.

## Composer والتحكم الصوتي

`Text` (نص فارغ ⇒ ميكروفون؛ نص مكتوب ⇒ زر إرسال النص) → `Recording` (مؤقت/إلغاء/Pause/Stop) ↔ `Paused` (Resume على **نفس MediaRecorder والملف**/إلغاء/Stop) → `Preview` (Play/Pause/Resume/Stop، شريط تقدّم، مدة، حذف، إرسال) → `Text`.

- Stop يعرض المعاينة بعد فحص الملف ولا يُنشئ صفًا. Cancel أو تغيير الصفحة أو إغلاق اللوحة يحذف المسودة. عند Send يُنقَل الملف داخل مجلد الجلسة ثم يُدرَج صف SQLite؛ إذا فشل الإدراج تعود المسودة للمعاينة. عند الاستبدال يُفحص مالك الصف ومساره وتُستبدل الصفوف داخل معاملة واحدة ثم يُحذف الملف القديم. الحذف يتحقق من هوية المرسل ومسار الملف الخاص. الحالات الباقية بعد انقطاع التطبيق تُصلَح عند التشغيل التالي.
- تشغيل `AudioClipPlayer` يستخدم MediaPlayer المحلي وموضعه، ويتوقف عند مغادرة الصفحة. حفظ/تقدم/تشغيل الرسائل يعيد بناء اللوحة أو المشغّل فقط؛ `PdfPageView` شقيق لها في Reader، لا يُعاد تحميله بتحديثات الصوت.
- تستعمل Phase 7 قناة Android الصوتية الموجودة وتضيف أوامر مستقلة، مع إبقاء `VoiceAudioService.playRecording` القديم (Future ينتهي بنهاية التشغيل) صالحًا لواجهة Phase 6. لا أذونات جديدة. `MediaRecorder.pause/resume` يعملان على Android API 24+؛ على الإصدارات الأقدم تُعرض رسالة واضحة بأن Pause غير مدعوم ويستمر التسجيل، دون الادعاء بأن الاستئناف متاح هناك أو رفع `minSdk`.

## التحقق الفعلي في هذه البيئة

| الفحص | النتيجة |
|---|---|
| تحليل نحوي مستقل لـ16 ملف Dart متصل بالتغيير و`MainActivity.kt` | نجح بـtree-sitter؛ **ليس** `flutter analyze` ولا بناء Android |
| تجربة SQL مستقلة بـSQLite (INSERT، اختيار الصفحة/المالك، DELETE) | نجحت؛ لا تتحقق من Drift أو Flutter أثناء التشغيل |
| مطابقة مفاتيح الترجمة الإنجليزية/العربية الجديدة و`git diff --check` | نجحت |
| `flutter analyze` | **لم يُشغّل: `flutter: command not found` (exit 127)** |
| `flutter test test/unit/phase7/audio_message_repository_test.dart test/unit/phase7/audio_message_panel_test.dart test/unit/phase7/audio_reader_integration_test.dart test/unit/phase6/text_messages_repository_test.dart test/unit/phase6/text_messages_panel_test.dart test/unit/phase6/text_messages_reader_wiring_test.dart` | **لم يُشغّل: `flutter: command not found` (exit 127)**؛ لم تُطلب أو تُجرّب suite شاملة |
| `flutter build apk --debug` | **لم يُبنَ APK: `flutter: command not found` (exit 127)** |

للتحقق النهائي على بيئة **Flutter 3.24.5 / Dart 3.5.4** مع Android SDK: شغّل الأوامر الثلاثة أعلاه، ثم اختبر على جهاز Android API 24+ منح/رفض الميكروفون، Pause/Resume للملف نفسه، المعاينة ثم الإرسال، إلغاء المسودة والتنقل بين الصفحات، استبدال/حذف المالك، إعادة فتح الجلسة دون شبكة، وعدم إعادة تهيئة PDF. لا تُعد معايير القبول (خصوصًا التسجيل والتشغيل الحقيقي وAPK) مُثبتة حتى تنجح هذه الخطوات.
