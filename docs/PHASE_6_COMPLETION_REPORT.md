# ReadMesh — تقرير تنفيذ Phase 6

> **ملاحظة أحدث:** يصف هذا التقرير تنفيذ Notes/Voice/LAN الأسبق. بعد طلب الرسائل النصية المحلية صار Reader الافتراضي يعرض `TextMessagesPanel` ضمن `Scaffold.body` بدل إظهار أزرار Notes/Highlight أو نافذة المحتوى القديمة؛ تفاصيل المسار والاختبارات غير المُشغّلة في [تقرير الرسائل النصية](PHASE_6_TEXT_MESSAGES_REPORT.md). كود الواجهة القديمة باقٍ باختيار صريح فقط. الحالة العامة **NOT COMPLETE** حتى اختبار Flutter وAPK على Android.

**التاريخ:** 2026-09-24
**الفرع:** `arena/01a0cd05-readcore`
**مرجع المقارنة:** `7409cca7c5ae64fb2ea843237ce4d5c90a412e46`
**الحالة:** **NOT COMPLETE** — تغييرات التنفيذ والاختبارات المكتوبة موجودة، لكن لم تُحلّل أو تُشغّل بـFlutter، ولم يُبنَ APK، ولم تُجرّب على هاتفين. لا تمثل هذه الوثيقة إثبات قبول على الأجهزة.

## تشخيص الـAPK الذي اختُبر ولم تظهر فيه الإضافات

- **قبل هذه المعالجة:** `git branch --show-current` = `arena/01a0cd05-readcore`، و`HEAD` و`main` و`origin/main` = `7409cca7c5ae64fb2ea843237ce4d5c90a412e46`. فحص `git ls-remote origin` أعاد `main` فقط عند الـSHA نفسه، لا فرع Arena منشورًا. كانت تغييرات Phase 6 الإضافية **35 مدخلًا في `git status --short` (بعضها مجلد غير متتبَّع يحوي عدة ملفات)، غير مُدرجة في أي commit**؛ أي بناء من `main` لا يحتويها. سيصبح commit التسليم مرجعًا يمكن التحقق منه عبر `git log -1 --format=%H` على فرع Arena؛ لا يصير `main` محدثًا إلا بعد مراجعة/دمج منفصل.
- **دليل غياب الواجهة في `main`:** `git show main:lib/main.dart` يبيّن تبويب My Sessions القديم، و`git show main:lib/features/reader/pdf_reader_screen.dart` لا يحتوي `reader_notes_discussion`/`reader_highlight`. كذلك لا يوجد أصلًا `lib/features/session_content/session_content_panel.dart` أو `session_content_sync.dart` في شجرة `main`. أما شجرة العمل الحالية: `main.dart` يربط تبويب My Sessions، و`setupLocator()` يسجّل محتوى Phase 6 والصوت، و`PdfReaderScreen` ينشئ `SessionContentSync` ويعرض أزرار Notes/Highlight، و`RoomDetailScreen` يعرض الرمز والمشاركة، واللوحة تعرض Pin/Discussion/Voice. **الغياب في APK يتوافق مع بناء نسخة لا تحتوي التغييرات، لكن لا يوجد APK المستخدم ولا SQLite هاتفه هنا لإثبات محتواه أو حالة جلسته حرفيًا.** إصدار التطبيق في `pubspec.yaml` باقٍ `1.0.0+1` ولا يثبت SHA البناء.
- **المسار القديم في `main`:** زر Save في القارئ يستدعي `saveAndLeaveSession`، لكن `_handleSaveAndLeave` يبتلع كل استثناء ويخرج من الشاشة مهما كانت نتيجة الكتابة؛ هكذا قد يفشل الحفظ دون إنذار. لا دليل يثبت أن SQLite هاتف المستخدم حملت `ended` بالفعل؛ التصرّف الظاهر وحده لا يكفي. في الكود الذي عولج هنا، زر الرجوع → Save → انتظار حفظ التقدم → **UPDATE ذري ومشروط** لـ`status='saved'` وصفحة/وقت SQLite → فحص نتيجة الكتابة → بث `sessionSaved`/إغلاق LAN → خروج. أما End فيمر وحده عبر `endReadingSession` → `status='ended'` وبث `sessionEnded`. لا يتم الخروج عند إخفاق Save.
- **إصلاح مسار الاستئناف:** Host لـGroup Resume يبدأ socket جديدًا ويربط TCP أولًا، ثم يغيّر `saved → active` بنفس session ID، ثم ينشر UDP؛ عند فشل الربط تبقى الجلسة `saved` ولا يظهر Host وهمي. Solo Resume يحتفظ بنفس session ID وتقدّم الصفحة، وMy Sessions ما زال ظاهرًا في navigation. تُرفض كتابة `ended/saved` عبر `updateSessionStatus` العامة، حتى في `LanSyncCoordinator`، وتستخدم الرسائل المعتمدة من Host دالتي Save/End الصريحتين. أُضيفت اختبارات SQLite بعد إغلاق/إعادة فتح الملف واختبارات ربط واجهة Reader وحالتي نجاح/فشل Group Resume، **ولم تُنفّذ بعد**.
- **لتحديد APK المستخدم:** لا يوجد ملف `.apk` في checkout، ولا سجل بناء مرتبط به. احتفظ بـ`git rev-parse HEAD` و`sha256sum build/app/outputs/flutter-apk/app-debug.apk` وقت البناء من فرع التسليم بعد `git status --short`، ثم قارن SHA وملف APK الذي ثُبِّت فعلاً. لا تصفح الكود وحده يثبت من أي commit بُني APK خارجي؛ بعد دمج التغييرات في `main` يلزم بناء APK جديد وإعادة تثبيته دون حذف بيانات PDF/SQLite، ثم قراءة `sessions.status` للتحقق على الجهاز.

