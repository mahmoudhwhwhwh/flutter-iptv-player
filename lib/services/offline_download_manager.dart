import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineDownloadItem {
  static const _keepError = Object();
  final String id;
  final String title;
  final String sourceUrl;
  final String filePath;
  final String mediaType;
  final String status;
  final int receivedBytes;
  final int totalBytes;
  final String? error;
  final String? subscriptionScope;
  final int updatedAt;

  const OfflineDownloadItem({
    required this.id,
    required this.title,
    required this.sourceUrl,
    required this.filePath,
    required this.mediaType,
    required this.status,
    required this.receivedBytes,
    required this.totalBytes,
    required this.error,
    required this.subscriptionScope,
    required this.updatedAt,
  });

  bool get isComplete => status == 'completed';
  bool get isRunning => status == 'downloading';
  bool get isPaused => status == 'paused';
  bool get isFailed => status == 'failed';
  double? get progress => totalBytes > 0 ? receivedBytes / totalBytes : null;

  OfflineDownloadItem copyWith({
    String? status,
    int? receivedBytes,
    int? totalBytes,
    Object? error = _keepError,
  }) {
    return OfflineDownloadItem(
      id: id,
      title: title,
      sourceUrl: sourceUrl,
      filePath: filePath,
      mediaType: mediaType,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: identical(error, _keepError) ? this.error : error as String?,
      subscriptionScope: subscriptionScope,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'mediaType': mediaType,
        'status': status,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'error': error,
        'subscriptionScope': subscriptionScope,
        'updatedAt': updatedAt,
      };

  factory OfflineDownloadItem.fromJson(Map<String, dynamic> json,
      {required String sourceUrl}) {
    return OfflineDownloadItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'ملف بدون اسم',
      sourceUrl: sourceUrl,
      filePath: json['filePath']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? 'mp4',
      status: json['status']?.toString() ?? 'failed',
      receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      error: json['error']?.toString(),
      subscriptionScope: json['subscriptionScope']?.toString(),
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class OfflineDownloadManager extends ChangeNotifier {
  OfflineDownloadManager._();
  static final OfflineDownloadManager instance = OfflineDownloadManager._();

  static const _metadataKey = 'offline_downloads_v1';
  static const _urlPrefix = 'offline_download_url_v1_';
  static const _storage = FlutterSecureStorage();

  final Dio _dio = Dio();
  final Map<String, OfflineDownloadItem> _items = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _deleteAfterCancel = <String>{};
  SharedPreferences? _prefs;
  Directory? _downloadDirectory;
  bool _loaded = false;

  List<OfflineDownloadItem> get items {
    final result = _items.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(result);
  }

  Future<void> initialize() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    final docs = await getApplicationDocumentsDirectory();
    _downloadDirectory = Directory('${docs.path}/offline_downloads');
    await _downloadDirectory!.create(recursive: true);
    final raw = _prefs!.getString(_metadataKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final rawItem in list) {
            if (rawItem is! Map) continue;
            final json = Map<String, dynamic>.from(rawItem);
            final id = json['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            final url = await _storage.read(key: '$_urlPrefix$id') ?? '';
            if (url.isEmpty) continue;
            var item = OfflineDownloadItem.fromJson(json, sourceUrl: url);
            if (item.status == 'downloading') {
              item = item.copyWith(status: 'paused', error: 'توقف التطبيق أثناء التنزيل');
            }
            if (item.isComplete && !File(item.filePath).existsSync()) {
              item = item.copyWith(
                  status: 'failed', error: 'ملف التنزيل غير موجود على الجهاز');
            }
            _items[id] = item;
          }
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  String? _supportedExtension(String url, [String? advertisedExtension]) {
    final clean = url.split('|').first.split('?').first.toLowerCase();
    for (final ext in ['.mp4', '.m4v', '.mov']) {
      if (clean.endsWith(ext)) return ext.substring(1);
    }
    final advertised = (advertisedExtension ?? '').toLowerCase().replaceFirst('.', '');
    if (advertised == 'mp4' || advertised == 'm4v' || advertised == 'mov') {
      return advertised;
    }
    return null;
  }

  String _stableId(String scope, String sourceUrl) {
    var hash = 2166136261;
    for (final codeUnit in '$scope|$sourceUrl'.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<OfflineDownloadItem?> add({
    required String title,
    required String url,
    required String? subscriptionScope,
    String? advertisedExtension,
  }) async {
    await initialize();
    final extension = _supportedExtension(url, advertisedExtension);
    if (extension == null) return null;
    final cleanUrl = url.split('|').first;
    final id = _stableId(subscriptionScope ?? 'default', cleanUrl);
    final existing = _items[id];
    if (existing != null) {
      if (existing.isComplete || existing.isRunning) return existing;
      unawaited(resume(id));
      return _items[id];
    }
    final safeTitle = title.replaceAll(RegExp(r'[^\w\-\u0600-\u06FF ]+'), '_').trim();
    final filePath = '${_downloadDirectory!.path}/$id-${safeTitle.isEmpty ? 'media' : safeTitle}.$extension';
    final item = OfflineDownloadItem(
      id: id,
      title: title,
      sourceUrl: cleanUrl,
      filePath: filePath,
      mediaType: extension,
      status: 'paused',
      receivedBytes: 0,
      totalBytes: 0,
      error: null,
      subscriptionScope: subscriptionScope,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _items[id] = item;
    await _storage.write(key: '$_urlPrefix$id', value: cleanUrl);
    await _persist();
    notifyListeners();
    unawaited(resume(id));
    return _items[id];
  }

  Future<void> resume(String id) async {
    await initialize();
    final item = _items[id];
    if (item == null || item.isComplete || item.isRunning) return;
    final token = CancelToken();
    _cancelTokens[id] = token;
    var partFile = File('${item.filePath}.part');
    var received = partFile.existsSync() ? await partFile.length() : 0;
    _items[id] = item.copyWith(status: 'downloading', receivedBytes: received, error: null);
    await _persist();
    notifyListeners();

    IOSink? sink;
    try {
      final response = await _dio.get<ResponseBody>(
        item.sourceUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: received > 0 ? {'Range': 'bytes=$received-'} : null,
          validateStatus: (status) => status != null && status >= 200 && status < 400,
        ),
        cancelToken: token,
      );
      final body = response.data;
      if (body == null) throw const HttpException('مصدر التنزيل لا يعيد بيانات');
      final statusCode = response.statusCode ?? 0;
      final acceptsRange = statusCode == 206 && received > 0;
      if (received > 0 && !acceptsRange) {
        received = 0;
        partFile = File('${item.filePath}.part');
      }
      final contentLength = int.tryParse(
            response.headers.value(Headers.contentLengthHeader) ?? '',
          ) ??
          -1;
      final total = acceptsRange && contentLength >= 0
          ? received + contentLength
          : contentLength;
      if (!acceptsRange && received == 0 && partFile.existsSync()) {
        await partFile.delete();
      }
      sink = partFile.openWrite(
        mode: acceptsRange ? FileMode.append : FileMode.write,
      );
      final activeSink = sink!;
      var downloaded = received;
      await for (final chunk in body.stream) {
        if (token.isCancelled) break;
        activeSink.add(chunk);
        downloaded += chunk.length;
        final current = _items[id];
        if (current == null) break;
        _items[id] = current.copyWith(
          status: 'downloading',
          receivedBytes: downloaded,
          totalBytes: total > 0 ? total : 0,
          error: null,
        );
        notifyListeners();
        if (downloaded % (512 * 1024) < chunk.length) await _persist();
      }
      await activeSink.flush();
      await activeSink.close();
      sink = null;
      if (token.isCancelled) {
        final current = _items[id];
        if (current != null) {
          _items[id] = current.copyWith(
              status: 'paused', receivedBytes: downloaded, error: null);
        }
      } else {
        final finalLength = await partFile.length();
        if (total > 0 && finalLength < total) {
          final current = _items[id];
          if (current == null) return;
          _items[id] = current.copyWith(
            status: 'failed',
            receivedBytes: finalLength,
            totalBytes: total,
            error: 'اكتمل الاتصال قبل اكتمال الملف',
          );
        } else {
          final finalFile = File(item.filePath);
          if (finalFile.existsSync()) await finalFile.delete();
          await partFile.rename(item.filePath);
          final current = _items[id];
          if (current == null) return;
          _items[id] = current.copyWith(
            status: 'completed',
            receivedBytes: finalLength,
            totalBytes: total > 0 ? total : finalLength,
            error: null,
          );
        }
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        final current = _items[id];
        if (current != null) {
          _items[id] = current.copyWith(status: 'paused', error: null);
        }
      } else {
        final current = _items[id];
        if (current == null) return;
        _items[id] = current.copyWith(
          status: 'failed',
          error: 'تعذر تنزيل الملف: ${error.response?.statusCode ?? 'اتصال'}',
        );
      }
    } catch (error) {
      final current = _items[id];
      if (current != null) {
        _items[id] = current.copyWith(
            status: 'failed', error: 'فشل التنزيل أو لا توجد مساحة كافية');
      }
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      _cancelTokens.remove(id);
      if (_deleteAfterCancel.remove(id)) {
        final current = _items.remove(id);
        if (current != null) {
          for (final path in [current.filePath, '${current.filePath}.part']) {
            final file = File(path);
            if (file.existsSync()) await file.delete();
          }
        }
        await _storage.delete(key: '$_urlPrefix$id');
      }
      await _persist();
      notifyListeners();
    }
  }

  Future<void> pause(String id) async {
    _cancelTokens[id]?.cancel('pause');
  }

  Future<void> cancel(String id) async {
    if (_cancelTokens.containsKey(id)) {
      _deleteAfterCancel.add(id);
      _cancelTokens[id]?.cancel('cancel');
      return;
    }
    _cancelTokens[id]?.cancel('cancel');
    final item = _items.remove(id);
    if (item != null) {
      for (final path in [item.filePath, '${item.filePath}.part']) {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      }
      await _storage.delete(key: '$_urlPrefix$id');
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteCompleted(String id) => cancel(id);

  Future<void> _persist() async {
    if (_prefs == null) return;
    await _prefs!.setString(
      _metadataKey,
      jsonEncode(_items.values.map((item) => item.toJson()).toList()),
    );
  }
}
