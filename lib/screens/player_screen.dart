import 'dart:io';
import 'package:flutter_iptv_player/services/download_manager.dart';
import 'package:flutter_iptv_player/widgets/pin_dialog.dart';
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
import 'dart:typed_data';
import 'package:flutter_iptv_player/screens/downloads_screen.dart';
import 'package:flutter_iptv_player/services/stalker_playback.dart';
import 'package:flutter_iptv_player/services/channel_switch_guard.dart';
import 'package:flutter_iptv_player/services/redacted_diagnostics.dart';

class _SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;
  const _SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });
}

class _ExternalSubtitleTrack {
  final String id;
  final String label;
  final String langCode;
  final String url;
  final Map<String, String>? headers;
  String? cachedContent;

  _ExternalSubtitleTrack({
    required this.id,
    required this.label,
    required this.langCode,
    required this.url,
    this.headers,
    this.cachedContent,
  });
}

const Map<int, int> _cp1256UpperMap = {
  0x80: 0x20AC, 0x81: 0x067E, 0x82: 0x201A, 0x83: 0x0192,
  0x84: 0x201E, 0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021,
  0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0679, 0x8B: 0x2039,
  0x8C: 0x0152, 0x8D: 0x0686, 0x8E: 0x0698, 0x8F: 0x0688,
  0x90: 0x06AF, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C,
  0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
  0x98: 0x06A9, 0x99: 0x2122, 0x9A: 0x0691, 0x9B: 0x203A,
  0x9C: 0x0153, 0x9D: 0x200C, 0x9E: 0x200D, 0x9F: 0x06BA,
  0xA0: 0x00A0, 0xA1: 0x060C, 0xA2: 0x00A2, 0xA3: 0x00A3,
  0xA4: 0x00A4, 0xA5: 0x00A5, 0xA6: 0x00A6, 0xA7: 0x00A7,
  0xA8: 0x00A8, 0xA9: 0x00A9, 0xAA: 0x06BE, 0xAB: 0x00AB,
  0xAC: 0x00AC, 0xAD: 0x00AD, 0xAE: 0x00AE, 0xAF: 0x00AF,
  0xB0: 0x00B0, 0xB1: 0x00B1, 0xB2: 0x00B2, 0xB3: 0x00B3,
  0xB4: 0x00B4, 0xB5: 0x00B5, 0xB6: 0x00B6, 0xB7: 0x00B7,
  0xB8: 0x00B8, 0xB9: 0x00B9, 0xBA: 0x061B, 0xBB: 0x00BB,
  0xBC: 0x00BC, 0xBD: 0x00BD, 0xBE: 0x00BE, 0xBF: 0x061F,
  0xC0: 0x06C1, 0xC1: 0x0621, 0xC2: 0x0622, 0xC3: 0x0623,
  0xC4: 0x0624, 0xC5: 0x0625, 0xC6: 0x0626, 0xC7: 0x0627,
  0xC8: 0x0628, 0xC9: 0x0629, 0xCA: 0x062A, 0xCB: 0x062B,
  0xCC: 0x062C, 0xCD: 0x062D, 0xCE: 0x062E, 0xCF: 0x062F,
  0xD0: 0x0630, 0xD1: 0x0631, 0xD2: 0x0632, 0xD3: 0x0633,
  0xD4: 0x0634, 0xD5: 0x0635, 0xD6: 0x0636, 0xD7: 0x00D7,
  0xD8: 0x0637, 0xD9: 0x0638, 0xDA: 0x0639, 0xDB: 0x063A,
  0xDC: 0x0640, 0xDD: 0x0641, 0xDE: 0x0642, 0xDF: 0x0643,
  0xE0: 0x00E0, 0xE1: 0x0644, 0xE2: 0x00E2, 0xE3: 0x0645,
  0xE4: 0x0646, 0xE5: 0x0647, 0xE6: 0x0648, 0xE7: 0x00E7,
  0xE8: 0x00E8, 0xE9: 0x00E9, 0xEA: 0x00EA, 0xEB: 0x00EB,
  0xEC: 0x0649, 0xED: 0x064A, 0xEE: 0x00EE, 0xEF: 0x00EF,
  0xF0: 0x064B, 0xF1: 0x064C, 0xF2: 0x064D, 0xF3: 0x064E,
  0xF4: 0x00F4, 0xF5: 0x064F, 0xF6: 0x0650, 0xF7: 0x00F7,
  0xF8: 0x0651, 0xF9: 0x00F9, 0xFA: 0x0652, 0xFB: 0x00FB,
  0xFC: 0x00FC, 0xFD: 0x200E, 0xFE: 0x200F, 0xFF: 0x06D2,
};

String _decodeSubtitleBytes(List<int> bytes) {
  if (bytes.isEmpty) return '';
  try {
    final decoded = utf8.decode(bytes);
    if (!decoded.contains('\uFFFD')) {
      return decoded.replaceFirst('\uFEFF', '');
    }
  } catch (_) {}
  final codeUnits = List<int>.generate(bytes.length, (i) {
    final b = bytes[i] & 0xFF;
    if (b < 0x80) return b;
    return _cp1256UpperMap[b] ?? b;
  });
  return String.fromCharCodes(codeUnits).replaceFirst('\uFEFF', '');
}

Duration? _parseSrtTimecode(String raw) {
  final clean = raw.trim().replaceAll(',', '.');
  final parts = clean.split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  int hours = 0;
  int minutes = 0;
  double seconds = 0.0;
  if (parts.length == 3) {
    hours = int.tryParse(parts[0].trim()) ?? 0;
    minutes = int.tryParse(parts[1].trim()) ?? 0;
    seconds = double.tryParse(parts[2].trim()) ?? 0.0;
  } else {
    minutes = int.tryParse(parts[0].trim()) ?? 0;
    seconds = double.tryParse(parts[1].trim()) ?? 0.0;
  }
  final totalMs =
      ((hours * 3600 + minutes * 60 + seconds) * 1000).round();
  return Duration(milliseconds: totalMs);
}

