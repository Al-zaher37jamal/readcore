# تشخيص مزامنة الرسائل النصية عبر LAN — ReadMesh

**الحالة:** تصحيح شيفري واختبارات انحدار مضافة؛ **التحقق التشغيلي وAndroid معلّقان** لعدم توفر Flutter SDK في بيئة العمل. الفرع: `arena/01a0cd05-readcore`. لم يحدث commit أو push، ولم تُحذف التغييرات السابقة.

## Root Cause / أول انقطاع

في الـReader الافتراضي، `TextMessagesPanel._send()` كان يستدعي `TextMessagesController.send()` ثم `MessageRepositoryImpl.createText()`؛ العملية الأخيرة تحفظ صفًا في جدول `messages` محليًا فقط، ولا تنشئ `LanMessage` ولا تستدعي `SessionContentSync`. مع أن `RoomDetailScreen` كان ينشئ Sync ويمرره للـReader، فإن Composer الجديد لم يستخدمه. لذلك يتوقف المسار **بعد commit المحلي وقبل LAN**؛ إضافة `refresh()` أو تعديل `watchDiscussion()` لا يعالج إرسالًا لم يحدث أصلًا.

يوجد مسار أقدم مختلف: `SessionContentPanel._sendText → SessionContentSync.sendText` يحفظ وينشر `contentUpsert`. فحص الشيفرة لا يثبت سبب سلوك **ملف APK قديم بعينه**؛ اختبارات الاتجاهين والتوافق مع هذا المسار أُضيفت، لكن لم تُشغّل بعد. وُجدت ثغرات استقبال إضافية: قد يُرسل Host سجلّ المحتوى فور join **قبل** إرفاق Sync لدى المشارك بعد preflight (فيُهمل)، وحدّ 4096 حرفًا يسقط JSON صحيحًا طويلًا، وحدّ صفحات يُجمّد عند 1 حين لا يملك المشارك عدد صفحات محليًا قبل وصول snapshot.

## Evidence / تتبع المسار

- `lib/features/reader/pdf_reader_screen.dart`: الوضع الافتراضي هو Composer المضمّن (`showLegacySessionContent = false`)؛ `RoomDetailScreen` يمرر نفس Sync/Host/Client إليه. `RoomsScreen` يحتفظ بنفس `LanParticipantClient` طوال `Navigator.push` ويغلقه بعد مغادرة الغرفة؛ مستمع preflight للبثّ لا يستهلك الرسائل من غيره، لكنه يتجاهل سجل المحتوى القادم قبل إرفاق Sync.
- `lib/features/lan/lan_host_server.dart`: الـsocket يفك `utf8.decoder → LineSplitter`، يتحقق من الجلسة وهوية المقبس، ثم ينشر إلى `messageStream`. `lan_participant_client.dart` يفك الأسطر وينشر في stream الكائن نفسه؛ `SessionContentSync.start()` يستمع لهذا stream على الطرفين.
- `lib/data/repositories/session_content_repository.dart`: `saveDiscussion` يحفظ في **جدول messages نفسه**، بمفتاح ID و`ON CONFLICT(id) DO NOTHING` مع `updates: {messagesTable}`. `watchDiscussion` و`MessageRepository.watchPageText` يستخدمان `readsFrom: {messagesTable}`. لذلك إشعار Drift بعد commit يصل إلى الواجهتين دون polling.

## Fix / الملفات

1. `text_messages_panel.dart`: نشر صف النص عبر callback **بعد** نجاح `controller.send`/SQLite، مستخدمًا الصف ومعرّفه الأصليين. يفصل خطأ LAN اللاحق عن فشل الحفظ، فلا يعرض المسودة المحفوظة كأنها لم تُرسل ولا يخلق ID جديدًا عند إعادة المحاولة. لا تغيير لمسار Solo أو Composer الصوت.
2. `pdf_reader_screen.dart`: يمرر publisher إلى Composer الجماعي، ويعيد استخدام Sync الخاص بـRoomDetail؛ وإذا فُتح Reader جماعي مباشرةً مع اتصال LAN ينشئ Sync واحدًا. يعرض خطأ DI/المزامنة بدل إخفائه، ويلغي اشتراك الأخطاء عند التخلص من الشاشة.
3. `room_detail_screen.dart`: يُوحّد عملية إرفاق Sync المتزامنة (`_attachingContentSync`) حتى لا ينتج سباق زر «اقرأ» وتهيئة الغرفة مستمعَين لنفس المقبس. ينتظر الإرفاق قبل فتح Reader؛ يظهر خطأ غياب المستودع/التخزين.
4. `session_content_sync.dart`: يحول `TextMessage` المحفوظ إلى `SessionDiscussion.toWire()` ثم `LanMessage.contentUpsert` بلا إدخال محلي ثانٍ؛ يُحتفَظ بالصف عند انقطاع LAN لإعادة بثه بواسطة replay القائم. يطلب المشارك استدراك السجل مرة واحدة **بعد** الاشتراك إذا كان snapshot قد سبق إرفاق Sync؛ وإذا بدأ Host Sync بعد دخول مشارك، يبث له السجل المحفوظ. يستخدم عدد الصفحات الموثوق من Host/snapshot، ويقبل JSON صالحًا قد يتجاوز 4KB بحد مضبوط 32KB. لا يعيد Host ترحيل ID سبق حفظه.
5. `lan_message.dart` و`lan_host_server.dart`: حزمة `contentReplayRequest` صغيرة على **المقبس نفسه**، مع حجز طلب استدراك واحد لكل اتصال منضم؛ تنظيف الحجز عند الفصل/إيقاف الخادم. لا يوجد polling ولا join/socket إضافي.
6. `app_localizations.dart`: رسالتا خطأ LAN بالعربية والإنجليزية.

