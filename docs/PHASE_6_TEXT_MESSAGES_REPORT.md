# Phase 6 — Text Messages: تنفيذ محلي يحتاج تحقق Flutter/Android

## الفحص قبل التعديل

- المعمارية الحالية: `get_it` + `StatefulWidget`، وليس Riverpod؛ Drift/SQLite ومخزن PDF محلي، مع `BookRepository` و`SessionRepository` و`ReadingProgressRepository` و`DeviceService`.
- `messages` جدول موجود سلفًا بربط FK إلى `sessions`، ويحوي الهوية والمُرسل والمحتوى ووقت الإنشاء. Phase 6 السابقة أضافت `page_number` بترحيل v4؛ ملف Drift المولَّد والمحفوظ ما يزال أقدم من الأعمدة المهاجرة. لم ننشئ جدولًا موازيًا.
- `MessageRepository` موجود؛ واجهته القديمة تقرأ حسب الجلسة فقط ولا تتحقق من مالك التعديل/الحذف. واجهة `SessionContentPanel` السابقة موجودة بالفعل لكنها Bottom Sheet وتشمل Notes/Voice/LAN، فلا تُعدّ حل Text Messages المطلوب.
- مسار المكتبة القديم `Read Now` يفتح جلسة جديدة بعد Save؛ للوصول إلى رسائل الجلسة القديمة أضفنا `Continue Reading` منفصلًا يعيد فتح نفس sessionId، من دون تغيير `Read Now`.
- لم تصل إجابة لسؤال التعامل مع كود الصوت/الملاحظات السابق؛ **احتفظنا بالملفات ولم نوسّعها**، وأخفينا واجهة القارئ القديمة افتراضيًا. بقيت متاحة فقط عبر خيار صريح `showLegacySessionContent` لدعم اختبار العمل السابق. الكود والصلاحيات السابقة موجودة؛ لذلك لا يصح الزعم أنها غير موجودة تمامًا في هذا الفرع.

## مراجعة wiring الفعلية بعد بلاغ Android

- `PdfLibraryScreen._buildBookCard()` يوجّه زر `Read Now` إلى `PdfReaderScreen(book: book)`؛ و`_continueSavedSolo()` يوجّه `Continue Reading` إلى `PdfReaderScreen(book: book, sessionId: latest.id)`. طريق الغرفة `RoomDetailScreen._buildBookCard()` يستخدم القارئ نفسه مع `sessionId` جماعي. داخل القارئ تنشئ `_initializeReader()` الجلسة الفردية `solo_<bookId>` عند اللزوم قبل إظهار الواجهة.
- موضع الفشل السابق في **شجرة العمل** كان `PdfReaderScreen._buildReaderFooter()`: أنشأ الرسائل في `Scaffold.bottomNavigationBar` بدل `Column` الأساسية ثم أعاد أزرار الصفحات وحدها بصمت عندما لم تكن `MessageRepository` مسجّلة. حُذفت هذه البوابة كاملة. الآن `PdfReaderScreen.build()` يضع `_buildBody()`، وفي حال فتح الكتاب بنجاح تبني `_buildBody()` دائمًا `LayoutBuilder → SingleChildScrollView → Column`، وأبناؤها بالترتيب: PDF بارتفاع محدد، أزرار التنقل، و`TextMessagesPanel` بارتفاع محدد؛ كل ذلك داخل `Scaffold.body`، Solo أو Group، من دون شرط `contentSync` أو flag. يبقى تمرير `pdfx` عموديًا داخل حيّز PDF المحدد، وقائمة الرسائل تمرر داخل حيّز اللوحة، ويمكن تمرير القارئ الخارجي من منطقة أزرار الصفحات للوصول إلى مؤلف الرسالة على شاشة قصيرة/أثناء لوحة المفاتيح.
- الواجهة القديمة في `PdfReaderScreen.build()` (`reader_notes_discussion` و`reader_highlight`) ومشاهدة الملاحظات/التظليل في `_buildBody()`/`_buildAnnotatedPage()` لا تعمل إلا مع `showLegacySessionContent: true` صراحةً، والقيمة الافتراضية `false`. ملفات Notes/Voice/Highlight لم تُحذف؛ نافذة `SessionContentPanel` القديمة ليست المسار الأساسي.
- `TextMessagesPanel._bindController()` يستخدم `MessageRepository` من `setupLocator()` (المسجّلة قبل `runApp`) أو Controller مُحقن للاختبار. إذا غابت الخدمة تظهر **اللوحة مع خطأ وإعادة محاولة** بدل إخفائها؛ قائمة التحميل والحالة الفارغة مستقلتان. للوحة عنوان مخصص مترجم «الرسائل النصية»/«Text messages»، وقائمة تمُرَّر ومؤلف أسفلها. زر الحقل الفارغ ميكروفون *شكلي ومعطّل* يتحول إلى Send عند النص، دون تسجيل صوت.
- `origin/main` و`origin/arena/01a0cd05-readcore` عند الفحص **لا يحتويان ملف `TextMessagesPanel`**؛ الفرع البعيد الحالي `3d346b6` ما زال يتضمن أزرار Notes/Highlight القديمة. لذلك أي APK مبني منه سيعرض الواجهة القديمة. لا يوجد هنا APK الهاتف أو سجل بنائه لإثبات SHA الخاص به، والإصلاح المحلي وحده لا يحدّثه.

