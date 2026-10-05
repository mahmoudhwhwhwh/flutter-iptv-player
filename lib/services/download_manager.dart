import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
  final int createdAt;

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
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

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
        'createdAt': createdAt,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString() ?? 'pending';
    DownloadStatus parsedStatus = DownloadStatus.pending;
    for (final s in DownloadStatus.values) {
      if (s.name == statusStr) {
        parsedStatus = s;
        break;
      }
    }
    return DownloadItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      poster: json['poster']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      type: json['type']?.toString() ?? 'movie',
      filePath: json['filePath']?.toString() ?? '',
      status: parsedStatus,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as num?)?.toInt(),
    );
  }

  String get formattedDownloadedSize {
    if (downloadedBytes <= 0) return '0.0 MB';
    final mb = downloadedBytes / (1024 * 1024);
    if (mb >= 1000) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get formattedTotalSize {
    if (totalBytes <= 0) return 'غير معروف';
    final mb = totalBytes / (1024 * 1024);
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
    receiveTimeout: const Duration(minutes: 120),
    followRedirects: true,
    maxRedirects: 8,
    headers: {
      'User-Agent': 'IPTVSmartersPro',
      'Accept': '*/*',
      'Connection': 'keep-alive',
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

  static String _normalizeId(String rawId) {
    return rawId
        .trim()
        .replaceFirst(RegExp(r'^offline_'), '')
        .replaceFirst(
            RegExp(
                r'^(vod556_movie_|stalker_movie_|movie_|vod556_series_|stalker_series_|series_)'),
            '');
  }

  DownloadItem? findCompletedForStream({
    required String streamId,
    String? url,
    String? title,
  }) {
    final direct =
        _items[streamId] ?? _items[streamId.replaceFirst(RegExp(r'^offline_'), '')];
    if (direct != null &&
        direct.status == DownloadStatus.completed &&
        _isValidLocalVideoFile(File(direct.filePath))) {
      return direct;
    }
    final cleanWanted = _normalizeId(streamId);
    for (final item in _items.values) {
      if (item.status != DownloadStatus.completed) continue;
      if (!_isValidLocalVideoFile(File(item.filePath))) continue;
      if (cleanWanted.isNotEmpty && _normalizeId(item.id) == cleanWanted) {
        return item;
      }
      if (url != null &&
          url.isNotEmpty &&
          (item.filePath == url || item.url == url)) {
        return item;
      }
      if (title != null &&
          title.trim().isNotEmpty &&
          item.title.trim() == title.trim()) {
        return item;
      }
    }
    return null;
  }

  bool isDownloaded(String id) {
    final direct =
        _items[id] ?? _items[id.replaceFirst(RegExp(r'^offline_'), '')];
    if (direct != null && direct.status == DownloadStatus.completed) {
      final file = File(direct.filePath);
      if (_isValidLocalVideoFile(file)) return true;
    }
    return findCompletedForStream(streamId: id) != null;
  }

  bool isDownloading(String id) {
    final item =
        _items[id] ?? _items[id.replaceFirst(RegExp(r'^offline_'), '')];
    return item != null &&
        (item.status == DownloadStatus.downloading ||
            item.status == DownloadStatus.pending);
  }

  DownloadItem? getItem(String id) {
    return _items[id] ??
        _items[id.replaceFirst(RegExp(r'^offline_'), '')] ??
        findCompletedForStream(streamId: id);
  }

  static String _peekHeaderText(File file) {
    try {
      if (!file.existsSync()) return '';
      final len = file.lengthSync();
      if (len <= 0) return '';
      final raf = file.openSync(mode: FileMode.read);
      try {
        final readLen = len < 256 ? len : 256;
        final bytes = raf.readSync(readLen);
        return utf8.decode(bytes, allowMalformed: true).trimLeft();
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return '';
    }
  }

  static bool _isHlsManifestFile(File file) {
    final head = _peekHeaderText(file);
    return head.startsWith('#EXTM3U');
  }

  static bool _isValidLocalVideoFile(File file) {
    try {
      if (!file.existsSync()) return false;
      final len = file.lengthSync();
      if (len <= 1024) return false;
      final head = _peekHeaderText(file).toLowerCase();
      if (head.startsWith('#extm3u') ||
          head.startsWith('<!doctype') ||
          head.startsWith('<html') ||
          head.startsWith('{"error') ||
          head.startsWith('{"status')) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final entry in list) {
          if (entry is Map) {
            final item =
                DownloadItem.fromJson(Map<String, dynamic>.from(entry));
            if (item.status == DownloadStatus.downloading ||
                item.status == DownloadStatus.pending) {
              item.status = DownloadStatus.paused;
            }
            if (item.status == DownloadStatus.completed) {
              final f = File(item.filePath);
              if (!_isValidLocalVideoFile(f)) {
                item.status = DownloadStatus.failed;
              } else {
                final actualLen = f.lengthSync();
                if (item.downloadedBytes <= 0) {
                  item.downloadedBytes = actualLen;
                }
                if (item.totalBytes <= 0) {
                  item.totalBytes = actualLen;
                }
              }
            }
            if (item.id.isNotEmpty) {
              _items[item.id] = item;
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('DownloadManager load error: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(_items.values.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('DownloadManager save error: $e');
    }
  }

  String? getLocalPath(String id) {
    final matched = findCompletedForStream(streamId: id);
    return matched?.filePath;
  }

  static List<String> _buildCandidateDownloadUrls(String rawUrl) {
    var base = rawUrl.trim();
    if (base.isEmpty) return const <String>[];
    if (base.startsWith('http://x.gamerdz1517.com')) {
      base = base.replaceFirst('http://', 'https://');
    }

    final result = <String>[];
    void addUnique(String candidate) {
      final c = candidate.trim();
      if (c.isNotEmpty && !result.contains(c)) {
        result.add(c);
      }
    }

    final isXtreamVodOrSeries =
        base.contains('/movie/') || base.contains('/series/');
    if (isXtreamVodOrSeries) {
      final dotIndex = base.lastIndexOf('.');
      final slashIndex = base.lastIndexOf('/');
      final hasExt = dotIndex > slashIndex;
      final prefix = hasExt ? base.substring(0, dotIndex) : base;
      final ext = hasExt ? base.substring(dotIndex + 1).toLowerCase() : '';

      if (ext == 'm3u8') {
        addUnique('$prefix.mp4');
        addUnique('$prefix.mkv');
        addUnique('$prefix.ts');
        addUnique(base);
      } else {
        addUnique(base);
        addUnique('$prefix.mp4');
        addUnique('$prefix.mkv');
        addUnique('$prefix.ts');
      }
    } else {
      addUnique(base);
    }

    // Add HTTP/HTTPS fallback for servers that redirect or block one scheme
    for (final url in List<String>.from(result)) {
      if (url.startsWith('https://') && !url.contains('x.gamerdz1517.com')) {
        addUnique(url.replaceFirst('https://', 'http://'));
      } else if (url.startsWith('http://')) {
        addUnique(url.replaceFirst('http://', 'https://'));
      }
    }
    return result;
  }

  Future<bool> _downloadHlsSegmentsToLocalFile({
    required String manifestUrl,
    required String initialManifestContent,
    required String targetPath,
    required DownloadItem item,
    required CancelToken cancelToken,
  }) async {
    String manifestText = initialManifestContent;
    Uri baseUri = Uri.parse(manifestUrl);

    // If master playlist, resolve the best media playlist first
    final lines = manifestText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final hasStreamInf = lines.any((l) => l.startsWith('#EXT-X-STREAM-INF'));
    if (hasStreamInf) {
      String? variantUrl;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('#EXT-X-STREAM-INF')) {
          for (int j = i + 1; j < lines.length; j++) {
            if (!lines[j].startsWith('#')) {
              variantUrl = lines[j];
              break;
            }
          }
          if (variantUrl != null) break;
        }
      }
      if (variantUrl == null) return false;
      final resolvedVariantUri = baseUri.resolve(variantUrl);
      final resp = await _dio.get<String>(
        resolvedVariantUri.toString(),
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.plain),
      );
      manifestText = resp.data ?? '';
      baseUri = resolvedVariantUri;
    }

    final mediaLines = manifestText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();

    if (mediaLines.isEmpty) return false;

    final segmentUris =
        mediaLines.map((seg) => baseUri.resolve(seg)).toList();
    final outFile = File(targetPath);
    if (outFile.existsSync()) {
      try {
        outFile.deleteSync();
      } catch (_) {}
    }
    final sink = outFile.openWrite(mode: FileMode.writeOnly);
    int totalWritten = 0;
    int lastBytes = 0;
    DateTime lastTime = DateTime.now();

    try {
      for (int idx = 0; idx < segmentUris.length; idx++) {
        if (cancelToken.isCancelled) {
          throw DioException.requestCancelled(
              requestOptions:
                  RequestOptions(path: segmentUris[idx].toString()),
              reason: 'Cancelled');
        }
        final segRes = await _dio.get<List<int>>(
          segmentUris[idx].toString(),
          cancelToken: cancelToken,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = segRes.data;
        if (bytes != null && bytes.isNotEmpty) {
          sink.add(Uint8List.fromList(bytes));
          totalWritten += bytes.length;
          item.downloadedBytes = totalWritten;
          item.progress = ((idx + 1) / segmentUris.length).clamp(0.0, 1.0);
          if (item.progress > 0.02) {
            item.totalBytes = (totalWritten / item.progress).round();
          }

          final now = DateTime.now();
          final diffMs = now.difference(lastTime).inMilliseconds;
          if (diffMs >= 500 || idx == segmentUris.length - 1) {
            final speedBytesPerSec = diffMs > 0
                ? ((totalWritten - lastBytes) / (diffMs / 1000)).round()
                : 0;
            final speedMb = speedBytesPerSec / (1024 * 1024);
            if (speedMb >= 1.0) {
              item.speed = '${speedMb.toStringAsFixed(1)} MB/s';
            } else {
              final speedKb = speedBytesPerSec / 1024;
              item.speed = '${speedKb.toStringAsFixed(0)} KB/s';
            }
            lastBytes = totalWritten;
            lastTime = now;
            notifyListeners();
          }
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    return outFile.existsSync() && outFile.lengthSync() > 1024;
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

    final candidates = _buildCandidateDownloadUrls(url);
    if (candidates.isEmpty) return;
    final primaryUrl = candidates.first;

    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/downloads');
    if (!downloadDir.existsSync()) {
      await downloadDir.create(recursive: true);
    }

    String ext = 'mp4';
    try {
      final uri = Uri.parse(primaryUrl);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (last.contains('.')) {
        ext = last.split('.').last.toLowerCase();
        if (ext == 'm3u8' || ext.length > 5 || ext.isEmpty) {
          ext = 'mp4';
        }
      }
    } catch (_) {}

    final safeBaseName = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    String targetPath = '${downloadDir.path}/$safeBaseName.$ext';

    final item = DownloadItem(
      id: id,
      title: title,
      url: primaryUrl,
      poster: poster,
      category: category,
      type: type,
      filePath: targetPath,
      status: DownloadStatus.downloading,
      progress: 0.0,
    );

    _items[id] = item;
    notifyListeners();
    await _saveToStorage();

    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    bool succeeded = false;
    Object? lastError;

    for (final candidateUrl in candidates) {
      if (cancelToken.isCancelled) break;
      int lastBytes = 0;
      DateTime lastTime = DateTime.now();

      try {
        await _dio.download(
          candidateUrl,
          targetPath,
          cancelToken: cancelToken,
          deleteOnError: true,
          onReceiveProgress: (received, total) {
            item.downloadedBytes = received;
            if (total > 0) {
              item.totalBytes = total;
              item.progress = (received / total).clamp(0.0, 1.0);
            } else {
              item.progress =
                  (received / (250 * 1024 * 1024)).clamp(0.02, 0.95);
            }

            final now = DateTime.now();
            final diffMs = now.difference(lastTime).inMilliseconds;
            if (diffMs >= 500) {
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
          },
        );

        File downloadedFile = File(targetPath);
        if (!downloadedFile.existsSync()) continue;

        if (_isHlsManifestFile(downloadedFile)) {
          final manifestContent = await downloadedFile.readAsString();
          final tsTargetPath = '${downloadDir.path}/$safeBaseName.ts';
          item.filePath = tsTargetPath;
          targetPath = tsTargetPath;
          final hlsOk = await _downloadHlsSegmentsToLocalFile(
            manifestUrl: candidateUrl,
            initialManifestContent: manifestContent,
            targetPath: tsTargetPath,
            item: item,
            cancelToken: cancelToken,
          );
          if (hlsOk) {
            downloadedFile = File(tsTargetPath);
          }
        }

        if (_isValidLocalVideoFile(downloadedFile)) {
          final actualLen = downloadedFile.lengthSync();
          item.downloadedBytes = actualLen;
          item.totalBytes = actualLen;
          item.status = DownloadStatus.completed;
          item.progress = 1.0;
          item.speed = '';
          succeeded = true;
          break;
        } else {
          try {
            if (downloadedFile.existsSync()) downloadedFile.deleteSync();
          } catch (_) {}
        }
      } catch (e) {
        lastError = e;
        if (e is DioException && CancelToken.isCancel(e)) {
          break;
        }
      }
    }

    _cancelTokens.remove(id);
    if (succeeded) {
      notifyListeners();
      await _saveToStorage();
      return;
    }

    if (lastError is DioException && CancelToken.isCancel(lastError)) {
      item.status = DownloadStatus.paused;
    } else {
      item.status = DownloadStatus.failed;
    }
    item.speed = '';
    notifyListeners();
    await _saveToStorage();
  }

  void pauseDownload(String id) {
    final token = _cancelTokens.remove(id);
    token?.cancel('Paused by user');
    final item = _items[id];
    if (item != null) {
      item.status = DownloadStatus.paused;
      item.speed = '';
      notifyListeners();
      _saveToStorage();
    }
  }

  void resumeDownload(String id) {
    final item = _items[id];
    if (item == null) return;
    startDownload(
      id: item.id,
      title: item.title,
      url: item.url,
      poster: item.poster,
      category: item.category,
      type: item.type,
    );
  }

  Future<void> deleteDownload(String id) async {
    final token = _cancelTokens.remove(id);
    token?.cancel('Deleted by user');
    final item = _items.remove(id);
    if (item != null) {
      try {
        final f = File(item.filePath);
        if (f.existsSync()) {
          await f.delete();
        }
      } catch (_) {}
      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> clearAllDownloads() async {
    for (final token in _cancelTokens.values) {
      token.cancel('Cleared all');
    }
    _cancelTokens.clear();
    for (final item in _items.values) {
      try {
        final f = File(item.filePath);
        if (f.existsSync()) {
          await f.delete();
        }
      } catch (_) {}
    }
    _items.clear();
    notifyListeners();
    await _saveToStorage();
  }
}
