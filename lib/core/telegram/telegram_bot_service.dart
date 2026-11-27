import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class TelegramBotStorage {
  final String botToken;
  final String chatId;

  TelegramBotStorage({required this.botToken, required this.chatId});

  Future<List<Map<String, dynamic>>> fetchAvailableFiles() async {
    final uri = Uri.parse('https://api.telegram.org/bot/getUpdates');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Telegram API error: ');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = (data['result'] as List<dynamic>? ?? []);
    final files = <Map<String, dynamic>>[];

    for (final item in results) {
      final msg = item['channel_post'] ?? item['message'];
      if (msg is Map<String, dynamic> && msg['document'] is Map<String, dynamic>) {
        final doc = msg['document'] as Map<String, dynamic>;
        files.add({
          'file_id': doc['file_id'],
          'file_name': doc['file_name'] ?? 'untitled',
          'file_size': doc['file_size'] ?? 0,
        });
      }
    }
    return files;
  }

  Future<String> downloadToFolder(String fileId, String fileName, String targetFolder) async {
    final infoResp = await http.get(
      Uri.parse('https://api.telegram.org/bot/getFile?file_id='),
    );
    final infoJson = jsonDecode(infoResp.body) as Map<String, dynamic>;
    final filePath = infoJson['result']?['file_path'] as String?;
    if (filePath == null) {
      throw Exception('Khong lay duoc duong dan file tu Telegram.');
    }

    final downloadUrl = Uri.parse('https://api.telegram.org/file/bot/');
    final fileResp = await http.get(downloadUrl);
    final outPath = p.join(targetFolder, fileName);
    await File(outPath).writeAsBytes(fileResp.bodyBytes);
    return outPath;
  }
}