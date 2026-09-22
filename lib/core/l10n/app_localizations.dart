import 'package:flutter/widgets.dart';

/// Simple localization without codegen, Arabic default RTL, English LTR.
/// Covers all hard-coded strings audited from Rooms, Library, Reader, LAN.
class AppLocalizations {
  final String localeCode; // 'ar' or 'en'

  AppLocalizations(this.localeCode);

  bool get isArabic => localeCode == 'ar';
  bool get isRTL => isArabic;

  static const supportedLocales = ['ar', 'en'];
  static const defaultLocale = 'ar';

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(defaultLocale);
  }

  // Core map
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appName': 'ReadMesh',
      'library': 'Library',
      'rooms': 'Rooms',
      'localReadingRooms': 'Local Reading Rooms',
      'myPdfLibrary': 'My PDF Library',
      'noBooksInLibrary': 'No Books in Library',
      'importHint': 'Import your PDF documents to start reading collaboratively.',
      'importSamplePdf': 'Import Sample PDF',
      'importBook': 'Import Book',
      'addPdfFile': 'Add PDF',
      'addPdfFileDesc': 'Add PDF File',
      'readNow': 'Read Now',
      'readAsHost': 'Read as Host',
      'readAsParticipant': 'Read as Participant',
      'openBook': 'Open Book',
      'deleteBook': 'Delete Book',
      'deleteBookConfirmTitle': 'Delete Book',
      'deleteBookConfirmBody': 'Are you sure you want to remove "{title}" from your library?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'ok': 'OK',
      'join': 'Join',
      'createRoom': 'Create Room',
      'createReadingRoom': 'Create Reading Room',
      'joinReadingRoom': 'Join Reading Room',
      'roomTitle': 'Room Title',
      'selectBook': 'Select Book',
      'roomCode': 'Room Code',
      'roomCodeExample': 'Room Code (e.g. RM-4821)',
      'hostLanIp': 'Host LAN IP',
      'hostLanIpExample': 'Host LAN IP (e.g. 10.87.235.106 or 192.168.1.50)',
      'hostLanIpHint': 'Enter Host IP shown on Host device',
      'lanHost': 'LAN Host',
      'discoveredRoomsOnLan': 'Discovered Rooms on LAN:',
      'noActiveReadingRooms': 'No Active Reading Rooms',
      'createRoomHint': 'Create a reading room for a book or join one using a room code.',
      'joinRoom': 'Join Room',
      'joinWithCode': 'Join with Code',
      'roomNotFound': 'Room not found. Please check the room code and Host IP.',
      'roomEndedHistory': 'Room has ended. It is available as history only.',
      'cannotJoinEnded': 'Cannot join an ended room. It is history only.',
      'invalidIp': 'Invalid Host IP. Please enter a valid LAN IP like 10.87.235.106, 192.168.1.50, or 10.87.235.106:40404.',
      'invalidCode': 'Invalid Room Code. Please enter a valid code like RM-4821.',
      'pleaseImportBook': 'Please import a PDF book in the Library before creating a room.',
      'failedToCreateRoom': 'Failed to create room',
      'joinFailed': 'Join failed',
      'roomCodeLabel': 'ROOM CODE',
      'copyCode': 'Copy Code',
      'copiedToClipboard': 'Copied code "{code}" to clipboard',
      'connected': 'connected',
      'disconnected': 'Disconnected',
      'connecting': 'Connecting',
      'reconnecting': 'Reconnecting',
      'lan': 'LAN',
      'reconnect': 'Reconnect',
      'hostControls': 'Host Controls',
      'roomStatus': 'Room Status',
      'youAreHost': 'You are Host',
      'participant': 'Participant',
      'youAreParticipant': 'You are Participant',
      'startReadingSession': 'Start Reading Session',
      'pause': 'Pause',
      'resume': 'Resume',
      'endRoom': 'End Room',
      'sessionEnded': 'This session has ended.',
      'hostRunning': 'The host is currently running this reading session.',
      'hostPaused': 'The host has paused this session.',
      'roomBook': 'Room Book',
      'participants': 'Participants',
      'noParticipantsYet': 'No participants yet.',
      'status': 'Status',
      'active': 'Active',
      'paused': 'Paused',
      'ended': 'Ended',
      'created': 'Created',
      'left': 'Left',
      'host': 'Host',
      'member': 'Member',
      'waitingForParticipants': 'Waiting for participants',
      'readingSessionPaused': 'Reading Session Paused by Host',
      'readingSessionEnded': 'Reading Session Ended by Host',
      'openingDocument': 'Opening document...',
      'jumpToPage': 'Jump to Page',
      'pageNumberRange': 'Page Number (1 - {total})',
      'go': 'Go',
      'syncedPage': 'Synced: Page {current} of {total}',
      'pageOf': 'Page {current} of {total}',
      'notStartedYet': 'Not started yet',
      'duplicateBookTitle': 'Book Already Exists',
      'duplicateBookMessage': 'This book is already in your library.',
      'duplicateBookMessageAr': 'هذا الكتاب موجود بالفعل في مكتبتك.',
      'openBookAction': 'Open Book',
      'importSuccess': 'Imported "{title}" successfully!',
      'importFailed': 'Import failed',
      'deleted': 'Deleted "{title}"',
      'language': 'Language',
      'arabic': 'العربية',
      'english': 'English',
      'settings': 'Settings',
      'chooseLanguage': 'Choose Language',
      'rtlNote': 'RTL enabled for Arabic',
      'historyOnly': 'History Only',
      'endedRoomHistoryOnly': 'ENDED - History only, not joinable',
      'pleaseCheckRoomCodeAndHostIp': 'Room not found. Please check the room code and Host IP.',
    },
    'ar': {
      'appName': 'ReadMesh',
      'library': 'المكتبة',
      'rooms': 'الغرف',
      'localReadingRooms': 'غرف القراءة المحلية',
      'myPdfLibrary': 'مكتبتي',
      'noBooksInLibrary': 'لا توجد كتب في المكتبة',
      'importHint': 'استورد مستندات PDF لبدء القراءة التعاونية.',
      'importSamplePdf': 'استيراد PDF تجريبي',
      'importBook': 'استيراد كتاب',
      'addPdfFile': 'إضافة ملف PDF',
      'addPdfFileDesc': 'إضافة ملف PDF',
      'readNow': 'اقرأ الآن',
      'readAsHost': 'اقرأ كمضيف',
      'readAsParticipant': 'اقرأ كمشارك',
      'openBook': 'فتح الكتاب',
      'deleteBook': 'حذف الكتاب',
      'deleteBookConfirmTitle': 'حذف الكتاب',
      'deleteBookConfirmBody': 'هل أنت متأكد من حذف "{title}" من مكتبتك؟',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'ok': 'موافق',
      'join': 'انضمام',
      'createRoom': 'إنشاء غرفة',
      'createReadingRoom': 'إنشاء غرفة قراءة',
      'joinReadingRoom': 'الانضمام إلى غرفة قراءة',
      'roomTitle': 'عنوان الغرفة',
      'selectBook': 'اختر الكتاب',
      'roomCode': 'رمز الغرفة',
      'roomCodeExample': 'رمز الغرفة (مثال RM-4821)',
      'hostLanIp': 'عنوان المضيف في الشبكة',
      'hostLanIpExample': 'عنوان المضيف (مثال 10.87.235.106 أو 192.168.1.50)',
      'hostLanIpHint': 'أدخل عنوان IP الظاهر على جهاز المضيف',
      'lanHost': 'المضيف في الشبكة',
      'discoveredRoomsOnLan': 'الغرف المكتشفة في الشبكة:',
      'noActiveReadingRooms': 'لا توجد غرف قراءة نشطة',
      'createRoomHint': 'أنشئ غرفة قراءة لكتاب أو انضم إلى غرفة باستخدام رمز الغرفة.',
      'joinRoom': 'انضمام إلى غرفة',
      'joinWithCode': 'انضمام برمز',
      'roomNotFound': 'الغرفة غير موجودة. تحقق من رمز الغرفة وعنوان المضيف.',
      'roomEndedHistory': 'انتهت الجلسة. متاحة كسجل فقط.',
      'cannotJoinEnded': 'لا يمكن الانضمام إلى غرفة منتهية. متاحة كسجل فقط.',
      'invalidIp': 'عنوان المضيف غير صالح. أدخل عنوان LAN صحيح مثل 10.87.235.106 أو 192.168.1.50 أو 10.87.235.106:40404.',
      'invalidCode': 'رمز الغرفة غير صالح. أدخل رمزًا صحيحًا مثل RM-4821.',
      'pleaseImportBook': 'يرجى استيراد كتاب PDF في المكتبة قبل إنشاء غرفة.',
      'failedToCreateRoom': 'فشل إنشاء الغرفة',
      'joinFailed': 'فشل الانضمام',
      'roomCodeLabel': 'رمز الغرفة',
      'copyCode': 'نسخ الرمز',
      'copiedToClipboard': 'تم نسخ الرمز "{code}" إلى الحافظة',
      'connected': 'متصل',
      'disconnected': 'غير متصل',
      'connecting': 'جاري الاتصال',
      'reconnecting': 'إعادة الاتصال',
      'lan': 'الشبكة',
      'reconnect': 'إعادة الاتصال',
      'hostControls': 'تحكم المضيف',
      'roomStatus': 'حالة الغرفة',
      'youAreHost': 'أنت المضيف',
      'participant': 'مشارك',
      'youAreParticipant': 'أنت مشارك',
      'startReadingSession': 'بدء جلسة القراءة',
      'pause': 'إيقاف مؤقت',
      'resume': 'استئناف',
      'endRoom': 'إنهاء الغرفة',
      'sessionEnded': 'انتهت هذه الجلسة.',
      'hostRunning': 'المضيف يشغّل جلسة القراءة حاليًا.',
      'hostPaused': 'المضيف أوقف الجلسة مؤقتًا.',
      'roomBook': 'كتاب الغرفة',
      'participants': 'المشاركون',
      'noParticipantsYet': 'لا يوجد مشاركون بعد.',
      'status': 'الحالة',
      'active': 'نشط',
      'paused': 'متوقف مؤقتًا',
      'ended': 'منتهي',
      'created': 'تم إنشاؤه',
      'left': 'غادر',
      'host': 'مضيف',
      'member': 'عضو',
      'waitingForParticipants': 'في انتظار المشاركين',
      'readingSessionPaused': 'تم إيقاف جلسة القراءة مؤقتًا بواسطة المضيف',
      'readingSessionEnded': 'تم إنهاء جلسة القراءة بواسطة المضيف',
      'openingDocument': 'جاري فتح المستند...',
      'jumpToPage': 'الانتقال إلى صفحة',
      'pageNumberRange': 'رقم الصفحة (1 - {total})',
      'go': 'انتقال',
      'syncedPage': 'متزامن: صفحة {current} من {total}',
      'pageOf': 'صفحة {current} من {total}',
      'notStartedYet': 'لم يبدأ بعد',
      'duplicateBookTitle': 'الكتاب موجود مسبقًا',
      'duplicateBookMessage': 'هذا الكتاب موجود بالفعل في مكتبتك.',
      'duplicateBookMessageAr': 'هذا الكتاب موجود بالفعل في مكتبتك.',
      'openBookAction': 'فتح الكتاب',
      'importSuccess': 'تم استيراد "{title}" بنجاح!',
      'importFailed': 'فشل الاستيراد',
      'deleted': 'تم حذف "{title}"',
      'language': 'اللغة',
      'arabic': 'العربية',
      'english': 'English',
      'settings': 'الإعدادات',
      'chooseLanguage': 'اختر اللغة',
      'rtlNote': 'تم تفعيل RTL للعربية',
      'historyOnly': 'سجل فقط',
      'endedRoomHistoryOnly': 'منتهية - سجل فقط، غير قابلة للانضمام',
      'pleaseCheckRoomCodeAndHostIp': 'الغرفة غير موجودة. تحقق من رمز الغرفة وعنوان المضيف.',
    },
  };

  String _get(String key) {
    return _localizedValues[localeCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  String tr(String key, {Map<String, String>? params}) {
    var value = _get(key);
    if (params != null) {
      params.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }

  // Convenience getters for audited hard-coded strings
  String get appNameLabel => _get('appName');
  String get library => _get('library');
  String get rooms => _get('rooms');
  String get localReadingRooms => _get('localReadingRooms');
  String get myPdfLibrary => _get('myPdfLibrary');
  String get noBooksInLibrary => _get('noBooksInLibrary');
  String get importHint => _get('importHint');
  String get importSamplePdf => _get('importSamplePdf');
  String get importBook => _get('importBook');
  String get addPdfFile => _get('addPdfFile');
  String get addPdfFileDesc => _get('addPdfFileDesc');
  String get readNow => _get('readNow');
  String get readAsHost => _get('readAsHost');
  String get readAsParticipant => _get('readAsParticipant');
  String get openBook => _get('openBook');
  String get deleteBook => _get('deleteBook');
  String get deleteBookConfirmTitle => _get('deleteBookConfirmTitle');
  String deleteBookConfirmBody(String title) => tr('deleteBookConfirmBody', params: {'title': title});
  String get cancel => _get('cancel');
  String get delete => _get('delete');
  String get ok => _get('ok');
  String get join => _get('join');
  String get createRoom => _get('createRoom');
  String get createReadingRoom => _get('createReadingRoom');
  String get joinReadingRoom => _get('joinReadingRoom');
  String get roomTitle => _get('roomTitle');
  String get selectBook => _get('selectBook');
  String get roomCode => _get('roomCode');
  String get roomCodeExample => _get('roomCodeExample');
  String get hostLanIp => _get('hostLanIp');
  String get hostLanIpExample => _get('hostLanIpExample');
  String get hostLanIpHint => _get('hostLanIpHint');
  String get lanHost => _get('lanHost');
  String get discoveredRoomsOnLan => _get('discoveredRoomsOnLan');
  String get noActiveReadingRooms => _get('noActiveReadingRooms');
  String get createRoomHint => _get('createRoomHint');
  String get joinRoom => _get('joinRoom');
  String get joinWithCode => _get('joinWithCode');
  String get roomNotFound => _get('roomNotFound');
  String get roomEndedHistory => _get('roomEndedHistory');
  String get cannotJoinEnded => _get('cannotJoinEnded');
  String get invalidIp => _get('invalidIp');
  String get invalidCode => _get('invalidCode');
  String get pleaseImportBook => _get('pleaseImportBook');
  String get failedToCreateRoom => _get('failedToCreateRoom');
  String get joinFailed => _get('joinFailed');
  String get roomCodeLabel => _get('roomCodeLabel');
  String get copyCode => _get('copyCode');
  String copiedToClipboard(String code) => tr('copiedToClipboard', params: {'code': code});
  String get connected => _get('connected');
  String get disconnected => _get('disconnected');
  String get connecting => _get('connecting');
  String get reconnecting => _get('reconnecting');
  String get lan => _get('lan');
  String get reconnect => _get('reconnect');
  String get hostControls => _get('hostControls');
  String get roomStatus => _get('roomStatus');
  String get youAreHost => _get('youAreHost');
  String get participantLabel => _get('participant');
  String get youAreParticipant => _get('youAreParticipant');
  String get startReadingSession => _get('startReadingSession');
  String get pause => _get('pause');
  String get resume => _get('resume');
  String get endRoom => _get('endRoom');
  String get sessionEnded => _get('sessionEnded');
  String get hostRunning => _get('hostRunning');
  String get hostPaused => _get('hostPaused');
  String get roomBook => _get('roomBook');
  String get participants => _get('participants');
  String get noParticipantsYet => _get('noParticipantsYet');
  String get status => _get('status');
  String get active => _get('active');
  String get pausedStatus => _get('paused');
  String get ended => _get('ended');
  String get created => _get('created');
  String get left => _get('left');
  String get host => _get('host');
  String get member => _get('member');
  String get waitingForParticipants => _get('waitingForParticipants');
  String get readingSessionPaused => _get('readingSessionPaused');
  String get readingSessionEnded => _get('readingSessionEnded');
  String get openingDocument => _get('openingDocument');
  String get jumpToPage => _get('jumpToPage');
  String pageNumberRange(int total) => tr('pageNumberRange', params: {'total': total.toString()});
  String get go => _get('go');
  String syncedPage(int current, int total) => tr('syncedPage', params: {'current': current.toString(), 'total': total.toString()});
  String pageOf(int current, int total) => tr('pageOf', params: {'current': current.toString(), 'total': total.toString()});
  String get notStartedYet => _get('notStartedYet');
  String get duplicateBookTitle => _get('duplicateBookTitle');
  String get duplicateBookMessage => _get('duplicateBookMessage');
  String get openBookAction => _get('openBookAction');
  String importSuccess(String title) => tr('importSuccess', params: {'title': title});
  String get importFailed => _get('importFailed');
  String deleted(String title) => tr('deleted', params: {'title': title});
  String get language => _get('language');
  String get arabic => _get('arabic');
  String get english => _get('english');
  String get settings => _get('settings');
  String get chooseLanguage => _get('chooseLanguage');
  String get historyOnly => _get('historyOnly');
  String get endedRoomHistoryOnly => _get('endedRoomHistoryOnly');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final code = AppLocalizations.supportedLocales.contains(locale.languageCode)
        ? locale.languageCode
        : AppLocalizations.defaultLocale;
    return AppLocalizations(code);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
