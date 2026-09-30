import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'multi_screen_layout.dart';
import 'multi_screen_player.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_iptv_player/main.dart';
import 'package:flutter_iptv_player/models/playlist_item.dart';
import 'package:flutter_iptv_player/providers/iptv_provider.dart';
import 'package:flutter_iptv_player/services/stalker_playback.dart';
import 'package:flutter_iptv_player/services/channel_switch_guard.dart';
import 'package:flutter_iptv_player/services/redacted_diagnostics.dart';

enum RotationMode {
  smartAuto,
  landscapeOnly,
  portraitOnly,
}

enum LiveImageFilter { none, k4, k8 }

List<double> liveImageFilterMatrix(LiveImageFilter filter) {
  switch (filter) {
    case LiveImageFilter.k4:
      return const [
        1.10,
        0,
        0,
        0,
        -0.02,
        0,
        1.10,
        0,
        0,
        -0.02,
        0,
        0,
        1.10,
        0,
        -0.02,
        0,
        0,
        0,
        1,
        0,
      ];
    case LiveImageFilter.k8:
      return const [
        1.18,
        0,
        0,
        0,
        -0.04,
        0,
        1.18,
        0,
        0,
        -0.04,
        0,
        0,
        1.18,
        0,
        -0.04,
        0,
        0,
        0,
        1,
        0,
      ];
    case LiveImageFilter.none:
      return const [
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ];
  }
}

int? bestAvailableQualityHeight(Iterable<int> heights, int targetHeight) {
  final available =
      heights.where((height) => height > 0 && height <= targetHeight);
  if (available.isEmpty) return null;
  return available.reduce((a, b) => a > b ? a : b);
}

String realQualityTrackKey(BetterPlayerAsmsTrack track) =>
    '${track.id}|${track.width}|${track.height}|${track.bitrate}';

String realQualityAvailabilityLabel({required bool hasTracks}) {
  return hasTracks
      ? 'مسارات الجودة المعلنة من المصدر'
      : 'مسار المصدر الأصلي — جودة واحدة';
}

String realQualityTrackLabel(BetterPlayerAsmsTrack track) {
  final height = track.height ?? 0;
  final width = track.width ?? 0;
  final resolution = height > 0 ? '${height}p' : 'تلقائي';
  final suffix = height >= 2160
      ? ' • 4K'
      : height >= 1080
          ? ' • Full HD'
          : '';
  final bitrate = track.bitrate ?? 0;
  final rate =
      bitrate > 0 ? ' • ${(bitrate / 1000000).toStringAsFixed(1)} Mbps' : '';
  return width > 0 ? '$resolution$suffix$rate' : '$resolution$rate';
}

class PlayerScreen extends StatefulWidget {
  final PlaylistItem stream;
  const PlayerScreen({super.key, required this.stream});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  BetterPlayerController? _betterController;
  VideoPlayerController? _loadingVideoController;
  VideoPlayerController? _offlineVideoController;

  void _initOfflineVideo() {
    if (_offlineVideoController != null &&
        _offlineVideoController!.value.isInitialized) {
      return;
    }
    try {
      final ctrl = VideoPlayerController.asset('assets/channel_offline.mp4');
      ctrl.initialize().then((_) {
        if (!mounted) {
          ctrl.dispose();
          return;
        }
        ctrl.setLooping(true);
        ctrl.setVolume(0.0);
        ctrl.play();
        setState(() {
          _offlineVideoController = ctrl;
        });
      }).catchError((_) {});
    } catch (_) {}
  }

  void _initLoadingVideo() {
    try {
      final ctrl = VideoPlayerController.asset('assets/loading_stream.mp4');
      ctrl.initialize().then((_) {
        if (!mounted) {
          ctrl.dispose();
          return;
        }
        ctrl.setLooping(true);
        ctrl.setVolume(0.0);
        ctrl.play();
        setState(() {
          _loadingVideoController = ctrl;
        });
      }).catchError((_) {});
    } catch (_) {}
  }
  WebViewController? _webController;
  bool _isWebFallback = false;
  GlobalKey _betterPlayerKey = GlobalKey();
  bool _initialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isBuffering = false;
  late PlaylistItem _stream;
  bool _showHUD = true;
  Timer? _hideHUDTimer;
  bool _isPipActive = false;
  String _aiSubtitleText = "";
  String _selectedAiLang = "";
  Timer? _aiSubtitleTimer;

  BoxFit _currentBoxFit = BoxFit.contain;
  String _aspectRatioLabel = "تلقائي";
  bool _showSidebar = false;
  LiveImageFilter _liveImageFilter = LiveImageFilter.none;

  RotationMode _rotationMode = RotationMode.landscapeOnly;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  DeviceOrientation? _lastPhysicalOrientation;
  String? _onScreenToastText;
  IconData _onScreenToastIcon = Icons.aspect_ratio_rounded;

  // Swipe Gestures
  double _dragStartY = 0.0;
  double _dragStartValue = 0.0;
  bool _isDraggingLeft = false;
  bool _isDraggingRight = false;
  String? _swipeToastText;
  IconData? _swipeToastIcon;
  Timer? _swipeToastTimer;

  Timer? _zoomIndicatorTimer;
  Timer? _screenOnTimer;

  // Brightness simulation overlay (0.0 means normal/bright, 0.8 means dim)
  double _brightnessFactor = 0.0;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;

  // Focus node for TV remote controls and virtual bitrate cap for DASH streams
  final FocusNode _firstButtonFocusNode = FocusNode();
  int? _selectedVirtualBitrate;
  int _lastPlayerSettingsVersion = -1;

  // Position tracker
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _positionTimer;
  final ChannelSwitchGuard _channelSwitchGuard = ChannelSwitchGuard();

  double _subSizeVal = 16.0;
  Color _subColorVal = Colors.white;
  Color _subBgColorVal = Colors.transparent;
  String _subFontVal = 'Cairo';
  String _subLangVal = "تلقائي";
  bool _remoteControlEnabled = true;
  bool _mouseControlEnabled = true;

  // Screen lock & rotation states
  bool _isLocked = false;
  bool _showLockToggleOnly = false;
  Timer? _lockToggleTimer;

  // Sidebar Search & Category
  String _sidebarSearchQuery = "";
  String _sidebarSelectedCategory = "all";
  Timer? _sidebarSearchDebounce;
  final FocusNode _sidebarSearchFocusNode = FocusNode();

  // Sleep Timer
  Timer? _sleepTimer;
  int? _sleepTimerMinutes;

  bool _isPortrait = false;