## التنفيذ

```text
PDF/pdfx (قائم)
  ↓
أزرار التنقل ورقم الصفحة (قائمة)
  ↓
TextMessagesPanel  ← TextMessagesController ← MessageRepository ← Drift/SQLite
  ├─ قائمة قابلة للتمرير عبر ListView.builder(reverse: true)
  └─ Emoji اختياري + TextField + ميكروفون شكلي مع حقل فارغ / Send مع نص
```

التخطيط: `LayoutBuilder` يخصّص من الارتفاع المتاح بعد احتساب التنقل/التقدم 56% للـPDF و44% للرسائل، مع حد أدنى 240px لكل منهما في الوضع الطبيعي، ويصير PDF بحد أدنى 160px عندما يقصر حيّز الجسم عن 400px (ينخفض تدريجيًا حتى 80px إذا ضاقت لوحة المفاتيح جدًا) كي تبقى أزرار الصفحات في متناول اللمس؛ ما زاد على الشاشة يُمرَّر في `SingleChildScrollView` الخارجي. لا يوضع `Expanded` مباشرة في عمود غير محدود الارتفاع؛ قائمة الرسائل وأخطاء Retry وأخطاء فتح PDF وحالة انتهاء الجلسة قابلة للتمرير ضمن حيّزها. لا تُستبدل شجرة `PdfPageView` عند تغيّر حجم الشاشة/لوحة المفاتيح. عند RTL يتبدّل اتجاه أسهم السابق/التالي بصريًا مع بقاء وظيفة الزرين كما هي. **هذا استدلال من الشيفرة واختبارات مكتوبة، لا إثبات تشغيل على الهاتف**.

إرسال الرسالة: تحقق من نص غير فارغ وطوله حتى 2000 حرف؛ تثبيت `sessionId + pageNumber + senderId` قبل الانتظار؛ كتابة محلية ذرية تحت `SingleWriterLock` وForeign Key؛ رسالة `status='local'`؛ مراقبة Drift للصفحة تعيد بناء لوحة النقاش **فقط**؛ تمرير لآخر رسالة؛ مسح النص بعد نجاح الكتابة. عند الفشل يبقى المسودّة ويظهر خطأ. التعديل والحذف محصوران بـ `sender_id` والجلسة والصفحة ونوع `text`. أوقفنا إرسال نص جديد في جلسة `saved` أو `ended`، مع الإبقاء على قراءة تاريخ الرسائل. لا إرسال شبكي أو Outbox أو انتظار اتصال.

`TextMessage`: `id`, `sessionId`, `pageNumber`, `senderId`, `senderName`, `text`, `createdAt`, `updatedAt`, `status`. ترتيب القراءة `created_at ASC, rowid ASC` لحفظ ترتيب رسائل الثانية الواحدة. يمكن عرض 1000 رسالة بإنشاء عناصر القائمة عند الطلب دون إعادة بناء PDF.

SQLite schema v5: إعادة استعمال `messages.page_number` الموجود؛ إضافة `updated_at INTEGER` (nullable لتوافق إدخالات Drift القديمة) و`status TEXT NOT NULL DEFAULT 'local'`، تعبئة وقت التحديث للسجلات القديمة وإنشاء index `idx_messages_session_page_created`. ترحيل مشروط بـ`PRAGMA table_info`؛ لا بيانات سابقة تُحذف. يمكن مزامنة `app_database.g.dart` بتشغيل `build_runner` لاحقًا على بيئة Flutter/Dart متوافقة؛ مسار النص الحالي يستخدم SQL المعلَّم بـDrift كما في ترحيلات Phase 6 السابقة، ولا يعتمد على حقول غير موجودة في `g.dart` المحفوظ.

