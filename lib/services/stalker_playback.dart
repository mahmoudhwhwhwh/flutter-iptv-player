String stripFfmpegPrefix(String url) {
  return url.replaceFirst(RegExp(r'^\s*ffmpeg\s+', caseSensitive: false), '').trim();
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

bool isWorkerStalkerStreamUrl(String url) {
  return stripFfmpegPrefix(url).toLowerCase().contains('/v1/stalker/stream');
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
      isWorkerStalkerStreamUrl(url);
}

bool isDirectStalkerPlaybackUrl(String url) {
  final normalized = stripFfmpegPrefix(url);
  final lower = _formatSearchText(normalized);
  return isWorkerStalkerStreamUrl(normalized) ||
      lower.contains('/play/live.php') ||
      isHlsPlaybackUrl(normalized) ||
      isDashPlaybackUrl(normalized) ||
      isProgressiveTsUrl(normalized);
}