## 1. Implemented — ما أُضيف إلى الكود (غير متحقق منه تشغيليًا)

- **الجلسات:** Save & Leave يحفظ التقدم والحالة `saved` دون End؛ End وحده يغيّرها إلى `ended` ويوقف TCP/UDP ويفصل الأعضاء. My Sessions يعرض النشطة/المحفوظة/المنتهية ويستأنف الجلسة نفسها من الصفحة المحلية؛ الإنهاء يمنع الاستئناف. عند التشغيل البارد تُحوَّل الجلسات التي تركها الإغلاق المفاجئ `active/paused/created` إلى `saved` قبل بناء الواجهات. Library Read Now يبقى قراءة محلية ويُنشئ سجل Solo جديدًا إذا كان السابق محفوظًا/منتهيًا؛ My Sessions → Resume يعيد **السجل نفسه**. حذف السجل محفوظ/منتهٍ فقط، ولا يزيل ملف الكتاب.
- **Group/LAN:** يستأنف المنظم Host جديدًا على TCP 40404، مع UDP 40405 وعنوان LAN الحالي، مستخدمًا نفس رمز الجلسة والصفحة. يمكن الانضمام بالرمز عبر UDP discovery، وانتظار إعلان جديد قليلًا، أو إدخال IP:port يدويًا. My Sessions يبحث أيضًا عن Host جديد قبل طلب IP. تبقى `joinAck` و`stateSnapshot` وHost-authoritative page/status كما كانت؛ قطع الاتصال وحده لا ينهي الجلسة. يظهر تقدم ووقت كل جهاز في قائمة أعضاء الغرفة.
- **المحتوى:** مستودع SQLite للملاحظات الخاصة/المشتركة، تثبيت الملاحظات، التظليل الملون بإحداثيات نسبية للصفحة، نقاش نصي/Emoji لكل صفحة، واستعادة العناصر المحلية بعد الاستئناف. داخل قارئ pdfx لوحة ثابتة الارتفاع بمساحتي ملاحظات/نقاش قابلتين للتمرير مع Scrollbar. تختار التظليل الشخصي/المشترك بالسحب فوق صفحة PDF؛ العناصر المشتركة تُرسل وتُعاد عبر TCP، والخاصة لا تُرسل. منطقة التظليل تعتمد أبعاد صفحة PDF في الوضع fit-to-page، وليس مساحة الشاشة كلها.
- **الصوت والمشاركة:** Android `MediaRecorder`/`MediaPlayer` مع طلب `RECORD_AUDIO` وقت التسجيل، Start/Stop/Cancel والمدة والتشغيل؛ ملف M4A محلي، وبيانات وصفية في SQLite. صوت LAN مجزأ ومحكوم بالحجم ويُتحقق من SHA-256 قبل التخزين، ويعاد إرساله عند الاتصال. مشاركة رمز الغرفة عبر Android Share Sheet. مشاركة **ملف التطبيق المثبت فعليًا فقط** عبر ContentProvider للقراءة؛ يرفض التثبيت المجزأ أو الملف غير الموجود مع توجيه للحصول على APK موحد وموقع، ولا يصنع APK وهميًا.
- **المكتبة:** أبقيت زر **إضافة ملف PDF** الظاهر أعلى الشاشة فقط؛ أزلت الأيقونة وFAB وزر الحالة الفارغة المكررة دون إزالة ملف الاختيار/الاستيراد أو زر PDF التجريبي المختلف.
- **Phase 1–5:** لم أبدّل Flutter/Dart أو `pdfx: 2.8.0` أو مكتبة PDF أو قاعدة البيانات أو بنية LAN، ولم أضف Cloud/Phase 7 أو تطبيق iOS أصليًا.

