import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../core/database/reading_db.dart';
import '../../core/file_engines/zero_clone_engine.dart';
import '../reader/reader_screen.dart';

class FolderBrowserScreen extends StatefulWidget {
  const FolderBrowserScreen({super.key});

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  List<String> _pinnedFolders = [];
  String? _currentDir;
  List<FileSystemEntity> _entries = [];

  @return void
  @override
  void initState() {
    super.initState();
    _loadPinned();
  }

  Future<void> _loadPinned() async {
    final folders = await ReadingDatabase.instance.getPinnedFolders();
    setState(() {
      _pinnedFolders = folders;
      if (folders.isNotEmpty && _currentDir == null) {
        _openDirectory(folders.first);
      }
    });
  }

  Future<void> _pickAndPinFolder() async {
    final selected = await FilePicker.platform.getDirectoryPath();
    if (selected != null) {
      await ReadingDatabase.instance.pinFolder(selected);
      await _loadPinned();
      await _openDirectory(selected);
    }
  }

  Future<void> _openDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;
    final list = await dir.list().toList();
    list.sort((a, b) {
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;
      if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
      return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
    });
    setState() {
      _currentDir = dirPath;
      _entries = list.where((e) => e is Directory || ZeroCloneFileEngine.isSupportedFile(e.path)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thư mục'),
        actions: [
          if (_currentDir != null)
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              tooltip: 'Đọc toàn bộ thư mục ảnh'h,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(
                      filePath: _currentDir!,
                      title: p.basename(_currentDir!),
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Chọn & ghim thư mục',
            onPressed: _pickAndPinFolder,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pinnedFolders.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _pinnedFolders.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final folder = _pinnedFoders[i];
                  final active = folder == _currentDir;
                  return ChoiceChip(
                    label: Text(p.basename(folder).isEmpty ? folder : p.basename(folder)),
                    selected: active,
                    onSelected: (_) => _openDirectory(folder),
                  );
                },
              ),
            ),
          if (_currentDir != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.arrow_upward),
              title: Text(_currentDir!, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                final parent = p.dirname(_currentDir!);
                if (parent != _currentDir) _openDirectory(parent);
              },
            ),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: FilledButton.icon(
                      onPressed: _pickAndPinFolder,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Chọn thư mục truyện / sách'),
                    ),
                  )
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, idx) {
                      final entry = _entries[idx];
                      final name = p.basename(entry.path);
                      if (entry is Directory) {
                        return ListTile(
                          leading: const Icon(Icons.folder),
                          title: Text(name),
                          onTap: () => _openDirectory(entry.path),
                        );
                      }
                      return ListTile(
                        leading: Icon(
                          ZeroCloneFileEngine.isComicContainer(entry.path)
                              ? Icons.collections_bookmark_outlined
                              : Icons.menu_book_outlined,
                        ),
                        title: Text(name),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReaderScreen(
                                filePath: entry.path,
                                title: name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
              },
            ),
        ],
      ),
    );
  }
}