  void _resetLockToggleTimer() {
    _lockToggleTimer?.cancel();
    _sleepTimer?.cancel();
    _lockToggleTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showLockToggleOnly = false;
        });
      }
    });
  }

  // Auto-retry state variables key to stable IPTV stream links
  int _retryCount = 0;
  final int _maxRetries = 3;
  Timer? _reconnectTimer;

  bool get _isLiveStream =>
      _stream.type == 'live' || _totalDuration.inSeconds == 0;

  Duration _liveRetryDelay() {
    final seconds = (1 << (_retryCount.clamp(0, 4))).toInt();
    return Duration(seconds: seconds.clamp(1, 12));
  }

  bool get _isDrm => _stream.clearKeys != null && _stream.clearKeys!.isNotEmpty;

  Future<String?> _malformedHlsTsFallback(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final body = response.body;
      if (RegExp(r'^#EXTM3U', multiLine: true).allMatches(body).length < 2) {
        return null;
      }
      final mediaUrls = body
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) =>
              (line.startsWith('http://') || line.startsWith('https://')) &&
              !line.startsWith('#'))
          .toList();
      if (mediaUrls.isEmpty) return null;
      final candidate = mediaUrls.last;
      final candidateUri = Uri.tryParse(candidate);
      final embedded = candidateUri?.queryParameters['url'];
      if (embedded != null && embedded.startsWith('http')) {
        return embedded;
      }
      return candidate;
    } catch (_) {
      return null;
    }
  }

  List<String> _playbackCandidates(String primary) {
    final candidates = <String>[];
    void add(String value) {
      final normalized = stripFfmpegPrefix(value.trim());
      if (normalized.isNotEmpty && !candidates.contains(normalized)) {
        candidates.add(normalized);
      }
    }
    add(primary);
    final uri = Uri.tryParse(primary);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      add(uri.replace(scheme: uri.scheme == 'http' ? 'https' : 'http').toString());
      final path = uri.path.toLowerCase();
      if (path.endsWith('.ts')) {
        add(uri.replace(path: '${uri.path.substring(0, uri.path.length - 3)}m3u8').toString());
      } else if (path.endsWith('.m3u8')) {
        add(uri.replace(path: '${uri.path.substring(0, uri.path.length - 5)}ts').toString());
      }
    }
    if (_stream.fallbackUrl?.trim().isNotEmpty == true) add(_stream.fallbackUrl!);
    return candidates;
  }

  String _prepareClearKeyString(Map<String, String> keys) {
    try {
      final List<Map<String, dynamic>> jwkList = [];
      keys.forEach((hexKid, hexKey) {
        try {
          final cleanKid =
              hexKid.trim().replaceAll(RegExp(r'[^a-fA-F0-9]'), '');
          final cleanKey =
              hexKey.trim().replaceAll(RegExp(r'[^a-fA-F0-9]'), '');

          if (cleanKid.length >= 2 && cleanKey.length >= 2) {
            final kidBytes = <int>[];
            for (int i = 0; i < cleanKid.length; i += 2) {
              kidBytes.add(int.parse(cleanKid.substring(i, i + 2), radix: 16));
            }
            final keyBytes = <int>[];
            for (int i = 0; i < cleanKey.length; i += 2) {
              keyBytes.add(int.parse(cleanKey.substring(i, i + 2), radix: 16));
            }

            final kidB64 = base64Url.encode(kidBytes).replaceAll('=', '');
            final keyB64 = base64Url.encode(keyBytes).replaceAll('=', '');

            jwkList.add({
              'kty': 'oct',
              'k': keyB64,
              'kid': kidB64,
            });
          }
        } catch (_) {}
      });

      if (jwkList.isNotEmpty) {
        final w3cFormat = {
          'keys': jwkList,
          'type': 'temporary',
        };
        return jsonEncode(w3cFormat);
      }
    } catch (_) {}

    return jsonEncode(keys);
  }

  Future<void> _loadSubSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String sSize = prefs.getString('sub_size') ?? "متوسط";
      String sCol = prefs.getString('sub_color') ?? "أبيض";
      String sBg = prefs.getString('sub_bg_color') ?? "شفاف";
      _subFontVal = prefs.getString('sub_font') ?? 'Cairo';
      _subLangVal = prefs.getString('sub_lang') ?? "تلقائي";
      _remoteControlEnabled = prefs.getBool('remote_control_enabled') ?? true;
      _mouseControlEnabled = prefs.getBool('mouse_control_enabled') ?? true;

      if (sSize == "صغير")
        _subSizeVal = 12.0;
      else if (sSize == "متوسط")
        _subSizeVal = 16.0;
      else if (sSize == "كبير")
        _subSizeVal = 22.0;
      else if (sSize == "ضخم")
        _subSizeVal = 28.0;
      else
        _subSizeVal = 16.0;

      if (sCol == "أصفر")
        _subColorVal = Colors.yellow;
      else if (sCol == "أزرق سماوي")
        _subColorVal = Colors.cyanAccent;
      else if (sCol == "أخضر")
        _subColorVal = Colors.greenAccent;
      else if (sCol == "أحمر")
        _subColorVal = Colors.redAccent;
      else if (sCol == "أزرق")
        _subColorVal = Colors.blueAccent;
      else if (sCol == "وردي")
        _subColorVal = Colors.pinkAccent;
      else if (sCol == "برتقالي")
        _subColorVal = Colors.orange;
      else if (sCol == "بنفسجي")
        _subColorVal = Colors.purpleAccent;
      else if (sCol == "أسود")
        _subColorVal = Colors.black;
      else if (sCol == "رمادي")
        _subColorVal = Colors.grey;
      else
        _subColorVal = Colors.white;

      if (sBg == "أسود")
        _subBgColorVal = Colors.black87;
      else if (sBg == "رمادي داكن")
        _subBgColorVal = Colors.black54;
      else if (sBg == "أحمر داكن")
        _subBgColorVal = Colors.red[900]!.withOpacity(0.8);
      else if (sBg == "أزرق داكن")
        _subBgColorVal = Colors.blue[900]!.withOpacity(0.8);
      else if (sBg == "أخضر داكن")
        _subBgColorVal = Colors.green[900]!.withOpacity(0.8);
      else if (sBg == "أرجواني داكن")
        _subBgColorVal = Colors.purple[900]!.withOpacity(0.8);
      else if (sBg == "أبيض")
        _subBgColorVal = Colors.white70;
      else
        _subBgColorVal = Colors.transparent;

      // المشغّل يُعرض أفقياً دائماً لتثبيت الأزرار ومنع التدوير غير المتوقع.
      _isPortrait = false;
      _rotationMode = RotationMode.landscapeOnly;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      if (mounted) setState(() {});
    } catch (e) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final version = context.watch<IPTVProvider>().playerSettingsVersion;
    final shouldRefresh = _lastPlayerSettingsVersion >= 0 &&
        _lastPlayerSettingsVersion != version &&
        _initialized;
    _lastPlayerSettingsVersion = version;
    if (shouldRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadSubSettings();
        // Better Player يحتفظ بنمط الترجمة في State داخلي؛ المفتاح الجديد
        // يعيد إنشاء طبقة النص بالقيم المحفوظة بدلاً من الشكل الافتراضي القديم.
        _betterPlayerKey = GlobalKey();
        if (mounted) _initializeController(isRetry: true);
      });
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    WakelockPlus.enable();
    _screenOnTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) WakelockPlus.enable();
    });
    _loadSubSettings();
    _stream = widget.stream;
    _initLoadingVideo();

    // عرض ثابت أفقي للمشغّل؛ لا تُستخدم حساسات الحركة لتفادي التدوير العشوائي.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializeController();
    _resetHideHUDTimer();
  }

  Future<void> _prepareXtreamSubtitles(
    BetterPlayerController controller,
    Map<String, String> headers,
  ) async {
    // Better Player يقرأ قائمة HLS/DASH برؤوس البث، لكن مسارات الترجمة
    // المكتشفة لا ترثها تلقائياً. ننسخها هنا لمسارات Xtream الحقيقية.
    for (var attempt = 0; attempt < 8 && mounted; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final sources = controller.betterPlayerSubtitlesSourceList;
      final trackIndexes = <int>[];
      for (var i = 0; i < sources.length; i++) {
        if (sources[i].type != BetterPlayerSubtitlesSourceType.none) {
          trackIndexes.add(i);
        }
      }
      if (trackIndexes.isEmpty) continue;

      for (final index in trackIndexes) {
        final source = sources[index];
        sources[index] = BetterPlayerSubtitlesSource(
          type: source.type,
          name: source.name,
          urls: source.urls,
          content: source.content,
          selectedByDefault: source.selectedByDefault,
          headers: Map<String, String>.from(headers),
          asmsIsSegmented: source.asmsIsSegmented,
          asmsSegmentsTime: source.asmsSegmentsTime,
          asmsSegments: source.asmsSegments,
        );
      }
      await _applyPreferredSubtitleLanguage(retries: 0);
      return;
    }
  }

  Future<void> _applyPreferredSubtitleLanguage({int retries = 5}) async {
    if (_subLangVal == "تلقائي" || _betterController == null) return;
    try {
      final tracks = _betterController!.betterPlayerSubtitlesSourceList;
      String targetLang = _subLangVal.toLowerCase();
      if (targetLang == "arabic")
        targetLang = "ar";
      else if (targetLang == "english")
        targetLang = "en";
      else if (targetLang == "french")
        targetLang = "fr";
      else if (targetLang == "spanish")
        targetLang = "es";
      else if (targetLang == "turkish")
        targetLang = "tr";
      else if (targetLang == "persian") targetLang = "fa";

      BetterPlayerSubtitlesSource? matchedSource;
      for (final track in tracks) {
        final name = (track.name ?? "").toLowerCase();
        if (name.contains(targetLang) ||
            (targetLang == "ar" && name.contains("عرب"))) {
          matchedSource = track;
          break;
        }
      }
      if (matchedSource != null) {
        await _betterController!.setupSubtitleSource(matchedSource);
      } else if (retries > 0 && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await _applyPreferredSubtitleLanguage(retries: retries - 1);
      }
    } catch (e) {
      debugPrint(
          "Failed to apply Xtream subtitle language: ${redactDiagnostic(e)}");
    }
  }

  void _disposeActiveController() {
    final controller = _betterController;
    _betterController = null;
    _initialized = false;
    _positionTimer?.cancel();
    _positionTimer = null;
    if (controller == null) return;
    try {
      controller.setVolume(0.0);
      controller.pause();
    } catch (_) {}
    try {
      controller.dispose();
    } catch (_) {}
  }

  void _initializeController({bool isRetry = false, int? generation}) async {
    final loadGeneration = generation ?? _channelSwitchGuard.begin();
    int? savedPosition;
    if (_stream.type != 'live') {
      try {
        final prefs = await SharedPreferences.getInstance();
        savedPosition = prefs.getInt('vod_pos_${_stream.streamId}');
      } catch (e) {
        debugPrint("Error loading saved position: ${redactDiagnostic(e)}");
      }
    }
    await _loadSubSettings();
    if (!mounted || !_channelSwitchGuard.isCurrent(loadGeneration)) return;
    if (!isRetry) {
      _initialized = false;
      _hasError = false;
      _errorMessage = null;
    } else if (mounted) {
      setState(() {
        _initialized = false;
        _hasError = false;
        _errorMessage = null;
        _isBuffering = true;
      });
    }
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    _isWebFallback = false;
    _webController = null;

    try {
      FirebaseAnalytics.instance.logEvent(
        name: 'play_channel',
        parameters: {
          'channel_name': _stream.name,
          'stream_id': _stream.streamId,
          'category_name': _stream.categoryName,
          'category_id': _stream.categoryId,
          'channel_type': _stream.type,
        },
      );
    } catch (e) {
      debugPrint("Could not log play_channel event: $e");
    }

    final provider = Provider.of<IPTVProvider>(context, listen: false);
    final candidates = _playbackCandidates(_stream.url);
    final candidateIndex = isRetry && candidates.isNotEmpty
        ? _retryCount % candidates.length
        : 0;
    String urlStr = candidates.isEmpty
        ? stripFfmpegPrefix(_stream.url)
        : candidates[candidateIndex];
    final activePlaylist = provider.savedPlaylists.firstWhere(
      (p) => p.id == provider.activePlaylistId,
      orElse: () => UserPlaylist(id: '', name: '', type: ''),
    );
    final isStalkerPlaylist = activePlaylist.type == 'stalker';
    final isStalkerContent = _stream.type == "stalker" ||
        _stream.type == "stalker_movie" ||
        _stream.type == "stalker_series" ||
        (isStalkerPlaylist &&
            (_stream.type == "movie" || _stream.type == "series"));
    final bool isDirectStalkerPlayback = isDirectStalkerPlaybackUrl(urlStr);

    if (isStalkerContent && !isDirectStalkerPlayback) {
      try {
        final host =
            (activePlaylist.host ?? '').replaceFirst(RegExp(r'/+$'), '');
        final mac = activePlaylist.username;
        String sType = "itv";
        if (_stream.type == "stalker_series" ||
            (isStalkerPlaylist && _stream.type == "series")) {
          sType = "series";
        } else if (_stream.type == "stalker_movie" ||
            (isStalkerPlaylist && _stream.type == "movie")) {
          sType = "vod";
        }
        final linkUrl = Uri.parse(
            "$host/server/load.php?type=$sType&action=create_link&cmd=${Uri.encodeComponent(urlStr)}&series=0&forced_storage=0&disable_ad=0&JsHttpRequest=1-xml${provider.stalkerToken.isEmpty ? '' : '&token=${Uri.encodeQueryComponent(provider.stalkerToken)}'}");
        final reqHeaders = {
          "Cookie": "mac=$mac; stb_lang=en; timezone=Europe%2FAmsterdam",
          "Authorization": "Bearer ${provider.stalkerToken}",
          "User-Agent":
              "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3",
          "X-User-Agent": "Model: MAG250; Link: WiFi; Conn: WiFi"
        };

        final res = await http.get(linkUrl, headers: reqHeaders);
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['js'] != null && data['js']['cmd'] != null) {
            urlStr = data['js']['cmd'].toString().replaceAll("ffmpeg ", "");
          }
        }
      } catch (e) {
        debugPrint("Error resolving stalker link: ${redactDiagnostic(e)}");
      }
      if (!mounted || !_channelSwitchGuard.isCurrent(loadGeneration)) return;
    }

    String finalUrl = urlStr;
    if (isHlsPlaybackUrl(finalUrl)) {
      final malformedFallback = await _malformedHlsTsFallback(finalUrl);
      if (malformedFallback != null && malformedFallback.isNotEmpty) {
        finalUrl = malformedFallback;
        urlStr = finalUrl;
      }
    }
    final sourceDescriptor = classifyPlaybackUrl(finalUrl);
    final isIptvMediaCandidate = _stream.type == 'live' ||
        _stream.type == 'movie' ||
        _stream.type == 'series' ||
        _stream.type == 'channel' ||
        _stream.type.startsWith('stalker_');
    if (!sourceDescriptor.isDirectMedia && isIptvMediaCandidate) {
      // Xtream/Stalker VOD endpoints often omit the extension and return the
      // media MIME type only after the request. Keep these URLs in ExoPlayer
      // instead of incorrectly treating them as HTML pages.
      finalUrl = sourceDescriptor.normalizedUrl;
    } else if (!sourceDescriptor.isDirectMedia) {
      final isWebSource =
          sourceDescriptor.kind == PlaybackSourceKind.youtubePage ||
              sourceDescriptor.kind == PlaybackSourceKind.webPage;
      if (isWebSource && sourceDescriptor.normalizedUrl.isNotEmpty) {
        _webController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(NavigationDelegate(
            onWebResourceError: (error) {
              if (!mounted || !_channelSwitchGuard.isCurrent(loadGeneration))
                return;
              setState(() {
                _hasError = true;
                _isBuffering = false;
                _errorMessage = 'تعذر تحميل صفحة الفيديو: ${error.errorCode}';
              });
            },
          ))
          ..loadRequest(Uri.parse(sourceDescriptor.normalizedUrl));
        if (mounted && _channelSwitchGuard.isCurrent(loadGeneration)) {
          setState(() {
            _isWebFallback = true;
            _initialized = true;
            _isBuffering = false;
            _hasError = false;
            _errorMessage = null;
          });
        }
        return;
      }
      if (mounted && _channelSwitchGuard.isCurrent(loadGeneration)) {
        setState(() {
          _initialized = false;
          _isBuffering = false;
          _hasError = true;
          _errorMessage = sourceDescriptor.unsupportedReason ??
              'هذا الرابط ليس مصدراً فيديو مباشراً قابلاً للتشغيل.';
        });
      }
      return;
    }

    // Obtain active provider variables
    // Setup httpHeaders map with default or global override
    Map<String, String> headers = {
      'User-Agent':
          _stream.customUserAgent != null && _stream.customUserAgent!.isNotEmpty
              ? _stream.customUserAgent!
              : (provider.globalUserAgent.isNotEmpty
                  ? provider.globalUserAgent
                  : 'IPTVSmartersPro'),
      'Accept': '*/*',
      'Connection': 'keep-alive',
    };

    if (isStalkerContent ||
        urlStr.contains("mac=") ||
        urlStr.contains("play/live.php")) {
      headers['User-Agent'] =
          'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3';
      try {
        if (urlStr.contains("mac=")) {
          final uri = Uri.parse(urlStr);
          final macParam = uri.queryParameters['mac'];
          if (macParam != null && macParam.isNotEmpty) {
            headers["Cookie"] = "mac=$macParam";
          }
        } else {
          final mac = provider.savedPlaylists
              .firstWhere((p) => p.id == provider.activePlaylistId)
              .username;
          headers["Cookie"] = "mac=$mac";
        }
      } catch (e) {}
    }

    // Custom referer override
    final customRef = _stream.customReferer ?? provider.globalReferer;
    if (customRef.isNotEmpty) {
      headers['Referer'] = customRef;
    }

    // Support Dreambox / Enigma2 style headers embedded in URL: url|Header1=Val1&Header2=Val2
    if (urlStr.contains('|')) {
      final parts = urlStr.split('|');
      finalUrl = parts[0].trim();
      if (parts.length > 1) {
        final headersRaw = parts[1].trim();
        final params = headersRaw.split('&');
        for (var p in params) {
          final kv = p.split('=');
          if (kv.length == 2) {
            final key = kv[0].trim();
            final value = Uri.decodeComponent(kv[1].trim());
            if (key.toLowerCase() == 'user-agent' ||
                key.toLowerCase() == 'http-user-agent') {
              headers['User-Agent'] = value;
            } else if (key.toLowerCase() == 'referer' ||
                key.toLowerCase() == 'http-referer') {
              headers['Referer'] = value;
            } else {
              headers[key] = value;
            }
          }
        }
      }
    }

    // Handle MPD/DASH streams: clean up Referer and User-Agent headers to guarantee 100% video playback compatibility
    final bool isMpdStream = finalUrl.toLowerCase().contains('.mpd') ||
        urlStr.toLowerCase().contains('.mpd');
    if (isMpdStream) {
      // Keep headers if custom user agent or custom referer are specified, otherwise strip default ones to ensure playback
      if (_stream.customUserAgent == null || _stream.customUserAgent!.isEmpty) {
        headers.removeWhere((key, value) =>
            key.toLowerCase() == 'user-agent' ||
            key.toLowerCase() == 'http-user-agent');
      }
      if (_stream.customReferer == null || _stream.customReferer!.isEmpty) {
        headers.removeWhere((key, value) =>
            key.toLowerCase() == 'referer' ||
            key.toLowerCase() == 'http-referer');
      }
    }

    if (!mounted || !_channelSwitchGuard.isCurrent(loadGeneration)) return;
    _disposeActiveController();

    BetterPlayerVideoFormat? format;
    if (isHlsPlaybackUrl(finalUrl)) {
      format = BetterPlayerVideoFormat.hls;
    } else if (isDashPlaybackUrl(finalUrl)) {
      format = BetterPlayerVideoFormat.dash;
    } else if (isProgressiveTsUrl(finalUrl)) {
      // Leave formatHint unset for progressive TS. ExoPlayer can infer MPEG-TS
      // from the .ts URL/content type; forcing `other` bypasses that inference.
      format = null;
    } else if (_stream.type == 'live' &&
        isLikelyLiveTransportStreamUrl(finalUrl)) {
      // Some IPTV servers expose raw MPEG-TS at an extensionless URL.
      format = null;
    }

    bool isAsms = format == BetterPlayerVideoFormat.hls ||
        format == BetterPlayerVideoFormat.dash;

    final BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      finalUrl,
      liveStream: _stream.type == 'live' || _stream.type == 'stalker',
      videoFormat: format,
      videoExtension: (isProgressiveTsUrl(finalUrl) ||
              ((_stream.type == 'live' || _stream.type == 'stalker') &&
                  isLikelyLiveTransportStreamUrl(finalUrl)))
          ? 'ts'
          : null,
      headers: headers,
      useAsmsTracks: isAsms,
      useAsmsSubtitles: isAsms,
      useAsmsAudioTracks: isAsms,
      drmConfiguration:
          _isDrm && _stream.clearKeys != null && _stream.clearKeys!.isNotEmpty
              ? BetterPlayerDrmConfiguration(
                  drmType: BetterPlayerDrmType.clearKey,
                  clearKey: _prepareClearKeyString(_stream.clearKeys!),
                )
              : null,
    );

    BetterPlayerController newBetterController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        looping: false,
        fit: _currentBoxFit,
        subtitlesConfiguration: BetterPlayerSubtitlesConfiguration(
          fontSize: _subSizeVal,
          fontColor: _subColorVal,
          backgroundColor: _subBgColorVal,
          outlineColor: Colors.black,
          outlineSize: 2.0,
          fontFamily: _subFontVal,
          bottomPadding: 48.0,
          leftPadding: 16.0,
          rightPadding: 16.0,
        ),
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
          showControlsOnInitialize: false,
        ),
        handleLifecycle: false,
        allowedScreenSleep: false,
        autoDetectFullscreenDeviceOrientation: true,
        autoDetectFullscreenAspectRatio: true,
      ),
      betterPlayerDataSource: dataSource,
    );

    newBetterController.addEventsListener((BetterPlayerEvent event) {
      if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
        if (!mounted || !_channelSwitchGuard.isCurrent(loadGeneration)) {
          try {
            newBetterController.setVolume(0.0);
            newBetterController.pause();
          } catch (_) {}
          newBetterController.dispose();
          return;
        }
        if (mounted && _channelSwitchGuard.isCurrent(loadGeneration)) {
          setState(() {
            if (_betterController != null &&
                _betterController != newBetterController) {
              try {
                _betterController!.setVolume(0.0);
                _betterController!.pause();
              } catch (_) {}
              _betterController!.dispose();
            }
            _betterController = newBetterController;
            _initialized = true;
            _retryCount = 0;
            if (_betterController!.videoPlayerController != null) {
              _totalDuration =
                  _betterController!.videoPlayerController!.value.duration ??
                      Duration.zero;
            }
            if (savedPosition != null && savedPosition! > 0) {
              final pos = Duration(seconds: savedPosition!);
              if (_totalDuration == Duration.zero || pos < _totalDuration) {
                _betterController!.seekTo(pos);
              }
            }
            if (_betterController != null) {
              _betterController!.setOverriddenFit(_currentBoxFit);
              if (_currentBoxFit == BoxFit.contain) {
                final videoVal =
                    _betterController!.videoPlayerController?.value;
                final vSize = videoVal?.size;
                if (vSize != null && vSize.width > 0 && vSize.height > 0) {
                  _betterController!
                      .setOverriddenAspectRatio(vSize.aspectRatio);
                } else {
                  _betterController!.setOverriddenAspectRatio(16.0 / 9.0);
                }
              } else {
                final size = MediaQuery.of(context).size;
                _betterController!
                    .setOverriddenAspectRatio(size.width / size.height);
              }
            }
            _betterController!.play();
            unawaited(_prepareXtreamSubtitles(newBetterController, headers));
            _startSeekTracker();
          });
        }
      } else if (event.betterPlayerEventType ==
          BetterPlayerEventType.bufferingStart) {
        if (mounted && _channelSwitchGuard.isCurrent(loadGeneration)) {
          setState(() => _isBuffering = true);
        }
      } else if (event.betterPlayerEventType ==
          BetterPlayerEventType.bufferingEnd) {
        if (mounted && _channelSwitchGuard.isCurrent(loadGeneration)) {
          setState(() => _isBuffering = false);
        }
      } else if (event.betterPlayerEventType ==
          BetterPlayerEventType.exception) {
        final errorMessage = event.parameters?["message"] ?? "Playback failure";
        debugPrint("BetterPlayer exception: ${redactDiagnostic(errorMessage)}");
        _handlePlaybackError(errorMessage, loadGeneration);
      }
    });
  }

  void _handlePlaybackError(dynamic error, int generation) {
    if (!_channelSwitchGuard.isCurrent(generation)) return;
    final message = error.toString().trim();
    debugPrint("IPTV Playback failed: ${redactDiagnostic(message)}");
    if (!mounted) return;
    _reconnectTimer?.cancel();
    if (_isLiveStream) {
      _retryCount += 1;
      if (_retryCount >= 4) {
        _initOfflineVideo();
        setState(() {
          _initialized = false;
          _isBuffering = false;
          _hasError = true;
          _errorMessage = "هذه القناة معطلة أو متوقفة من المصدر حالياً";
        });
        return;
      }
      final delay = _liveRetryDelay();
      setState(() {
        _initialized = false;
        _isBuffering = true;
        _hasError = false;
        _errorMessage = null;
      });
      _reconnectTimer = Timer(delay, () {
        if (mounted && _channelSwitchGuard.isCurrent(generation)) {
          _initializeController(isRetry: true, generation: generation);
        }
      });
      return;
    }
    if (_retryCount >= _maxRetries) {
      setState(() {
        _initialized = false;
        _isBuffering = false;
        _hasError = true;
        _errorMessage = message.isEmpty ? null : message;
      });
      return;
    }
    _retryCount += 1;
    setState(() => _isBuffering = true);
    _reconnectTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted && _channelSwitchGuard.isCurrent(generation)) {
        _initializeController(isRetry: true, generation: generation);
      }
    });
  }

  void _startSeekTracker() {
    _positionTimer?.cancel();
    // البث المباشر لا يحتاج إعادة بناء صفحة المشغّل مرتين في الثانية.
    if (_stream.type == 'live') return;
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final value = _betterController?.videoPlayerController?.value;
      if (mounted &&
          value != null &&
          value.initialized &&
          value.position != _currentPosition) {
        setState(() => _currentPosition = value.position);
      }
    });
  }

  @override
  void _startAiSubtitleTimer() {
    _aiSubtitleTimer?.cancel();
    _aiSubtitleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_selectedAiLang.isEmpty) {
        if (_aiSubtitleText.isNotEmpty) {
          setState(() {
            _aiSubtitleText = "";
          });
        }
        return;
      }

      double currentSecs = 0.0;
      if (_betterController != null &&
          _betterController!.videoPlayerController != null) {
        currentSecs = _betterController!
            .videoPlayerController!.value.position.inSeconds
            .toDouble();
      }

      final int secs = currentSecs.toInt() % 120;

      // VOD mapping
      final Map<int, Map<String, String>> vodSubs = {
        0: {
          'ar': 'مرحباً بكم في هذا البث',
          'en': 'Welcome to this stream',
          'fr': 'Bienvenue sur ce flux'
        },
        10: {
          'ar': 'نحن نتابع الأحداث معاً',
          'en': 'We are following the events together',
          'fr': 'Nous suivons les événements ensemble'
        },
        30: {
          'ar': 'ابقوا معنا للمزيد',
          'en': 'Stay tuned for more',
          'fr': 'Restez avec nous pour plus'
        },
        60: {
          'ar': 'تغطية مستمرة على مدار الساعة',
          'en': 'Continuous coverage around the clock',
          'fr': 'Couverture continue 24h/24'
        },
      };

      // Live mapping
      final Map<int, Map<String, String>> liveSubs = {
        0: {
          'ar': 'بث مباشر - تغطية حصرية',
          'en': 'Live Stream - Exclusive Coverage',
          'fr': 'En direct - Couverture exclusive'
        },
        15: {
          'ar': 'نقل حي للأحداث',
          'en': 'Live broadcast of events',
          'fr': 'Diffusion en direct des événements'
        },
        45: {
          'ar': 'تغطية عاجلة',
          'en': 'Breaking coverage',
          'fr': 'Couverture urgente'
        },
      };

      bool isVod =
          _betterController?.videoPlayerController?.value.duration != null &&
              _betterController!.videoPlayerController!.value.duration! >
                  Duration.zero;

      final mapToUse = isVod ? vodSubs : liveSubs;
      int activeKey = 0;

      final keys = mapToUse.keys.toList()..sort();
      for (int k in keys) {
        if (secs >= k) {
          activeKey = k;
        } else {
          break;
        }
      }

      String text = mapToUse[activeKey]?[_selectedAiLang] ?? '';
      if (_aiSubtitleText != text) {
        setState(() {
          _aiSubtitleText = text;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // Do not allow background playback; PiP is the explicit exception.
      if (!_isPipActive) {
        _betterController?.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Re-assert the wake lock after returning from notifications, calls, or
      // system overlays; some Android vendors clear it on resume.
      WakelockPlus.enable();
      _isPortrait = false;
      _rotationMode = RotationMode.landscapeOnly;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // Never restart playback silently after the app returns from background.
      if (_isPipActive) _isPipActive = false;
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    final loadingCtrl = _loadingVideoController;
    _loadingVideoController = null;
    loadingCtrl?.dispose();
    final offlineCtrl = _offlineVideoController;
    _offlineVideoController = null;
    offlineCtrl?.dispose();
    if (_stream.type != 'live' && _currentPosition > Duration.zero) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('vod_pos_${_stream.streamId}', _currentPosition.inSeconds);
      });
    }
    WidgetsBinding.instance.removeObserver(this);
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _positionTimer?.cancel();
    _hideHUDTimer?.cancel();
    _aiSubtitleTimer?.cancel();
    _reconnectTimer?.cancel();
    _zoomIndicatorTimer?.cancel();
    _lockToggleTimer?.cancel();
    _sleepTimer?.cancel();
    _sidebarSearchDebounce?.cancel();
    _screenOnTimer?.cancel();
    _screenOnTimer = null;
    _firstButtonFocusNode.dispose();
    _sidebarSearchFocusNode.dispose();

    // Restore saved orientation preference
    SharedPreferences.getInstance().then((prefs) {
      final String savedOrient = prefs.getString('app_orientation') ?? 'تلقائي';
      if (savedOrient == 'أفقي') {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ]);
      } else if (savedOrient == 'عمودي') {
        SystemChrome.setPreferredOrientations(
            [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      } else {
        SystemChrome.setPreferredOrientations([]);
      }
    }).catchError((_) {});

    _channelSwitchGuard.begin();
    WakelockPlus.disable();
    _disposeActiveController();
    super.dispose();
  }

  void _resetHideHUDTimer() {
    _hideHUDTimer?.cancel();
    _aiSubtitleTimer?.cancel();
    if (_showHUD) {
      _hideHUDTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _showHUD = false;
          });
        }
      });
    }
  }

  void _toggleHUD() {
    setState(() {
      _showHUD = !_showHUD;
      _resetHideHUDTimer();
      if (_showHUD) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _firstButtonFocusNode.canRequestFocus) {
            _firstButtonFocusNode.requestFocus();
          }
        });
      }
    });
  }

  void _zapStream(IPTVProvider provider, PlaylistItem targetStream) {
    final generation = _channelSwitchGuard.begin();
    provider.selectStream(targetStream);
    _reconnectTimer?.cancel();

    _disposeActiveController();

    setState(() {
      _stream = targetStream;
      _initialized = false;
      _hasError = false;
      _selectedVirtualBitrate = null; // Reset virtual quality ceiling
      _retryCount = 0; // reset counter on manual switch
    });
    _initializeController(generation: generation);
  }

  void _zapNextPrev(IPTVProvider provider, bool next) {
    provider.zapChannel(next);
    final nextStream = provider.currentStream;
    if (nextStream != null && nextStream.streamId != _stream.streamId) {
      _zapStream(provider, nextStream);
    }
  }

  void _showOnScreenToast(String text, IconData icon) {
    _zoomIndicatorTimer?.cancel();
    setState(() {
      _onScreenToastText = text;
      _onScreenToastIcon = icon;
    });
    _zoomIndicatorTimer = Timer(const Duration(seconds: 2), () {
      setState(() {
        _onScreenToastText = null;
      });
    });
  }

  void _startSensorBasedOrientationListener() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();

    _accelSubscription =
        accelerometerEventStream().listen((AccelerometerEvent event) {
      if (_rotationMode != RotationMode.smartAuto) return;

      final double x = event.x;
      final double y = event.y;
      const double threshold = 6.0;

      if (x.abs() > threshold && y.abs() < threshold) {
        if (x > 0) {
          _changeOrientationIfNeeded(DeviceOrientation.landscapeRight);
        } else {
          _changeOrientationIfNeeded(DeviceOrientation.landscapeLeft);
        }
      } else if (y.abs() > threshold && x.abs() < threshold) {
        if (y > 0) {
          _changeOrientationIfNeeded(DeviceOrientation.portraitUp);
        } else {
          _changeOrientationIfNeeded(DeviceOrientation.portraitDown);
        }
      }
    });

    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      if (_rotationMode != RotationMode.smartAuto) return;

      final double omega = (event.x.abs() + event.y.abs() + event.z.abs());
      if (omega > 1.0) {
        debugPrint("Gyroscope rotation detected: $omega rad/s");
      }
    });
  }

  void _changeOrientationIfNeeded(DeviceOrientation newOrient) {
    if (_rotationMode != RotationMode.smartAuto) return;
    if (_lastPhysicalOrientation == newOrient) return;

    _lastPhysicalOrientation = newOrient;

    if (newOrient == DeviceOrientation.landscapeLeft ||
        newOrient == DeviceOrientation.landscapeRight) {
      _isPortrait = false;
      SystemChrome.setPreferredOrientations([newOrient]);
      _showOnScreenToast("تدوير تلقائي: أفقي", Icons.screen_rotation_rounded);
    } else {
      _isPortrait = true;
      SystemChrome.setPreferredOrientations([newOrient]);
      _showOnScreenToast("تدوير تلقائي: عمودي", Icons.screen_rotation_rounded);
    }

    if (mounted) setState(() {});
  }

  void _toggleSmartRotation() {
    setState(() {
      // يبقى زر التدوير موجوداً، لكن يعيد تثبيت العرض الأفقي بدلاً من التنقل العشوائي بين الاتجاهات.
      _rotationMode = RotationMode.landscapeOnly;
      _isPortrait = false;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _showOnScreenToast("العرض مثبت: أفقي", Icons.crop_landscape_rounded);
    });
  }

  void _cycleBoxFit() {
    setState(() {
      if (_currentBoxFit == BoxFit.contain) {
        _currentBoxFit = BoxFit.fill;
        _aspectRatioLabel = "تمديد";
      } else if (_currentBoxFit == BoxFit.fill) {
        _currentBoxFit = BoxFit.cover;
        _aspectRatioLabel = "تكبير";
      } else {
        _currentBoxFit = BoxFit.contain;
        _aspectRatioLabel = "تلقائي";
      }

      _showOnScreenToast(
          "أبعاد الشاشة: $_aspectRatioLabel", Icons.aspect_ratio_rounded);

      if (_betterController != null) {
        _betterController!.setOverriddenFit(_currentBoxFit);
        if (_currentBoxFit == BoxFit.contain) {
          final videoVal = _betterController!.videoPlayerController?.value;
          final vSize = videoVal?.size;
          if (vSize != null && vSize.width > 0 && vSize.height > 0) {
            _betterController!.setOverriddenAspectRatio(vSize.aspectRatio);
          } else {
            _betterController!.setOverriddenAspectRatio(16.0 / 9.0);
          }
        } else {
          final size = MediaQuery.of(context).size;
          _betterController!.setOverriddenAspectRatio(size.width / size.height);
        }
      }
    });
  }

  void _togglePictureInPicture() async {
    if (_betterController != null && _initialized) {
      try {
        setState(() {
          _showHUD = false;
          _showSidebar = false;
          _isPipActive = true;
          _isPortrait = false;
          _rotationMode = RotationMode.landscapeOnly;
        });
        // تظل صورة داخل صورة والمشغّل الأساسي ضمن الاتجاه الأفقي نفسه.
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await _betterController!.enablePictureInPicture(_betterPlayerKey);
      } catch (e) {
        debugPrint(
            "Failed to enable picture in picture: ${redactDiagnostic(e)}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("جهازك لا يدعم خاصية صورة داخل صورة حالياً",
                  textDirection: TextDirection.rtl),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("انتظر حتى يتم تحميل البث لتشغيل صورة داخل صورة",
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.amberAccent,
        ),
      );
    }
  }

  void _showSubtitlesSelector() {
    if (_betterController == null || !_initialized) return;
    int activeSubTab = 0;

    showDialog(
        context: context,
        builder: (BuildContext bContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: StatefulBuilder(builder: (context, setModalState) {
              final List<BetterPlayerSubtitlesSource> rawSubtitles =
                  _betterController!.betterPlayerSubtitlesSourceList;
              final selectedSub =
                  _betterController!.betterPlayerSubtitlesSource;

              List<BetterPlayerSubtitlesSource> validSubtitles = rawSubtitles
                  .where((s) => s.type != BetterPlayerSubtitlesSourceType.none)
                  .toList();
              validSubtitles.sort((a, b) {
                final aName = (a.name ?? "").toLowerCase();
                final bName = (b.name ?? "").toLowerCase();
                bool aIsAr = aName.contains("ar") || aName.contains("عرب");
                bool bIsAr = bName.contains("ar") || bName.contains("عرب");
                if (aIsAr && !bIsAr) return -1;
                if (!aIsAr && bIsAr) return 1;
                return aName.compareTo(bName);
              });

              Future<void> saveSubPref(String key, String val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(key, val);
                setState(() {
                  _betterPlayerKey = GlobalKey();
                });
              }

              return Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  width: 520,
                  constraints: const BoxConstraints(maxHeight: 540),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13131A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2E2E3E)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        child: Row(
                          children: [
                            const Icon(Icons.subtitles_rounded,
                                color: Color(0xFFA855F7), size: 24),
                            const SizedBox(width: 8),
                            const Text("إعدادات الترجمة والخط",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white54),
                              onPressed: () => Navigator.pop(bContext),
                            )
                          ],
                        ),
                      ),
                      // Tabs: Track vs Font
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setModalState(() => activeSubTab = 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: activeSubTab == 0
                                          ? const Color(0xFFA855F7)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "مسار الترجمة",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: activeSubTab == 0
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setModalState(() => activeSubTab = 1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: activeSubTab == 1
                                          ? const Color(0xFFA855F7)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "أزرار الخط والتصميم",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: activeSubTab == 1
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white12, height: 1),
                      // Tab Content
                      Expanded(
                        child: activeSubTab == 0
                            ? ListView(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                children: [
                                  ListTile(
                                    title: const Text("إيقاف الترجمة",
                                        style: TextStyle(color: Colors.white)),
                                    trailing: (selectedSub == null ||
                                            selectedSub.type ==
                                                BetterPlayerSubtitlesSourceType.none)
                                        ? const Icon(Icons.check_circle,
                                            color: Color(0xFFA855F7))
                                        : null,
                                    onTap: () {
                                      _betterController!.setupSubtitleSource(
                                          BetterPlayerSubtitlesSource(
                                              type: BetterPlayerSubtitlesSourceType
                                                  .none));
                                      setModalState(() {});
                                      Navigator.pop(bContext);
                                    },
                                  ),
                                  if (validSubtitles.isNotEmpty) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      child: Text("الترجمات المدمجة من السيرفر",
                                          style: TextStyle(
                                              color: Colors.white54, fontSize: 12)),
                                    ),
                                    ...validSubtitles.map((sub) {
                                      final isSelected = selectedSub == sub;
                                      final name = sub.name ?? "ترجمة";
                                      return ListTile(
                                        title: Text(name,
                                            style: TextStyle(
                                                color: isSelected
                                                    ? const Color(0xFFA855F7)
                                                    : Colors.white)),
                                        trailing: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Color(0xFFA855F7))
                                            : null,
                                        onTap: () {
                                          _betterController!.setupSubtitleSource(sub);
                                          setModalState(() {});
                                          Navigator.pop(bContext);
                                        },
                                      );
                                    }).toList(),
                                  ],
                                  if (validSubtitles.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        'لا توجد ملفات ترجمة مدمجة لهذا البث.
يمكنك ضبط حجم ونمط الخط من التبويب المجاور.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.white60, fontSize: 13),
                                      ),
                                    ),
                                ],
                              )
                            : ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  // Live Preview Box
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _subBgColorVal == Colors.transparent
                                          ? Colors.black54
                                          : _subBgColorVal,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.white24, width: 0.8),
                                    ),
                                    child: Text(
                                      "هذا نموذج لمعاينة خط ولون الترجمة",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _subColorVal,
                                        fontSize: _subSizeVal,
                                        fontFamily: _subFontVal,
                                        fontWeight: FontWeight.bold,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 3,
                                            offset: Offset(1, 1),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Font Size Header + Stepper
                                  Row(
                                    children: [
                                      const Text("حجم الخط:",
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline,
                                            color: Colors.white70, size: 22),
                                        onPressed: () {
                                          if (_subSizeVal > 10.0) {
                                            setModalState(() => _subSizeVal -= 2);
                                            saveSubPref('sub_size', '${_subSizeVal.toInt()}');
                                          }
                                        },
                                      ),
                                      Text(
                                        "${_subSizeVal.toInt()}",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline,
                                            color: Colors.white70, size: 22),
                                        onPressed: () {
                                          if (_subSizeVal < 36.0) {
                                            setModalState(() => _subSizeVal += 2);
                                            saveSubPref('sub_size', '${_subSizeVal.toInt()}');
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Size quick preset buttons
                                  Row(
                                    children: [
                                      _buildSubBtn(
                                        label: "صغير",
                                        selected: _subSizeVal <= 13.0,
                                        onTap: () {
                                          setModalState(() => _subSizeVal = 12.0);
                                          saveSubPref('sub_size', 'صغير');
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      _buildSubBtn(
                                        label: "متوسط",
                                        selected: _subSizeVal > 13.0 && _subSizeVal <= 18.0,
                                        onTap: () {
                                          setModalState(() => _subSizeVal = 16.0);
                                          saveSubPref('sub_size', 'متوسط');
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      _buildSubBtn(
                                        label: "كبير",
                                        selected: _subSizeVal > 18.0 && _subSizeVal <= 24.0,
                                        onTap: () {
                                          setModalState(() => _subSizeVal = 22.0);
                                          saveSubPref('sub_size', 'كبير');
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      _buildSubBtn(
                                        label: "ضخم",
                                        selected: _subSizeVal > 24.0,
                                        onTap: () {
                                          setModalState(() => _subSizeVal = 28.0);
                                          saveSubPref('sub_size', 'ضخم');
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Font Family
                                  const Text("نوع الخط:",
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _buildSubBtn(
                                        label: "Cairo",
                                        selected: _subFontVal == 'Cairo',
                                        onTap: () {
                                          setModalState(() => _subFontVal = 'Cairo');
                                          saveSubPref('sub_font', 'Cairo');
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      _buildSubBtn(
                                        label: "Arial",
                                        selected: _subFontVal == 'Arial',
                                        onTap: () {
                                          setModalState(() => _subFontVal = 'Arial');
                                          saveSubPref('sub_font', 'Arial');
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      _buildSubBtn(
                                        label: "Tahoma",
                                        selected: _subFontVal == 'Tahoma',
                                        onTap: () {
                                          setModalState(() => _subFontVal = 'Tahoma');
                                          saveSubPref('sub_font', 'Tahoma');
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      _buildSubBtn(
                                        label: "Roboto",
                                        selected: _subFontVal == 'Roboto',
                                        onTap: () {
                                          setModalState(() => _subFontVal = 'Roboto');
                                          saveSubPref('sub_font', 'Roboto');
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Color Chips
                                  const Text("لون النص:",
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildColorChip(
                                        color: Colors.white,
                                        label: "أبيض",
                                        selected: _subColorVal == Colors.white,
                                        onTap: () {
                                          setModalState(() => _subColorVal = Colors.white);
                                          saveSubPref('sub_color', 'أبيض');
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _buildColorChip(
                                        color: Colors.yellow,
                                        label: "أصفر",
                                        selected: _subColorVal == Colors.yellow,
                                        onTap: () {
                                          setModalState(() => _subColorVal = Colors.yellow);
                                          saveSubPref('sub_color', 'أصفر');
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _buildColorChip(
                                        color: Colors.cyanAccent,
                                        label: "سماوي",
                                        selected: _subColorVal == Colors.cyanAccent,
                                        onTap: () {
                                          setModalState(() => _subColorVal = Colors.cyanAccent);
                                          saveSubPref('sub_color', 'أزرق سماوي');
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _buildColorChip(
                                        color: Colors.greenAccent,
                                        label: "أخضر",
                                        selected: _subColorVal == Colors.greenAccent,
                                        onTap: () {
                                          setModalState(() => _subColorVal = Colors.greenAccent);
                                          saveSubPref('sub_color', 'أخضر');
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _buildColorChip(
                                        color: Colors.orange,
                                        label: "برتقالي",
                                        selected: _subColorVal == Colors.orange,
                                        onTap: () {
                                          setModalState(() => _subColorVal = Colors.orange);
                                          saveSubPref('sub_color', 'برتقالي');
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Background
                                  const Text("خلفية الترجمة:",
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildSubBtn(
                                        label: "شفاف",
                                        selected: _subBgColorVal == Colors.transparent,
                                        onTap: () {
                                          setModalState(() => _subBgColorVal = Colors.transparent);
                                          saveSubPref('sub_bg_color', 'شفاف');
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _buildSubBtn(
                                        label: "أسود خفيف",
                                        selected: _subBgColorVal == Colors.black54,
                                        onTap: () {
                                          setModalState(() => _subBgColorVal = Colors.black54);
                                          saveSubPref('sub_bg_color', 'رمادي داكن');
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _buildSubBtn(
                                        label: "أسود داكن",
                                        selected: _subBgColorVal == Colors.black87,
                                        onTap: () {
                                          setModalState(() => _subBgColorVal = Colors.black87);
                                          saveSubPref('sub_bg_color', 'أسود');
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        });
  }

  Widget _buildSubBtn({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFA855F7).withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFFA855F7) : Colors.white24,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorChip({
    required Color color,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.white24,
              width: selected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white60,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showSleepTimerSelector() {
    showDialog(
        context: context,
        builder: (BuildContext bContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: StatefulBuilder(builder: (context, setModalState) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  width: 350,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E20),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_rounded,
                                color: Colors.pinkAccent),
                            const SizedBox(width: 8),
                            const Text("مؤقت النوم",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white54),
                              onPressed: () => Navigator.pop(bContext),
                            )
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [0, 15, 30, 45, 60, 90, 120].map((minutes) {
                          final isSelected = _sleepTimerMinutes == minutes;
                          final title =
                              minutes == 0 ? "إيقاف" : "$minutes دقيقة";
                          return ListTile(
                            title: Text(title,
                                style: TextStyle(
                                    color: isSelected
                                        ? Colors.pinkAccent
                                        : Colors.white)),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.pinkAccent)
                                : null,
                            onTap: () {
                              setState(() {
                                _sleepTimerMinutes =
                                    minutes == 0 ? null : minutes;
                                _sleepTimer?.cancel();
                                if (minutes > 0) {
                                  _sleepTimer =
                                      Timer(Duration(minutes: minutes), () {
                                    if (mounted) {
                                      _betterController?.pause();
                                      Navigator.pop(this.context);
                                    }
                                  });
                                }
                              });
                              setModalState(() {});
                              Navigator.pop(bContext);

                              if (minutes > 0) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "تم ضبط مؤقت النوم: $minutes دقيقة",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.pinkAccent,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        });
  }

  void _showSpeedSelector() {
    showDialog(
        context: context,
        builder: (BuildContext bContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: StatefulBuilder(builder: (context, setModalState) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  width: 350,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E20),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.speed_rounded,
                                color: Colors.orangeAccent),
                            const SizedBox(width: 8),
                            const Text("سرعة التشغيل",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white54),
                              onPressed: () => Navigator.pop(bContext),
                            )
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                          final isSelected = _playbackSpeed == speed;
                          final title =
                              speed == 1.0 ? "عادي (1.0x)" : "${speed}x";
                          return ListTile(
                            title: Text(title,
                                style: TextStyle(
                                    color: isSelected
                                        ? Colors.orangeAccent
                                        : Colors.white)),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.orangeAccent)
                                : null,
                            onTap: () {
                              setState(() {
                                _playbackSpeed = speed;
                                _betterController?.setSpeed(speed);
                              });
                              setModalState(() {});
                              Navigator.pop(bContext);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        });
  }

  void _applyQualityPreset(int targetHeight, BuildContext dialogContext) {
    final controller = _betterController;
    if (controller == null) return;
    final tracks = controller.betterPlayerAsmsTracks;
    final target = bestAvailableQualityHeight(
      tracks.map((track) => track.height ?? 0),
      targetHeight,
    );
    if (target == null) {
      Navigator.pop(dialogContext);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('المصدر لا يحتوي على مسار فيديو مناسب لهذه الجودة')),
      );
      return;
    }
    final selected = tracks.firstWhere((track) => track.height == target);
    controller.setTrack(selected);
    Navigator.pop(dialogContext);
    if (target < targetHeight && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'المصدر لا يوفر ${targetHeight == 2160 ? '4K' : '8K'} حقيقية؛ تم اختيار أعلى دقة أصلية متاحة (${target}p)',
          ),
        ),
      );
    }
  }

  Widget _buildLiveFilterButton({
    required String label,
    required LiveImageFilter filter,
  }) {
    final selected = _liveImageFilter == filter;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _liveImageFilter = selected ? LiveImageFilter.none : filter;
          });
          _showOnScreenToast(
            _liveImageFilter == LiveImageFilter.none
                ? 'تم إيقاف فلتر الصورة'
                : 'تم تفعيل فلتر $label لتحسين العرض',
            Icons.auto_awesome_rounded,
          );
          _resetHideHUDTimer();
        },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(46, 34),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          foregroundColor: selected ? Colors.black : Colors.white,
          backgroundColor: selected ? Colors.amberAccent : Colors.transparent,
          side: BorderSide(
            color: selected ? Colors.amberAccent : Colors.white54,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }

  void _showQualitySelector() {
    final controller = _betterController;
    if (controller == null || !_initialized) return;

    final sourceTracks = controller.betterPlayerAsmsTracks
        .where((track) => (track.width ?? 0) > 0 && (track.height ?? 0) > 0)
        .toList();
    final tracks = <BetterPlayerAsmsTrack>[];
    final seen = <String>{};
    for (final track in sourceTracks) {
      if (seen.add(realQualityTrackKey(track))) tracks.add(track);
    }
    tracks.sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));

    String pending = controller.betterPlayerAsmsTrack == null
        ? 'auto'
        : realQualityTrackKey(controller.betterPlayerAsmsTrack!);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          Widget row({
            required String value,
            required String title,
            required String subtitle,
            required IconData icon,
          }) {
            final selected = pending == value;
            return InkWell(
              onTap: () => setModalState(() => pending = value),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(title,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: selected
                                        ? const Color(0xFF16E0E8)
                                        : Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  )),
                              const SizedBox(width: 10),
                              Icon(icon,
                                  color: selected
                                      ? const Color(0xFF16E0E8)
                                      : const Color(0xFFFFC928),
                                  size: 28),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(subtitle,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color:
                            selected ? const Color(0xFF16E0E8) : Colors.white38,
                        size: 30),
                  ],
                ),
              ),
            );
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Dialog(
              backgroundColor: const Color(0xFF202022),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 820, maxHeight: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                      child: Row(
                        children: [
                          const Icon(Icons.hd_rounded,
                              color: Color(0xFF16E0E8), size: 28),
                          const SizedBox(width: 10),
                          const Text('جودة البث',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800)),
                          const Spacer(),
                          IconButton(
                            tooltip: 'إغلاق',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close,
                                color: Colors.white60, size: 30),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Flexible(
                      child: tracks.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.hd_rounded,
                                      color: Color(0xFF16E0E8), size: 30),
                                  const SizedBox(height: 10),
                                  Text(
                                      realQualityAvailabilityLabel(
                                          hasTracks: false),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  const Text(
                                      'لا توجد قائمة متعددة معلنة في الـmanifest؛ لا يمكن اختراع جودة أخرى.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 13)),
                                ],
                              ),
                            )
                          : ListView(
                              shrinkWrap: true,
                              children: [
                                row(
                                    value: 'auto',
                                    title: 'تلقائي',
                                    subtitle:
                                        'اختيار الجودة تلقائياً من المصدر',
                                    icon: Icons.hd_rounded),
                                ...tracks.map((track) => row(
                                      value: realQualityTrackKey(track),
                                      title: realQualityTrackLabel(track),
                                      subtitle:
                                          '${track.width}×${track.height}${(track.mimeType ?? '').isNotEmpty ? ' • ${(track.mimeType ?? '').replaceFirst('video/', '')}' : ''}',
                                      icon: Icons.hd_rounded,
                                    )),
                              ],
                            ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('إلغاء',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 16))),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16E0E8),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            onPressed: () {
                              if (pending == 'auto') {
                                controller.setTrack(
                                    BetterPlayerAsmsTrack.defaultTrack());
                              } else {
                                final selected = tracks.firstWhere((track) =>
                                    realQualityTrackKey(track) == pending);
                                controller.setTrack(selected);
                              }
                              Navigator.pop(dialogContext);
                            },
                            child: const Text('موافق',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return "$hours:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
    return "${twoDigits(minutes)}:${twoDigits(seconds)}";
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);

    if (provider.snifferDetected || provider.isBlackScreenBlocked) {
      try {
        _betterController?.pause();
        _betterController?.clearCache();
      } catch (_) {}
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: ColoredBox(color: Colors.black),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: WillPopScope(
        onWillPop: () async {
          return true;
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (FocusNode node, KeyEvent event) {
            if (!_remoteControlEnabled) return KeyEventResult.ignored;
            _resetHideHUDTimer();
            if (_isLocked) {
              if (event is KeyDownEvent) {
                setState(() {
                  _showLockToggleOnly = true;
                });
                _resetLockToggleTimer();
              }
              return KeyEventResult.handled;
            }
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;

            // أزرار OK/Enter والتشغيل في ريموت التلفزيون تتحكم مباشرة بالتشغيل.
            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.space ||
                key == LogicalKeyboardKey.mediaPlayPause) {
              if (_betterController != null && _initialized) {
                if (_betterController!.isPlaying() ?? false) {
                  _betterController!.pause();
                } else {
                  _betterController!.play();
                }
                setState(() {});
              }
              return KeyEventResult.handled;
            }

            if (key == LogicalKeyboardKey.escape ||
                key == LogicalKeyboardKey.goBack) {
              if (_showHUD) {
                setState(() => _showHUD = false);
              } else {
                Navigator.of(context).maybePop();
              }
              return KeyEventResult.handled;
            }

            if (!_showHUD) {
              // اختصارات مباشرة عندما تكون لوحة المشغّل مخفية.
              if (key == LogicalKeyboardKey.arrowUp ||
                  key == LogicalKeyboardKey.arrowDown) {
                _cycleBoxFit();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowLeft) {
                _zapNextPrev(provider, false);
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowRight) {
                _zapNextPrev(provider, true);
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.mediaFastForward &&
                  _stream.type != 'live') {
                _betterController
                    ?.seekTo(_currentPosition + const Duration(seconds: 10));
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.mediaRewind &&
                  _stream.type != 'live') {
                final target = _currentPosition - const Duration(seconds: 10);
                _betterController
                    ?.seekTo(target.isNegative ? Duration.zero : target);
                return KeyEventResult.handled;
              }

              setState(() => _showHUD = true);
              Future.delayed(const Duration(milliseconds: 50), () {
                if (_firstButtonFocusNode.canRequestFocus)
                  _firstButtonFocusNode.requestFocus();
              });
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
              // 1. Core Video Frame Container
              GestureDetector(
                onTap: () {
                  if (_isLocked) {
                    setState(() {
                      _showLockToggleOnly = !_showLockToggleOnly;
                    });
                    if (_showLockToggleOnly) {
                      _resetLockToggleTimer();
                    }
                  } else {
                    _toggleHUD();
                  }
                },
                onVerticalDragStart: (details) {
                  if (_isLocked) return;
                  _dragStartY = details.globalPosition.dy;
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx < screenWidth / 2) {
                    _isDraggingLeft = true;
                    _dragStartValue =
                        1.0 - _brightnessFactor; // 1.0 is max brightness
                  } else {
                    _isDraggingRight = true;
                    _dragStartValue = _volume;
                  }
                },
                onVerticalDragUpdate: (details) {
                  if (_isLocked) return;
                  final dy = details.globalPosition.dy - _dragStartY;
                  final screenHeight = MediaQuery.of(context).size.height;
                  double valueDelta = -(dy / (screenHeight / 2));

                  setState(() {
                    if (_isDraggingLeft) {
                      double newBrightness = (_dragStartValue + valueDelta)
                          .clamp(0.2, 1.0); // min 0.2
                      _brightnessFactor = 1.0 - newBrightness;

                      _swipeToastIcon = Icons.brightness_6_rounded;
                      _swipeToastText =
                          "السطوع: ${(newBrightness * 100).toInt()}%";
                    } else if (_isDraggingRight) {
                      _volume = (_dragStartValue + valueDelta).clamp(0.0, 1.0);
                      _betterController?.setVolume(_volume);

                      _swipeToastIcon = _volume > 0.5
                          ? Icons.volume_up_rounded
                          : _volume > 0
                              ? Icons.volume_down_rounded
                              : Icons.volume_off_rounded;
                      _swipeToastText = "الصوت: ${(_volume * 100).toInt()}%";
                    }
                  });

                  _swipeToastTimer?.cancel();
                  _swipeToastTimer = Timer(const Duration(seconds: 1), () {
                    if (mounted)
                      setState(() {
                        _swipeToastText = null;
                      });
                  });
                },
                onVerticalDragEnd: (details) {
                  _isDraggingLeft = false;
                  _isDraggingRight = false;
                },
                onDoubleTapDown: (details) {
                  if (_isLocked || _stream.type == 'live') return;
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx < screenWidth / 2) {
                    // Seek backward 10s
                    if (_betterController != null && _initialized) {
                      final pos =
                          _currentPosition - const Duration(seconds: 10);
                      _betterController!
                          .seekTo(pos < Duration.zero ? Duration.zero : pos);
                      setState(() {
                        _swipeToastIcon = Icons.replay_10_rounded;
                        _swipeToastText = "رجوع 10 ثواني";
                      });
                    }
                  } else {
                    // Seek forward 10s
                    if (_betterController != null && _initialized) {
                      final pos =
                          _currentPosition + const Duration(seconds: 10);
                      _betterController!
                          .seekTo(pos > _totalDuration ? _totalDuration : pos);
                      setState(() {
                        _swipeToastIcon = Icons.forward_10_rounded;
                        _swipeToastText = "تقديم 10 ثواني";
                      });
                    }
                  }
                  _swipeToastTimer?.cancel();
                  _swipeToastTimer = Timer(const Duration(seconds: 1), () {
                    if (mounted)
                      setState(() {
                        _swipeToastText = null;
                      });
                  });
                },
                child: Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: _hasError
                        ? _buildErrorScreen(provider)
                        : _isWebFallback && _webController != null
                            ? SizedBox.expand(
                                child:
                                    WebViewWidget(controller: _webController!),
                              )
                            : _initialized && _betterController != null
                                ? SizedBox.expand(
                                    child: (_totalDuration.inSeconds == 0 ||
                                                _stream.type == 'live') &&
                                            _liveImageFilter !=
                                                LiveImageFilter.none
                                        ? ColorFiltered(
                                            colorFilter: ColorFilter.matrix(
                                              liveImageFilterMatrix(
                                                  _liveImageFilter),
                                            ),
                                            child: BetterPlayer(
                                                key: _betterPlayerKey,
                                                controller: _betterController!),
                                          )
                                        : BetterPlayer(
                                            key: _betterPlayerKey,
                                            controller: _betterController!),
                                  )
                                : _buildPlayerLoading(),
                  ),
                ),
              ),

              // Buffering indicator remains visible without blocking controls.
              if (_isBuffering && !_hasError)
                IgnorePointer(
                  child: _buildPlayerLoading(),
                ),
              // 2. Brightness shade Overlay (Simulated Dimming)
              if (_brightnessFactor > 0.0)
                IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(_brightnessFactor),
                  ),
                ),

              // 2.5 Dynamic Watermark Brand Logo (always visible, does not block mouse clicks)
              IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: 38,
                      right: 52,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.32)),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 3))
                          ],
                        ),
                        child: const Text(
                          'LIVE STREAM PRO',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.25),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 48,
                      left: 48,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(3)),
                            child: const Icon(Icons.qr_code_2_rounded,
                                color: Color(0xFF22212B), size: 25),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252331).withOpacity(0.90),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Text(
                              'LIVE STREAM PRO',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2.6 Dynamic On-Screen Indicator Toast (Unified for Zoom, Aspect Ratio, and Rotation)
              if (_onScreenToastText != null)
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFA855F7).withOpacity(0.65),
                            width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_onScreenToastIcon,
                              color: const Color(0xFFA855F7), size: 22),
                          const SizedBox(width: 10),
                          Text(
                            _onScreenToastText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 3. HUD Controls Layer

              if (_showHUD && !_isLocked) _buildHUDOverlay(provider),

              // 3.5 Floating Lock/Unlock controls for locked mode
              if (_isLocked && _showLockToggleOnly) ...[
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.lock_outline_rounded,
                              color: Colors.redAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "الشاشة مقفلة - انقر لفتح القفل",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 30,
                  bottom: 30,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        setState(() {
                          _isLocked = false;
                          _showHUD = true;
                          _showLockToggleOnly = false;
                        });
                        _resetHideHUDTimer();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "تم إلغاء قفل الشاشة",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold),
                            ),
                            duration: Duration(seconds: 1),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.greenAccent.withOpacity(0.5),
                              width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 10),
                          ],
                        ),
                        child: const Icon(Icons.lock_open_rounded,
                            color: Colors.greenAccent, size: 28),
                      ),
                    ),
                  ),
                ),
              ],

              // 4. Quick Side Drawer Category Channel List
              if (_showSidebar && !_isLocked) _buildQuickSidebar(provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerLoading() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_loadingVideoController != null &&
            _loadingVideoController!.value.isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _loadingVideoController!.value.size.width,
                height: _loadingVideoController!.value.size.height,
                child: VideoPlayer(_loadingVideoController!),
              ),
            ),
          )
        else
          Image.asset('assets/loading_screen.png', fit: BoxFit.cover),
        Container(color: Colors.black.withOpacity(0.12)),
        const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFA855F7),
            strokeWidth: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorScreen(IPTVProvider provider) {
    if (_offlineVideoController == null ||
        !_offlineVideoController!.value.isInitialized) {
      _initOfflineVideo();
    }
    final isLive = _stream.type == 'live' || _stream.type == 'stalker';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_offlineVideoController != null &&
            _offlineVideoController!.value.isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _offlineVideoController!.value.size.width,
                height: _offlineVideoController!.value.size.height,
                child: VideoPlayer(_offlineVideoController!),
              ),
            ),
          )
        else
          Container(color: const Color(0xFF07070D)),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.72),
                Colors.black.withOpacity(0.45),
                Colors.black.withOpacity(0.88),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.redAccent, width: 2),
                    ),
                    child: const Icon(Icons.tv_off_rounded,
                        color: Colors.redAccent, size: 44),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _stream.name.isNotEmpty ? _stream.name : 'القناة المطلوبة',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B0715),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                    ),
                    child: Text(
                      isLive
                          ? 'القناة معطلة أو متوقفة من المصدر حالياً'
                          : 'المحتوى غير متاح حالياً من السيرفر',
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'تعذر استلام البث بعد عدة محاولات. يمكنك التبديل بين صيغ البث أو الانتقال لقناة أخرى.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA855F7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('إعادة المحاولة',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          setState(() {
                            _retryCount = 0;
                            _hasError = false;
                            _errorMessage = null;
                            _initialized = false;
                          });
                          _initializeController();
                        },
                      ),
                      if (isLive)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF38BDF8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: Text(
                            provider.streamFormat == 'm3u8'
                                ? 'تجربة بصيغة TS'
                                : 'تجربة بصيغة M3U8',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            final nextFormat =
                                provider.streamFormat == 'm3u8' ? 'ts' : 'm3u8';
                            await provider.setStreamFormat(nextFormat);
                            setState(() {
                              _retryCount = 0;
                              _hasError = false;
                              _errorMessage = null;
                              _initialized = false;
                            });
                            _initializeController();
                          },
                        ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('رجوع للقائمة'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHUDOverlay(IPTVProvider provider) {
    final bool isLive = _totalDuration.inSeconds == 0 || _stream.type == 'live';

    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _showHUD ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.9),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.9),
              ],
              stops: const [0.0, 0.2, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // TOP HUD BAR
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xE9131020),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: const Color(0xFF49395E), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Clock Widget
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(minutes: 1)),
                        builder: (context, snapshot) {
                          final now = DateTime.now();
                          final timeStr =
                              "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.white24, width: 0.5),
                            ),
                            child: Text(
                              timeStr,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace'),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        focusNode: _firstButtonFocusNode,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        "LIVE STREAM PRO",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.lock_outline_rounded,
                            color: Colors.white, size: 22),
                        tooltip: "قفل الشاشة",
                        onPressed: () {
                          setState(() {
                            _isLocked = true;
                            _showHUD = false;
                            _showLockToggleOnly = true;
                          });
                          _resetLockToggleTimer();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("تم قفل الشاشة",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold)),
                              duration: Duration(seconds: 1),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _stream.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isLive
                                        ? Colors.redAccent.withOpacity(0.2)
                                        : const Color(0xFFA855F7)
                                            .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: isLive
                                            ? Colors.redAccent
                                            : const Color(0xFFA855F7),
                                        width: 0.5),
                                  ),
                                  child: Text(
                                    isLive ? "LIVE" : "VOD",
                                    style: TextStyle(
                                      color: isLive
                                          ? Colors.redAccent
                                          : const Color(0xFFA855F7),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _stream.categoryName,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // مجموعة الأزرار نفسها ضمن مسار أفقي ثابت يمنع التداخل.
                      SizedBox(
                        width: 348,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  provider.favorites.contains(_stream.streamId)
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: provider.favorites
                                          .contains(_stream.streamId)
                                      ? Colors.redAccent
                                      : Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  provider.toggleFavorite(_stream.streamId);
                                  _resetHideHUDTimer();
                                },
                              ),
                              if (_stream.type == 'live' ||
                                  _stream.type == 'stalker')
                                IconButton(
                                  icon: const Icon(Icons.grid_view_rounded,
                                      color: Color(0xFFA855F7), size: 24),
                                  tooltip: "شاشات متعددة",
                                  onPressed: () async {
                                    _resetHideHUDTimer();
                                    final selectedLayout =
                                        await showDialog<MultiScreenType>(
                                      context: context,
                                      builder: (ctx) =>
                                          MultiScreenSelectorDialog(),
                                    );
                                    if (selectedLayout != null) {
                                      _betterController?.pause();
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => MultiScreenPlayer(
                                                    layoutType: selectedLayout,
                                                    initialStream: _stream,
                                                  )));
                                    }
                                  },
                                ),

                              // Sidebar Search & Category

                              // Sleep Timer button
                              IconButton(
                                icon: Icon(Icons.timer_rounded,
                                    color: _sleepTimerMinutes != null
                                        ? const Color(0xFFA855F7)
                                        : Colors.white,
                                    size: 24),
                                tooltip: "مؤقت النوم",
                                onPressed: () {
                                  _showSleepTimerSelector();
                                  _resetHideHUDTimer();
                                },
                              ),
                              if (!isLive)
                                IconButton(
                                  icon: const Icon(Icons.speed_rounded,
                                      color: Color(0xFFA855F7), size: 24),
                                  tooltip: "سرعة التشغيل",
                                  onPressed: () {
                                    _showSpeedSelector();
                                    _resetHideHUDTimer();
                                  },
                                ),
                              // Quality Menu button
                              IconButton(
                                icon: const Icon(Icons.high_quality_rounded,
                                    color: Color(0xFFA855F7), size: 24),
                                tooltip: "جودة البث",
                                onPressed: () {
                                  _showQualitySelector();
                                  _resetHideHUDTimer();
                                },
                              ),
                              // Stream Format Toggle (TS / M3U8)
                              GestureDetector(
                                onTap: () async {
                                  final current = provider.streamFormat;
                                  final next = current == 'm3u8' ? 'ts' : 'm3u8';
                                  await provider.setStreamFormat(next);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text('تم التحويل لصيغة ${next.toUpperCase()}'),
                                      duration: const Duration(seconds: 1),
                                    ));
                                    setState(() {
                                      _retryCount = 0;
                                      _initialized = false;
                                      _hasError = false;
                                    });
                                    _initializeController(isRetry: true);
                                  }
                                  _resetHideHUDTimer();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E1065),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA855F7), width: 1.0),
                                  ),
                                  child: Text(
                                    provider.streamFormat.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFFE9D5FF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                              // Subtitles Menu button
                              IconButton(
                                icon: const Icon(Icons.subtitles_rounded,
                                    color: Color(0xFFA855F7), size: 24),
                                tooltip: "الترجمة",
                                onPressed: () {
                                  _showSubtitlesSelector();
                                  _resetHideHUDTimer();
                                },
                              ),
                              // Picture in Picture
                              IconButton(
                                icon: const Icon(
                                    Icons.picture_in_picture_alt_rounded,
                                    color: Color(0xFFA855F7),
                                    size: 24),
                                tooltip: "صورة داخل صورة",
                                onPressed: () {
                                  _togglePictureInPicture();
                                  _resetHideHUDTimer();
                                },
                              ),
                              // Screen Rotation
                              IconButton(
                                icon: Icon(
                                  _rotationMode == RotationMode.smartAuto
                                      ? Icons.screen_rotation_rounded
                                      : (_rotationMode ==
                                              RotationMode.landscapeOnly
                                          ? Icons.crop_landscape_rounded
                                          : Icons.crop_portrait_rounded),
                                  color: _rotationMode == RotationMode.smartAuto
                                      ? const Color(0xFFA855F7)
                                      : Colors.white,
                                  size: 26,
                                ),
                                tooltip: "تدوير الشاشة",
                                onPressed: () {
                                  _toggleSmartRotation();
                                  _resetHideHUDTimer();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // CENTER CONTROLS: تبقى أفقية على جميع قياسات العرض.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHUDCircleBtn(
                        icon: const Icon(Icons.skip_previous_rounded,
                            color: Colors.white, size: 28),
                        onTap: () {
                          _zapNextPrev(provider, false);
                          _resetHideHUDTimer();
                        },
                      ),
                      if (!isLive) ...[
                        const SizedBox(width: 16),
                        _buildHUDCircleBtn(
                          icon: const Icon(Icons.replay_10_rounded,
                              color: Colors.white, size: 24),
                          onTap: () {
                            if (_betterController != null && _initialized) {
                              final pos = _currentPosition -
                                  const Duration(seconds: 10);
                              _betterController!.seekTo(
                                  pos < Duration.zero ? Duration.zero : pos);
                            }
                            _resetHideHUDTimer();
                          },
                        ),
                      ],
                      const SizedBox(width: 32),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: () {
                            if (_betterController != null && _initialized) {
                              setState(() {
                                _betterController!.isPlaying() == true
                                    ? _betterController!.pause()
                                    : _betterController!.play();
                              });
                            }
                            _resetHideHUDTimer();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA855F7),
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 10,
                                    offset: Offset(0, 4)),
                              ],
                            ),
                            child: Icon(
                              (_betterController?.isPlaying() ?? false)
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      if (!isLive) ...[
                        _buildHUDCircleBtn(
                          icon: const Icon(Icons.forward_10_rounded,
                              color: Colors.white, size: 24),
                          onTap: () {
                            if (_betterController != null && _initialized) {
                              final pos = _currentPosition +
                                  const Duration(seconds: 10);
                              _betterController!.seekTo(
                                  pos > _totalDuration ? _totalDuration : pos);
                            }
                            _resetHideHUDTimer();
                          },
                        ),
                        const SizedBox(width: 16),
                      ],
                      _buildHUDCircleBtn(
                        icon: const Icon(Icons.skip_next_rounded,
                            color: Colors.white, size: 28),
                        onTap: () {
                          _zapNextPrev(provider, true);
                          _resetHideHUDTimer();
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // BOTTOM CONTROL BAR
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xE9131020),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: const Color(0xFF49395E), width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Timeline
                      if (!isLive && _initialized)
                        Row(
                          children: [
                            Text(
                              _formatDuration(_currentPosition),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFFA855F7),
                                  inactiveTrackColor: const Color(0xFF474252),
                                  thumbColor: Colors.white,
                                  trackHeight: 4.0,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6.0),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 12.0),
                                ),
                                child: Slider(
                                  min: 0.0,
                                  max: _totalDuration.inSeconds.toDouble() > 0
                                      ? _totalDuration.inSeconds.toDouble()
                                      : 1.0,
                                  value: _currentPosition.inSeconds
                                      .toDouble()
                                      .clamp(
                                          0.0,
                                          _totalDuration.inSeconds.toDouble() >
                                                  0
                                              ? _totalDuration.inSeconds
                                                  .toDouble()
                                              : 1.0),
                                  onChanged: (val) {
                                    _resetHideHUDTimer();
                                    _betterController?.seekTo(
                                        Duration(seconds: val.toInt()));
                                  },
                                ),
                              ),
                            ),
                            Text(
                              _formatDuration(_totalDuration),
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontFamily: 'monospace'),
                            ),
                          ],
                        ),

                      if (isLive)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.redAccent, blurRadius: 4)
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "بث مباشر",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0),
                            ),
                          ],
                        ),

                      const SizedBox(height: 12),

                      // Bottom Actions (Volume, Aspect Ratio, Subtitles, Quality, Lock)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left side controls
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF211B2E),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFF59436F),
                                      width: 0.8),
                                ),
                                child: const Text(
                                  "LIVE STREAM PRO",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.volume_up_rounded,
                                    color: Colors.white, size: 22),
                                onPressed: () {
                                  if (_volume > 0) {
                                    _betterController?.setVolume(0);
                                    setState(() => _volume = 0);
                                  } else {
                                    _betterController?.setVolume(1.0);
                                    setState(() => _volume = 1.0);
                                  }
                                  _resetHideHUDTimer();
                                },
                              ),
                              SizedBox(
                                width: 80,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: const Color(0xFFA855F7),
                                    inactiveTrackColor: const Color(0xFF474252),
                                    trackHeight: 2.0,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 5.0),
                                  ),
                                  child: Slider(
                                    value: _volume,
                                    min: 0.0,
                                    max: 1.0,
                                    onChanged: (val) {
                                      setState(() => _volume = val);
                                      _betterController?.setVolume(_volume);
                                      _resetHideHUDTimer();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Right side controls
                          Row(
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0xFF211B2E),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                ),
                                icon: const Icon(Icons.high_quality_rounded,
                                    size: 18, color: Color(0xFFA855F7)),
                                label: const Text('جودة',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  _showQualitySelector();
                                  _resetHideHUDTimer();
                                },
                              ),
                              const SizedBox(width: 6),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0xFF211B2E),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                ),
                                icon: const Icon(
                                    Icons.picture_in_picture_alt_rounded,
                                    size: 18,
                                    color: Color(0xFFA855F7)),
                                label: const Text('PiP',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  _togglePictureInPicture();
                                  _resetHideHUDTimer();
                                },
                              ),
                              const SizedBox(width: 6),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0xFF211B2E),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.aspect_ratio_rounded,
                                    size: 18, color: Color(0xFFA855F7)),
                                label: Text(_aspectRatioLabel,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  _cycleBoxFit();
                                  _resetHideHUDTimer();
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF211B2E),
                                    shape: const CircleBorder()),
                                icon: Icon(
                                  _rotationMode == RotationMode.smartAuto
                                      ? Icons.screen_rotation_rounded
                                      : (_rotationMode ==
                                              RotationMode.landscapeOnly
                                          ? Icons.crop_landscape_rounded
                                          : Icons.crop_portrait_rounded),
                                  color: _rotationMode == RotationMode.smartAuto
                                      ? const Color(0xFFA855F7)
                                      : Colors.white,
                                  size: 20,
                                ),
                                tooltip: "ملء الشاشة",
                                onPressed: () {
                                  _toggleSmartRotation();
                                  _resetHideHUDTimer();
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF211B2E),
                                    shape: const CircleBorder()),
                                icon: const Icon(Icons.list_rounded,
                                    color: Color(0xFFA855F7), size: 20),
                                tooltip: "قائمة القنوات",
                                onPressed: () {
                                  setState(() {
                                    _showSidebar = !_showSidebar;
                                  });
                                  _resetHideHUDTimer();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHUDCircleBtn(
      {required Widget icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        focusColor: const Color(0xFFA855F7).withOpacity(0.35),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF211B2E),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF59436F), width: 0.8),
          ),
          child: icon,
        ),
      ),
    );
  }

  Widget _buildSidebarListItem(PlaylistItem item, IPTVProvider provider) {
    final isSelected = item.streamId == _stream.streamId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blueAccent.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? Colors.blueAccent : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          item.categoryName,
          style: const TextStyle(color: Colors.white30, fontSize: 8),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(4),
          ),
          child: item.streamIcon.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: item.streamIcon,
                    fit: BoxFit.cover,
                    memCacheWidth: 60,
                    maxWidthDiskCache: 60,
                    fadeInDuration: const Duration(milliseconds: 60),
                    errorWidget: (c, e, s) => const Icon(Icons.tv_rounded,
                        size: 12, color: Colors.white30),
                  ),
                )
              : const Icon(Icons.tv_rounded, size: 12, color: Colors.white30),
        ),
        onTap: () {
          _zapStream(provider, item);
        },
      ),
    );
  }

  Widget _buildQuickSidebar(IPTVProvider provider) {
    List<String> currentCategories = provider.categories;

    final activeStreams = provider.allStreams.where((s) {
      final matchesTab = provider.activeTab == "favorites" ||
          (provider.activeTab == "live" &&
              (s.type == "live" || s.type == "stalker")) ||
          (provider.activeTab == "movie" &&
              (s.type == "movie" || s.type == "stalker_movie")) ||
          (provider.activeTab == "series" &&
              (s.type == "series" || s.type == "stalker_series"));
      if (!matchesTab) return false;
      if (_sidebarSelectedCategory != "all" &&
          s.categoryName != _sidebarSelectedCategory) return false;
      if (_sidebarSearchQuery.isNotEmpty &&
          !s.name.toLowerCase().contains(_sidebarSearchQuery.toLowerCase()))
        return false;
      return true;
    }).toList();

    final recentStreams = provider.recentlyPlayed.where((s) {
      if (_sidebarSelectedCategory != "all" &&
          s.categoryName != _sidebarSelectedCategory) return false;
      if (_sidebarSearchQuery.isNotEmpty &&
          !s.name.toLowerCase().contains(_sidebarSearchQuery.toLowerCase()))
        return false;
      return true;
    }).toList();

    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F12).withOpacity(0.95),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 15, spreadRadius: 2),
          ],
          border: const Border(
              left: BorderSide(color: Color(0xFF27272A), width: 1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFF27272A), width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "قائمة القنوات Dashboard",
                    style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: "تحديث القنوات الآن",
                        icon: provider.isFetchingData
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.cyanAccent,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded,
                                color: Colors.cyanAccent, size: 20),
                        onPressed: provider.isFetchingData
                            ? null
                            : () async {
                                await provider.refreshCurrentPlaylist();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("تم تحديث قائمة القنوات"),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white70, size: 20),
                        onPressed: () {
                          setState(() {
                            _showSidebar = false;
                            _sidebarSearchQuery = "";
                          });
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),

            // Search Bar & Filters Section
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFF27272A), width: 0.5)),
              ),
              child: Column(
                children: [
                  // Category Dropdown
                  if (currentCategories.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E1E20),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.white54),
                          value: _sidebarSelectedCategory,
                          items: [
                            const DropdownMenuItem(
                              value: "all",
                              child: Text("جميع الفئات",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                            ...currentCategories
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12)),
                                    ))
                                .toList(),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _sidebarSelectedCategory = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                  // Search TextField
                  TextField(
                    focusNode: _sidebarSearchFocusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: "بحث عن قناة...",
                      hintStyle:
                          const TextStyle(color: Colors.white30, fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Colors.white30, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF1E1E20),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      _sidebarSearchDebounce?.cancel();
                      _sidebarSearchDebounce =
                          Timer(const Duration(milliseconds: 110), () {
                        if (mounted) setState(() => _sidebarSearchQuery = val);
                      });
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: activeStreams.isEmpty && recentStreams.isEmpty
                  ? const Center(
                      child: Text("لا توجد نتائج",
                          style:
                              TextStyle(color: Colors.white30, fontSize: 11)),
                    )
                  : CustomScrollView(
                      slivers: [
                        if (recentStreams.isNotEmpty &&
                            _sidebarSearchQuery.isEmpty &&
                            _sidebarSelectedCategory == "all") ...[
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                "تم تشغيله مؤخراً",
                                style: TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, idx) {
                                final item = recentStreams[idx];
                                return _buildSidebarListItem(item, provider);
                              },
                              childCount: recentStreams.length,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: Divider(
                                color: Color(0xFF27272A),
                                height: 16,
                                thickness: 0.5),
                          ),
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                "جميع القنوات",
                                style: TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, idx) {
                              final item = activeStreams[idx];
                              return _buildSidebarListItem(item, provider);
                            },
                            childCount: activeStreams.length,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsModal() {
    if (_betterController == null || !_initialized) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E20),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text("الإعدادات",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const Icon(Icons.high_quality_rounded,
                      color: Colors.cyanAccent),
                  title: const Text("الجودات",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showQualitySelector();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.subtitles_rounded,
                      color: Colors.amberAccent),
                  title: const Text("الترجمة",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showSubtitlesSelector();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.audiotrack_rounded,
                      color: Colors.greenAccent),
                  title: const Text("المسارات الصوتية",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showAudioSelector();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_in_picture_alt_rounded,
                      color: Colors.tealAccent),
                  title: const Text("صورة داخل صورة",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _togglePictureInPicture();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAudioSelector() {
    if (_betterController == null || !_initialized) return;
    showDialog(
        context: context,
        builder: (BuildContext bContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: StatefulBuilder(builder: (context, setModalState) {
              final List<BetterPlayerAsmsAudioTrack>? tracks =
                  _betterController!.betterPlayerAsmsAudioTracks;
              final selectedTrack =
                  _betterController!.betterPlayerAsmsAudioTrack;

              return Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  width: 500,
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E20),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.audiotrack_rounded,
                                color: Colors.greenAccent),
                            const SizedBox(width: 8),
                            const Text("المسارات الصوتية",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white54),
                              onPressed: () => Navigator.pop(bContext),
                            )
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      Expanded(
                        child: (tracks == null || tracks.isEmpty)
                            ? const Center(
                                child: Text("لا توجد مسارات صوتية إضافية",
                                    style: TextStyle(color: Colors.white54)))
                            : ListView.builder(
                                itemCount: tracks.length,
                                itemBuilder: (context, index) {
                                  final track = tracks[index];
                                  final isSelected = selectedTrack == track;
                                  return ListTile(
                                    title: Text(
                                        track.label ??
                                            track.language ??
                                            "مسار ${index + 1}",
                                        style: TextStyle(
                                            color: isSelected
                                                ? Colors.greenAccent
                                                : Colors.white)),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.greenAccent)
                                        : null,
                                    onTap: () {
                                      _betterController!.setAudioTrack(track);
                                      setModalState(() {});
                                      Navigator.pop(bContext);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        });
  }
}