## 2. Modified Files

- `lib/main.dart`; `lib/core/di/injection.dart`; `lib/core/l10n/app_localizations.dart`.
- `lib/data/database/migrations/schema_migrations.dart`; `lib/data/database/tables/notes_table.dart`; `lib/data/database/tables/messages_table.dart`.
- `lib/data/repositories/session_repository.dart`; `lib/data/repositories/participant_reading_time_repository.dart`; **جديد:** `lib/data/repositories/session_content_repository.dart`؛ **جديد:** `lib/data/storage/session_voice_store.dart`.
- `lib/features/lan/lan_discovery_service.dart`; `lan_host_server.dart`; `lan_participant_client.dart`; `lan_message.dart`; `lan_sync_coordinator.dart` (توجيه Save/End الصريح)؛ **جديد:** `session_content_sync.dart` (جميعها تحت `lib/features/lan/`).
- `lib/features/reader/pdf_reader_screen.dart`; `pdf_page_view.dart`; `lib/features/room/local_room_service.dart`; `room_detail_screen.dart`; `rooms_screen.dart`; `lib/features/session_history/my_sessions_screen.dart`; `lib/features/library/pdf_library_screen.dart`.
- **جديد:** `lib/features/session_content/app_sharing_service.dart`; `voice_audio_service.dart`; `session_content_panel.dart`.
- `android/app/src/main/AndroidManifest.xml`; `android/app/src/main/kotlin/com/example/readmesh/MainActivity.kt`; **جديد:** `android/app/src/main/kotlin/com/example/readmesh/ReadMeshApkProvider.kt`.
- `test/unit/phase5/library_import_and_sync_test.dart`; `test/unit/phase6/session_history_test.dart`؛ **جديد:** `test/unit/phase6/phase6_regression_test.dart`, `session_content_repository_test.dart`, `session_content_lan_test.dart`, `session_content_panel_test.dart`, `room_code_discovery_test.dart`, `app_sharing_service_test.dart`؛ وهذا التقرير.

## 3. Database Changes

