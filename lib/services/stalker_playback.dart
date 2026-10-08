import 'dart:io';

String stripFfmpegPrefix(String url) {
  return url
      .replaceFirst(RegExp(r'^\s*ffmpeg\s+', caseSensitive: false), '')
      .trim();
}

String _formatSearchText(String url) {
  final normalized = stripFfmpegPrefix(url);
  try {
    final embedded = Uri.parse(normalized).queryParameters['url'];
    if (embedded != null && embedded.isNotEmpty) {
      return '$normalized ${stripFfmpegPrefix(embedded)}'.toLowerCase();
    }
  } catch (_) {}
  return normalized.toLowerCase();
}

enum PlaybackSourceKind {
  hls,
  dash,
  transportStream,
  progressiveFile,
  youtubePage,
  webPage,
  unknown,
}

class PlaybackSourceDescriptor {
  final PlaybackSourceKind kind;
  final String normalizedUrl;
  final String? unsupportedReason;

  const PlaybackSourceDescriptor({
    required this.kind,
    required this.normalizedUrl,
    this.unsupportedReason,
  });

  bool get isDirectMedia =>
      kind == PlaybackSourceKind.hls ||
      kind == PlaybackSourceKind.dash ||
      kind == PlaybackSourceKind.transportStream ||
      kind == PlaybackSourceKind.progressiveFile;
}

bool isWorkerStalkerStreamUrl(String url) {
  return stripFfmpegPrefix(url).toLowerCase().contains('/v1/stalker/stream');
}

bool isHlsPlaybackUrl(String url) {
  final lower = _formatSearchText(url);
  return lower.contains('.m3u8') ||
      lower.contains('extension=m3u8') ||
      lower.contains('format=m3u8') ||
      lower.contains('format=hls') ||
      _isHlsProxyEndpoint(url);
}

bool _isHlsProxyEndpoint(String url) {
  try {
    final uri = Uri.parse(stripFfmpegPrefix(url));
    return uri.path == '/tv' && uri.queryParameters.containsKey('url');
  } catch (_) {
    return false;
  }
}

bool isDashPlaybackUrl(String url) {
  final lower = _formatSearchText(url);
  return lower.contains('.mpd') ||
      lower.contains('extension=mpd') ||
      lower.contains('format=mpd') ||
      lower.contains('format=dash');
}

bool isProgressiveTsUrl(String url) {
  final lower = _formatSearchText(url);
  if (isHlsPlaybackUrl(url) || isDashPlaybackUrl(url)) return false;
  return lower.endsWith('.ts') ||
      lower.contains('extension=ts') ||
      lower.contains('format=ts') ||
      isWorkerStalkerStreamUrl(url);
}

/// Some IPTV servers return raw MPEG-TS from an extensionless live endpoint.
bool isLikelyLiveTransportStreamUrl(String url) {
  final lower = _formatSearchText(url);
  if (isHlsPlaybackUrl(url) ||
      isDashPlaybackUrl(url) ||
      isProgressiveFileUrl(url)) {
    return false;
  }
  return lower.startsWith('http://') || lower.startsWith('https://');
}

bool isProgressiveFileUrl(String url) {
  final lower = _formatSearchText(url);
  return RegExp(r'\.(mp4|m4v|webm|mov|mkv|avi)(?:[?#&]|$)').hasMatch(lower);
}

bool _isDirectGoogleMediaUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();
    return (host == 'drive.google.com' || host == 'docs.google.com') &&
        (uri.queryParameters['export'] == 'download' ||
            uri.queryParameters['alt'] == 'media');
  } catch (_) {
    return false;
  }
}

bool _isYoutubeHost(String host) {
  final lower = host.toLowerCase();
  return lower == 'youtu.be' ||
      lower == 'youtube.com' ||
      lower.endsWith('.youtube.com') ||
      lower == 'youtube-nocookie.com' ||
      lower.endsWith('.youtube-nocookie.com');
}

PlaybackSourceDescriptor classifyPlaybackUrl(String rawUrl) {
  final normalized = stripFfmpegPrefix(rawUrl);
  if (isHlsPlaybackUrl(normalized)) {
    return PlaybackSourceDescriptor(
      kind: PlaybackSourceKind.hls,
      normalizedUrl: normalized,
    );
  }
  if (isDashPlaybackUrl(normalized)) {
    return PlaybackSourceDescriptor(
      kind: PlaybackSourceKind.dash,
      normalizedUrl: normalized,
    );
  }
  if (isProgressiveTsUrl(normalized)) {
    return PlaybackSourceDescriptor(
      kind: PlaybackSourceKind.transportStream,
      normalizedUrl: normalized,
    );
  }
  if (isProgressiveFileUrl(normalized) || _isDirectGoogleMediaUrl(normalized)) {
    return PlaybackSourceDescriptor(
      kind: PlaybackSourceKind.progressiveFile,
      normalizedUrl: normalized,
    );
  }

  try {
    final uri = Uri.parse(normalized);
    if (_isYoutubeHost(uri.host)) {
      return PlaybackSourceDescriptor(
        kind: PlaybackSourceKind.youtubePage,
        normalizedUrl: normalized,
        unsupportedReason:
            'رابط YouTube صفحة ويب وليس ملف وسائط؛ يحتاج مشغل YouTube رسمي أو رابط manifest مصرحاً به.',
      );
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return PlaybackSourceDescriptor(
        kind: PlaybackSourceKind.webPage,
        normalizedUrl: normalized,
        unsupportedReason:
            'رابط صفحة ويب؛ لا يمكن لـExoPlayer تشغيل HTML كرابط فيديو مباشر.',
      );
    }
  } catch (_) {}

  return PlaybackSourceDescriptor(
    kind: PlaybackSourceKind.unknown,
    normalizedUrl: normalized,
    unsupportedReason: 'صيغة الرابط غير معروفة أو غير قابلة للتحليل.',
  );
}