## الملفات في هذا الطلب (قياسًا بفرع Arena المنشور قبل الطلب)

**أُنشئت:**
- `lib/features/text_messages/domain/text_message.dart`
- `lib/features/text_messages/presentation/text_messages_controller.dart`
- `lib/features/text_messages/presentation/text_messages_panel.dart`
- `test/unit/phase6/text_messages_repository_test.dart`
- `test/unit/phase6/text_messages_panel_test.dart`
- `test/unit/phase6/text_messages_library_resume_test.dart`
- `test/unit/phase6/text_messages_reader_wiring_test.dart` (مراجعة Library→Read Now وRoomDetail→Group، وGroup بلا contentSync، وغياب DI، وحجم الشاشة/RTL)
- `docs/PHASE_6_TEXT_MESSAGES_REPORT.md`

**عُدّلت:**
- `lib/data/database/tables/messages_table.dart`
- `lib/data/database/migrations/schema_migrations.dart`
- `lib/data/repositories/message_repository.dart`
- `lib/features/reader/pdf_reader_screen.dart`
- `lib/features/reader/pdf_page_view.dart` (تحصين عرض أخطاء PDF على الشاشات القصيرة؛ محرك pdfx لم يُستبدل)
- `lib/features/library/pdf_library_screen.dart`
- `lib/core/l10n/app_localizations.dart`
- `test/unit/phase6/phase6_regression_test.dart` (تفعيل صريح لواجهة الاختبار القديمة بدل تفعيلها افتراضيًا)

بقية ملفات Phase 1–5 لم تُعَد بناؤها؛ وملفات Phase 6 السابقة بما فيها Notes/Audio/Sharing/LAN لا تزال محفوظة ولم تُحذف. تغييرات النص الجديدة لا تُضيف Internet/Supabase/WebSocket/Cloud/Remote API/Voice/Notes CRUD.

## الاختبارات والتحقق

| الاختبار | النتيجة الحقيقية |
|---|---|
| `flutter test test/unit/phase6/text_messages_reader_wiring_test.dart test/unit/phase6/text_messages_library_resume_test.dart test/unit/phase6/text_messages_panel_test.dart test/unit/phase6/text_messages_repository_test.dart` | **FAIL / لم يُنفّذ**: exit 127، `flutter: command not found` (بعد تعديل التخطيط) |
| `flutter analyze` (كل المشروع) | **FAIL / لم يُنفّذ**: exit 127، `flutter: command not found` |
| `flutter build apk --debug` | **FAIL / لم يُنفّذ**: exit 127، `flutter: command not found` |
| `flutter install --debug` | **FAIL / لم يُنفّذ**: exit 127، `flutter: command not found`؛ لا `adb` أو جهاز |
| فحص نحو Dart مستقل بـtree-sitter على 7 ملفات Dart الجديدة/المعدّلة لهذه الجولة | **PASS نحوي فقط**: لا أخطاء parse؛ **ليس** تحليل أنواع أو اختبار Flutter |
| فحص نحو Dart المستقل السابق على 102 ملف في المشروع | 0 أخطاء نحو حينها، قبل تعديل التخطيط الحالي؛ لا يستبدل Flutter |
| فحص SQL مستقل سابق بـPython SQLite باستعمال جمل SELECT/INSERT/UPDATE/DELETE من المستودع | نجح ترحيل الأعمدة، الملكية، فرز/تصفية الصفحة والجلسة، إعادة فتح قاعدة ملف، FK cascade؛ **ليس** تنفيذ Dart/Drift |
| `git diff --check` | **PASS** |
| APK وتجربة هاتف/وضع طيران وإغلاق التطبيق | **FAIL / غير مُتحقَّق منها**؛ لا Flutter/Android SDK/جهاز ولا APK في هذه البيئة |

### حالة بنود القبول التشغيلي (وجود الشيفرة/الاختبار المكتوب ليس PASS)

