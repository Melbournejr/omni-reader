import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStateStore.instance.init();
  runApp(const OmniReaderApp());
}

class LocalStateStore {
  LocalStateStore._();
  static final LocalStateStore instance = LocalStateStore._();

  late File _stateFile;
  Map<String, dynamic> _data = {
    'history': <String, dynamic>{},
    'pinned_folders': <String>[],
    'tg_token': '',
    'tg_chat_id': '',
  };

  Future<void> init() async {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    final dir = Directory(p.join(home, '.omni_reader'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _stateFile = File(p.join(dir.path, 'state.json'));
    if (await _stateFile.exists()) {
      try {
        final raw = await _stateFile.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _data = decoded;
        }
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    await _stateFile.writeAsString(jsonEncode(_data));
  }

  List<String> get pinnedFolders =>
      List<String>.from(_data['pinned_folders'] ?? const []);

  Future<void> pinFolder(String path) async {
    final list = pinnedFolders;
    if (!list.contains(path)) {
      list.add(path);
      _data['pinned_folders'] = list;
      await _save();
    }
  }

  String get tgToken => (_data['tg_token'] ?? '') as String;
  String get tgChatId => (_data['tg_chat_id'] ?? '') as String;

  Future<void> saveTelegram(String token, String chatId) async {
    _data['tg_token'] = token;
    _data['tg_chat_id'] = chatId;
    await _save();
  }

  Map<String, dynamic>? getProgress(String filePath) {
    final hist = _data['history'];
    if (hist is Map<String, dynamic> && hist[filePath] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(hist[filePath] as Map);
    }
    return null;
  }

  List<Map<String, dynamic>> getHistoryList() {
    final hist = _data['history'];
    if (hist is! Map<String, dynamic>) return [];
    final items = hist.values
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    items.sort((a, b) =>
        (b['last_opened'] ?? '').toString().compareTo((a['last_opened'] ?? '').toString()));
    return items;
  }

  Future<void> saveProgress(Map<String, dynamic> entry) async {
    final hist = (_data['history'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    entry['last_opened'] = DateTime.now().toIso8601String();
    hist[entry['file_path'] as String] = entry;
    _data['history'] = hist;
    await _save();
  }
}

class ZeroCloneEngine {
  static const comicExts = {'.cbz', '.zip'};
  static const imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.gif'};
  static const textExts = {'.txt', '.md', '.epub', '.html', '.htm'};

  static bool isSupported(String path) {
    final ext = p.extension(path).toLowerCase();
    return comicExts.contains(ext) || textExts.contains(ext);
  }

  static bool isComic(String path) {
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.directory) {
      return true;
    }
    return comicExts.contains(p.extension(path).toLowerCase());
  }

  static Future<List<Uint8List>> loadComicPages(String path) async {
    if (await FileSystemEntity.type(path) == FileSystemEntityType.directory) {
      final files = (await Directory(path).list().toList())
          .whereType<File>()
          .where((f) => imageExts.contains(p.extension(f.path).toLowerCase()))
          .toList()
        ..sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
      final pages = <Uint8List>[];
      for (final f in files) {
        pages.add(await f.readAsBytes());
      }
      return pages;
    }
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final imgs = archive.files
        .where((f) => f.isFile && imageExts.contains(p.extension(f.name).toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return imgs.map((f) => Uint8List.fromList(f.content as List<int>)).toList();
  }

  static Future<String> loadTextContent(String path) async {
    final ext = p.extension(path).toLowerCase();
    final bytes = await File(path).readAsBytes();
    if (ext == '.epub') {
      final archive = ZipDecoder().decodeBytes(bytes);
      final htmls = archive.files
          .where((f) => f.isFile && (f.name.endsWith('.xhtml') || f.name.endsWith('.html')))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final buf = StringBuffer();
      for (final f in htmls) {
        final raw = utf8.decode(f.content as List<int>, allowMalformed: true);
        final text = raw
            .replaceAll(RegExp('<style[^>]*>[\\s\\S]*?</style>', caseSensitive: false), '')
            .replaceAll(RegExp('<[^>]+>'), ' ')
            .replaceAll(RegExp('\\s+'), ' ')
            .trim();
        if (text.isNotEmpty) {
          buf.writeln(text);
          buf.writeln('');
        }
      }
      return buf.toString().isEmpty ? '(EPUB khong co noi dung van ban)' : buf.toString();
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}

class OmniReaderApp extends StatelessWidget {
  const OmniReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniReader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6B5D)),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HistoryTab(onUpdated: () => setState(() {})),
      FolderTab(onOpened: () => setState(() {})),
      const TelegramTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Dang doc',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open_outlined),
            selectedIcon: Icon(Icons.folder_open),
            label: 'Thu muc',
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

class HistoryTab extends StatelessWidget {
  final VoidCallback onUpdated;
  const HistoryTab({super.key, required this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final items = LocalStateStore.instance.getHistoryList();
    return Scaffold(
      appBar: AppBar(title: const Text('OmniReader — Dang doc')),
      body: items.isEmpty
          ? const Center(child: Text('Chua co lich su doc. Hay mo tab Thu muc de chon sach/truyen.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = items[i];
                final cur = (item['current_page'] as int?) ?? 0;
                final tot = (item['total_pages'] as int?) ?? 1;
                final pct = tot > 0 ? ((cur + 1) / tot * 100).clamp(0, 100).toStringAsFixed(0) : '0';
                return Card(
                  child: ListTile(
                    title: Text(item['title'] ?? 'Khong ten', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Tien do: % • Trang /'),
                    trailing: FilledButton(
                      onPressed: () async {
                        await Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => ReaderScreen(
                              filePath: item['file_path'] as String,
                              title: (item['title'] ?? 'Doc') as String,
                            ),
                          ),
                        );
                        onUpdated();
                      },
                      child: const Text('Doc tiep'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class FolderTab extends StatefulWidget {
  final VoidCallback onOpened;
  const FolderTab({super.key, required this.onOpened});

  @override
  State<FolderTab> createState() => _FolderTabState();
}

class _FolderTabState extends State<FolderTab> {
  String? _currentDir;
  List<FileSystemEntity> _entries = [];

  @override
  void initState() {
    super.initState();
    final pinned = LocalStateStore.instance.pinnedFolders;
    if (pinned.isNotEmpty) {
      _openDir(pinned.first);
    }
  }

  Future<void> _pickFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) {
      await LocalStateStore.instance.pinFolder(dir);
      await _openDir(dir);
    }
  }

  Future<void> _openDir(String path) async {
    final d = Directory(path);
    if (!await d.exists()) return;
    final list = await d.list().toList();
    list.sort((a, b) {
      final aDir = a is Directory;
      final bDir = b is Directory;
      if (aDir != bDir) return aDir ? -1 : 1;
      return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
    });
    setState(() {
      _currentDir = path;
      _entries = list.where((e) => e is Directory || ZeroCloneEngine.isSupported(e.path)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pinned = LocalStateStore.instance.pinnedFolders;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thu muc goc'),
        actions: [
          if (_currentDir != null)
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              tooltip: 'Doc toan bo thu muc anh nay',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(
                      filePath: _currentDir!,
                      title: p.basename(_currentDir!),
                    ),
                  ),
                );
                widget.onOpened();
              },
            ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Chon & ghim thu muc',
            onPressed: _pickFolder,
          ),
        ],
      ),
      body: Column(
        children: [
          if (pinned.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: pinned.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(p.basename(pinned[i]).isEmpty ? pinned[i] : p.basename(pinned[i])),
                  selected: pinned[i] == _currentDir,
                  onSelected: (_) => _openDir(pinned[i]),
                ),
              ),
            ),
          if (_currentDir != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.arrow_upward),
              title: Text(_currentDir!, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                final parent = p.dirname(_currentDir!);
                if (parent != _currentDir) _openDir(parent);
              },
            ),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: FilledButton.icon(
                      onPressed: _pickFolder,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Chon thu muc truyen / sach'),
                    ),
                  )
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (_, i) {
                      final e = _entries[i];
                      final name = p.basename(e.path);
                      if (e is Directory) {
                        return ListTile(
                          leading: const Icon(Icons.folder),
                          title: Text(name),
                          onTap: () => _openDir(e.path),
                        );
                      }
                      return ListTile(
                        leading: Icon(
                          ZeroCloneEngine.isComic(e.path)
                              ? Icons.collections_bookmark_outlined
                              : Icons.menu_book_outlined,
                        ),
                        title: Text(name),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReaderScreen(filePath: e.path, title: name),
                            ),
                          );
                          widget.onOpened();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TelegramTab extends StatefulWidget {
  const TelegramTab({super.key});

  @override
  State<TelegramTab> createState() => _TelegramTabState();
}

class _TelegramTabState extends State<TelegramTab> {
  final _tokenCtrl = TextEditingController();
  final _chatCtrl = TextEditingController();
  List<Map<String, dynamic>> _files = [];
  bool _loading = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _tokenCtrl.text = LocalStateStore.instance.tgToken;
    _chatCtrl.text = LocalStateStore.instance.tgChatId;
  }

  Future<void> _sync() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) return;
    final chatId = _chatCtrl.text.trim();
    await LocalStateStore.instance.saveTelegram(token, chatId);
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final resp = await http.get(Uri.parse('https://api.telegram.org/bot/getUpdates'));
      if (resp.statusCode != 200) throw Exception('HTTP ');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (data['result'] as List<dynamic>? ?? []);
      final found = <Map<String, dynamic>>[];
      for (final item in results) {
        final msg = item['channel_post'] ?? item['message'];
        if (msg is Map<String, dynamic> && msg['document'] is Map<String, dynamic>) {
          final chat = msg['chat'] as Map<String, dynamic>?;
          if (chatId.isNotEmpty && chat != null && chat['id'].toString() != chatId) continue;
          final doc = msg['document'] as Map<String, dynamic>;
          found.add({
            'file_id': doc['file_id'],
            'file_name': doc['file_name'] ?? 'file',
            'file_size': doc['file_size'] ?? 0,
          });
        }
      }
      setState(() => _files = found);
    } catch (e) {
      setState(() => _status = 'Loi: ');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _download(Map<String, dynamic> doc) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    final token = _tokenCtrl.text.trim();
    setState(() => _status = 'Dang tai ...');
    try {
      final infoResp = await http.get(
        Uri.parse('https://api.telegram.org/bot/getFile?file_id='),
      );
      final info = jsonDecode(infoResp.body) as Map<String, dynamic>;
      final filePath = info['result']?['file_path'] as String?;
      if (filePath == null) throw Exception('Khong co file_path');
      final fileResp = await http.get(Uri.parse('https://api.telegram.org/file/bot/'));
      final out = p.join(dir, doc['file_name'] as String);
      await File(out).writeAsBytes(fileResp.bodyBytes);
      setState(() => _status = 'Da luu: ');
    } catch (e) {
      setState(() => _status = 'Loi tai: ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kho Telegram')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _tokenCtrl,
              decoration: const InputDecoration(labelText: 'Bot Token', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _chatCtrl,
              decoration: const InputDecoration(labelText: 'Chat / Channel ID (tuy chon)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _sync,
                icon: const Icon(Icons.sync),
                label: Text(_loading ? 'Dang dong bo...' : 'Lay danh sach file'),
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(_status!),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (_, i) {
                  final f = _files[i];
                  return ListTile(
                    title: Text(f['file_name'].toString()),
                    subtitle: Text(' bytes'),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _download(f),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderScreen extends StatefulWidget {
  final String filePath;
  final String title;
  const ReaderScreen({super.key, required this.filePath, required this.title});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _loading = true;
  bool _isComic = false;
  List<Uint8List> _comicPages = [];
  List<String> _textPages = [];
  int _currentPage = 0;
  double _fontSize = 18.0;
  double _lineHeight = 1.65;
  String _fontFamily = 'default';
  String _bgTheme = 'paper';
  String _direction = 'ltr';
  bool _doublePage = false;
  bool _showUi = true;
  late PageController _pageController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _step => _doublePage ? 2 : 1;
  int get _totalItems => _isComic ? _comicPages.length : _textPages.length;
  int get _totalSpreads => _totalItems == 0 ? 1 : (_totalItems / _step).ceil();

  Future<void> _load() async {
    final saved = LocalStateStore.instance.getProgress(widget.filePath);
    if (saved != null) {
      _currentPage = (saved['current_page'] as int?) ?? 0;
      _fontSize = ((saved['font_size'] as num?) ?? 18.0).toDouble();
      _lineHeight = ((saved['line_height'] as num?) ?? 1.65).toDouble();
      _fontFamily = (saved['font_family'] as String?) ?? 'default';
      _bgTheme = (saved['bg_theme'] as String?) ?? 'paper';
      _direction = (saved['direction'] as String?) ?? 'ltr';
      _doublePage = (saved['double_page'] as bool?) ?? false;
    }

    if (ZeroCloneEngine.isComic(widget.filePath)) {
      _isComic = true;
      _comicPages = await ZeroCloneEngine.loadComicPages(widget.filePath);
      if (_currentPage >= _comicPages.length) _currentPage = 0;
    } else {
      _isComic = false;
      final raw = await ZeroCloneEngine.loadTextContent(widget.filePath);
      const chunk = 1800;
      _textPages = [
        for (int i = 0; i < raw.length; i += chunk)
          raw.substring(i, i + chunk > raw.length ? raw.length : i + chunk),
      ];
      if (_textPages.isEmpty) _textPages = ['(File trong)'];
      if (_currentPage >= _textPages.length) _currentPage = 0;
    }

    final initSpread = (_currentPage / _step).floor();
    _pageController.dispose();
    _pageController = PageController(initialPage: initSpread);
    setState(() => _loading = false);
    await _save();
  }

  Future<void> _save() async {
    await LocalStateStore.instance.saveProgress({
      'file_path': widget.filePath,
      'title': widget.title,
      'current_page': _currentPage,
      'total_pages': _totalItems == 0 ? 1 : _totalItems,
      'font_size': _fontSize,
      'line_height': _lineHeight,
      'font_family': _fontFamily,
      'bg_theme': _bgTheme,
      'direction': _direction,
      'double_page': _doublePage,
    });
  }

  void _goSpread(int idx) {
    final maxIdx = _totalSpreads - 1;
    if (maxIdx < 0) return;
    final target = idx.clamp(0, maxIdx);
    if (_direction != 'vertical' && _pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
    setState(() => _currentPage = target * _step);
    _save();
  }

  void _next() => _goSpread((_currentPage / _step).floor() + 1);
  void _prev() => _goSpread((_currentPage / _step).floor() - 1);

  void _onTap(TapDownDetails d, double w) {
    final x = d.localPosition.dx;
    if (x < w * 0.28) {
      _direction == 'rtl' ? _next() : _prev();
    } else if (x > w * 0.72) {
      _direction == 'rtl' ? _prev() : _next();
    } else {
      setState(() => _showUi = !_showUi);
    }
  }

  Color _bgColor() {
    switch (_bgTheme) {
      case 'sepia':
        return const Color(0xFFF4ECD8);
      case 'gray':
        return const Color(0xFFE6E8EC);
      case 'dark':
        return const Color(0xFF121212);
      default:
        return const Color(0xFFFAF9F6);
    }
  }

  Color _fgColor() => _bgTheme == 'dark' ? const Color(0xFFE2E2E2) : const Color(0xFF1F2328);

  String? _resolvedFont() {
    switch (_fontFamily) {
      case 'serif':
        return 'Georgia';
      case 'sans':
        return 'Arial';
      case 'mono':
        return 'monospace';
      default:
        return null;
    }
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cai dat doc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Chieu doc'),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Trai -> Phai'),
                    selected: _direction == 'ltr',
                    onSelected: (_) {
                      setState(() => _direction = 'ltr');
                      setSheet(() {});
                      _save();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Phai -> Trai (Manga)'),
                    selected: _direction == 'rtl',
                    onSelected: (_) {
                      setState(() => _direction = 'rtl');
                      setSheet(() {});
                      _save();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Cuon doc'),
                    selected: _direction == 'vertical',
                    onSelected: (_) {
                      setState(() => _direction = 'vertical');
                      setSheet(() {});
                      _save();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Bo cuc trang'),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('1 trang'),
                    selected: !_doublePage,
                    onSelected: (_) {
                      setState(() => _doublePage = false);
                      setSheet(() {});
                      _save();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('2 trang doi'),
                    selected: _doublePage,
                    onSelected: (_) {
                      setState(() => _doublePage = true);
                      setSheet(() {});
                      _save();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Mau nen'),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in [
                    ['paper', 'Giay trang'],
                    ['sepia', 'Vang Sepia'],
                    ['gray', 'Xam diu'],
                    ['dark', 'Nen toi'],
                  ])
                    ChoiceChip(
                      label: Text(t[1]),
                      selected: _bgTheme == t[0],
                      onSelected: (_) {
                        setState(() => _bgTheme = t[0]);
                        setSheet(() {});
                        _save();
                      },
                    ),
                ],
              ),
              if (!_isComic) ...[
                const SizedBox(height: 12),
                const Text('Font chu'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in [
                      ['default', 'Mac dinh'],
                      ['serif', 'Serif (Sach)'],
                      ['sans', 'Sans-Serif'],
                      ['mono', 'Monospace'],
                    ])
                      ChoiceChip(
                        label: Text(f[1]),
                        selected: _fontFamily == f[0],
                        onSelected: (_) {
                          setState(() => _fontFamily = f[0]);
                          setSheet(() {});
                          _save();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Co chu: pt'),
                Slider(
                  value: _fontSize,
                  min: 13,
                  max: 36,
                  onChanged: (v) {
                    setState(() => _fontSize = v);
                    setSheet(() {});
                    _save();
                  },
                ),
                Text('Gian dong: '),
                Slider(
                  value: _lineHeight,
                  min: 1.2,
                  max: 2.2,
                  onChanged: (v) {
                    setState(() => _lineHeight = v);
                    setSheet(() {});
                    _save();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _singleItem(int idx) {
    if (_isComic) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(child: Image.memory(_comicPages[idx], fit: BoxFit.contain)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Text(
          _textPages[idx],
          style: TextStyle(
            fontSize: _fontSize,
            height: _lineHeight,
            fontFamily: _resolvedFont(),
            color: _fgColor(),
          ),
        ),
      ),
    );
  }

  Widget _spreadItem(int spreadIdx) {
    if (!_doublePage) return _singleItem(spreadIdx);
    final a = spreadIdx * 2;
    final b = a + 1;
    final hasB = b < _totalItems;
    final left = _direction == 'rtl' ? (hasB ? b : a) : a;
    final right = _direction == 'rtl' ? (hasB ? a : null) : (hasB ? b : null);
    return Row(
      children: [
        Expanded(child: _singleItem(left)),
        const VerticalDivider(width: 1),
        Expanded(child: right != null ? _singleItem(right) : const SizedBox.shrink()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final curSpread = (_currentPage / _step).floor().clamp(0, _totalSpreads - 1);
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (ev) {
        if (ev is KeyDownEvent) {
          final k = ev.logicalKey;
          if (k == LogicalKeyboardKey.arrowRight ||
              k == LogicalKeyboardKey.space ||
              k == LogicalKeyboardKey.pageDown) {
            _direction == 'rtl' ? _prev() : _next();
          } else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.pageUp) {
            _direction == 'rtl' ? _next() : _prev();
          }
        }
      },
      child: Scaffold(
        backgroundColor: _bgColor(),
        appBar: _showUi
            ? AppBar(
                title: Text(widget.title),
                actions: [
                  IconButton(
                    icon: Icon(_doublePage ? Icons.looks_one_outlined : Icons.looks_two_outlined),
                    tooltip: _doublePage ? 'Chuyen 1 trang' : 'Chuyen 2 trang doi',
                    onPressed: () {
                      setState(() => _doublePage = !_doublePage);
                      _save();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Cai dat doc',
                    onPressed: _openSettings,
                  ),
                ],
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (_, c) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _onTap(d, c.maxWidth),
                  child: _direction == 'vertical'
                      ? ListView.builder(
                          itemCount: _totalItems,
                          itemBuilder: (_, i) => _singleItem(i),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          reverse: _direction == 'rtl',
                          itemCount: _totalSpreads,
                          onPageChanged: (s) {
                            setState(() => _currentPage = s * _step);
                            _save();
                          },
                          itemBuilder: (_, s) => _spreadItem(s),
                        ),
                ),
              ),
        bottomNavigationBar: _showUi && _totalItems > 0
            ? BottomAppBar(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _direction == 'rtl' ? _next : _prev,
                    ),
                    Text('/'),
                    Expanded(
                      child: Slider(
                        value: curSpread.toDouble(),
                        max: (_totalSpreads - 1) > 0 ? (_totalSpreads - 1).toDouble() : 1,
                        onChanged: (v) => _goSpread(v.round()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _direction == 'rtl' ? _prev : _next,
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: _openSettings,
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}