bool isDirectStalkerPlaybackUrl(String url) {
  final normalized = stripFfmpegPrefix(url);
  final lower = _formatSearchText(normalized);
  return isWorkerStalkerStreamUrl(normalized) ||
      lower.contains('/v1/stalker/play') ||
      lower.contains('/play/live.php') ||
      isHlsPlaybackUrl(normalized) ||
      isDashPlaybackUrl(normalized) ||
      isProgressiveTsUrl(normalized);
}

const String _kGamerdzLiveBase =
    'https://x.gamerdz1517.com/live/00%3A1A%3A79%3A27%3A9F%3AA2/b8cfjif9';

const Map<int, String> _kCustomStreamIndexReplacements = <int, String>{
  0: '$_kGamerdzLiveBase/1294764.ts',
  1: '$_kGamerdzLiveBase/1294763.ts',
  2: '$_kGamerdzLiveBase/1294762.ts',
  3: '$_kGamerdzLiveBase/1294761.ts',
  4: '$_kGamerdzLiveBase/1294760.ts',
  5: '$_kGamerdzLiveBase/1294759.ts',
  6: '$_kGamerdzLiveBase/1330437.ts',
  7: '$_kGamerdzLiveBase/1330438.ts',
  8: '$_kGamerdzLiveBase/1330439.ts',
  9: '$_kGamerdzLiveBase/1294761.ts',
  10: '$_kGamerdzLiveBase/1330441.ts',
  11: '$_kGamerdzLiveBase/1330442.ts',
  12: '$_kGamerdzLiveBase/591593.ts',
  13: '$_kGamerdzLiveBase/591591.ts',
  14: '$_kGamerdzLiveBase/787903.ts',
  15: '$_kGamerdzLiveBase/591589.ts',
  16: '$_kGamerdzLiveBase/591587.ts',
  17: '$_kGamerdzLiveBase/787906.ts',
  18: '$_kGamerdzLiveBase/988032.ts',
  19: '$_kGamerdzLiveBase/988033.ts',
  20: '$_kGamerdzLiveBase/988034.ts',
  21: '$_kGamerdzLiveBase/1936353.ts',
  22: '$_kGamerdzLiveBase/1936352.ts',
  23: '$_kGamerdzLiveBase/1936351.ts',
  24: '$_kGamerdzLiveBase/993336.ts',
  25: '$_kGamerdzLiveBase/993337.ts',
  26: '$_kGamerdzLiveBase/591556.ts',
  27: '$_kGamerdzLiveBase/8116.ts',
  34: '$_kGamerdzLiveBase/6586.ts',
  36: '$_kGamerdzLiveBase/6613.ts',
  37: '$_kGamerdzLiveBase/7765.ts',
  41: '$_kGamerdzLiveBase/7746.ts',
};

