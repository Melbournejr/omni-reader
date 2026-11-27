import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/telegram/telegram_bot_service.dart';

class TelegramCloudScreen extends StatefulWidget {
  const TelegramCloudScreen({super.key});

  @override
  State<TelegramCloudScreen> createState() => _TelegramCloudScreenState();
}

class _TelegramCloudScreenState extends State<TelegramCloudScreen> {
  final _tokenCtrl = TextEditingController();
  final _chatIdCtrl = TextEditingController();
  List> _files = [];
  bool _loading = false;
  String? _status;

  Future<void> _fetchFiles() async {
    if (_tokenCtrl.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final bot = TelegramBotStorage(
        botToken: _tokenCtrl.text.trim(),
        chatId: _chatIdCtrl.text.trim(),
      );
      final list = await bot.fetchAvailableFiles();
      setState(() => _files = list);
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _downloadFile(Map<String, dynamic> doc) async {
    final folder = await FilePicker.platform.getDirectoryPath();
    if (folder == null) return;
    setState(() => _status = 'Đang tải ${doc['file_name']}...');
    try {
      final bot = TelegramBotStorage(
        botToken: _tokenCtrl.text.trim(),
        chatId: _chatIdCtrl.text.trim(),
      );
      final savedPath = await bot.downloadToFolder(
        doc['file_id'] as String,
        doc['file_name'] as String,
        folder,
      );
      setState(() => _status = 'Đã lưu tại: $savedPath');
    } catch (e) {
      setState(() => _status = 'Lỗi tải file: $e');
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
              decoration: const InputDecoration(
                labelText: 'Telegram Bot Token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _chatIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Channel / Chat ID (tùy chọn)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _fetchFiles,
                icon: const Icon(Icons.sync),
                label: Text(_loading ? 'Đang đồng bộ...' : 'Lấy danh sách file từ Telegram'),
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(_status!, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, idx) {
                  final f = _files[idx];
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(f['file_name'] as String),
                    subtitle: Text('${f['file_size']} bytes'),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _downloadFile(f),
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
