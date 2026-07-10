import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_iptv_player/main.dart';
import 'package:flutter_iptv_player/models/playlist_item.dart';
import 'package:flutter_iptv_player/providers/iptv_provider.dart';

class PlayerScreen extends StatefulWidget {
  final PlaylistItem stream;
  const PlayerScreen({super.key, required this.stream});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  BetterPlayerController? _betterController;
  final GlobalKey _betterPlayerKey = GlobalKey();
  bool _initialized = false;
  bool _hasError = false;
  late PlaylistItem _stream;
  bool _showHUD = true;
  Timer? _hideHUDTimer;
  BoxFit _currentBoxFit = BoxFit.contain;
  String _aspectRatioLabel = "تلقائي";
  bool _showSidebar = false;
  
  String? _zoomIndicatorText;
  Timer? _zoomIndicatorTimer;
  
  // Brightness simulation overlay (0.0 means normal/bright, 0.8 means dim)
  double _brightnessFactor = 0.0;
  double _volume = 1.0;
  
  // Focus node for TV remote controls and virtual bitrate cap for DASH streams
  final FocusNode _firstButtonFocusNode = FocusNode();
  int? _selectedVirtualBitrate;
  
  // Position tracker
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _positionTimer;

  // Auto-retry state variables key to stable IPTV stream links
  int _retryCount = 0;
  final int _maxRetries = 3;
  Timer? _reconnectTimer;

  bool get _isDrm => true;

