import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_iptv_player/models/playlist_item.dart';
import 'package:flutter_iptv_player/screens/player_screen.dart';
import 'package:flutter_iptv_player/services/offline_download_manager.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final manager = OfflineDownloadManager.instance;

  @override
  void initState() {
    super.initState();
    manager.initialize();
  }

  String _bytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    if (value < 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _status(OfflineDownloadItem item) {
    if (item.isComplete) return 'مكتمل';
    if (item.isRunning) return 'قيد التنزيل';
    if (item.isPaused) return 'متوقف مؤقتاً';
    return item.error ?? 'فشل التنزيل';
  }

  void _play(OfflineDownloadItem item) {
    if (!item.isComplete || !File(item.filePath).existsSync()) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          stream: PlaylistItem(
            streamId: 'offline_${item.id}',
            name: item.title,
            streamIcon: '',
            categoryId: 'offline',
            categoryName: 'التنزيلات',
            url: item.filePath,
            type: 'file',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111019),
      appBar: AppBar(
        title: const Text('التنزيلات'),
        backgroundColor: const Color(0xFF111019),
      ),
      body: AnimatedBuilder(
        animation: manager,
        builder: (context, _) {
          final items = manager.items;
          if (items.isEmpty) {
            return const Center(
              child: Text('لا توجد تنزيلات محفوظة',
                  style: TextStyle(color: Colors.white60)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final progress = item.progress;
              return Card(
                color: const Color(0xFF1E1B2B),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () => manager.deleteCompleted(item.id),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_status(item)} • ${_bytes(item.receivedBytes)}${item.totalBytes > 0 ? ' / ${_bytes(item.totalBytes)}' : ''}',
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.white12,
                          color: const Color(0xFFA855F7),
                        ),
                        const SizedBox(height: 4),
                        Text('${(progress * 100).toStringAsFixed(1)}%',
                            textAlign: TextAlign.left,
                            style: const TextStyle(color: Colors.white70)),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (item.isComplete)
                            TextButton.icon(
                              onPressed: () => _play(item),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('تشغيل دون إنترنت'),
                            )
                          else if (item.isRunning)
                            TextButton.icon(
                              onPressed: () => manager.pause(item.id),
                              icon: const Icon(Icons.pause),
                              label: const Text('إيقاف مؤقت'),
                            )
                          else
                            TextButton.icon(
                              onPressed: () => manager.resume(item.id),
                              icon: const Icon(Icons.download),
                              label: const Text('استكمال'),
                            ),
                          if (!item.isComplete)
                            TextButton(
                              onPressed: () => manager.cancel(item.id),
                              child: const Text('إلغاء'),
                            ),
                        ],
                      ),
                    ],
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