String repairKnownDeadStreamUrl(String rawUrl, {String streamName = ''}) {
  var u = stripFfmpegPrefix(rawUrl.trim());
  if (u.isEmpty) return u;

  if (u.startsWith('http://x.gamerdz1517.com')) {
    u = u.replaceFirst('http://', 'https://');
  }

  if (u.toLowerCase().contains('so.ta2al.us')) {
    final liveMatch = RegExp(r'/live/[^/]+/[^/]+/(\d+)', caseSensitive: false).firstMatch(u);
    if (liveMatch != null) {
      return '$_kGamerdzLiveBase/${liveMatch.group(1)}.ts';
    }
    final vodMatch = RegExp(r'/(movie|series)/[^/]+/[^/]+/(.+)$', caseSensitive: false).firstMatch(u);
    if (vodMatch != null) {
      return 'https://x.gamerdz1517.com/${vodMatch.group(1)}/00%3A1A%3A79%3A27%3A9F%3AA2/b8cfjif9/${vodMatch.group(2)}';
    }
  }

  final customMatch =
      RegExp(r'/v1/custom/stream/(\d+)\.ts', caseSensitive: false).firstMatch(u);
  if (customMatch != null) {
    final idx = int.tryParse(customMatch.group(1) ?? '');
    if (idx != null && _kCustomStreamIndexReplacements.containsKey(idx)) {
      return _kCustomStreamIndexReplacements[idx]!;
    }
  }

  final lower = u.toLowerCase();
  final nameUpper = streamName.toUpperCase();

  if (lower.contains('82.39.115.19:24652/h1')) return '$_kGamerdzLiveBase/1294764.ts';
  if (lower.contains('82.39.115.19:24652/h2')) return '$_kGamerdzLiveBase/1294763.ts';
  if (lower.contains('82.39.115.19:24652/h3')) return '$_kGamerdzLiveBase/1294762.ts';
  if (lower.contains('82.39.115.19:24652/h4')) return '$_kGamerdzLiveBase/1294761.ts';
  if (lower.contains('82.39.115.19:24652/h5')) {
    if (nameUpper.contains('SPORTS 6')) return '$_kGamerdzLiveBase/1294759.ts';
    return '$_kGamerdzLiveBase/1294760.ts';
  }

  if (lower.contains('live-football-2mf.pages.dev/bein1')) return '$_kGamerdzLiveBase/1330437.ts';
  if (lower.contains('live-football-2mf.pages.dev/bein2')) return '$_kGamerdzLiveBase/1330438.ts';
  if (lower.contains('live-football-2mf.pages.dev/bein3')) return '$_kGamerdzLiveBase/1330439.ts';
  if (lower.contains('live-football-2mf.pages.dev/bein4')) return '$_kGamerdzLiveBase/1294761.ts';
  if (lower.contains('live-football-2mf.pages.dev/bein5')) return '$_kGamerdzLiveBase/1330441.ts';
  if (lower.contains('live-football-2mf.pages.dev/bein6')) return '$_kGamerdzLiveBase/1330442.ts';

  if (lower.contains('livealkass-eu/alkass1')) return '$_kGamerdzLiveBase/591593.ts';
  if (lower.contains('livealkass-eu/alkass2')) return '$_kGamerdzLiveBase/591591.ts';
  if (lower.contains('livealkass-eu/alkass3')) return '$_kGamerdzLiveBase/787903.ts';
  if (lower.contains('livealkass-eu/alkass4')) return '$_kGamerdzLiveBase/591589.ts';
  if (lower.contains('livealkass-eu/alkass5')) return '$_kGamerdzLiveBase/591587.ts';
  if (lower.contains('livealkass-eu/alkass6')) return '$_kGamerdzLiveBase/787906.ts';

  if (lower.contains('index_starz%20play1') || lower.contains('index_starz play1')) {
    return '$_kGamerdzLiveBase/988032.ts';
  }
  if (lower.contains('index_starz%20play2') || lower.contains('index_starz play2')) {
    return '$_kGamerdzLiveBase/988033.ts';
  }
  if (lower.contains('index_starz%20play3') || lower.contains('index_starz play3')) {
    return '$_kGamerdzLiveBase/988034.ts';
  }

  if (lower.contains('marveliptv.life') && lower.contains('474871')) {
    return '$_kGamerdzLiveBase/1936353.ts';
  }
  if (lower.contains('marveliptv.life') && lower.contains('474867')) {
    return '$_kGamerdzLiveBase/1936352.ts';
  }
  if (lower.contains('marveliptv.life') && lower.contains('474863')) {
    return '$_kGamerdzLiveBase/1936351.ts';
  }
  if (lower.contains('marveliptv.life') && lower.contains('261524')) {
    return '$_kGamerdzLiveBase/591556.ts';
  }

  if (lower.contains('index_ad%20sports1') || lower.contains('index_ad sports1')) {
    return '$_kGamerdzLiveBase/993336.ts';
  }
  if (lower.contains('index_ad%20sports2') || lower.contains('index_ad sports2')) {
    return '$_kGamerdzLiveBase/993337.ts';
  }

  if (lower.contains('iraqia-sports-1')) return '$_kGamerdzLiveBase/8116.ts';
  if (lower.contains('fastlyrwb-live.cdn.intigral-ott.net/nhd')) {
    return '$_kGamerdzLiveBase/6586.ts';
  }
  if (lower.contains('live-hls-apps-ajd-fa.getaj.net')) {
    return '$_kGamerdzLiveBase/6613.ts';
  }
  if (lower.contains('ml-pull-dvc-myco.io:2096/discover_pakistan')) {
    return '$_kGamerdzLiveBase/7765.ts';
  }
  if (lower.contains('bitmovin-mbc-2/51db9d7fa48a27d051f1eecb68069151/index.mpd')) {
    return '$_kGamerdzLiveBase/7746.ts';
  }

  return u;
}

/// Resolves a single-hop redirect (if any) without consuming the final media stream.
/// Useful for ExoPlayer when an HTTPS panel redirects (302) to an HTTP storage node.
Future<String> resolveCrossProtocolRedirectForPlayback(
  String rawUrl,
  Map<String, String> headers,
) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..idleTimeout = const Duration(seconds: 15)
    ..autoUncompress = false
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
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