List<_SubtitleCue> _parseSubtitleCues(String rawText) {
  final cues = <_SubtitleCue>[];
  if (rawText.trim().isEmpty) return cues;
  final lines = rawText
      .replaceFirst('\uFEFF', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');

  final timeRegex = RegExp(
    r'((?:\d{1,2}:)?\d{1,2}:\d{2}[,.]\d{1,3})\s*-->\s*((?:\d{1,2}:)?\d{1,2}:\d{2}[,.]\d{1,3})',
  );

  int i = 0;
  while (i < lines.length) {
    final line = lines[i].trim();
    final match = timeRegex.firstMatch(line);
    if (match != null) {
      final start = _parseSrtTimecode(match.group(1) ?? '');
      final end = _parseSrtTimecode(match.group(2) ?? '');
      i++;
      final textLines = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        if (timeRegex.hasMatch(lines[i])) break;
        final cleanedLine = lines[i]
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll(RegExp(r'\{\\[^}]*\}'), '')
            .trim();
        if (cleanedLine.isNotEmpty) {
          textLines.add(cleanedLine);
        }
        i++;
      }
      if (start != null &&
          end != null &&
          end >= start &&
          textLines.isNotEmpty) {
        cues.add(_SubtitleCue(
          start: start,
          end: end,
          text: textLines.join('\n'),
        ));
      }
    } else {
      i++;
    }
  }
  return cues;
}

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
    // Kept lightweight to avoid competing with ExoPlayer hardware decoder
  }
  WebViewController? _webController;
  bool _isWebFallback = false;
  VideoPlayerController? _localFallbackController;
  bool _usingLocalFallback = false;
  String _activePlaybackUrl = '';
  Map<String, String> _activePlaybackHeaders = const {};
  List<_SubtitleCue> _parsedSubtitleCues = [];
  List<_ExternalSubtitleTrack> _externalSubtitleTracks = [];
  String _selectedExternalSubId = '';
  bool _isSearchingOnlineSubs = false;
  int _subtitleDelayMs = 0;
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
      _stream.type == 'live' || _stream.type == 'stalker';

  Duration _liveRetryDelay() {
    return const Duration(milliseconds: 400);
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
      var normalized = stripFfmpegPrefix(value.trim());
      if (normalized.startsWith('http://x.gamerdz1517.com')) {
        normalized = normalized.replaceFirst('http://', 'https://');
      }
      if (normalized.isNotEmpty && !candidates.contains(normalized)) {
        candidates.add(normalized);
      }
    }
    final uri = Uri.tryParse(primary.trim());
    final isXtreamLive = primary.contains('/live/');
    final isXtreamVodOrSeries =
        primary.contains('/movie/') || primary.contains('/series/');
    if (uri != null && isXtreamLive && uri.path.toLowerCase().endsWith('.m3u8')) {
      add(uri.replace(path: '${uri.path.substring(0, uri.path.length - 5)}ts').toString());
    }
    add(primary);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final path = uri.path.toLowerCase();
      if (isXtreamVodOrSeries) {
        final dotIdx = uri.path.lastIndexOf('.');
        final slashIdx = uri.path.lastIndexOf('/');
        final prefix = dotIdx > slashIdx
            ? uri.path.substring(0, dotIdx)
            : uri.path;
        for (final ext in ['mp4', 'mkv', 'ts']) {
          add(uri.replace(path: '$prefix.$ext').toString());
        }
      } else if (path.endsWith('.ts')) {
        add(uri.replace(path: '${uri.path.substring(0, uri.path.length - 3)}m3u8').toString());
      } else if (path.endsWith('.m3u8')) {
        add(uri.replace(path: '${uri.path.substring(0, uri.path.length - 5)}ts').toString());
      }
      add(uri.replace(scheme: uri.scheme == 'http' ? 'https' : 'http').toString());
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

      if (sSize == "صغير جداً" || sSize == "12")
        _subSizeVal = 12.0;
      else if (sSize == "صغير" || sSize == "14")
        _subSizeVal = 14.0;
      else if (sSize == "متوسط" || sSize == "18" || sSize == "16")
        _subSizeVal = 18.0;
      else if (sSize == "كبير" || sSize == "24" || sSize == "22")
        _subSizeVal = 24.0;
      else if (sSize == "ضخم" || sSize == "32" || sSize == "28")
        _subSizeVal = 32.0;
      else if (sSize == "ضخم جداً" || sSize == "40")
        _subSizeVal = 40.0;
      else {
        final parsed = double.tryParse(sSize);
        if (parsed != null && parsed >= 10 && parsed <= 50) {
          _subSizeVal = parsed;
        } else {
          _subSizeVal = 18.0;
        }
      }

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

  void _applySubtitlesConfiguration() {
    if (mounted) setState(() {});
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
        _applySubtitlesConfiguration();
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
    _stream = widget.stream;
    _initLoadingVideo();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializeController();
    _resetHideHUDTimer();
  }

  static String _cleanMediaTitleForSubtitleSearch(String rawTitle) {
    var t = rawTitle.trim();
    if (t.isEmpty) return '';
    // Strip common IPTV prefixes like "AR:", "EN -", "[4K]", "(2024)", "مترجم", etc.
    t = t.replaceAll(RegExp(r'^\[[^\]]+\]\s*'), '');
    t = t.replaceAll(
        RegExp(
            r'^(?:AR|EN|TR|FR|ES|DE|VIP|NETFLIX|SHAHID|OSN|TOD|WATCHIT|FHD|HD|4K|UHD|SD)\s*[:|\-–]\s*',
            caseSensitive: false),
        '');
    t = t.replaceAll(
        RegExp(
            r'\b(?:4K|UHD|FHD|1080p|720p|480p|WEB-DL|WEBRip|BluRay|BRRip|HDRip|x264|x265|HEVC|AAC)\b',
            caseSensitive: false),
        ' ');
    t = t.replaceAll(
        RegExp(r'(?:مترجم|مدبلج|كامل|جودة عالية|حصرياً|فيلم|مسلسل)'), ' ');
    // Strip "- الحلقة 1" or "S01E01" when extracting base title
    t = t.replaceAll(
        RegExp(r'\s*[-–|]\s*(?:الحلقة|حلقة|Episode|Ep\.?)\s*\d+.*$',
            caseSensitive: false),
        '');
    t = t.replaceAll(
        RegExp(r'\bS\d{1,2}\s*E\d{1,3}\b.*$', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\(\s*\d{4}\s*\)'), ' ');
    t = t.replaceAll(RegExp(r'\[\s*\d{4}\s*\]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.isEmpty ? rawTitle.trim() : t;
  }

  static ({int? season, int? episode}) _extractSeasonAndEpisode(String raw) {
    final sxe =
        RegExp(r'S(\d{1,2})\s*E(\d{1,3})', caseSensitive: false).firstMatch(raw);
    if (sxe != null) {
      return (
        season: int.tryParse(sxe.group(1) ?? '') ?? 1,
        episode: int.tryParse(sxe.group(2) ?? ''),
      );
    }
    final arSeason =
        RegExp(r'(?:الموسم|موسم)\s*(\d{1,2})').firstMatch(raw);
    final arEp =
        RegExp(r'(?:الحلقة|حلقة|ep\.?|episode)\s*(\d{1,3})', caseSensitive: false)
            .firstMatch(raw);
    if (arEp != null) {
      return (
        season: int.tryParse(arSeason?.group(1) ?? '') ?? 1,
        episode: int.tryParse(arEp.group(1) ?? ''),
      );
    }
    return (season: null, episode: null);
  }

  Future<bool> _loadExternalSubtitleTrack(
    _ExternalSubtitleTrack track, {
    bool saveAsPreferred = true,
  }) async {
    try {
      String srtContent = track.cachedContent ?? '';
      if (srtContent.trim().isEmpty && track.url.isNotEmpty) {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10);
        client.badCertificateCallback = (cert, host, port) => true;
        try {
          Uri uri = Uri.parse(track.url);
          for (int hop = 0; hop < 6; hop++) {
            final req = await client.getUrl(uri).timeout(const Duration(seconds: 10));
            req.followRedirects = false;
            req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
            req.headers.set('Accept', '*/*');
            track.headers?.forEach((k, v) {
              if (v.isNotEmpty) req.headers.set(k, v);
            });
            final resp = await req.close().timeout(const Duration(seconds: 10));
            if (resp.statusCode == 301 ||
                resp.statusCode == 302 ||
                resp.statusCode == 303 ||
                resp.statusCode == 307 ||
                resp.statusCode == 308) {
              final loc = resp.headers.value(HttpHeaders.locationHeader);
              await resp.drain<void>().catchError((_) {});
              if (loc == null || loc.isEmpty) break;
              uri = uri.resolve(loc.trim());
              continue;
            }
            if (resp.statusCode == 200) {
              final builder = BytesBuilder(copy: false);
              await for (final chunk in resp) {
                builder.add(chunk);
              }
              final bytes = builder.takeBytes();
              srtContent = _decodeSubtitleBytes(bytes);
            }
            break;
          }
        } finally {
          client.close(force: true);
        }
      }

      if (srtContent.trim().isEmpty) return false;
      final cues = _parseSubtitleCues(srtContent);
      if (cues.isEmpty) return false;

      track.cachedContent = srtContent;
      if (mounted) {
        setState(() {
          _parsedSubtitleCues = cues;
          _selectedExternalSubId = track.id;
          _selectedAiLang = '';
          _aiSubtitleText = '';
          _aiSubtitleTimer?.cancel();
        });
      }
      _startSeekTracker();

      // Cache subtitle locally so offline playback also has subtitles
      try {
        final prefs = await SharedPreferences.getInstance();
        final cleanId = _stream.streamId.replaceFirst(RegExp(r'^offline_'), '');
        await prefs.setString('sub_srt_cache_$cleanId', srtContent);
        await prefs.setString('sub_srt_label_$cleanId', track.label);
        if (saveAsPreferred) {
          await prefs.setString(
            'sub_lang',
            track.langCode == 'ar'
                ? 'العربية'
                : (track.langCode == 'en'
                    ? 'الإنجليزية'
                    : (track.langCode == 'fr' ? 'الفرنسية' : track.label)),
          );
        }
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _searchAndLoadOnlineSubtitles(
    String searchQuery, {
    String? knownImdbId,
    int? season,
    int? episode,
    bool autoSelectPreferred = true,
  }) async {
    final cleanQuery = searchQuery.trim();
    if (cleanQuery.isEmpty && (knownImdbId == null || knownImdbId.isEmpty)) {
      return;
    }
    if (mounted) {
      setState(() => _isSearchingOnlineSubs = true);
    }

    try {
      String imdbId = (knownImdbId ?? '').trim();
      final isSeries = _stream.type == 'series' ||
          _stream.type == 'stalker_series' ||
          _stream.url.contains('/series/') ||
          (episode != null && episode > 0);
      final epInfo = _extractSeasonAndEpisode(_stream.name);
      final targetSeason = season ?? epInfo.season ?? 1;
      final targetEpisode = episode ?? epInfo.episode ?? 1;

      // 1. Resolve IMDb ID (ttXXXXXXX) if not already provided
      if (!imdbId.startsWith('tt') && cleanQuery.isNotEmpty) {
        // Try IMDb Official Public Suggestion CDN first (ultra fast, no API key)
        try {
          final firstChar = cleanQuery
              .replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF]'), '')
              .toLowerCase();
          final bucket = firstChar.isNotEmpty ? firstChar[0] : 'x';
          final sugUri = Uri.parse(
              'https://v3.sg.media-imdb.com/suggestion/${Uri.encodeComponent(bucket)}/${Uri.encodeComponent(cleanQuery)}.json');
          final sugResp = await http
              .get(sugUri, headers: const {'Accept': 'application/json'})
              .timeout(const Duration(seconds: 6));
          if (sugResp.statusCode == 200) {
            final data = jsonDecode(sugResp.body);
            if (data is Map && data['d'] is List) {
              for (final entry in data['d'] as List) {
                if (entry is Map) {
                  final candidateId = entry['id']?.toString() ?? '';
                  if (candidateId.startsWith('tt')) {
                    imdbId = candidateId;
                    break;
                  }
                }
              }
            }
          }
        } catch (_) {}

        // Fallback to Stremio Cinemeta Catalog Search
        if (!imdbId.startsWith('tt')) {
          try {
            final catalogType = isSeries ? 'series' : 'movie';
            final cineUri = Uri.parse(
                'https://v3-cinemeta.strem.io/catalog/$catalogType/top/search=${Uri.encodeComponent(cleanQuery)}.json');
            final cineResp = await http
                .get(cineUri, headers: const {'Accept': 'application/json'})
                .timeout(const Duration(seconds: 6));
            if (cineResp.statusCode == 200) {
              final data = jsonDecode(cineResp.body);
              if (data is Map &&
                  data['metas'] is List &&
                  (data['metas'] as List).isNotEmpty) {
                final firstMeta = (data['metas'] as List).first;
                if (firstMeta is Map) {
                  final idStr = firstMeta['imdb_id']?.toString() ??
                      firstMeta['id']?.toString() ??
                      '';
                  if (idStr.startsWith('tt')) {
                    imdbId = idStr;
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      if (!imdbId.startsWith('tt')) return;

      final discovered = <_ExternalSubtitleTrack>[];
      final seenUrls = _externalSubtitleTracks.map((e) => e.url).toSet();

      void addTrack({
        required String url,
        required String rawLang,
        String? labelOverride,
      }) {
        final cleanUrl = url.trim();
        if (cleanUrl.isEmpty || seenUrls.contains(cleanUrl)) return;
        final lower = rawLang.toLowerCase();
        String langCode = 'other';
        String langLabel = labelOverride ?? rawLang;
        if (lower == 'ar' ||
            lower == 'ara' ||
            lower.contains('arab') ||
            lower.contains('عرب')) {
          langCode = 'ar';
          langLabel = 'العربية (ملف ترجمة كامل)';
        } else if (lower == 'en' ||
            lower == 'eng' ||
            lower.contains('english')) {
          langCode = 'en';
          langLabel = 'English (Full Subtitles)';
        } else if (lower == 'fr' ||
            lower == 'fre' ||
            lower == 'fra' ||
            lower.contains('french')) {
          langCode = 'fr';
          langLabel = 'Français (Sous-titres)';
        } else if (lower == 'tr' ||
            lower == 'tur' ||
            lower.contains('turk')) {
          langCode = 'tr';
          langLabel = 'Türkçe (Altyazı)';
        } else if (lower == 'es' ||
            lower == 'spa' ||
            lower.contains('span')) {
          langCode = 'es';
          langLabel = 'Español (Subtítulos)';
        } else {
          return; // Keep menu clean with supported languages
        }

        // Limit to at most 3 tracks per language to keep UI fast and clean
        final countForLang =
            discovered.where((t) => t.langCode == langCode).length;
        if (countForLang >= 3) return;

        seenUrls.add(cleanUrl);
        final suffix = countForLang > 0 ? ' #${countForLang + 1}' : '';
        discovered.add(_ExternalSubtitleTrack(
          id: 'ext_${langCode}_${discovered.length}_${cleanUrl.hashCode}',
          label: '$langLabel$suffix',
          langCode: langCode,
          url: cleanUrl,
        ));
      }

      // 2. Query Wyzie Subs API (returns direct UTF-8 .srt URLs)
      try {
        final wyzieParams = <String, String>{'id': imdbId};
        if (isSeries) {
          wyzieParams['season'] = targetSeason.toString();
          wyzieParams['episode'] = targetEpisode.toString();
        }
        final wyzieUri = Uri.parse('https://sub.wyzie.ru/search')
            .replace(queryParameters: wyzieParams);
        final wyzieResp = await http
            .get(wyzieUri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
        if (wyzieResp.statusCode == 200) {
          final list = jsonDecode(wyzieResp.body);
          if (list is List) {
            for (final item in list) {
              if (item is Map) {
                final subUrl = (item['url'] ?? '').toString();
                final lang =
                    (item['language'] ?? item['display'] ?? '').toString();
                addTrack(url: subUrl, rawLang: lang);
              }
            }
          }
        }
      } catch (_) {}

      // 3. Query OpenSubtitles v3 Stremio Public API
      try {
        final osPath = isSeries
            ? 'series/$imdbId:$targetSeason:$targetEpisode.json'
            : 'movie/$imdbId.json';
        final osUri =
            Uri.parse('https://opensubtitles-v3.strem.io/subtitles/$osPath');
        final osResp = await http
            .get(osUri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
        if (osResp.statusCode == 200) {
          final data = jsonDecode(osResp.body);
          if (data is Map && data['subtitles'] is List) {
            for (final item in data['subtitles'] as List) {
              if (item is Map) {
                final subUrl = (item['url'] ?? '').toString();
                final lang = (item['lang'] ?? '').toString();
                addTrack(url: subUrl, rawLang: lang);
              }
            }
          }
        }
      } catch (_) {}

      if (discovered.isNotEmpty && mounted) {
        discovered.sort((a, b) {
          if (a.langCode == 'ar' && b.langCode != 'ar') return -1;
          if (a.langCode != 'ar' && b.langCode == 'ar') return 1;
          return a.label.compareTo(b.label);
        });
        setState(() {
          _externalSubtitleTracks = [
            ..._externalSubtitleTracks,
            ...discovered,
          ];
        });
        if (autoSelectPreferred &&
            _parsedSubtitleCues.isEmpty &&
            _subLangVal != 'إيقاف') {
          await _applyPreferredSubtitleLanguage(retries: 0);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isSearchingOnlineSubs = false);
      }
    }
  }

  Future<void> _fetchXtreamVodRemoteSubtitles(
    BetterPlayerController? controller,
    Map<String, String> headers,
  ) async {
    String? remoteTitle;
    String? remoteImdbId;
    try {
      // 1. Check local offline cached subtitle for this stream first
      final prefs = await SharedPreferences.getInstance();
      final cleanId = _stream.streamId.replaceFirst(RegExp(r'^offline_'), '');
      final cachedSrt = prefs.getString('sub_srt_cache_$cleanId');
      final cachedLabel =
          prefs.getString('sub_srt_label_$cleanId') ?? 'العربية (محفوظة أوفلاين)';
      if (cachedSrt != null && cachedSrt.trim().isNotEmpty) {
        final cachedTrack = _ExternalSubtitleTrack(
          id: 'cached_$cleanId',
          label: cachedLabel,
          langCode: 'ar',
          url: '',
          cachedContent: cachedSrt,
        );
        if (!_externalSubtitleTracks.any((t) => t.id == cachedTrack.id)) {
          _externalSubtitleTracks.insert(0, cachedTrack);
        }
        if (_subLangVal != 'إيقاف' && _parsedSubtitleCues.isEmpty) {
          await _loadExternalSubtitleTrack(cachedTrack, saveAsPreferred: false);
        }
      }

      final rawUrl = _stream.url.trim();
      final isMovie = rawUrl.contains('/movie/');
      final isSeries = rawUrl.contains('/series/');
      if (isMovie || isSeries) {
        final uri = Uri.tryParse(rawUrl);
        if (uri != null) {
          final segs = uri.pathSegments;
          final idx = isMovie ? segs.indexOf('movie') : segs.indexOf('series');
          if (idx >= 0 && segs.length >= idx + 4) {
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
            final mediaId = fileSeg.contains('.')
                ? fileSeg.substring(0, fileSeg.lastIndexOf('.'))
                : fileSeg;
            if (mediaId.isNotEmpty && isMovie) {
              final apiUri = Uri.parse('$host/player_api.php').replace(
                queryParameters: {
                  'username': user,
                  'password': pass,
                  'action': 'get_vod_info',
                  'vod_id': mediaId,
                },
              );
              final resp = await http
                  .get(apiUri, headers: headers)
                  .timeout(const Duration(seconds: 8));
              if (resp.statusCode == 200) {
                final decoded = jsonDecode(resp.body);
                if (decoded is Map) {
                  final info = decoded['info'];
                  final movieData = decoded['movie_data'];
                  if (info is Map) {
                    remoteTitle = (info['o_name'] ??
                            info['name'] ??
                            (movieData is Map ? movieData['name'] : null) ??
                            '')
                        .toString()
                        .trim();
                    final tmdbOrImdb =
                        (info['imdb_id'] ?? info['kinopoisk_url'] ?? '')
                            .toString()
                            .trim();
                    final ttMatch =
                        RegExp(r'(tt\d{6,10})').firstMatch(tmdbOrImdb);
                    if (ttMatch != null) {
                      remoteImdbId = ttMatch.group(1);
                    }
                  }
                  final rawSubs = <dynamic>[
                    if (decoded['subtitles'] is List)
                      ...(decoded['subtitles'] as List),
                    if (info is Map && info['subtitles'] is List)
                      ...(info['subtitles'] as List),
                    if (movieData is Map && movieData['subtitles'] is List)
                      ...(movieData['subtitles'] as List),
                  ];
                  for (final item in rawSubs) {
                    String? subUrl;
                    String subName = 'العربية (سيرفر)';
                    if (item is String && item.trim().isNotEmpty) {
                      subUrl = item.trim();
                    } else if (item is Map) {
                      subUrl =
                          (item['url'] ?? item['file'] ?? item['src'] ?? '')
                              .toString()
                              .trim();
                      final lang = (item['language'] ??
                              item['lang'] ??
                              item['label'] ??
                              item['title'] ??
                              '')
                          .toString()
                          .trim();
                      if (lang.isNotEmpty) subName = lang;
                    }
                    if (subUrl != null && subUrl.isNotEmpty) {
                      final trackId = 'xtream_${subUrl.hashCode}';
                      if (!_externalSubtitleTracks.any((t) => t.id == trackId)) {
                        final lower = subName.toLowerCase();
                        final code = (lower.contains('ar') ||
                                lower.contains('عرب'))
                            ? 'ar'
                            : (lower.contains('en') ? 'en' : 'ar');
                        _externalSubtitleTracks.add(_ExternalSubtitleTrack(
                          id: trackId,
                          label: subName,
                          langCode: code,
                          url: subUrl,
                          headers: Map<String, String>.from(headers),
                        ));
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // 2. If Movie or Series, also search online subtitle providers automatically
    if (!_isLiveStream) {
      final baseSearchTitle = _cleanMediaTitleForSubtitleSearch(
        (remoteTitle != null && remoteTitle.isNotEmpty)
            ? remoteTitle
            : _stream.name,
      );
      await _searchAndLoadOnlineSubtitles(
        baseSearchTitle,
        knownImdbId: remoteImdbId,
        autoSelectPreferred: true,
      );
    }
  }

  Future<void> _prepareXtreamSubtitles(
    BetterPlayerController? controller,
    Map<String, String> headers,
  ) async {
    await _fetchXtreamVodRemoteSubtitles(controller, headers);
    if (!mounted) return;
    if (controller != null) {
      for (var attempt = 0; attempt < 6 && mounted; attempt++) {
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
        break;
      }
    }
    await _applyPreferredSubtitleLanguage(retries: 1);
  }

  Future<void> _applyPreferredSubtitleLanguage({int retries = 3}) async {
    if (_subLangVal == "إيقاف") return;
    try {
      String targetLang = _subLangVal.toLowerCase();
      if (_subLangVal == "العربية" ||
          targetLang == "arabic" ||
          targetLang == "ar" ||
          _subLangVal == "تلقائي")
        targetLang = "ar";
      else if (_subLangVal == "الإنجليزية" ||
          targetLang == "english" ||
          targetLang == "en")
        targetLang = "en";
      else if (_subLangVal == "الفرنسية" ||
          targetLang == "french" ||
          targetLang == "fr")
        targetLang = "fr";
      else if (_subLangVal == "الإسبانية" ||
          targetLang == "spanish" ||
          targetLang == "es")
        targetLang = "es";
      else if (_subLangVal == "التركية" ||
          targetLang == "turkish" ||
          targetLang == "tr")
        targetLang = "tr";
      else if (targetLang == "persian") targetLang = "fa";

      // 1. Prefer real external/cached SRT tracks first
      for (final extTrack in _externalSubtitleTracks) {
        if (extTrack.langCode == targetLang ||
            (targetLang == 'ar' && extTrack.label.contains('عرب'))) {
          final ok = await _loadExternalSubtitleTrack(
            extTrack,
            saveAsPreferred: false,
          );
          if (ok) return;
        }
      }
      if (_externalSubtitleTracks.isNotEmpty && _parsedSubtitleCues.isEmpty) {
        final ok = await _loadExternalSubtitleTrack(
          _externalSubtitleTracks.first,
          saveAsPreferred: false,
        );
        if (ok) return;
      }

      // 2. Check BetterPlayer embedded/HLS subtitle tracks
      if (_betterController != null) {
        final tracks = _betterController!.betterPlayerSubtitlesSourceList;
        BetterPlayerSubtitlesSource? matchedSource;
        for (final track in tracks) {
          if (track.type == BetterPlayerSubtitlesSourceType.none) continue;
          final name = (track.name ?? "").toLowerCase();
          if (name.contains(targetLang) ||
              (targetLang == "ar" && name.contains("عرب"))) {
            matchedSource = track;
            break;
          }
        }
        if (matchedSource != null) {
          _selectedAiLang = "";
          _aiSubtitleText = "";
          await _betterController!.setupSubtitleSource(matchedSource);
          if (mounted) setState(() {});
          return;
        }
      }

      if (retries > 0 && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await _applyPreferredSubtitleLanguage(retries: retries - 1);
      }
    } catch (e) {
      debugPrint(
          "Failed to apply preferred subtitle language: ${redactDiagnostic(e)}");
    }
  }

  void _disposeActiveController() {
    final controller = _betterController;
    _betterController = null;
    final localCtrl = _localFallbackController;
    _localFallbackController = null;
    _usingLocalFallback = false;
    _initialized = false;
    _positionTimer?.cancel();
    _positionTimer = null;
    if (localCtrl != null) {
      try {
        localCtrl.pause();
        localCtrl.dispose();
      } catch (_) {}
    }
    if (controller == null) return;
    try {
      controller.setVolume(0.0);
      controller.pause();
    } catch (_) {}
    try {
      controller.dispose();
    } catch (_) {}
  }

  Future<bool> _startLocalNativeFallback(
    String cleanLocalPath,
    int? savedPosition,
    int loadGeneration,
  ) async {
    try {
      final file = File(cleanLocalPath);
      if (!file.existsSync() || file.lengthSync() <= 0) return false;
      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      if (!mounted || !_channelSwitchGuard.isCurrent(loadGeneration)) {
        await ctrl.dispose();
        return false;
      }
      await ctrl.setLooping(false);
      await ctrl.setVolume(_volume);
      final dur = ctrl.value.duration;
      if (savedPosition != null && savedPosition > 0) {
        final pos = Duration(seconds: savedPosition);
        if (dur == Duration.zero || pos < dur) {
          await ctrl.seekTo(pos);
        }
      }
      await ctrl.play();
      if (mounted && _channelSwitchGuard.isCurrent(loadGeneration)) {
        setState(() {
          _localFallbackController = ctrl;
          _usingLocalFallback = true;
          _initialized = true;
          _isBuffering = false;
          _hasError = false;
          _errorMessage = null;
          _totalDuration = dur;
        });
        unawaited(_prepareXtreamSubtitles(null, _activePlaybackHeaders));
        _startSeekTracker();
      }
      return true;
    } catch (e) {
      debugPrint('Local native fallback error: $e');
      return false;
    }
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

    bool isOfflineMedia = _stream.type == 'file' ||
        _stream.url.startsWith('/') ||
        _stream.url.startsWith('file://');
    final provider = Provider.of<IPTVProvider>(context, listen: false);
    String urlStr = _stream.url;
    final cleanDownloadId =
        _stream.streamId.replaceFirst(RegExp(r'^offline_'), '');
    final existingDownload = DownloadManager.instance.findCompletedForStream(
      streamId: cleanDownloadId,
      url: _stream.url,
      title: _stream.name,
    );
    if (existingDownload != null && existingDownload.filePath.isNotEmpty) {
      final dlFile = File(existingDownload.filePath);
      if (dlFile.existsSync() && dlFile.lengthSync() > 0) {
        urlStr = existingDownload.filePath;
        isOfflineMedia = true;
      }
    }
    if (!isOfflineMedia) {
      final candidates = _playbackCandidates(_stream.url);
      final candidateIndex = isRetry && candidates.isNotEmpty
          ? _retryCount % candidates.length
          : 0;
      urlStr = candidates.isEmpty
          ? stripFfmpegPrefix(_stream.url)
          : candidates[candidateIndex];
    }
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

    if (!isOfflineMedia && isStalkerContent && !isDirectStalkerPlayback) {
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

        final res = await http
            .get(linkUrl, headers: reqHeaders)
            .timeout(const Duration(seconds: 12));
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
    // Skip pre-fetch HTTP delay; pass stream URL directly to ExoPlayer for instant playback
    final sourceDescriptor = classifyPlaybackUrl(finalUrl);
    final isIptvMediaCandidate = _stream.type == 'live' ||
        _stream.type == 'movie' ||
        _stream.type == 'series' ||
        _stream.type == 'channel' ||
        _stream.type.startsWith('stalker_');
    if (isOfflineMedia) {
      // Offline local file playback
    } else if (!sourceDescriptor.isDirectMedia && isIptvMediaCandidate) {
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
    if (!isRetry) {
      _parsedSubtitleCues = [];
      _externalSubtitleTracks = [];
      _selectedExternalSubId = '';
    }

    final bool isLocalFile = _stream.type == 'file' ||
        finalUrl.startsWith('/') ||
        finalUrl.startsWith('file://');
    String cleanLocalPath = finalUrl.replaceFirst(RegExp(r'^file://'), '');
    if (isLocalFile) {
      File localFile = File(cleanLocalPath);
      if (!localFile.existsSync() || localFile.lengthSync() <= 0) {
        if (mounted) {
          setState(() {
            _initialized = false;
            _isBuffering = false;
            _hasError = true;
            _errorMessage = 'ملف الفيديو غير مكتمل أو غير موجود على الجهاز، يرجى إعادة تنزيله.';
          });
        }
        return;
      }
      final detectedExt =
          DownloadManager.detectContainerExtensionFromBytes(localFile);
      if (detectedExt != null &&
          !cleanLocalPath.toLowerCase().endsWith('.$detectedExt')) {
        final dotIdx = cleanLocalPath.lastIndexOf('.');
        final renamedPath = dotIdx > 0
            ? '${cleanLocalPath.substring(0, dotIdx)}.$detectedExt'
            : '$cleanLocalPath.$detectedExt';
        try {
          localFile = localFile.renameSync(renamedPath);
          cleanLocalPath = localFile.path;
        } catch (_) {}
      }
      _activePlaybackUrl = cleanLocalPath;
      _activePlaybackHeaders = const {};
    } else {
      // Resolve HTTPS <-> HTTP cross-protocol 302 redirects for VOD/Series before ExoPlayer
      if (finalUrl.contains('/movie/') ||
          finalUrl.contains('/series/') ||
          finalUrl.contains('x.gamerdz1517.com')) {
        finalUrl = await DownloadManager.resolveCrossProtocolRedirectForPlayback(
          finalUrl,
          headers,
        );
        if (!mounted || !_channelSwitchGuard.isCurrent(loadGeneration)) return;
      }
      _activePlaybackUrl = finalUrl;
      _activePlaybackHeaders = Map<String, String>.from(headers);
    }

    BetterPlayerVideoFormat? format;
    if (isLocalFile || finalUrl.contains('/live/')) {
      format = null;
    } else if (isHlsPlaybackUrl(finalUrl)) {
      format = BetterPlayerVideoFormat.hls;
    } else if (isDashPlaybackUrl(finalUrl)) {
      format = BetterPlayerVideoFormat.dash;
    } else {
      format = null;
    }
    bool isAsms = !isLocalFile &&
        (format == BetterPlayerVideoFormat.hls ||
            format == BetterPlayerVideoFormat.dash);
    final BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      isLocalFile
          ? BetterPlayerDataSourceType.file
          : BetterPlayerDataSourceType.network,
      isLocalFile ? cleanLocalPath : finalUrl,
      liveStream:
          !isLocalFile && (_stream.type == 'live' || _stream.type == 'stalker'),
      videoFormat: format,
      videoExtension: isLocalFile
          ? null
          : ((isProgressiveTsUrl(finalUrl) ||
                  ((_stream.type == 'live' || _stream.type == 'stalker') &&
                      isLikelyLiveTransportStreamUrl(finalUrl)))
              ? 'ts'
              : null),
      headers: isLocalFile ? null : headers,
      useAsmsTracks: isAsms,
      useAsmsSubtitles: !isLocalFile,
      useAsmsAudioTracks: !isLocalFile,
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 1200,
        maxBufferMs: 8000,
        bufferForPlaybackMs: 300,
        bufferForPlaybackAfterRebufferMs: 800,
      ),
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
        subtitlesConfiguration: const BetterPlayerSubtitlesConfiguration(
          fontSize: 0.0,
          fontColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          outlineColor: Colors.transparent,
          outlineSize: 0.0,
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
        if (isLocalFile) {
          unawaited(
            _startLocalNativeFallback(
              cleanLocalPath,
              savedPosition,
              loadGeneration,
            ).then((ok) {
              if (!ok) _handlePlaybackError(errorMessage, loadGeneration);
            }),
          );
          return;
        }
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

  Widget _buildSubtitleOverlay() {
    if (_betterController == null && _localFallbackController == null) {
      return const SizedBox.shrink();
    }
    String subtitleText = '';
    final rawPos = _usingLocalFallback
        ? (_localFallbackController?.value.position ?? _currentPosition)
        : (_betterController?.videoPlayerController?.value.position ??
            _currentPosition);
    final adjustedPos = rawPos + Duration(milliseconds: _subtitleDelayMs);

    // 1. Check our parsed SRT/WebVTT subtitle cues first
    if (_parsedSubtitleCues.isNotEmpty) {
      for (final cue in _parsedSubtitleCues) {
        if (cue.start <= adjustedPos && cue.end >= adjustedPos) {
          subtitleText = cue.text;
          break;
        }
      }
    }

    // 2. Fallback to BetterPlayer's internal HLS/ASMS subtitle lines
    if (subtitleText.trim().isEmpty && _betterController != null) {
      final lines = _betterController!.subtitlesLines;
      if (lines.isNotEmpty) {
        dynamic activeSubtitle;
        for (final sub in lines) {
          if (sub.start != null &&
              sub.end != null &&
              sub.start! <= adjustedPos &&
              sub.end! >= adjustedPos) {
            activeSubtitle = sub;
            break;
          }
        }
        if (activeSubtitle != null && activeSubtitle.texts is List) {
          final rawTexts = activeSubtitle.texts as List;
          if (rawTexts.isNotEmpty) {
            subtitleText = rawTexts.map((e) => e.toString()).join('\n');
          }
        }
      }
    }

    // 3. Fallback to Live/Instant subtitle text
    if (subtitleText.trim().isEmpty && _aiSubtitleText.trim().isNotEmpty) {
      subtitleText = _aiSubtitleText.trim();
    }
    if (subtitleText.trim().isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: _showHUD ? 85.0 : 35.0,
            left: 24.0,
            right: 24.0,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _subBgColorVal,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              children: [
                Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _subSizeVal,
                    fontFamily: _subFontVal,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2.5
                      ..color = Colors.black,
                  ),
                ),
                Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _subSizeVal,
                    fontFamily: _subFontVal,
                    color: _subColorVal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startSeekTracker() {
    _positionTimer?.cancel();
    if (_stream.type == 'live' && _parsedSubtitleCues.isEmpty) return;
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) return;
      if (_usingLocalFallback && _localFallbackController != null) {
        final val = _localFallbackController!.value;
        if (val.isInitialized && val.position != _currentPosition) {
          setState(() {
            _currentPosition = val.position;
            if (val.duration > Duration.zero) {
              _totalDuration = val.duration;
            }
          });
        }
        return;
      }
      final value = _betterController?.videoPlayerController?.value;
      if (value != null &&
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
    if (!_initialized) return;
    int activeSubTab = 0;
    final TextEditingController searchSubCtrl = TextEditingController(
      text: _cleanMediaTitleForSubtitleSearch(_stream.name),
    );

    showDialog(
        context: context,
        builder: (BuildContext bContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: StatefulBuilder(builder: (context, setModalState) {
              final List<BetterPlayerSubtitlesSource> rawSubtitles =
                  _betterController?.betterPlayerSubtitlesSourceList ?? [];
              final selectedSub =
                  _betterController?.betterPlayerSubtitlesSource;

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
                if (_selectedAiLang.isEmpty &&
                    _selectedExternalSubId.isEmpty &&
                    (_betterController?.betterPlayerSubtitlesSource == null ||
                        _betterController?.betterPlayerSubtitlesSource?.type ==
                            BetterPlayerSubtitlesSourceType.none)) {
                  _selectedAiLang = 'ar';
                  _aiSubtitleText = 'معاينة حية للترجمة على شاشة الفيديو';
                  _startAiSubtitleTimer();
                }
                _applySubtitlesConfiguration();
              }

              final bool isSubOff = _selectedAiLang.isEmpty &&
                  _selectedExternalSubId.isEmpty &&
                  _parsedSubtitleCues.isEmpty &&
                  (selectedSub == null ||
                      selectedSub.type == BetterPlayerSubtitlesSourceType.none);

              return Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  width: 540,
                  constraints: const BoxConstraints(maxHeight: 580),
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
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.subtitles_rounded,
                                color: Color(0xFFA855F7), size: 24),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text("الترجمة الاحترافية وإعدادات الخط",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                            ),
                            if (_isSearchingOnlineSubs)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFA855F7),
                                  ),
                                ),
                              ),
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
                                  onTap: () =>
                                      setModalState(() => activeSubTab = 0),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: activeSubTab == 0
                                          ? const Color(0xFFA855F7)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "مسارات الترجمة (${_externalSubtitleTracks.length + validSubtitles.length})",
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
                                  onTap: () =>
                                      setModalState(() => activeSubTab = 1),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: activeSubTab == 1
                                          ? const Color(0xFFA855F7)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "الخط والمزامنة",
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                children: [
                                  // Online Subtitle Search Box
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: searchSubCtrl,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13),
                                            decoration: InputDecoration(
                                              hintText:
                                                  "ابحث باسم الفيلم أو المسلسل لجلب الترجمة...",
                                              hintStyle: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 12),
                                              filled: true,
                                              fillColor:
                                                  const Color(0xFF1E1E2A),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: Colors.white24),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: Colors.white12),
                                              ),
                                            ),
                                            onSubmitted: (q) async {
                                              if (q.trim().isEmpty) return;
                                              setModalState(() {});
                                              await _searchAndLoadOnlineSubtitles(
                                                q.trim(),
                                                autoSelectPreferred: true,
                                              );
                                              if (mounted) setState(() {});
                                              setModalState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFA855F7),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: _isSearchingOnlineSubs
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.search_rounded,
                                                  size: 18),
                                          label: const Text("جلب",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold)),
                                          onPressed: _isSearchingOnlineSubs
                                              ? null
                                              : () async {
                                                  final q =
                                                      searchSubCtrl.text.trim();
                                                  setModalState(() {});
                                                  await _searchAndLoadOnlineSubtitles(
                                                    q.isNotEmpty
                                                        ? q
                                                        : _cleanMediaTitleForSubtitleSearch(
                                                            _stream.name),
                                                    autoSelectPreferred: true,
                                                  );
                                                  if (mounted) setState(() {});
                                                  setModalState(() {});
                                                },
                                        ),
                                      ],
                                    ),
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.subtitles_off_rounded,
                                      color: isSubOff
                                          ? const Color(0xFFA855F7)
                                          : Colors.white54,
                                    ),
                                    title: const Text("إيقاف الترجمة",
                                        style: TextStyle(color: Colors.white)),
                                    trailing: isSubOff
                                         ? const Icon(Icons.check_circle,
                                             color: Color(0xFFA855F7))
                                         : null,
                                    onTap: () async {
                                      _selectedAiLang = "";
                                      _aiSubtitleText = "";
                                      _subLangVal = "إيقاف";
                                      _selectedExternalSubId = "";
                                      _parsedSubtitleCues = [];
                                      _aiSubtitleTimer?.cancel();
                                      try {
                                        _betterController?.setupSubtitleSource(
                                            BetterPlayerSubtitlesSource(
                                                type:
                                                    BetterPlayerSubtitlesSourceType
                                                        .none));
                                      } catch (_) {}
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setString(
                                          'sub_lang', 'إيقاف');
                                      if (mounted) setState(() {});
                                      setModalState(() {});
                                      Navigator.pop(bContext);
                                    },
                                  ),
                                  if (_externalSubtitleTracks.isNotEmpty) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 6),
                                      child: Text(
                                          "ملفات الترجمة المتاحة (متزامنة بالكامل SRT/VTT)",
                                          style: TextStyle(
                                              color: Color(0xFF38BDF8),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    ..._externalSubtitleTracks.map((track) {
                                      final isSelected =
                                          _selectedExternalSubId == track.id;
                                      final srcName = track.id
                                              .startsWith('xtream_')
                                          ? 'السيرفر'
                                          : (track.id.startsWith('cached_')
                                              ? 'محفوظ أوفلاين'
                                              : 'OpenSubtitles / Wyzie');
                                      return ListTile(
                                        dense: true,
                                        leading: Icon(
                                          Icons.closed_caption_rounded,
                                          color: isSelected
                                              ? const Color(0xFF22C55E)
                                              : const Color(0xFFA855F7),
                                        ),
                                        title: Text(
                                          track.label,
                                          style: TextStyle(
                                            color: isSelected
                                                ? const Color(0xFF22C55E)
                                                : Colors.white,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "المصدر: $srcName • اللغة: ${track.langCode.toUpperCase()}",
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11),
                                        ),
                                        trailing: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Color(0xFF22C55E))
                                            : null,
                                        onTap: () async {
                                          await _loadExternalSubtitleTrack(
                                              track);
                                          final prefs = await SharedPreferences
                                              .getInstance();
                                          await prefs.setString(
                                              'sub_lang',
                                              track.langCode == 'ar'
                                                  ? 'العربية'
                                                  : (track.langCode == 'en'
                                                      ? 'الإنجليزية'
                                                      : 'الفرنسية'));
                                          if (mounted) setState(() {});
                                          setModalState(() {});
                                          if (bContext.mounted) {
                                            Navigator.pop(bContext);
                                          }
                                        },
                                      );
                                    }),
                                  ],
                                  if (validSubtitles.isNotEmpty) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      child: Text("الترجمات المدمجة في البث",
                                          style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12)),
                                    ),
                                    ...validSubtitles.map((sub) {
                                      final isSelected =
                                          _selectedAiLang.isEmpty &&
                                              _selectedExternalSubId.isEmpty &&
                                              selectedSub == sub;
                                      final name = sub.name ?? "ترجمة مدمجة";
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(
                                            Icons.subtitles_outlined,
                                            color: Colors.white70),
                                        title: Text(name,
                                            style: TextStyle(
                                                color: isSelected
                                                    ? const Color(0xFFA855F7)
                                                    : Colors.white)),
                                        trailing: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Color(0xFFA855F7))
                                            : null,
                                        onTap: () async {
                                          _selectedAiLang = "";
                                          _selectedExternalSubId = "";
                                          _parsedSubtitleCues = [];
                                          _aiSubtitleText = "";
                                          try {
                                            _betterController
                                                ?.setupSubtitleSource(sub);
                                          } catch (_) {}
                                          // If this embedded subtitle also has URLs, parse it into our custom overlay too!
                                          if (sub.urls != null &&
                                              sub.urls!.isNotEmpty &&
                                              sub.urls!.first != null) {
                                            await _loadExternalSubtitleTrack(
                                              _ExternalSubtitleTrack(
                                                id: 'embedded_${sub.name}',
                                                label: name,
                                                langCode: name
                                                            .toLowerCase()
                                                            .contains('ar') ||
                                                        name.contains('عرب')
                                                    ? 'ar'
                                                    : 'en',
                                                url: sub.urls!.first!,
                                              ),
                                            );
                                          }
                                          if (mounted) setState(() {});
                                          setModalState(() {});
                                          if (bContext.mounted) {
                                            Navigator.pop(bContext);
                                          }
                                        },
                                      );
                                    }).toList(),
                                  ],
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Text(
                                        "الترجمة التلقائية والبحث الذكي حسب اللغة",
                                        style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12)),
                                  ),
                                  ...[
                                    {
                                      'code': 'ar',
                                      'label': 'العربية (تلقائي + فوري)',
                                      'sample': 'تم تفعيل الترجمة العربية'
                                    },
                                    {
                                      'code': 'en',
                                      'label': 'English (Auto Subtitles)',
                                      'sample': 'English Subtitles Enabled'
                                    },
                                    {
                                      'code': 'fr',
                                      'label': 'Français (Sous-titres Auto)',
                                      'sample': 'Sous-titres Français Activés'
                                    },
                                  ].map((item) {
                                    final code = item['code']!;
                                    final isSelected = _selectedAiLang == code;
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        Icons.auto_awesome_rounded,
                                        color: isSelected
                                            ? const Color(0xFFA855F7)
                                            : Colors.amberAccent,
                                      ),
                                      title: Text(
                                        item['label']!,
                                        style: TextStyle(
                                          color: isSelected
                                              ? const Color(0xFFA855F7)
                                              : Colors.white,
                                        ),
                                      ),
                                      trailing: isSelected
                                          ? const Icon(Icons.check_circle,
                                              color: Color(0xFFA855F7))
                                          : null,
                                      onTap: () async {
                                        final prefs = await SharedPreferences
                                            .getInstance();
                                        final langPref = code == 'ar'
                                            ? 'العربية'
                                            : (code == 'en'
                                                ? 'الإنجليزية'
                                                : 'الفرنسية');
                                        await prefs.setString(
                                            'sub_lang', langPref);
                                        _subLangVal = langPref;
                                        setState(() {
                                          _selectedAiLang = code;
                                        });
                                        // Check if we already have an external track for this language
                                        final matching = _externalSubtitleTracks
                                            .where((t) => t.langCode == code)
                                            .toList();
                                        if (matching.isNotEmpty) {
                                          await _loadExternalSubtitleTrack(
                                              matching.first);
                                        } else {
                                          _startAiSubtitleTimer();
                                          unawaited(
                                            _searchAndLoadOnlineSubtitles(
                                              _cleanMediaTitleForSubtitleSearch(
                                                  _stream.name),
                                              autoSelectPreferred: true,
                                            ),
                                          );
                                        }
                                        setModalState(() {});
                                        if (bContext.mounted) {
                                          Navigator.pop(bContext);
                                        }
                                      },
                                    );
                                  }),
                                ],
                              )
                            : ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  // Subtitle Sync Offset Control
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E2A),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.timer_outlined,
                                            color: Color(0xFF38BDF8), size: 18),
                                        const SizedBox(width: 6),
                                        const Text("مزامنة التوقيت:",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                        const Spacer(),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.white70,
                                              size: 20),
                                          tooltip: "تأخير 0.5 ثانية",
                                          onPressed: () {
                                            setState(() =>
                                                _subtitleDelayMs -= 500);
                                            setModalState(() {});
                                          },
                                        ),
                                        Text(
                                          "${(_subtitleDelayMs / 1000.0).toStringAsFixed(1)} ث",
                                          style: const TextStyle(
                                              color: Color(0xFF38BDF8),
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.white70,
                                              size: 20),
                                          tooltip: "تقديم 0.5 ثانية",
                                          onPressed: () {
                                            setState(() =>
                                                _subtitleDelayMs += 500);
                                            setModalState(() {});
                                          },
                                        ),
                                        if (_subtitleDelayMs != 0)
                                          TextButton(
                                            onPressed: () {
                                              setState(
                                                  () => _subtitleDelayMs = 0);
                                              setModalState(() {});
                                            },
                                            child: const Text("ضبط",
                                                style: TextStyle(
                                                    color: Colors.amberAccent,
                                                    fontSize: 11)),
                                          ),
                                      ],
                                    ),
                                  ),
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
                    if (_initialized) {
                      final pos =
                          _currentPosition - const Duration(seconds: 10);
                      final target = pos < Duration.zero ? Duration.zero : pos;
                      if (_usingLocalFallback &&
                          _localFallbackController != null) {
                        _localFallbackController!.seekTo(target);
                      } else {
                        _betterController?.seekTo(target);
                      }
                      setState(() {
                        _swipeToastIcon = Icons.replay_10_rounded;
                        _swipeToastText = "رجوع 10 ثواني";
                      });
                    }
                  } else {
                    // Seek forward 10s
                    if (_initialized) {
                      final pos =
                          _currentPosition + const Duration(seconds: 10);
                      final target =
                          pos > _totalDuration ? _totalDuration : pos;
                      if (_usingLocalFallback &&
                          _localFallbackController != null) {
                        _localFallbackController!.seekTo(target);
                      } else {
                        _betterController?.seekTo(target);
                      }
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
                            : _initialized &&
                                    _usingLocalFallback &&
                                    _localFallbackController != null &&
                                    _localFallbackController!
                                        .value.isInitialized
                                ? SizedBox.expand(
                                    child: FittedBox(
                                      fit: _currentBoxFit,
                                      child: SizedBox(
                                        width: _localFallbackController!
                                                    .value.size.width >
                                                0
                                            ? _localFallbackController!
                                                .value.size.width
                                            : 1280,
                                        height: _localFallbackController!
                                                    .value.size.height >
                                                0
                                            ? _localFallbackController!
                                                .value.size.height
                                            : 720,
                                        child: VideoPlayer(
                                            _localFallbackController!),
                                      ),
                                    ),
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
                                                    controller:
                                                        _betterController!),
                                              )
                                            : BetterPlayer(
                                                key: _betterPlayerKey,
                                                controller: _betterController!),
                                      )
                                    : _buildPlayerLoading(),
                  ),
                ),
              ),

              // Real-time Dynamic Subtitle Overlay
              _buildSubtitleOverlay(),

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
                              // Download Button (Works for Xtream VOD/movies/series)
                              if (_stream.type != 'live' &&
                                  _stream.type != 'file' &&
                                  !_stream.url.startsWith('/'))
                                ListenableBuilder(
                                  listenable: DownloadManager.instance,
                                  builder: (context, _) {
                                    final streamId = _stream.streamId;
                                    final isDone = DownloadManager.instance
                                        .isDownloaded(streamId);
                                    final isDling = DownloadManager.instance
                                        .isDownloading(streamId);

                                    return IconButton(
                                      icon: Icon(
                                        isDone
                                            ? Icons.check_circle_rounded
                                            : (isDling
                                                ? Icons.downloading_rounded
                                                : Icons.download_rounded),
                                        color: isDone
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFA855F7),
                                        size: 24,
                                      ),
                                      tooltip: isDone
                                          ? "تم تنزيل الفيديو مسبقاً"
                                          : (isDling
                                              ? "قيد التحميل الآن..."
                                              : "تنزيل الفيديو للجهاز"),
                                      onPressed: () {
                                        _resetHideHUDTimer();
                                        if (isDone) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'هذا الفيديو تم تنزيله وموجود في التنزيلات للتشغيل أوفلاين',
                                                style: TextStyle(
                                                    fontFamily: 'Cairo'),
                                              ),
                                              action: SnackBarAction(
                                                label: 'فتح التنزيلات',
                                                textColor:
                                                    const Color(0xFF38BDF8),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const DownloadsScreen(),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        } else if (isDling) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'جارِ تحميل هذا الفيديو بالفعل في قائمة التنزيلات',
                                                style: TextStyle(
                                                    fontFamily: 'Cairo'),
                                              ),
                                              action: SnackBarAction(
                                                label: 'عرض التقدم',
                                                textColor:
                                                    const Color(0xFF38BDF8),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const DownloadsScreen(),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        } else {
                                          final url = _activePlaybackUrl
                                                  .isNotEmpty
                                              ? _activePlaybackUrl
                                              : _stream.url;
                                          DownloadManager.instance
                                              .startDownload(
                                            id: streamId,
                                            title: _stream.name,
                                            url: url,
                                            poster: _stream.streamIcon,
                                            category: _stream.categoryName,
                                            type: _stream.type == 'series'
                                                ? 'series'
                                                : 'movie',
                                            headers: _activePlaybackHeaders
                                                    .isNotEmpty
                                                ? _activePlaybackHeaders
                                                : null,
                                          );
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'بدأ تنزيل "${_stream.name}" (ملاحظة: يفضل إغلاق المشغل إذا كان اشتراكك يدعم اتصالاً واحداً لتسريع التنزيل)',
                                                style: const TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12),
                                              ),
                                              duration:
                                                  const Duration(seconds: 4),
                                              action: SnackBarAction(
                                                label: 'التنزيلات',
                                                textColor:
                                                    const Color(0xFF38BDF8),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const DownloadsScreen(),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
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
                            if (_initialized) {
                              final pos = _currentPosition -
                                  const Duration(seconds: 10);
                              final target =
                                  pos < Duration.zero ? Duration.zero : pos;
                              if (_usingLocalFallback &&
                                  _localFallbackController != null) {
                                _localFallbackController!.seekTo(target);
                              } else {
                                _betterController?.seekTo(target);
                              }
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
                            if (_initialized) {
                              setState(() {
                                if (_usingLocalFallback &&
                                    _localFallbackController != null) {
                                  _localFallbackController!.value.isPlaying
                                      ? _localFallbackController!.pause()
                                      : _localFallbackController!.play();
                                } else if (_betterController != null) {
                                  _betterController!.isPlaying() == true
                                      ? _betterController!.pause()
                                      : _betterController!.play();
                                }
                              });
                            }
                            _resetHideHUDTimer();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFA855F7),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 10,
                                    offset: Offset(0, 4)),
                              ],
                            ),
                            child: Icon(
                              (_usingLocalFallback
                                      ? (_localFallbackController
                                              ?.value.isPlaying ??
                                          false)
                                      : (_betterController?.isPlaying() ??
                                          false))
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
                            if (_initialized) {
                              final pos = _currentPosition +
                                  const Duration(seconds: 10);
                              final target =
                                  pos > _totalDuration ? _totalDuration : pos;
                              if (_usingLocalFallback &&
                                  _localFallbackController != null) {
                                _localFallbackController!.seekTo(target);
                              } else {
                                _betterController?.seekTo(target);
                              }
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
                                    final target =
                                        Duration(seconds: val.toInt());
                                    if (_usingLocalFallback &&
                                        _localFallbackController != null) {
                                      _localFallbackController!.seekTo(target);
                                    } else {
                                      _betterController?.seekTo(target);
                                    }
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
    final isLocked = provider.isChannelLocked(item.streamId);
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.blueAccent : Colors.white70,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isLocked)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.lock_rounded, size: 12, color: Color(0xFFA855F7)),
              ),
          ],
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