- قاعدة **Drift/SQLite نفسها**؛ الإصدار الحالي للمخطط `4`. تستبقي migration الإصدار `3` حقول الجلسة (`last_page`, `total_pages`, `last_activity_at`, `session_type`, `timer_enabled`, `stats_enabled`). أضاف الإصدار `4` إلى `notes`: `session_id` (nullable لحماية ملاحظات الكتب القديمة)، `note_kind`, `visibility`, `is_pinned`, `region_width`, `region_height`؛ وإلى `messages`: `page_number`, `voice_path`, `duration_ms`, `voice_sha256`, `voice_bytes`، مع فهارس session/page. الإحداثيات `position_x/position_y` كانت موجودة أصلًا.
- تستعمل `reading_progress` تقدمًا منفصلًا لكل device/session؛ `participant_reading_time` وقتًا تراكميًا منفصلًا عن عرض Timer/Statistics، مع تحديثات محلية ذرية وقيمة Host LAN تصاعدية لا تتناقص. Notes/Messages/Time تُحذف بمفتاح session عند حذف التاريخ؛ Books/PDF لا تُحذف.
- حاليًا تعتمد أعمدة المحتوى الجديدة استعلامات Drift الخام داخل `AppDatabase.writeTx` وmigration يفحص الأعمدة الموجودة؛ **لم يُعَد توليد `app_database.g.dart`** لأن Dart/Flutter/build_runner غير متاح. يجب تشغيل analyzer/tests والتحقق من ترقية قاعدة قديمة على جهاز قبل الاعتماد على الهجرة.

## 4. LAN Protocol Changes

رسائل إضافية فقط عبر TCP الموجود: `contentUpsert` (ملاحظة/تظليل/نص/بيانات الصوت)، `voiceChunk` (M4A/base64 مجزأ مع فحص SHA-256)، `participantProgress`، `participantTime` (ثوانٍ تراكمية). يتأكد Host من هوية socket، يُعيد المحتوى المشترك عند join/reconnect، ولا يُرحِّل ملاحظات شخصية أو مسارات الملفات الخاصة. لم تتغير أسماء رسائل `join`, `joinAck`, `stateSnapshot`, `pageChanged`, `sessionStarted`, `sessionPaused`, `sessionResumed`, `sessionSaved`, `sessionEnded`, `leave`, `ping`, `pong`. لا منفذ جديد؛ TCP **40404** وUDP **40405**. الاختبارات الحقيقية للشبكة/الأجهزة لا تزال مطلوبة.

## 5. Storage

| البيانات | الموضع |
|---|---|
| PDF | ملفات محلية في `getApplicationDocumentsDirectory()/books/` وفق `BookFileManager`؛ مراجع/تجزئة SHA-256 في SQLite `books`. |
| Sessions, progress, reading time, notes, highlights, pins, discussion, Emoji, voice metadata | `getApplicationDocumentsDirectory()/readmesh.db`، ضمن الجداول الحالية. لا BLOB للصوت. |
| Voice M4A | `getApplicationDocumentsDirectory()/readmesh_voice/<SHA-256(session-id)[:32]>/<voice-id>.m4a`، ونسخ LAN تستقر بعد فحص التجزئة؛ حذف التاريخ يزيل مجلد صوت الجلسة فقط. |
| APK عند المشاركة | **`applicationInfo.sourceDir`** الفعلي عبر URI مؤقت read-only، وفقط عندما يكون APK مستقلًا وموجودًا؛ ليس ملفًا مرفقًا داخل المشروع. |

## 6. Tests Passed

- `git diff --check`: ناجح، لا أخطاء whitespace.
- فحص **نحوي فقط** بـ tree-sitter لعدد **95 ملف Dart** في `lib/test/integration_test`: 0 أخطاء syntax عند آخر تشغيل. **لا يفحص الأنواع أو Flutter ولا ينفّذ اختبارًا واحدًا.**
- **اختبارات Flutter المنفّذة والناجحة: لا يوجد** في بيئة Arena الحالية.

## 7. Tests Not Run

- كُتبت/حُدثت اختبارات Phase 6 للوصول إلى **42 تعريف test/testWidgets** عبر ملفات Phase 6، منها SQLite file-backed/restart/history/private/shared/pin/highlight/voice/time، واسترجاع LAN TCP loopback لثلاثة أطراف، وUDP code discovery، وواجهة التمرير/Emoji والتسجيل بمسجل وهمي، ونص مشاركة الرمز. توجد كذلك اختبارات Phase 5 السابقة المعدّلة لتوقع زر PDF واحد. **كلها غير منفّذة**؛ وجودها ليس PASS.
- المحاولات: `flutter --version`, `flutter pub get`, `flutter analyze`, `flutter test test/unit/phase6/`, `flutter build apk --debug` انتهت جميعها بكود **127: `flutter: command not found`**. لا Android SDK ولا جهاز/محاكي مثبت في بيئة التنفيذ. يجب أيضًا تشغيل `flutter test` كاملًا، اختبار migration من قاعدة قديمة، واختبارات Kotlin/Android على الجهاز، واختبار هاتفين LAN حقيقي.