| البند | الحالة العملية |
|---|---|
| Library → Read Now → Solo Reader واللوحة داخل الجسم | **FAIL / غير متحقق**: مسار المصدر والاختبار مكتوبان، لم يعمل Flutter |
| Library → Continue Reading لنفس الجلسة والرسالة بعد إغلاق DB | **FAIL / غير متحقق**: اختبار ملف SQLite مكتوب، لم يعمل Flutter/Android |
| RoomDetail → Group Reader بلا اشتراط `contentSync` | **FAIL / غير متحقق**: اختبار المسار وGroup المباشر مكتوبان، لم يعملا |
| PDF → أزرار الصفحات → العنوان والقائمة والمؤلف؛ Legacy خارج الافتراضي | **FAIL / غير متحقق على جهاز**: فحص ترتيب الشيفرة فقط |
| صفحة 8 → 9 → 8 وترشيح الرسائل وCRUD محلي | **FAIL / غير متحقق**: الاختبارات المستهدفة لم تعمل |
| الإرسال دون إعادة فتح PDF؛ 🎤 معطّل/Send عند النص | **FAIL / غير متحقق على جهاز**: assertions مكتوبة ولم تعمل |
| loading/empty/error/Retry وغياب Repository دون اختفاء اللوحة | **FAIL / غير متحقق**: حالات Widget مكتوبة ولم تعمل |
| هاتف صغير/كبير، portrait/landscape، RTL ولوحة مفاتيح بلا RenderFlex overflow | **FAIL / غير متحقق**: اختبار تغيير الارتفاع/الاتجاه محاكاة مكتوبة ولم تعمل، لا جهاز |
| `flutter analyze` وبناء APK والتثبيت | **FAIL / لم يُنفّذ**: Flutter/Android SDK/adb غير متوفرة |
| تجربة فعلية دون إنترنت على Android بعد بناء APK من الشجرة الحالية | **FAIL / لم تُنفّذ**: لا جهاز ولا APK هنا |

أُضيفت اختبارات مستهدفة لإنشاء/قراءة/مراقبة/تعديل/حذف/ملكية/تصفية/ملف SQLite، وحالات تحميل/فراغ/خطأ، وزر الميكروفون الشكلي ثم Send، والفلترة عند التنقل، والتمرير على 1000 رسالة دون إعادة بناء عنصر PDF المجاور. اختبار wiring يفتح **Library → Read Now → Solo Reader** ويتحقق من وجود اللوحة داخل `Scaffold.body` والتمرير الخارجي وغياب الأزرار القديمة، ويرسل رسالة وينتقل بين الصفحات؛ ويختبر Group Reader بلا `contentSync`، ومسار **RoomDetail → Open Room Book → Reader** باستخدام Socket loopback واكتشاف LAN شكلي للاختبار فقط، وحالة غياب تسجيل `MessageRepository` مع بقاء اللوحة ظاهرة بحالة خطأ. أُضيفت حالة تغيير حجم الشاشة (هاتف صغير portrait وlandscape وهاتف أكبر وتقصير الارتفاع لمحاكاة أثر لوحة المفاتيح) وRTL مع التحقق من بقاء حالة PDF واللوحة واتجاه الأسهم ومن عدم رصد استثناء Flutter، واختبار عرض خطأ PDF في حيّز 160px دون overflow. اختبار Continue يعيد فتح ملف SQLite والجلسة نفسها. هذه **اختبارات مكتوبة غير مشغَّلة** هنا، وليست نجاحًا مُعلَنًا؛ واختبارات Widget لا تغني عن تجربة Android.

## حالة التسليم والقبول

قبل إنشاء commit التسليم كان `HEAD` المحلي عند `7409cca` مع تغييرات Phase 6 السابقة والنص الجديد في ملفات العمل. يُحدَّد commit التسليم الحالي على فرع Arena بأمرَي `git log -1 --oneline` و`git rev-parse HEAD`. كان الالتزام السابق `3d346b6` موجودًا على الفرع البعيد، ولم تُدفع تغييرات Text Messages إلى GitHub أو main ولم يُبنَ منها APK في بيئة Arena؛ تسليم الشيفرة وحده لا يثبت شيئًا عن APK المثبَّت على هاتف.

لتأكيد معيار القبول: من بيئة Flutter 3.24.5/Dart 3.5.4 شغّل الاختبارات الأربعة المستهدفة أعلاه و`flutter analyze`، ثم ابْنِ APK وثبّته على Android؛ افصل الإنترنت/فعّل وضع الطيران؛ افتح PDF بالصفحة 8 وأرسل «السلام عليكم»، تحقق من ظهورها، الانتقال إلى 9 وعودتها على 8، ثم Save & Leave → إغلاق التطبيق → Library → Continue Reading لنفس الكتاب، والتحقق من الصفحة والرسالة. لا تعلن اكتمال المرحلة قبل نجاح هذا الاختبار والجهاز.
