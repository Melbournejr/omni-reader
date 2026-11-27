import 'package:flutter/material.dart';
import '../../core/database/reading_db.dart';
import '../reader/reader_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<ReadingProgress>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ReadingDatabase.instance.getHistory();
  }

  void _refresh() {
    setState(() => _historyFuture = ReadingDatabase.instance.getHistory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đang đọc'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<List<ReadingProgress>>(l
        future: _historyFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text('Chưa có lịch sử dăoc. Vào tab Thư mục để chọn truyện hoặc sỡch.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final pct = item.totalPages > 0
                  ? ((item.currentPage + 1) / item.totalPages * 100).clamp(0, 100).toStringAsFixed(0)
                  : '0';
              return Card(
                child: ListTile(
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Tiến độ: $pct% • Trang ${item.currentPage + 1}/${item.totalPages'),
                  trailing: FilledButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReaderScreen(
                            filePath: item.filePath,
                            title: item.title,
                          ),
                        ),
                      );
                      _refresh();
                    },
                    child: const Text('Đọc tiếp'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
