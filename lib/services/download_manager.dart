import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
}

class DownloadItem {
  final String id;
  final String title;
  final String url;
  final String poster;
  final String category;
  final String type; // 'movie' or 'series'
  String filePath;
  DownloadStatus status;
  double progress;
  int downloadedBytes;
  int totalBytes;
  String speed;
  final DateTime createdAt;

  DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.poster,
    required this.category,
    required this.type,
    required this.filePath,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speed = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'poster': poster,
        'category': category,
        'type': type,
        'filePath': filePath,
        'status': status.name,
        'progress': progress,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'speed': speed,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        poster: json['poster']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        type: json['type']?.toString() ?? 'movie',
        filePath: json['filePath']?.toString() ?? '',
        status: DownloadStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => DownloadStatus.completed,
        ),
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
        totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
        speed: json['speed']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  String get formattedTotalSize {
    if (totalBytes <= 0) return 'غير معروف';
    final mb = totalBytes / (1024 * 1024);
    if (mb >= 1000) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get formattedDownloadedSize {
    final mb = downloadedBytes / (1024 * 1024);
    if (mb >= 1000) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class DownloadManager extends ChangeNotifier {
  static final DownloadManager instance = DownloadManager._internal();
  DownloadManager._internal() {
    _loadFromStorage();
  }

  static const String _storageKey = 'offline_downloads_v1';
  final Map<String, DownloadItem> _items = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 60),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; LiveStreamPro) AppleWebKit/537.36',
    },
  ));

  List<DownloadItem> get items => _items.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<DownloadItem> get completedItems =>
      items.where((i) => i.status == DownloadStatus.completed).toList();

  List<DownloadItem> get activeItems => items
      .where((i) =>
          i.status == DownloadStatus.downloading ||
          i.status == DownloadStatus.pending)
      .toList();

  int get totalCompletedBytes {
    var sum = 0;
    for (final i in completedItems) {
      sum += i.downloadedBytes;
    }
    return sum;
  }

  String get formattedTotalStorageUsed {
    final mb = totalCompletedBytes / (1024 * 1024);
    if (mb >= 1000) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  bool isDownloaded(String id) {
    final item = _items[id];
    if (item == null) return false;
    if (item.status == DownloadStatus.completed) {
      final file = File(item.filePath);
      return file.existsSync() && file.lengthSync() > 0;
    }
    return false;
  }

  bool isDownloading(String id) {
    final item = _items[id];
    return item != null &&
        (item.status == DownloadStatus.downloading ||
            item.status == DownloadStatus.pending);
  }

  DownloadItem? getItem(String id) => _items[id];

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        for (final entry in list) {
          final item = DownloadItem.fromJson(entry as Map<String, dynamic>);
          // Verify local file exists for completed items
          if (item.status == DownloadStatus.completed) {
            final f = File(item.filePath);
            if (!f.existsSync() || f.lengthSync() == 0) {
              item.status = DownloadStatus.failed;
            }
          } else if (item.status == DownloadStatus.downloading) {
            item.status = DownloadStatus.paused;
          }
          _items[item.id] = item;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _items.values.map((i) => i.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving downloads: $e');
    }
  }

  Future<void> startDownload({
    required String id,
    required String title,
    required String url,
    required String poster,
    required String category,
    required String type,
  }) async {
    if (url.isEmpty) return;

    if (isDownloaded(id)) return;

    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/downloads');
    if (!downloadDir.existsSync()) {
      downloadDir.createSync(recursive: true);
    }

    String ext = 'mp4';
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (last.contains('.')) {
        ext = last.split('.').last.toLowerCase();
        if (ext.length > 5 || ext.isEmpty) ext = 'mp4';
      }
    } catch (_) {}

    final safeFileName =
        '${id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.$ext';
    final targetPath = '${downloadDir.path}/$safeFileName';

    final item = DownloadItem(
      id: id,
      title: title,
      url: url,
      poster: poster,
      category: category,
      type: type,
      filePath: targetPath,
      status: DownloadStatus.downloading,
      progress: 0.0,
    );

    _items[id] = item;
    notifyListeners();
    _saveToStorage();

    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    int lastBytes = 0;
    DateTime lastTime = DateTime.now();

    try {
      await _dio.download(
        url,
        targetPath,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            item.downloadedBytes = received;
            item.totalBytes = total;
            item.progress = received / total;

            final now = DateTime.now();
            final diffMs = now.difference(lastTime).inMilliseconds;
            if (diffMs >= 600) {
              final speedBytesPerSec =
                  ((received - lastBytes) / (diffMs / 1000)).round();
              final speedMb = speedBytesPerSec / (1024 * 1024);
              if (speedMb >= 1.0) {
                item.speed = '${speedMb.toStringAsFixed(1)} MB/s';
              } else {
                final speedKb = speedBytesPerSec / 1024;
                item.speed = '${speedKb.toStringAsFixed(0)} KB/s';
              }
              lastBytes = received;
              lastTime = now;
              notifyListeners();
            }
          }
        },
      );

      item.status = DownloadStatus.completed;
      item.progress = 1.0;
      item.speed = '';
      _cancelTokens.remove(id);
      notifyListeners();
      _saveToStorage();
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        item.status = DownloadStatus.paused;
      } else {
        item.status = DownloadStatus.failed;
      }
      item.speed = '';
      _cancelTokens.remove(id);
      notifyListeners();
      _saveToStorage();
    }
  }

  void pauseDownload(String id) {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]?.cancel('Paused by user');
      _cancelTokens.remove(id);
    }
    final item = _items[id];
    if (item != null) {
      item.status = DownloadStatus.paused;
      item.speed = '';
      notifyListeners();
      _saveToStorage();
    }
  }

  Future<void> resumeDownload(String id) async {
    final item = _items[id];
    if (item == null) return;
    await startDownload(
      id: item.id,
      title: item.title,
      url: item.url,
      poster: item.poster,
      category: item.category,
      type: item.type,
    );
  }

  Future<void> deleteDownload(String id) async {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]?.cancel('Deleted by user');
      _cancelTokens.remove(id);
    }
    final item = _items[id];
    if (item != null) {
      try {
        final file = File(item.filePath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        debugPrint('Error deleting download file: $e');
      }
      _items.remove(id);
      notifyListeners();
      await _saveToStorage();
    }
  }
}
