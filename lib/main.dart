import 'package:flutter/material.dart';
import 'package:readmesh/core/constants/app_constants.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/theme/app_theme.dart';
import 'package:readmesh/features/library/pdf_library_screen.dart';
import 'package:readmesh/features/room/rooms_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupLocator();
  runApp(const ReadMeshApp());
}

class ReadMeshApp extends StatelessWidget {
  const ReadMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ReadMeshMainShell(),
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.meeting_room_rounded),
            label: 'Rooms',
          ),
        ],
      ),
    );
  }
}
