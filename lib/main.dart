import 'package:flutter/material.dart';
import 'package:readmesh/core/widgets/app_icon.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:readmesh/core/constants/app_constants.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/core/l10n/language_service.dart';
import 'package:readmesh/core/theme/app_theme.dart';
import 'package:readmesh/data/repositories/kvs_repository.dart';
import 'package:readmesh/features/library/pdf_library_screen.dart';
import 'package:readmesh/features/room/rooms_screen.dart';
import 'package:readmesh/features/session_history/my_sessions_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupLocator();
  final languageService = getIt<LanguageService>();
  runApp(ReadMeshApp(languageService: languageService));
}

class ReadMeshApp extends StatelessWidget {
  final LanguageService languageService;
  const ReadMeshApp({super.key, required this.languageService});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: languageService,
      builder: (context, _) {
        final locale = languageService.currentLocale;
        final isRTL = languageService.isRTL;
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: locale,
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            );
          },
          home: const ReadMeshMainShell(),
        );
      },
    );
  }
}

/// The main application shell hosting the top-level tabs: Library and Rooms.
class ReadMeshMainShell extends StatefulWidget {
  const ReadMeshMainShell({super.key});

  @override
  State<ReadMeshMainShell> createState() => _ReadMeshMainShellState();
}

class _ReadMeshMainShellState extends State<ReadMeshMainShell> {
  int _currentIndex = 0;

  final _pages = const [
    PdfLibraryScreen(),
    RoomsScreen(),
    MySessionsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appNameLabel),
        actions: [
          IconButton(
            icon: AppIcon.language(),
            tooltip: l10n.language,
            onPressed: () => _showLanguageDialog(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: AppIcon.book(),
            label: l10n.library,
          ),
          BottomNavigationBarItem(
            icon: AppIcon.group(),
            label: l10n.rooms,
          ),
          BottomNavigationBarItem(
            icon: AppIcon.history(),
            label: l10n.mySessions,
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageService = getIt<LanguageService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chooseLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(l10n.arabic),
              subtitle: const Text('RTL'),
              value: 'ar',
              groupValue: languageService.currentCode,
              onChanged: (val) {
                if (val != null) {
                  languageService.setLanguage(val);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<String>(
              title: Text(l10n.english),
              subtitle: const Text('LTR'),
              value: 'en',
              groupValue: languageService.currentCode,
              onChanged: (val) {
                if (val != null) {
                  languageService.setLanguage(val);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}