## 8. Build

**لا يوجد APK مبني أو مثبت أو مُشارك من هذه البيئة.** `build/app/outputs/flutter-apk/app-debug.apk` غير موجود. المطلوب على جهاز تطوير متوافق: Flutter **3.24.5** / Dart **3.5.4**، `flutter pub get && flutter analyze && flutter test && flutter build apk --debug`، ثم التأكد من وجود وحجم APK وتجربة تثبيته على جهاز Android آخر. لا يُعتَمد الزر الأصلي لمشاركة APK قبل تجريب تطبيق مُثبت فعليًا.

## 9. Remaining Issues / خطوات القبول على الأجهزة

1. **Blocked:** لم تُجرَ عملية analyze أو compile لـKotlin/Flutter، اختبارات الوحدة والتكامل، ترقية SQLite من قاعدة قديمة فعلًا، إنشاء/تثبيت APK، أو اختبار هاتفين. أي خطأ compilation/runtime محتمل حتى تنفيذها وإصلاحه.
2. **تظليل pdfx:** الإحداثيات مضبوطة على صفحة PDF عند fit-to-page؛ التكبير/تحريك الصفحة (pinch/zoom) ليس مربوطًا بتحويل Overlay بعد التكبير، فيحتاج اختبارًا أو تحسينًا قبل اعتبار تطابق مناطق التظليل عبر جميع أوضاع العرض مكتملًا.
3. **نقل PDF غير موجود في Phase 6:** الاستيراد المحلي للملف نفسه مطلوب على الهاتفين كما في بنية Phase 2–5؛ عند أول اتصال عن بُعد ومع وجود كتب مختلفة قد يختار placeholder أول كتاب محلي بدل مطابقة SHA-256 كتاب Host. ينبغي اختبار/معالجة اختيار الكتاب قبل إثبات سيناريو قارئ واحد متزامن.
4. **وقت الإغلاق القسري:** تسجيل الوقت أثناء القراءة كل 15 ثانية وعند تعليق/مغادرة الشاشة؛ قتل العملية دون lifecycle قد يُفقد آخر ثوانٍ قليلة، لكن استئناف الجلسة والتقدم المُحفوظ والملفات مستقلون عن End.
5. مشاركة APK مقصورة على تثبيت APK مستقل؛ Play split APK يتطلب ملف توزيع موحدًا وموقعًا من القناة الرسمية، لا يصلح إرسال `base.apk` وحده. توفر Quick Share/Bluetooth/WhatsApp/Telegram يعتمد على التطبيقات المستقبِلة ونوع الملف؛ لم يُختبر.

**سيناريو الهاتفين المطلوب، ولم يُنفّذ هنا:** ثبّت **نفس APK** واستورد **نفس PDF** على A/B؛ على A أنشئ Group → افتح القارئ → اذهب للصفحة 10 → أضف Note مشتركة وثبّتها → تظليلًا مشتركًا → رسالة/Emoji → سجّل Voice وشغّله → Save & Leave. أغلق وافتح التطبيقين بعد يوم/أسبوع؛ من My Sessions يستأنف A **نفس** الغرفة والصفحة ويعرض Host IP الحالي/رمزها ويشارك الرمز. على B ادخل Rooms برمز الغرفة فقط، تحقّق من `joinAck`/snapshot والمحتوى المشترك على **الصفحة 10 وحدها** وأن ملاحظات A الخاصة لا تظهر؛ إذا حُجب UDP استخدم IP:port اليدوي. اقطع Wi‑Fi مؤقتًا ثم أعده لتختبر reconnect وتقدم/وقت B؛ أجرب Timer ON/Stats OFF والعكس، Pause/Resume؛ أنهِ من A وحده وتحقق من انقطاع B، منع join، بقاء PDF والتاريخ، ثم حذف تاريخ الجلسة دون إزالة الكتاب أو PDF. افحص مشاركة الـAPK وتثبيته على هاتف ثانٍ فعلًا وسجل النتائج قبل تغيير الحالة إلى COMPLETE.

