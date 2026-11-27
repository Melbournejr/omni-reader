import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/database/reading_db.dart';
import '../../core/file_engines/zero_clone_engine.dart';

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
  String _bgTheme = 'paper';
  String _readingDirection = 'ltr';
  bool _showControls = false;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initReader();
  }

  Future<void> _initReader() async {
    final saved = await ReadingDatabase.instance.getProgress(widget.filePath);
    if (saved != null) {
      _currentPage = saved.currentPage;
      _fontSize = saved.fontSize;
      _bgTheme = saved.bgTheme;
      _readingDirection = saved.readingDirection;
    }

    if (ZeroCloneFileEngine.isComicArchive(widget.filePath)) {
      _isComic = true;
      _comicPages = await ZeroCloneFileEngine.loadComicPagesInMemory(widget.filePath);
      if (_currentPage >= _comicPages.length) _currentPage = 0;
    } else {
      _isComic = false;
      final raw = await ZeroCloneFileEngine.readTextFileDirect(widget.filePath);
      const chunkSize = 1600;
      _textPages = [
        for (var i = 0; i < raw.length; i += chunkSize)
          raw.substring(i, i + chunkSize > raw.length ? raw.length : i + chunkSize),
      ];
      if (_textPages.isEmpty) _textPages = ['(File trống)'];
      if (_currentPage >= _textPages.length) _currentPage = 0;
    }

    _pageController = PageController(initialPage: _currentPage);
    setState(() => _loading = false);
    await _saveProgress();
  }

  Future<void> _saveProgress() async {
    final total = _isComic ? _comicPages.length : _textPages.length;
    await ReadingDatabase.instance.upsertProgress(
      ReadingProgress(
        filePath: widget.filePath,
        title: widget.title,
        currentPage: _currentPage,
        totalPages: total == 0 ? 1 : total,
        fontSize: _fontSize,
        bgTheme: _bgTheme,
        readingDirection: _readingDirection,
        lastOpened: DateTime.now(),
      ),
    );
  }

  Color _backgroundColor() {
    switch (_bgTheme) {
      case 'sepia':
        return const Color(0xFFF4ECD8);
      case 'gray':
        return const Color(0xFFE6E8EC);
      case 'dark':
        return const Color(0xFF141414);
      default:
        return const Color(0xFFFAF9F6);
    }
  }

  Color _textColor() => _bgTheme == 'dark' ? const Color(0xFFE2E2E2) : const Color(0xFF1F2328);

  @override
  Widget build(BuildContext context) {
    final totalPages = _isComic ? _comicPages.length : _textPages.length;

    return Scaffold(
      backgroundColor: _backgroundColor(),
      appBar: _showControls
          ? AppBar(
              title: Text(widget.title),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: 'Chiều đọc',
                  onSelected: (val) {
                    setState(() => _readingDirection = val);
                    _saveProgress();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'ltr', child: Text('Trái sang Phải (LTR)')),
                    PopupMenuItem(value: 'rtl', child: Text('Phải sang Trái (Manga Nhật)')),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.palette_outlined),
                  tooltip: 'Màu nền trang giấy',
                  onSelected: (val) {
                    setState(() => _bgTheme = val);
                    _saveProgress();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'paper', child: Text('Giấy trắng dịu')),
                    PopupMenuItem(value: 'sepia', child: Text('Vàng giấy cũ')),
                    PopupMenuItem(value: 'gray', child: Text('Xám nhạt')),
                    PopupMenuItem(value: 'dark', child: Text('Nền tối')),
                  ],
                ),
              ],
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: PageView.builder(
                controller: _pageController,
                reverse: _readingDirection == 'rtl',
                itemCount: totalPages,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                  _saveProgress();
                },
                itemBuilder: (context, idx) {
                  if (_isComic) {
                    return Center(
                      child: InteractiveViewer(
                        child: Image.memory(_comicPages[idx], fit: BoxFit.contain),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    child: SingleChildScrollView(
                      child: Text(
                        _textPages[idx],
                        style: TextStyle(
                          fontSize: _fontSize,
                          height: 1.55,
                          color: _textColor(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: _showControls && totalPages > 0
          ? BottomAppBar(
              child: Row(
                children: [
                  Text('${_currentPage + 1} / $totalPages'),
                  Expanded(
                    child: Slider(
                      value: _currentPage.toDouble().clamp(0, (totalPages - 1).toDouble()),
                      max: (totalPages - 1) > 0 ? (totalPages - 1).toDouble() : 1,
                      onChanged: (v) {
                        final target = v.round();
                        _pageController.jumpToPage(target);
                        setState(() => _currentPage = target);
                        _saveProgress();
                      },
                    ),
                  ),
                  if (!_isComic) ...[
                    IconButton(
                      icon: const Icon(Icons.text_decrease),
                      onPressed: () {
                        setState(() => _fontSize = (_fontSize - 1).clamp(13, 36));
                        _saveProgress();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.text_increase),
                      onPressed: () {
                        setState(() => _fontSize = (_fontSize + 1).clamp(13, 36));
                        _saveProgress();
                      },
                    ),
                  ],
                ],
              ),
            )
          : null,
    );
  }
}
