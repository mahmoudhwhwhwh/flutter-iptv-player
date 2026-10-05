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
  String? errorMessage;
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
    this.errorMessage,
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
        'errorMessage': errorMessage,
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
      errorMessage: json['errorMessage']?.toString(),
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
  final Map<String, Map<String, String>> _itemHeaders = {};

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
    if (item != null &&
        (item.status == DownloadStatus.downloading ||
            item.status == DownloadStatus.pending)) {
      return true;
    }
    final cleanWanted = _normalizeId(id);
    if (cleanWanted.isNotEmpty) {
      for (final entry in _items.values) {
        if (_normalizeId(entry.id) == cleanWanted &&
            (entry.status == DownloadStatus.downloading ||
                entry.status == DownloadStatus.pending)) {
          return true;
        }
      }
    }
    return false;
  }

  DownloadItem? getItem(String id) {
    return _items[id] ??
        _items[id.replaceFirst(RegExp(r'^offline_'), '')] ??
        findCompletedForStream(streamId: id);
  }

  static Uint8List _peekHeaderBytes(File file, [int maxBytes = 512]) {
    try {
      if (!file.existsSync()) return Uint8List(0);
      final len = file.lengthSync();
      if (len <= 0) return Uint8List(0);
      final raf = file.openSync(mode: FileMode.read);
      try {
        final readLen = len < maxBytes ? len : maxBytes;
        return raf.readSync(readLen);
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return Uint8List(0);
    }
  }

  static String _peekHeaderText(File file) {
    final bytes = _peekHeaderBytes(file, 256);
    if (bytes.isEmpty) return '';
    return utf8.decode(bytes, allowMalformed: true).trimLeft();
  }

  static bool _isHlsManifestFile(File file) {
    final head = _peekHeaderText(file);
    return head.startsWith('#EXTM3U');
  }

  /// Inspects magic bytes of a downloaded video file to determine its real container format.
  static String? detectContainerExtensionFromBytes(File file) {
    final bytes = _peekHeaderBytes(file, 256);
    if (bytes.length < 12) return null;

    // 1. MP4 / MOV / M4V: bytes 4..8 == 'ftyp' or 'moov' or 'wide' or 'mdat'
    final boxType = String.fromCharCodes(bytes.sublist(4, 8));
    if (boxType == 'ftyp' ||
        boxType == 'moov' ||
        boxType == 'mdat' ||
        boxType == 'wide' ||
        boxType == 'free') {
      return 'mp4';
    }

    // 2. Matroska / MKV / WebM: 0x1A 0x45 0xDF 0xA3
    if (bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3) {
      return 'mkv';
    }

    // 3. MPEG-TS: sync byte 0x47 at offset 0 (and 188 if enough bytes)
    if (bytes[0] == 0x47 && (bytes.length < 189 || bytes[188] == 0x47)) {
      return 'ts';
    }
    // Sometimes MPEG-TS starts after a small packet offset
    for (int offset = 0; offset < 64 && offset + 188 < bytes.length; offset++) {
      if (bytes[offset] == 0x47 && bytes[offset + 188] == 0x47) {
        return 'ts';
      }
    }

    // 4. AVI: 'RIFF' .... 'AVI '
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'avi';
    }

    // 5. FLV: 'FLV'
    if (bytes[0] == 0x46 && bytes[1] == 0x4C && bytes[2] == 0x56) {
      return 'mp4';
    }

    return null;
  }

  static bool _isValidLocalVideoFile(File file) {
    try {
      if (!file.existsSync()) return false;
      final len = file.lengthSync();
      // A real video file must be at least 16 KB (rejects HTML/JSON error pages)
      if (len <= 16384) return false;
      final head = _peekHeaderText(file).toLowerCase();
      if (head.startsWith('#extm3u') ||
          head.startsWith('<!doctype') ||
          head.startsWith('<html') ||
          head.startsWith('<head') ||
          head.startsWith('<body') ||
          head.startsWith('{"error') ||
          head.startsWith('{"status') ||
          head.startsWith('{"user_info') ||
          head.startsWith('error') ||
          head.startsWith('access denied') ||
          head.startsWith('403 ') ||
          head.startsWith('404 ')) {
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
                final detectedExt = detectContainerExtensionFromBytes(f);
                if (detectedExt != null &&
                    !item.filePath.toLowerCase().endsWith('.$detectedExt')) {
                  final dotIdx = item.filePath.lastIndexOf('.');
                  final newPath = dotIdx > 0
                      ? '${item.filePath.substring(0, dotIdx)}.$detectedExt'
                      : '${item.filePath}.$detectedExt';
                  try {
                    final renamed = f.renameSync(newPath);
                    item.filePath = renamed.path;
                  } catch (_) {}
                }
                final actualFile = File(item.filePath);
                final actualLen = actualFile.existsSync() ? actualFile.lengthSync() : 0;
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

  static HttpClient _createRawHttpClient() {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 25);
    client.idleTimeout = const Duration(seconds: 60);
    client.autoUncompress = false;
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return client;
  }

  /// Opens an HTTP GET request and manually follows 301/302/303/307/308 redirects
  /// across both HTTP and HTTPS schemes (preventing Dart's RedirectException on HTTPS -> HTTP redirects).
  Future<HttpClientResponse> _openGetWithManualRedirects(
    HttpClient client,
    Uri initialUri,
    Map<String, String> headers, {
    int startByte = 0,
  }) async {
    Uri currentUri = initialUri;
    for (int hop = 0; hop < 10; hop++) {
      final request = await client.getUrl(currentUri);
      request.followRedirects = false;
      headers.forEach((key, value) {
        if (value.isNotEmpty) {
          request.headers.set(key, value);
        }
      });
      if (startByte > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$startByte-');
      }
      final response = await request.close();
      final code = response.statusCode;
      if (code == HttpStatus.movedPermanently ||
          code == HttpStatus.found ||
          code == HttpStatus.seeOther ||
          code == HttpStatus.temporaryRedirect ||
          code == HttpStatus.permanentRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>().catchError((_) {});
        if (location == null || location.trim().isEmpty) {
          return response;
        }
        currentUri = currentUri.resolve(location.trim());
        continue;
      }
      return response;
    }
    throw Exception('Too many redirects while resolving download stream');
  }

  /// Resolves a single-hop redirect (if any) without consuming the final media stream.
  /// Useful for ExoPlayer when an HTTPS panel redirects (302) to an HTTP storage node.
  static Future<String> resolveCrossProtocolRedirectForPlayback(
    String rawUrl,
    Map<String, String> headers,
  ) async {
    final client = _createRawHttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      Uri currentUri = Uri.parse(rawUrl.trim());
      for (int hop = 0; hop < 5; hop++) {
        final request = await client
            .getUrl(currentUri)
            .timeout(const Duration(seconds: 6));
        request.followRedirects = false;
        headers.forEach((k, v) {
          if (v.isNotEmpty) request.headers.set(k, v);
        });
        final response =
            await request.close().timeout(const Duration(seconds: 6));
        final code = response.statusCode;
        if (code == HttpStatus.movedPermanently ||
            code == HttpStatus.found ||
            code == HttpStatus.seeOther ||
            code == HttpStatus.temporaryRedirect ||
            code == HttpStatus.permanentRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>().catchError((_) {});
          if (location == null || location.trim().isEmpty) break;
          final nextUri = currentUri.resolve(location.trim());
          // If redirected to a direct storage node (different host or port), return it immediately
          // before opening a connection to the storage node so one-time tokens remain valid for ExoPlayer.
          if (nextUri.host != currentUri.host ||
              nextUri.port != currentUri.port ||
              nextUri.scheme != currentUri.scheme) {
            // If it's just http -> https on the same domain (Cloudflare), follow one more hop
            if (nextUri.host == currentUri.host &&
                currentUri.scheme == 'http' &&
                nextUri.scheme == 'https') {
              currentUri = nextUri;
              continue;
            }
            return nextUri.toString();
          }
          currentUri = nextUri;
          continue;
        }
        // Not a redirect; abort connection immediately and return currentUri
        client.close(force: true);
        return currentUri.toString();
      }
      return currentUri.toString();
    } catch (_) {
      return rawUrl;
    } finally {
      try {
        client.close(force: true);
      } catch (_) {}
    }
  }

  /// Queries Xtream API if the URL is a series container (e.g., series_123) or a movie whose
  /// true container_extension on the server might be .mkv/.mp4/.avi.
  Future<List<String>> _resolveXtreamApiCandidates(
    String rawUrl,
    String id,
    String type,
    Map<String, String> headers,
  ) async {
    final discovered = <String>[];
    final client = _createRawHttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.tryParse(rawUrl.trim());
      if (uri == null) return discovered;
      final segs = uri.pathSegments;
      final isMovie = segs.contains('movie');
      final isSeries = segs.contains('series');
      if (!isMovie && !isSeries) return discovered;

      final idx = isMovie ? segs.indexOf('movie') : segs.indexOf('series');
      if (idx < 0 || segs.length < idx + 4) return discovered;

      final baseSegs = segs.take(idx).toList();
      var host = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: baseSegs.isEmpty ? '' : '/${baseSegs.join('/')}',
      ).toString().replaceFirst(RegExp(r'/$'), '');
      if (host.startsWith('http://x.gamerdz1517.com')) {
        host = host.replaceFirst('http://', 'https://');
      }

      final user = Uri.decodeComponent(segs[idx + 1]);
      final pass = Uri.decodeComponent(segs[idx + 2]);
      final fileSeg = segs[idx + 3];
      final cleanMediaId = fileSeg.contains('.')
          ? fileSeg.substring(0, fileSeg.lastIndexOf('.'))
          : fileSeg;
      if (cleanMediaId.isEmpty) return discovered;

      if (isMovie) {
        final apiUri = Uri.parse('$host/player_api.php').replace(
          queryParameters: {
            'username': user,
            'password': pass,
            'action': 'get_vod_info',
            'vod_id': cleanMediaId,
          },
        );
        final resp = await _openGetWithManualRedirects(client, apiUri, headers)
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final bodyBytes = await consolidateHttpClientResponseBytes(resp);
          final decoded = jsonDecode(utf8.decode(bodyBytes, allowMalformed: true));
          if (decoded is Map) {
            final movieData = decoded['movie_data'];
            final info = decoded['info'];
            final serverExt = (movieData is Map
                        ? (movieData['container_extension'] ??
                            movieData['extension'])
                        : null) ??
                    (info is Map
                        ? (info['container_extension'] ?? info['extension'])
                        : null);
            final extStr =
                serverExt?.toString().trim().replaceFirst('.', '') ?? '';
            if (extStr.isNotEmpty) {
              discovered.add(
                  '$host/movie/${Uri.encodeComponent(user)}/${Uri.encodeComponent(pass)}/$cleanMediaId.$extStr');
            }
          }
        }
      } else if (isSeries &&
          (id.startsWith('series_') || id.startsWith('vod556_series_'))) {
        // The user clicked download on a Series container card instead of an individual episode.
        // Resolve the first episode's real ID and extension via get_series_info!
        final seriesId = _normalizeId(id).isNotEmpty ? _normalizeId(id) : cleanMediaId;
        final apiUri = Uri.parse('$host/player_api.php').replace(
          queryParameters: {
            'username': user,
            'password': pass,
            'action': 'get_series_info',
            'series_id': seriesId,
          },
        );
        final resp = await _openGetWithManualRedirects(client, apiUri, headers)
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final bodyBytes = await consolidateHttpClientResponseBytes(resp);
          final decoded = jsonDecode(utf8.decode(bodyBytes, allowMalformed: true));
          if (decoded is Map && decoded['episodes'] is Map) {
            final epsMap = decoded['episodes'] as Map;
            for (final seasonKey in epsMap.keys) {
              final epList = epsMap[seasonKey];
              if (epList is List && epList.isNotEmpty) {
                final firstEp = epList.first;
                if (firstEp is Map) {
                  final epId = firstEp['id']?.toString().trim() ?? '';
                  final epExt = (firstEp['container_extension'] ??
                              firstEp['extension'] ??
                              'mp4')
                          .toString()
                          .trim()
                          .replaceFirst('.', '');
                  if (epId.isNotEmpty) {
                    discovered.add(
                        '$host/series/${Uri.encodeComponent(user)}/${Uri.encodeComponent(pass)}/$epId.${epExt.isEmpty ? 'mp4' : epExt}');
                    discovered.add(
                        '$host/series/${Uri.encodeComponent(user)}/${Uri.encodeComponent(pass)}/$epId.mp4');
                    discovered.add(
                        '$host/series/${Uri.encodeComponent(user)}/${Uri.encodeComponent(pass)}/$epId.mkv');
                    break;
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {
    } finally {
      try {
        client.close(force: true);
      } catch (_) {}
    }
    return discovered;
  }

  static List<String> _buildCandidateDownloadUrls(
    String rawUrl, {
    List<String> priorityUrls = const <String>[],
  }) {
    var base = rawUrl.trim();
    if (base.isEmpty && priorityUrls.isEmpty) return const <String>[];
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

    for (final p in priorityUrls) {
      addUnique(p);
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
        addUnique('$prefix.avi');
      }
    } else if (base.isNotEmpty) {
      addUnique(base);
    }

    for (final url in List<String>.from(result)) {
      if (url.startsWith('https://')) {
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
    required Map<String, String> headers,
  }) async {
    final client = _createRawHttpClient();
    try {
      String manifestText = initialManifestContent;
      Uri baseUri = Uri.parse(manifestUrl);

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
        final resp = await _openGetWithManualRedirects(
          client,
          resolvedVariantUri,
          headers,
        );
        if (resp.statusCode < 200 || resp.statusCode >= 300) return false;
        final bytes = await consolidateHttpClientResponseBytes(resp);
        manifestText = utf8.decode(bytes, allowMalformed: true);
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
          final segResp = await _openGetWithManualRedirects(
            client,
            segmentUris[idx],
            headers,
          );
          if (segResp.statusCode >= 200 && segResp.statusCode < 300) {
            await for (final chunk in segResp) {
              if (cancelToken.isCancelled) break;
              if (chunk.isNotEmpty) {
                sink.add(chunk);
                totalWritten += chunk.length;
              }
            }
            item.downloadedBytes = totalWritten;
            item.progress = ((idx + 1) / segmentUris.length).clamp(0.0, 1.0);
            if (item.progress > 0.02) {
              item.totalBytes = (totalWritten / item.progress).round();
            }

            final now = DateTime.now();
            final diffMs = now.difference(lastTime).inMilliseconds;
            if (diffMs >= 400 || idx == segmentUris.length - 1) {
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

      return outFile.existsSync() && outFile.lengthSync() > 16384;
    } finally {
      try {
        client.close(force: true);
      } catch (_) {}
    }
  }

  Future<bool> _streamSingleCandidateToFile({
    required String candidateUrl,
    required String targetPath,
    required DownloadItem item,
    required CancelToken cancelToken,
    required Map<String, String> headers,
  }) async {
    final client = _createRawHttpClient();
    IOSink? sink;
    StreamSubscription<List<int>>? sub;
    try {
      final uri = Uri.parse(candidateUrl);
      final response = await _openGetWithManualRedirects(client, uri, headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>().catchError((_) {});
        return false;
      }

      final contentType =
          response.headers.value(HttpHeaders.contentTypeHeader)?.toLowerCase() ??
              '';
      if (contentType.contains('text/html') ||
          contentType.contains('application/json')) {
        await response.drain<void>().catchError((_) {});
        return false;
      }

      final total = response.contentLength;
      if (total > 0) {
        item.totalBytes = total;
      }

      final outFile = File(targetPath);
      if (outFile.existsSync()) {
        try {
          outFile.deleteSync();
        } catch (_) {}
      }
      sink = outFile.openWrite(mode: FileMode.writeOnly);

      int received = 0;
      int lastBytes = 0;
      DateTime lastTime = DateTime.now();
      final completer = Completer<bool>();

      void onCancel() {
        sub?.cancel();
        try {
          client.close(force: true);
        } catch (_) {}
        if (!completer.isCompleted) {
          completer.completeError(DioException.requestCancelled(
            requestOptions: RequestOptions(path: candidateUrl),
            reason: 'Cancelled',
          ));
        }
      }

      cancelToken.whenCancel.then((_) => onCancel());

      sub = response.listen(
        (List<int> chunk) {
          if (cancelToken.isCancelled) {
            onCancel();
            return;
          }
          if (chunk.isNotEmpty) {
            sink?.add(chunk);
            received += chunk.length;
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
            if (diffMs >= 400) {
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
        onDone: () async {
          try {
            await sink?.flush();
            await sink?.close();
            sink = null;
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.complete(received > 0);
          }
        },
        onError: (Object err) async {
          try {
            await sink?.close();
            sink = null;
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.completeError(err);
          }
        },
        cancelOnError: true,
      );

      return await completer.future;
    } finally {
      try {
        await sub?.cancel();
      } catch (_) {}
      try {
        await sink?.close();
      } catch (_) {}
      try {
        client.close(force: true);
      } catch (_) {}
    }
  }

  Future<void> startDownload({
    required String id,
    required String title,
    required String url,
    required String poster,
    required String category,
    required String type,
    Map<String, String>? headers,
  }) async {
    if (url.isEmpty) return;
    if (isDownloaded(id)) return;
    if (isDownloading(id)) return;

    final requestHeaders = <String, String>{
      'User-Agent': 'IPTVSmartersPro',
      'Accept': '*/*',
      'Connection': 'keep-alive',
      if (headers != null) ...headers,
    };
    _itemHeaders[id] = requestHeaders;

    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/downloads');
    if (!downloadDir.existsSync()) {
      await downloadDir.create(recursive: true);
    }

    final safeBaseName = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    String targetPath = '${downloadDir.path}/$safeBaseName.mp4';

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
      speed: 'جاري الاتصال...',
      errorMessage: null,
    );

    _items[id] = item;
    notifyListeners();
    await _saveToStorage();

    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    // Resolve Xtream VOD/Series container info (including resolving Series container IDs to episode 1!)
    final apiDiscoveredUrls = await _resolveXtreamApiCandidates(
      url,
      id,
      type,
      requestHeaders,
    );
    final candidates = _buildCandidateDownloadUrls(
      url,
      priorityUrls: apiDiscoveredUrls,
    );
    if (candidates.isEmpty) {
      item.status = DownloadStatus.failed;
      item.speed = '';
      item.errorMessage = 'الرابط غير صالح للتنزيل';
      _cancelTokens.remove(id);
      notifyListeners();
      await _saveToStorage();
      return;
    }

    bool succeeded = false;
    Object? lastError;

    // Up to 4 retry rounds (handles Xtream servers with max_connections=1 when player is closing)
    for (int round = 0; round < 4 && !succeeded && !cancelToken.isCancelled; round++) {
      if (round > 0) {
        item.speed = 'إعادة المحاولة (${round + 1}/4)...';
        notifyListeners();
        await Future<void>.delayed(Duration(seconds: 2 * round));
      }

      for (final candidateUrl in candidates) {
        if (cancelToken.isCancelled) break;

        try {
          final ok = await _streamSingleCandidateToFile(
            candidateUrl: candidateUrl,
            targetPath: targetPath,
            item: item,
            cancelToken: cancelToken,
            headers: requestHeaders,
          );
          if (!ok) continue;

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
              headers: requestHeaders,
            );
            if (hlsOk) {
              downloadedFile = File(tsTargetPath);
            }
          }

          if (_isValidLocalVideoFile(downloadedFile)) {
            // Detect true binary container format and normalize file extension for ExoPlayer
            final detectedExt =
                detectContainerExtensionFromBytes(downloadedFile) ?? 'mp4';
            final finalPath = '${downloadDir.path}/$safeBaseName.$detectedExt';
            if (downloadedFile.path != finalPath) {
              try {
                final existingTarget = File(finalPath);
                if (existingTarget.existsSync()) {
                  existingTarget.deleteSync();
                }
                downloadedFile = downloadedFile.renameSync(finalPath);
              } catch (_) {}
            }
            item.filePath = downloadedFile.path;
            final actualLen = downloadedFile.lengthSync();
            item.downloadedBytes = actualLen;
            item.totalBytes = actualLen;
            item.status = DownloadStatus.completed;
            item.progress = 1.0;
            item.speed = '';
            item.errorMessage = null;
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
      item.errorMessage =
          'تعذر التحميل من المصدر (تأكد من إغلاق المشغل إذا كان الاشتراك يدعم اتصالاً واحداً فقط ثم اضغط إعادة المحاولة)';
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
      headers: _itemHeaders[id],
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