## Message Flow / 16 نقطة

1. ضغط Send في Composer نص الصفحة. 2. التقاط رقم الصفحة/النص وpublisher الخاصين بتلك الجلسة. 3. `TextMessagesController.send()` يُنشئ ID واحدًا. 4. `MessageRepository.createText()` يتحقق ويحفظ في SQLite transaction. 5. يعود الصف بعد commit؛ Stream المحلي يستطيع تحديث واجهة المرسل. 6. `publishCommittedText` يتحقق من الجلسة/هوية المرسل/الصفحة ولا يكرر INSERT. 7. يبني `contentUpsert` بنفس ID. 8. Host يرسل عبر `sendToParticipant` أو Participant عبر `sendAndFlush` على المقبس القائم؛ عدم الاتصال لا يمس الصف المحلي. 9. يحوّل TCP البيانات إلى UTF-8 وأسطر JSON. 10. يتحقق Host من session وهوية الـsocket المنضم؛ Client يتحقق من session. 11. ينشر `LanHostServer` أو `LanParticipantClient` إلى `messageStream`. 12. يتلقاه `SessionContentSync.start()` باشتراك واحد لكل غرفة. 13. `_receiveContent` يفحص الحمولة والمرسل وحدّ الصفحة والقيود. 14. `saveDiscussion` يحفظ على المستقبل في `messages`؛ Host يرحّل الجديد فقط لبقية المشاركين. 15. `ON CONFLICT(id) DO NOTHING` يمنع صفًا ثانيًا عند echo/replay، ويثير commit تحديث Drift (`updates`/`readsFrom`). 16. يعيد `watchPageText`/`watchDiscussion` إصدار بيانات الصفحة والجلسة، فيعيد StreamBuilder بناء الرسائل **دون refresh أو إعادة دخول**. عند إرفاق Sync بعد preflight يُطلب السجل الفائت مرةً واحدة على الاتصال القائم؛ وعند إعادة الاتصال يعيد replay الموجود الرسائل المحلية بمعرّفاتها.

## Regression Check

أُضيف إلى `test/unit/phase6/session_content_lan_test.dart` اختبار TCP حقيقي بقاعدتين/ثلاث قواعد Drift: A→B، B→A، B→C، **سجل أُرسل أثناء preflight قبل إرفاق Sync ثم استُدرك دون إعادة الانضمام**، وHost Sync يُرفق بعد طلب استدراك فاتَه، وصفحات أعلى من fallback=1، ونص عربي/emoji وJSON مُهرّب أكبر من 4KB، وإرسال المسار القديم، وidempotency وrelay مرة واحدة، وصف محفوظ Offline ثم replay على نفس client. واختبار Widget يضغط Send في لوحتين ويترقب تحديث واجهة الطرف الآخر من DB. عُزّز `text_messages_reader_wiring_test.dart` للتحقق من تمرير Sync/publisher الفعليين من RoomDetail إلى Reader.

**النتائج الفعلية:** `git diff --check` ناجح؛ فحص نحوي مستقل بـtree-sitter للملفات المعدلة ناجح (ليس تحليل أنواع ولا بديلًا عن Flutter). تمت محاولة `flutter clean`, `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`؛ كل منها **exit 127: `flutter: command not found`**. لا تُدّعى نتيجة اختبار/تحليل/بناء ناجحة، ولم يُختبر Android أو APK قديم. يلزم تشغيل الأوامر الخمسة واختبار هاتفين حقيقيين بعد توفير Flutter 3.24.5/Dart 3.5.4 قبل اعتماد الإصلاح تشغيليًا.
