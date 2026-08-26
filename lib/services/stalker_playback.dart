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

/// Authenticated custom-menu streams are real MPEG-TS media. The query string
/// follows the `.ts` suffix, so a plain endsWith check is insufficient.
bool isWorkerCustomStreamUrl(String url) {
  final normalized = stripFfmpegPrefix(url).toLowerCase();
  return RegExp(r'/v1/custom/stream/[^/?]+\.ts(?:[?#&]|$)')
      .hasMatch(normalized);
}

bool isHlsPlaybackUrl(String url) {
  final lower = _formatSearchText(url);
  return lower.contains('.m3u8') ||
      lower.contains('extension=m3u8') ||
      lower.contains('format=m3u8') ||
      lower.contains('format=hls');
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
      isWorkerStalkerStreamUrl(url) ||
      isWorkerCustomStreamUrl(url);
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
