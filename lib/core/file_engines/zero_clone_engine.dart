import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class ZeroCloneFileEngine {
  static const comicExtensions = {'.cbz', '.zip'};
  static const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif'};
  static const textExtensions = {'.txt', '.md', '.epub', '.pdf', '.mobi', '.azw3', '.fb2', '.cbr'};

  static bool isSupportedFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return comicExtensions.contains(ext) || textExtensions.contains(ext);
  }

  static bool isComicArchive(String filePath) {
    return comicExtensions.contains(p.extension(filePath).toLowerCase());
  }

  static Future<List<Uint8List>> loadComicPagesInMemory(String archivePath) async {
    final bytes = await File(archivePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final imageFiles = archive.files
        .where((f) => f.isFile && imageExtensions.contains(p.extension(f.name).toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return imageFiles.map((f) => Uint8List.fromList(f.content as List<int>)).toList();
  }

  static Future<String> readTextFileDirect(String filePath) async {
    final file = File(filePath);
    return file.readAsString();
  }
}