  String _prepareClearKeyString(Map<String, String> keys) {
    try {
      final List<Map<String, dynamic>> jwkList = [];
      keys.forEach((hexKid, hexKey) {
        try {
          final cleanKid = hexKid.trim().replaceAll(RegExp(r'[^a-fA-F0-9]'), '');
          final cleanKey = hexKey.trim().replaceAll(RegExp(r'[^a-fA-F0-9]'), '');
          
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

  @override
  void initState() {
    super.initState();
    _stream = widget.stream;
    
    // Auto-scale and configure device for horizontal immersive screen view
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _initializeController();
    _resetHideHUDTimer();
  }

  void _initializeController() {
    _initialized = false;
    _hasError = false;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    
    // Log play_channel event to Firebase Analytics
    try {
      appAnalytics?.logEvent(
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
    
    final urlStr = _stream.url.trim();
    String finalUrl = urlStr;

    // Advanced dynamic fallbacks for multi-device compatibility (Smartphones & TV boxes)
    if (_retryCount > 0) {
      if (finalUrl.contains('.ts')) {
        // Fall back from MPEG-TS (.ts) to HLS (.m3u8) which is 100% compatible natively
        finalUrl = finalUrl.replaceAll('.ts', '.m3u8');
        debugPrint("Playback Fallback (Retry $_retryCount): Remapping TS stream to HLS .m3u8 format.");
      } else if (finalUrl.contains('.m3u8')) {
        // Some newer Xtream servers/proxies stream natively without an extension
        finalUrl = finalUrl.replaceAll('.m3u8', '');
        debugPrint("Playback Fallback (Retry $_retryCount): Removing HLS extension query.");
      } else {
        // Fallback: try appending .ts
        finalUrl = '$finalUrl.ts';
        debugPrint("Playback Fallback (Retry $_retryCount): Appending TS format.");
      }
    }
    
    // Obtain active provider variables
    final provider = Provider.of<IPTVProvider>(context, listen: false);
    
    // Setup httpHeaders map with default or global override
    Map<String, String> headers = {
      'User-Agent': _stream.customUserAgent != null && _stream.customUserAgent!.isNotEmpty
          ? _stream.customUserAgent!
          : (provider.globalUserAgent.isNotEmpty
               ? provider.globalUserAgent
               : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'),
      'Accept': '*/*',
      'Connection': 'keep-alive',
    };
    
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
            if (key.toLowerCase() == 'user-agent' || key.toLowerCase() == 'http-user-agent') {
              headers['User-Agent'] = value;
            } else if (key.toLowerCase() == 'referer' || key.toLowerCase() == 'http-referer') {
              headers['Referer'] = value;
            } else {
              headers[key] = value;
            }
          }
        }
      }
    }

    // Handle MPD/DASH streams: clean up Referer and User-Agent headers to guarantee 100% video playback compatibility
    final bool isMpdStream = finalUrl.toLowerCase().contains('.mpd') || urlStr.toLowerCase().contains('.mpd');
    if (isMpdStream) {
      headers.removeWhere((key, value) =>
        key.toLowerCase() == 'user-agent' ||
        key.toLowerCase() == 'referer' ||
        key.toLowerCase() == 'http-user-agent' ||
        key.toLowerCase() == 'http-referer'
      );
    }

    final uri = Uri.parse(finalUrl);
    final path = uri.path.toLowerCase();
    
    VideoFormat? detectedFormat;
    final urlLower = finalUrl.toLowerCase();
    if (urlLower.contains('m3u8') || urlLower.contains('/hls/') || urlLower.contains('hls-live') || urlLower.contains('/hls-') || urlLower.contains('.m3u8') || urlLower.contains('master') || urlLower.contains('playlist')) {
      detectedFormat = VideoFormat.hls;
    } else if (urlLower.contains('mpd') || urlLower.contains('.mpd')) {
      detectedFormat = VideoFormat.dash;
    } else if (urlLower.contains('ism') || urlLower.contains('/manifest') || urlLower.contains('ss')) {
      detectedFormat = VideoFormat.ss;
    } else {
      if (!urlLower.contains('.ts') && !urlLower.contains('.mp4') && !urlLower.contains('.mkv')) {
        detectedFormat = VideoFormat.hls;
      }
    }

    if (_isDrm) {
      if (_controller != null) {
        _controller!.removeListener(_videoListener);
        _controller!.dispose();
        _controller = null;
      }
      if (_betterController != null) {
        _betterController!.dispose();
        _betterController = null;
      }

      BetterPlayerVideoFormat bpFormat = BetterPlayerVideoFormat.other;
      if (detectedFormat == VideoFormat.hls) {
        bpFormat = BetterPlayerVideoFormat.hls;
      } else if (detectedFormat == VideoFormat.dash) {
        bpFormat = BetterPlayerVideoFormat.dash;
      } else if (detectedFormat == VideoFormat.ss) {
        bpFormat = BetterPlayerVideoFormat.ss;
      }

      final BetterPlayerDataSource dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        finalUrl,
        headers: headers,
        videoFormat: bpFormat,
        useAsmsTracks: true,
        useAsmsSubtitles: true,
        useAsmsAudioTracks: true,
        drmConfiguration: _stream.clearKeys != null && _stream.clearKeys!.isNotEmpty
            ? BetterPlayerDrmConfiguration(
                drmType: BetterPlayerDrmType.clearKey,
                clearKey: _prepareClearKeyString(_stream.clearKeys!),
              )
            : null,
      );

      _betterController = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: true,
          looping: false,
          fit: _currentBoxFit,
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            showControls: false,
            showControlsOnInitialize: false,
          ),
        ),
        betterPlayerDataSource: dataSource,
      );

      _betterController!.addEventsListener((BetterPlayerEvent event) {
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          if (mounted) {
            setState(() {
              _initialized = true;
              _retryCount = 0;
              if (_betterController!.videoPlayerController != null) {
                _totalDuration = _betterController!.videoPlayerController!.value.duration ?? Duration.zero;
              }
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
              _betterController!.play();
              _startSeekTracker();
            });
          }
        } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          final errorMessage = event.parameters?["message"] ?? "DRM Playback failure";
          debugPrint("BetterPlayer exception: $errorMessage");
          _handlePlaybackError(errorMessage);
        }
      });
    } else {
      if (_betterController != null) {
        _betterController!.dispose();
        _betterController = null;
      }
      if (_controller != null) {
        _controller!.removeListener(_videoListener);
        _controller!.dispose();
        _controller = null;
      }

      _controller = VideoPlayerController.networkUrl(
        uri,
        formatHint: detectedFormat,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: headers,
      );

      _controller!.initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
            _retryCount = 0; // reset retry level on successful launch
            _totalDuration = _controller!.value.duration;
            _controller?.play();
            _startSeekTracker();
          });
          _controller!.addListener(_videoListener);
        }
      }).catchError((error) {
        _handlePlaybackError(error);
      });
    }
  }

  void _handlePlaybackError(dynamic error) {
    debugPrint("IPTV Playback attempt $_retryCount failed: $error");
    if (mounted) {
      if (_retryCount < _maxRetries) {
        _retryCount++;
        setState(() {
          _initialized = false;
        });
        _reconnectTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            _initializeController();
          }
        });
      } else {
        setState(() {
          _hasError = true;
          _initialized = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null) return;
    
    if (_controller!.value.hasError) {
      final errorMessage = _controller!.value.errorDescription;
      debugPrint("VideoPlayer runtime error: $errorMessage");
      
      _controller!.removeListener(_videoListener);
      _handlePlaybackError(errorMessage);
    }
  }

  void _startSeekTracker() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isDrm) {
        if (_betterController != null && _betterController!.videoPlayerController != null && _betterController!.videoPlayerController!.value.initialized) {
          if (mounted) {
            setState(() {
              _currentPosition = _betterController!.videoPlayerController!.value.position;
            });
          }
        }
      } else {
        if (_controller != null && _controller!.value.isInitialized && _controller!.value.isPlaying) {
          if (mounted) {
            setState(() {
              _currentPosition = _controller!.value.position;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _hideHUDTimer?.cancel();
    _reconnectTimer?.cancel();
    _zoomIndicatorTimer?.cancel();
    _firstButtonFocusNode.dispose();
    
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
    }
    if (_betterController != null) {
      _betterController!.dispose();
    }
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
    provider.selectStream(targetStream);
    _reconnectTimer?.cancel();
    
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
      _controller = null;
    }
    if (_betterController != null) {
      _betterController!.dispose();
      _betterController = null;
    }
    
    setState(() {
      _stream = targetStream;
      _initialized = false;
      _hasError = false;
      _selectedVirtualBitrate = null; // Reset virtual quality ceiling
      _retryCount = 0; // reset counter on manual switch
    });
    _initializeController();
  }

  void _zapNextPrev(IPTVProvider provider, bool next) {
    provider.zapChannel(next);
    final nextStream = provider.currentStream;
    if (nextStream != null && nextStream.streamId != _stream.streamId) {
      _zapStream(provider, nextStream);
    }
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
      
      _zoomIndicatorText = _aspectRatioLabel;
      _zoomIndicatorTimer?.cancel();
      _zoomIndicatorTimer = Timer(const Duration(seconds: 2), () {
        setState(() {
          _zoomIndicatorText = null;
        });
      });
      
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
        });
        await _betterController!.enablePictureInPicture(_betterPlayerKey);
      } catch (e) {
        debugPrint("Failed to enable picture in picture: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("جهازك لا يدعم خاصية صورة داخل صورة حالياً", textDirection: TextDirection.rtl),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("انتظر حتى يتم تحميل البث لتشغيل صورة داخل صورة", textDirection: TextDirection.rtl),
          backgroundColor: Colors.amberAccent,
        ),
      );
    }
  }

  void _showQualitySelector() {
    if (_betterController == null || !_initialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("يرجى الانتظار لحين بدء تشغيل القناة أولاً", textDirection: TextDirection.rtl),
          backgroundColor: Colors.amberAccent,
        ),
      );
      return;
    }

    final List<BetterPlayerAsmsTrack> tracks = _betterController!.betterPlayerAsmsTracks;

    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("البث الحالي لا يحتوي على جودات متعددة", textDirection: TextDirection.rtl),
          backgroundColor: Colors.amberAccent,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121216),
      barrierColor: Colors.black.withOpacity(0.6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext bContext) {
        final selectedTrack = _betterController!.betterPlayerAsmsTrack;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.high_quality_rounded, color: Color(0xFFFFB300), size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      "اختر جودة البث المطلوبة ⚡",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      String displayName = "";
                      final bitrateValue = track.bitrate;
                      
                      if (track.width == null || track.height == null) {
                        if (track.bitrate != null) {
                          if (track.bitrate! >= 5000000) {
                            displayName = "جودة فائقة (FHD - ${track.bitrate! ~/ 1000} Kbps)";
                          } else if (track.bitrate! >= 2500000) {
                            displayName = "جودة عالية (HD - ${track.bitrate! ~/ 1000} Kbps)";
                          } else if (track.bitrate! >= 1000000) {
                            displayName = "جودة متوسطة (SD - ${track.bitrate! ~/ 1000} Kbps)";
                          } else {
                            displayName = "جودة منخفضة (${track.bitrate! ~/ 1000} Kbps)";
                          }
                        } else {
                          displayName = "تلقائي (تعديل ذكي)";
                        }
                      } else {
                        displayName = "${track.width}x${track.height}p";
                        if (track.height != null) {
                          if (track.height! >= 1080) {
                            displayName += " (FHD)";
                          } else if (track.height! >= 720) {
                            displayName += " (HD)";
                          } else {
                            displayName += " (SD)";
                          }
                        }
                      }

                      final isSelected = selectedTrack != null &&
                          selectedTrack.width == track.width &&
                          selectedTrack.height == track.height &&
                          selectedTrack.bitrate == track.bitrate;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0x22FFB300) : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFFB300) : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            displayName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          leading: Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? const Color(0xFFFFB300) : Colors.white24,
                          ),
                          trailing: bitrateValue != null
                              ? Text(
                                  "${(bitrateValue / 1000).round()} Kbps",
                                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                                )
                              : null,
                          onTap: () {
                            _betterController!.setTrack(tracks[index]);
                            Navigator.pop(bContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("تم تحويل البث إلى: $displayName", textDirection: TextDirection.rtl),
                                backgroundColor: const Color(0xFFFFB300),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: WillPopScope(
        onWillPop: () async {
          return true;
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (FocusNode node, KeyEvent event) {
            _resetHideHUDTimer();
            if (event is KeyDownEvent) {
              if (!_showHUD) {
                // Direct TV Remote shortcuts when HUD is hidden
                if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                    event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _cycleBoxFit();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _zapNextPrev(provider, false);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _zapNextPrev(provider, true);
                  return KeyEventResult.handled;
                }
                
                setState(() {
                  _showHUD = true;
                });
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (_firstButtonFocusNode.canRequestFocus) {
                    _firstButtonFocusNode.requestFocus();
                  }
                });
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
            // 1. Core Video Frame Container
            GestureDetector(
              onTap: _toggleHUD,
              child: Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: _hasError
                      ? _buildErrorScreen(provider)
                      : _initialized && (_controller != null || _betterController != null)
                          ? SizedBox.expand(
                              child: _isDrm
                                  ? BetterPlayer(key: _betterPlayerKey, controller: _betterController!)
                                  : FittedBox(
                                      fit: _currentBoxFit,
                                      child: SizedBox(
                                        width: (((_controller?.value.size?.width) ?? 0) > 0 ? _controller!.value.size!.width : 1280),
                                        height: (((_controller?.value.size?.height) ?? 0) > 0 ? _controller!.value.size!.height : 720),
                                        child: VideoPlayer(_controller!),
                                      ),
                                    ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 3),
                                SizedBox(height: 12),
                                Text(
                                  "جاري شحن البث والاتصال بالخادم...",
                                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                ),
              ),
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
                  // Top-Right Logo: "live stream pro" Purple Capsule Broadcast Logo positioned to cover/hide default channel watermarks (like beIN Sports)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 15, right: 25),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF3B1D6D), // Deep Purple
                              Color(0xFF6B3FA0), // Soft Violet/Indigo
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white24, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          "live stream pro",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Bottom-Left Logo: "live stream pro" translucent glass capsule (without 'الرئيسي')
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 25, left: 30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B1D6D).withOpacity(0.55),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24, width: 0.6),
                        ),
                        child: const Text(
                          "live stream pro",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2.6 Dynamic Zoom/Aspect Ratio On-Screen Indicator Toast
            if (_zoomIndicatorText != null)
              IgnorePointer(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amberAccent.withOpacity(0.5), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.aspect_ratio_rounded, color: Colors.amberAccent, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          "أبعاد الشاشة: $_zoomIndicatorText",
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
            if (_showHUD) _buildHUDOverlay(provider),

            // 4. Quick Side Drawer Category Channel List
            if (_showSidebar) _buildQuickSidebar(provider),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(IPTVProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      color: const Color(0xFF0C0C0E),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent, size: 55),
          const SizedBox(height: 12),
          const Text(
            "عذراً، فشل تشغيل البث المباشر للقناة.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              "التفسير المحتمل: يعود فشل التشغيل غالباً إلى تجاوز الحد الأقصى للمشاهدين على نفس الحساب (Max Connections: 1). إذا كان الحساب مشغلاً على جهاز آخر أو معلقاً بالخادم، يرجى إغلاق التطبيقات الأخرى والمحاولة مرة أخرى بعد دقيقتين.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orangeAccent, fontSize: 11, height: 1.5, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "الرابط: [ روابط البث مشفرة ومحمية لحماية الخادم من السرقة ]",
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("إعادة المحاولة / RETRY"),
                onPressed: () {
                  setState(() {
                    _initializeController();
                  });
                },
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text("الخروج"),
                onPressed: () => Navigator.pop(context),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHUDOverlay(IPTVProvider provider) {
    final bool isLive = _totalDuration.inSeconds == 0 || _stream.type == 'live';

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.transparent,
              Colors.black.withOpacity(0.9),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            // TOP HUD BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    focusNode: _firstButtonFocusNode,
                    focusColor: Colors.white24,
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  // Stream Meta Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _stream.name,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isLive ? Colors.redAccent.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isLive ? "LIVE" : "VOD",
                                style: TextStyle(
                                  color: isLive ? Colors.redAccent : Colors.blueAccent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _stream.categoryName,
                                style: const TextStyle(color: Colors.white60, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // TOP ACTION BUTTONS
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        focusColor: Colors.redAccent.withOpacity(0.3),
                        icon: Icon(
                          provider.favorites.contains(_stream.streamId) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: provider.favorites.contains(_stream.streamId) ? Colors.redAccent : Colors.white,
                        ),
                        onPressed: () {
                          provider.toggleFavorite(_stream.streamId);
                          _resetHideHUDTimer();
                        },
                      ),
                      
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white10,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Colors.white12),
                          ),
                        ).copyWith(
                          side: MaterialStateProperty.resolveWith<BorderSide?>((states) {
                            if (states.contains(MaterialState.focused)) {
                              return const BorderSide(color: Colors.amberAccent, width: 2);
                            }
                            return null;
                          }),
                        ),
                        icon: const Icon(Icons.aspect_ratio_rounded, size: 16, color: Colors.amberAccent),
                        label: Text(_aspectRatioLabel, style: const TextStyle(fontSize: 10)),
                        onPressed: () {
                          _cycleBoxFit();
                          _resetHideHUDTimer();
                        },
                      ),

                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white10,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Colors.white12),
                          ),
                        ).copyWith(
                          side: MaterialStateProperty.resolveWith<BorderSide?>((states) {
                            if (states.contains(MaterialState.focused)) {
                              return const BorderSide(color: Colors.cyanAccent, width: 2);
                            }
                            return null;
                          }),
                        ),
                        icon: const Icon(Icons.high_quality_rounded, size: 16, color: Colors.cyanAccent),
                        label: const Text("الجودة", style: TextStyle(fontSize: 10)),
                        onPressed: () {
                          _showQualitySelector();
                          _resetHideHUDTimer();
                        },
                      ),

                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white10,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Colors.white12),
                          ),
                        ).copyWith(
                          side: MaterialStateProperty.resolveWith<BorderSide?>((states) {
                            if (states.contains(MaterialState.focused)) {
                              return const BorderSide(color: Colors.tealAccent, width: 2);
                            }
                            return null;
                          }),
                        ),
                        icon: const Icon(Icons.picture_in_picture_alt_rounded, size: 16, color: Colors.tealAccent),
                        label: const Text("صور داخل صور", style: TextStyle(fontSize: 10)),
                        onPressed: () {
                          _togglePictureInPicture();
                          _resetHideHUDTimer();
                        },
                      ),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ).copyWith(
                          side: MaterialStateProperty.resolveWith<BorderSide?>((states) {
                            if (states.contains(MaterialState.focused)) {
                              return const BorderSide(color: Colors.white, width: 2);
                            }
                            return null;
                          }),
                        ),
                        icon: const Icon(Icons.list_alt_rounded, size: 16),
                        label: const Text("قائمة القنوات", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
            ),

            const Spacer(),

            // CENTER HUD OVERLAY CONTROLS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHUDCircleBtn(
                  icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
                  onTap: () {
                    _zapNextPrev(provider, false);
                    _resetHideHUDTimer();
                  },
                ),
                const SizedBox(width: 24),

                if (!isLive)
                  _buildHUDCircleBtn(
                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 24),
                    onTap: () {
                      if (_isDrm) {
                        if (_betterController != null && _initialized) {
                          final pos = _currentPosition - const Duration(seconds: 10);
                          _betterController!.seekTo(pos < Duration.zero ? Duration.zero : pos);
                        }
                      } else {
                        if (_controller != null && _initialized) {
                          final pos = _currentPosition - const Duration(seconds: 10);
                          _controller!.seekTo(pos < Duration.zero ? Duration.zero : pos);
                        }
                      }
                      _resetHideHUDTimer();
                    },
                  ),
                if (!isLive) const SizedBox(width: 24),

                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    focusColor: Colors.lightBlueAccent.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(50),
                    onTap: () {
                      if (_isDrm) {
                        if (_betterController != null && _initialized) {
                          setState(() {
                            _betterController!.isPlaying() == true ? _betterController!.pause() : _betterController!.play();
                          });
                        }
                      } else {
                        if (_controller != null && _initialized) {
                          setState(() {
                            _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                          });
                        }
                      }
                      _resetHideHUDTimer();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Icon(
                        _isDrm
                            ? (_betterController?.isPlaying() ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded
                            : (_controller?.value.isPlaying ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                if (!isLive)
                  _buildHUDCircleBtn(
                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 24),
                    onTap: () {
                      if (_isDrm) {
                        if (_betterController != null && _initialized) {
                          final pos = _currentPosition + const Duration(seconds: 10);
                          _betterController!.seekTo(pos > _totalDuration ? _totalDuration : pos);
                        }
                      } else {
                        if (_controller != null && _initialized) {
                          final pos = _currentPosition + const Duration(seconds: 10);
                          _controller!.seekTo(pos > _totalDuration ? _totalDuration : pos);
                        }
                      }
                      _resetHideHUDTimer();
                    },
                  ),
                if (!isLive) const SizedBox(width: 24),

                _buildHUDCircleBtn(
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                  onTap: () {
                    _zapNextPrev(provider, true);
                    _resetHideHUDTimer();
                  },
                ),
              ],
            ),

            const Spacer(),

            // BOTTOM CONTROL BAR
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 4),
              child: Column(
                children: [
                   if (!isLive && _initialized) ...[
                    Row(
                      children: [
                        Text(
                          _formatDuration(_currentPosition),
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.blueAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.amberAccent,
                              trackHeight: 3.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                            ),
                            child: Slider(
                              min: 0.0,
                              max: _totalDuration.inSeconds.toDouble() > 0 ? _totalDuration.inSeconds.toDouble() : 1.0,
                              value: _currentPosition.inSeconds.toDouble().clamp(0.0, _totalDuration.inSeconds.toDouble() > 0 ? _totalDuration.inSeconds.toDouble() : 1.0),
                              onChanged: (val) {
                                _resetHideHUDTimer();
                                if (_isDrm) {
                                  _betterController?.seekTo(Duration(seconds: val.toInt()));
                                } else {
                                  _controller?.seekTo(Duration(seconds: val.toInt()));
                                }
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_totalDuration),
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "بث حي ومباشر / LIVE STREAM BROADCAST",
                          style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _brightnessFactor > 0.6
                                ? Icons.brightness_low_rounded
                                : _brightnessFactor > 0.2
                                    ? Icons.brightness_medium_rounded
                                    : Icons.brightness_high_rounded,
                            color: Colors.amberAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            height: 24,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.yellow,
                                inactiveTrackColor: Colors.white10,
                                trackHeight: 2.0,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.0),
                              ),
                              child: Slider(
                                value: 1.0 - _brightnessFactor,
                                min: 0.2, // minimum brightness simulation limit
                                max: 1.0,
                                onChanged: (val) {
                                  setState(() {
                                    _brightnessFactor = 1.0 - val;
                                  });
                                  _resetHideHUDTimer();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text("السطوع", style: TextStyle(color: Colors.white54, fontSize: 9)),
                        ],
                      ),

                      Row(
                        children: [
                          const Text("الصوت", style: TextStyle(color: Colors.white54, fontSize: 9)),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 100,
                            height: 24,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.blueAccent,
                                inactiveTrackColor: Colors.white10,
                                trackHeight: 2.0,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.0),
                              ),
                              child: Slider(
                                value: _volume,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (val) async {
                                  setState(() {
                                    _volume = val;
                                  });
                                  if (_isDrm) {
                                    await _betterController?.setVolume(_volume);
                                  } else {
                                    await _controller?.setVolume(_volume);
                                  }
                                  _resetHideHUDTimer();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _volume == 0.0
                                ? Icons.volume_mute_rounded
                                : _volume < 0.5
                                    ? Icons.volume_down_rounded
                                    : Icons.volume_up_rounded,
                            color: Colors.blueAccent,
                            size: 16,
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
    );
  }

  Widget _buildHUDCircleBtn({required Widget icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        focusColor: Colors.blueAccent.withOpacity(0.3),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white12,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10, width: 0.5),
          ),
          child: icon,
        ),
      ),
    );
  }

  Widget _buildQuickSidebar(IPTVProvider provider) {
    final activeStreams = provider.streams;

    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F12).withOpacity(0.95),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 15, spreadRadius: 2),
          ],
          border: const Border(left: BorderSide(color: Color(0xFF27272A), width: 1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF27272A), width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "قائمة القنوات Dashboard",
                    style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    onPressed: () {
                      setState(() {
                        _showSidebar = false;
                      });
                    },
                  )
                ],
              ),
            ),
            Expanded(
              child: activeStreams.isEmpty
                  ? const Center(
                      child: Text("قائمة فارغة", style: TextStyle(color: Colors.white30, fontSize: 11)),
                    )
                  : ListView.builder(
                      itemCount: activeStreams.length,
                      itemBuilder: (context, idx) {
                        final item = activeStreams[idx];
                        final isSelected = item.streamId == _stream.streamId;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blueAccent.withOpacity(0.15) : Colors.transparent,
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
                                      child: Image.network(
                                        item.streamIcon,
                                        fit: BoxFit.cover,
                                        cacheWidth: 60,
                                        cacheHeight: 60,
                                        errorBuilder: (c, e, s) => const Icon(Icons.tv_rounded, size: 12, color: Colors.white30),
                                      ),
                                    )
                                  : const Icon(Icons.tv_rounded, size: 12, color: Colors.white30),
                            ),
                            onTap: () {
                              _zapStream(provider, item);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
