import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class ReadingProgress {
  final String filePath;
  final String title;
  final int currentPage;
  final int totalPages;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final String bgTheme;
  final String readingDirection;
  final bool doublePage;
  final DateTime lastOpened;

  ReadingProgress({
    required this.filePath,
    required this.title,
    required this.currentPage,
    required this.totalPages,
    this.fontSize = 18.0,
    this.lineHeight = 1.65,
    this.fontFamily = 'default',
    this.bgTheme = 'paper',
    this.readingDirection = 'ltr',
    this.doublePage = false,
    required this.lastOpened,
  });

  Map<String, dynamic> toMap() => {
        'file_path': filePath,
        'title': title,
        'current_page': currentPage,
        'total_pages': totalPages,
        'font_size': fontSize,
        'line_height': lineHeight,
        'font_family': fontFamily,
        'bg_theme': bgTheme,
        'reading_direction': readingDirection,
        'double_page': doublePage ? 1 : 0,
        'last_opened': lastOpened.toIso8601String(),
      };

  factory ReadingProgress.fromMap(Map<String, dynamic> map) => ReadingProgress(
        filePath: map['file_path'] as String,
        title: map['title'] as String,
        currentPage: map['current_page'] as int,
        totalPages: map['total_pages'] as int,
        fontSize: (map['font_size'] as num?)?.toDouble() ?? 18.0,
        lineHeight: (map['line_height'] as num?)?.toDouble() ?? 1.65,
        fontFamily: (map['font_family'] as String?) ?? 'default',
        bgTheme: (map['bg_theme'] as String?) ?? 'paper',
        readingDirection: (map['reading_direction'] as String?) ?? 'ltr',
        doublePage: (map['double_page'] as int?) == 1,
        lastOpened: DateTime.tryParse(map['last_opened'] as String? ?? '') ?? DateTime.now(),
      );
}

class ReadingDatabase {
  ReadingDatabase._();
  static final ReadingDatabase instance = ReadingDatabase._();
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'omni_reader_v2.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''s
          CREATE TABLE reading_history (
            file_path TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            current_page INTEGER NOT NULL,
            total_pages INTEGER NOT NULL,
            font_size REAL NOT NULL,
            line_height REAL NOT NULL,
            font_family TEXT NOT NULL,
            bg_theme TEXT NOT NULL,
            reading_direction TEXT NOT NULL,
            double_page INTEGER NOT NULL,
            last_opened TEXT NOT NULL
          )
        ''');
        await db.execute('''s
          CREATE TABLE pinned_folders (
            folder_path TEXT PRIMARY KEY
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            val TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> upsertProgress(ReadingProgress item) async {
    await init();
    await _db!.insert(
      'reading_history',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ReadingProgress?> getProgress(String filePath) async {
    await init();
    final rows = await _db!.query(
      'reading_history',
      where: 'file_path = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReadingProgress.fromMap(rows.first);
  }

  Future<List<ReadingProgress>> getHistory() async {
    await init();
    final rows = await _db!.query(
      'reading_history',
      orderBy: 'last_opened DESC',
    );
    return rows.map(ReadingProgress.fromMap).toList();
  }

  Future<void> pinFolder(String folderPath) async {
    await init();
    await _db!.insert(
      'pinned_folders',
      {'folder_path': folderPath},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<String>> getPinnedFolders() async {
    await init();
    final rows = await _db!.query('pinned_folders');
    return rows.map((r) => r['folder_path'] as String).toList();
  }

  Future<void> setSetting(String key, String value) async {
    await init();
    await _db!.insert(
      'app_settings',
      {'key': key, 'val': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    await init();
    final rows = await _db!.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['val'] as String;
  }
}
