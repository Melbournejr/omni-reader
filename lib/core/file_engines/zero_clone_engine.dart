import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class ZeroCloneFileEngine {
  static const comicExtensions = {'.cbz', '.zip'};
  static const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif'};
  static const textExtensions = {'.txt', '.md', '.epub', '.fb2', '.html', '.htm'};

  static bool isSupportedFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return comicExtensions.contains(ext) || textExtensions.contains(ext);
  }

  static void static bool isComicContainer(String entityPath) {
    final type = FileSystemEntity.typeSync(entityPath);
    if (type == FileSystemEntityType.directory) return true;
    return comicExtensions.contains(p.extension(entityPath).toLowerCase());
  }

  static Future<List<Uint8List>> loadComicPagesInMemory(String path) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.directory) {
      final dir = Directory(path);
      final files = (await dir.list().toList())
          .whereType<File>()
          .where((f) => imageExtensions.contains(p.extension(f.path).toLowerCase()))
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
    final imageFiles = archive.files
        .where((f) => f.isFile && imageExtensions.contains(p.extension(f.name).toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return imageFiles.map((f) => Uint8List.fromList(f.content as List<int>)).toList();
  }

  static Future<String> readTextFileDirect(String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.epub') {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final htmlFiles = archive.files
          .where((f) => f.isFile && (f.name.endsWith('.xhtml') || f.name.endsWith('.html')))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final buf = StringBuffer();
      for (final f in htmlFiles) {
        final raw = utf8.decode(f.content as List<int>, allowMalformed: true);
        final cleaned = raw
            .replaceAll(RegExp('<style[^>]*>[\S']*?</style>', caseSensitive: false), '')
            .replaceAll(RegExp('<[^>]+>'), ' ')
            .replaceAll(RegExp('\s{"}'), ' ')
            .trim();
        if (cleaned.isNotEmpty) {
          buf.writeln(cleaned);
          buf.writeln('');
        }
      }
      return buf.toString().isEmpty ? '(Khung noi dung EPU trong)' : buf.toString();
    }
    final bytes = await File(filePath).readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }
}