### 52 بند قبول: كلها غير متحقق منها عمليًا

| # | بند الاختبار المطلوب | # | بند الاختبار المطلوب |
|---:|---|---:|---|
| 1 | Solo import/قراءة محلية | 2 | Group إنشاء واختيار PDF |
| 3 | حفظ الصفحة 10 وإجمالي الصفحات | 4 | حفظ last_activity والتاريخ |
| 5 | Save & Leave لا ينهي | 6 | إيقاف Host/اتصال LAN بأمان |
| 7 | إغلاق التطبيق → saved عند العودة | 8 | My Sessions يعرض الحالة الصحيحة |
| 9 | My Sessions العنوان واسم الكتاب | 10 | My Sessions Solo/Group والتاريخ |
| 11 | استئناف الصفحة نفسها بعد أسبوع | 12 | Library يقرأ PDF مستقلًا عن Resume |
| 13 | End فقط ينهي الجلسة | 14 | End يفصل الجميع ويوقف discovery |
| 15 | End يمنع إعادة join | 16 | End يحتفظ بالسجل وPDF |
| 17 | Resume Group بنفس session ID | 18 | Host جديد/IP حالي/40404 |
| 19 | إعلان UDP 40405 | 20 | انضمام بكود فقط |
| 21 | fallback عنوان IP يدوي | 22 | joinAck/stateSnapshot أصليان |
| 23 | حفظ دور Host/Participant | 24 | reconnect أثناء LAN وانقطاع عابر |
| 25 | حفظ تقدم كل جهاز مستقلاً | 26 | سياسة Host authoritative للصفحة |
| 27 | قراءة وقت كل جهاز مستقلاً | 28 | Timer ON/Statistics OFF |
| 29 | Timer OFF/Statistics ON | 30 | استعادة flags بعد الاستئناف |
| 31 | ملاحظة صفحة صحيحة | 32 | Personal لا تظهر للآخرين |
| 33 | Shared ترحل عبر LAN | 34 | Pin يظهر لدى المجموعة |
| 35 | Pin لا يظهر بالصفحات الأخرى | 36 | استعادة Notes/Pin بعد حفظ |
| 37 | Highlight يُحفظ بإحداثيات ولون | 38 | Shared Highlight يظهر بصفحة محددة |
| 39 | استعادة Highlights بعد أسبوع | 40 | Discussion نصي لصفحة |
| 41 | Emoji يبقى داخل الرسالة | 42 | نقاش LAN وscrollbar كثيف |
| 43 | تسجيل صوت حقيقي وإذن MIC | 44 | إظهار المدة/إيقاف التسجيل |
| 45 | إلغاء التسجيل والتنظيف | 46 | تشغيل M4A محفوظ |
| 47 | نقل صوت مُتحقَّق SHA-256 | 48 | استعادة/إعادة إرسال الصوت |
| 49 | Share Sheet لرمز الجلسة | 50 | زر إضافة PDF واحد والمستورد يعمل |
| 51 | حذف سجل فقط والكتاب/الملف باقٍ | 52 | بناء/تثبيت/مشاركة APK حقيقي بين هاتفين |

**حالة البنود 1–52: NOT RUN / BLOCKED** إلى حين تنفيذ Flutter والاختبارات العملية حسب البند. الاختبارات المكتوبة تحقق أجزاء من المنطق برمجيًا عند توفر الأداة؛ لا تحول أي بند إلى PASS بذاتها.

## 10. Phase 6 Status

# NOT COMPLETE

توقف العمل عند Phase 6 فقط؛ لا Phase 7 ولا Online Rooms ولا Cloud/Supabase/PostgreSQL. عند توفر Flutter/Android SDK والأجهزة، نفّذ الفحوص، أصلح الأخطاء الفعلية، ثم أعد تقريرًا قائمًا على النتائج لا على وجود الكود.
