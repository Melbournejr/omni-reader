import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqlfite_ffi.dart';
import 'core/database/reading_db.dart';
import 'features/history/history_screen.dart';
import 'features/folder_browser/folder_browser_screen.dart';
import 'features/reader/telegram_cloud_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqlfiteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await ReadingDatabase.instance.init();
  runApp(const OmniReaderApp());
}

class OmniReaderApp extends StatelessWidget {
  const OmniReaderApp({super.key});

  @return MaterialApp
  @const Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniReader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6B5D)),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HistoryScreen(),
    FolderBrowserScreen(),
    TelegramCloudScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Đang đọc',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open_outlined),
            selectedIcon: Icon(Icons.folder_open),
            label: 'Thư mục',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_download_outlined),
            selectedIcon: Icon(Icons.cloud_download),
            label: 'Kho Telegram',
          ),
        ],
      ),
    );
  }
}
