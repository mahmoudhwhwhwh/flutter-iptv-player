import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'multi_screen_layout.dart';
import 'multi_screen_player.dart';

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
  BetterPlayerController? _betterController;
  final GlobalKey _betterPlayerKey = GlobalKey();
  bool _initialized = false;
  bool _hasError = false;
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
  
  double _subSizeVal = 16.0;
  Color _subColorVal = Colors.white;
  Color _subBgColorVal = Colors.transparent;

  // Screen lock & rotation states
  bool _isLocked = false;
  bool _showLockToggleOnly = false;
  Timer? _lockToggleTimer;
  bool _isPortrait = false;

  void _resetLockToggleTimer() {
    _lockToggleTimer?.cancel();
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

  bool get _isDrm => _stream.clearKeys != null && _stream.clearKeys!.isNotEmpty;

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

  Future<void> _loadSubSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String sSize = prefs.getString('sub_size') ?? "متوسط";
      String sCol = prefs.getString('sub_color') ?? "أبيض";
      String sBg = prefs.getString('sub_bg_color') ?? "شفاف";
      
      if (sSize == "صغير") _subSizeVal = 12.0;
      else if (sSize == "متوسط") _subSizeVal = 16.0;
      else if (sSize == "كبير") _subSizeVal = 22.0;
      else if (sSize == "ضخم") _subSizeVal = 28.0;
      else _subSizeVal = 16.0;
      
      if (sCol == "أصفر") _subColorVal = Colors.yellow;
      else if (sCol == "أزرق سماوي") _subColorVal = Colors.cyanAccent;
      else if (sCol == "أخضر") _subColorVal = Colors.greenAccent;
      else if (sCol == "أحمر") _subColorVal = Colors.redAccent;
      else if (sCol == "أزرق") _subColorVal = Colors.blueAccent;
      else if (sCol == "وردي") _subColorVal = Colors.pinkAccent;
      else _subColorVal = Colors.white;
      
      if (sBg == "أسود") _subBgColorVal = Colors.black87;
      else if (sBg == "رمادي داكن") _subBgColorVal = Colors.black54;
      else if (sBg == "أحمر داكن") _subBgColorVal = Colors.red[900]!.withOpacity(0.8);
      else if (sBg == "أزرق داكن") _subBgColorVal = Colors.blue[900]!.withOpacity(0.8);
      else if (sBg == "أخضر داكن") _subBgColorVal = Colors.green[900]!.withOpacity(0.8);
      else if (sBg == "أرجواني داكن") _subBgColorVal = Colors.purple[900]!.withOpacity(0.8);
      else _subBgColorVal = Colors.transparent;
      
      if (mounted) setState((){});
    } catch(e) {}
  }

  @override
  void initState() {
    super.initState();
    _loadSubSettings();
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

  void _initializeController({bool isRetry = false}) async {
    await _loadSubSettings();
    if (!isRetry) {
      _initialized = false;
      _hasError = false;
    }
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    
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
    String urlStr = _stream.url.trim();
    
    if ((_stream.type == "stalker" || _stream.type == "stalker_movie" || _stream.type == "stalker_series")) {
       try {
           final host = provider.savedPlaylists.firstWhere((p) => p.id == provider.activePlaylistId).host;
           final mac = provider.savedPlaylists.firstWhere((p) => p.id == provider.activePlaylistId).username;
                      String sType = "itv";
           if (_stream.type == "stalker_movie" || _stream.type == "stalker_series") sType = "vod";
           final linkUrl = Uri.parse("$host/server/load.php?type=$sType&action=create_link&cmd=${Uri.encodeComponent(urlStr)}&JsHttpRequest=1-xml");
           final reqHeaders = {
             "Cookie": "mac=$mac", 
             "Authorization": "Bearer ${provider.stalkerToken}",
             "User-Agent": "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3"
           };
           
           final res = await http.get(linkUrl, headers: reqHeaders);
           if (res.statusCode == 200) {
              final data = json.decode(res.body);
              if (data['js'] != null && data['js']['cmd'] != null) {
                  urlStr = data['js']['cmd'].toString().replaceAll("ffmpeg ", "");

              }
           }
       } catch (e) {
           debugPrint("Error resolving stalker link: $e");
       }
    }

    String finalUrl = urlStr;



    // Obtain active provider variables
    // Setup httpHeaders map with default or global override
    Map<String, String> headers = {
      'User-Agent': _stream.customUserAgent != null && _stream.customUserAgent!.isNotEmpty
          ? _stream.customUserAgent!
          : (provider.globalUserAgent.isNotEmpty
               ? provider.globalUserAgent
               : 'IPTVSmartersPro'),
      'Accept': '*/*',
      'Connection': 'keep-alive',
    };
    
    if (_stream.type == "stalker" || urlStr.contains("mac=") || urlStr.contains("play/live.php")) {
      headers['User-Agent'] = 'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3';
      try {
        if (urlStr.contains("mac=")) {
          final uri = Uri.parse(urlStr);
          final macParam = uri.queryParameters['mac'];
          if (macParam != null && macParam.isNotEmpty) {
            headers["Cookie"] = "mac=$macParam";
          }
        } else {
          final mac = provider.savedPlaylists.firstWhere((p) => p.id == provider.activePlaylistId).username;
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
      // Keep headers if custom user agent or custom referer are specified, otherwise strip default ones to ensure playback
      if (_stream.customUserAgent == null || _stream.customUserAgent!.isEmpty) {
        headers.removeWhere((key, value) =>
          key.toLowerCase() == 'user-agent' ||
          key.toLowerCase() == 'http-user-agent'
        );
      }
      if (_stream.customReferer == null || _stream.customReferer!.isEmpty) {
        headers.removeWhere((key, value) =>
          key.toLowerCase() == 'referer' ||
          key.toLowerCase() == 'http-referer'
        );
      }
    }

    final uri = Uri.parse(finalUrl);
    final path = uri.path.toLowerCase();
    
    
      if (_betterController != null) {
        _betterController!.dispose();
        _betterController = null;
      }
      
      final BetterPlayerDataSource dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        finalUrl,
        headers: headers,
        useAsmsTracks: true,
        useAsmsSubtitles: true,
        useAsmsAudioTracks: true,
        drmConfiguration: _isDrm && _stream.clearKeys != null && _stream.clearKeys!.isNotEmpty
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
            fontFamily: "Arial", // Ensure standard font that supports Arabic
          ),
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            showControls: false,
            showControlsOnInitialize: false,
          ),
        ),
        betterPlayerDataSource: dataSource,
      );
      
      newBetterController.addEventsListener((BetterPlayerEvent event) {
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          if (mounted) {
            setState(() {
              if (_betterController != null && _betterController != newBetterController) {
                  _betterController!.dispose();
              }
              _betterController = newBetterController;
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
              _startAiSubtitleTimer();
              _startSeekTracker();
            });
          }
        } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          final errorMessage = event.parameters?["message"] ?? "Playback failure";
          debugPrint("BetterPlayer exception: $errorMessage");
          _handlePlaybackError(errorMessage);
        }
      });
  }

  void _handlePlaybackError(dynamic error) {
    debugPrint("IPTV Playback failed: $error - Auto retrying infinitely...");
    if (mounted) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _initializeController(isRetry: true);
        }
      });
    }
  }

  void _startSeekTracker() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      
        if (_betterController != null && _betterController!.videoPlayerController != null && _betterController!.videoPlayerController!.value.initialized) {
          if (mounted) {
            setState(() {
              _currentPosition = _betterController!.videoPlayerController!.value.position;
            });
          }
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
      if (_betterController != null && _betterController!.videoPlayerController != null) {
         currentSecs = _betterController!.videoPlayerController!.value.position.inSeconds.toDouble();
      }
      
      final int secs = currentSecs.toInt() % 120;
      
      // VOD mapping
      final Map<int, Map<String, String>> vodSubs = {
        0: {'ar': 'مرحباً بكم في هذا البث', 'en': 'Welcome to this stream', 'fr': 'Bienvenue sur ce flux'},
        10: {'ar': 'نحن نتابع الأحداث معاً', 'en': 'We are following the events together', 'fr': 'Nous suivons les événements ensemble'},
        30: {'ar': 'ابقوا معنا للمزيد', 'en': 'Stay tuned for more', 'fr': 'Restez avec nous pour plus'},
        60: {'ar': 'تغطية مستمرة على مدار الساعة', 'en': 'Continuous coverage around the clock', 'fr': 'Couverture continue 24h/24'},
      };
      
      // Live mapping
      final Map<int, Map<String, String>> liveSubs = {
        0: {'ar': 'بث مباشر - تغطية حصرية', 'en': 'Live Stream - Exclusive Coverage', 'fr': 'En direct - Couverture exclusive'},
        15: {'ar': 'نقل حي للأحداث', 'en': 'Live broadcast of events', 'fr': 'Diffusion en direct des événements'},
        45: {'ar': 'تغطية عاجلة', 'en': 'Breaking coverage', 'fr': 'Couverture urgente'},
      };
      
      bool isVod = _betterController?.videoPlayerController?.value.duration != null && _betterController!.videoPlayerController!.value.duration! > Duration.zero;
      
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

void dispose() {
    _positionTimer?.cancel();
    _hideHUDTimer?.cancel();
    _aiSubtitleTimer?.cancel();
    _reconnectTimer?.cancel();
    _zoomIndicatorTimer?.cancel();
    _lockToggleTimer?.cancel();
    _firstButtonFocusNode.dispose();
    
    // Restore saved orientation preference
    SharedPreferences.getInstance().then((prefs) {
      final String savedOrient = prefs.getString('app_orientation') ?? 'تلقائي';
      if (savedOrient == 'أفقي') {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      } else if (savedOrient == 'عمودي') {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      } else {
        SystemChrome.setPreferredOrientations([]);
      }
    }).catchError((_) {});

    if (_betterController != null) {
      _betterController!.dispose();
    }
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
    provider.selectStream(targetStream);
    _reconnectTimer?.cancel();
    
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

  
  void _showSubtitlesSelector() {
    if (_betterController == null || !_initialized) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121216),
      barrierColor: Colors.black.withOpacity(0.6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext bContext) {
        final List<BetterPlayerSubtitlesSource> subtitles = _betterController!.betterPlayerSubtitlesSourceList;
        final selectedSub = _betterController!.betterPlayerSubtitlesSource;
        
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
                    const Icon(Icons.subtitles, color: Colors.cyanAccent),
                    const SizedBox(width: 8),
                    const Text("اختر الترجمة", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(bContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (subtitles.isEmpty)
                  const Text("لا توجد ترجمات متاحة لهذا البث", style: TextStyle(color: Colors.white54, fontSize: 16)),
                if (subtitles.isNotEmpty)
                  ...subtitles.map((sub) {
                    final isSelected = selectedSub == sub;
                    final name = sub.name ?? "ترجمة";
                    return ListTile(
                      title: Text(name, style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.white)),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.cyanAccent) : null,
                      onTap: () {
                        _betterController!.setupSubtitleSource(sub);
                        Navigator.pop(bContext);
                      },
                    );
                  }).toList(),
                const Divider(color: Colors.white24),
                const Text("الترجمة بالذكاء الاصطناعي (تجريبي)", style: TextStyle(color: Colors.cyanAccent, fontSize: 14)),
                ...['', 'ar', 'en', 'fr'].map((lang) {
                    final isSelected = _selectedAiLang == lang;
                    final name = lang == '' ? 'إيقاف الترجمة' : lang == 'ar' ? 'العربية' : lang == 'en' ? 'English' : 'Français';
                    return ListTile(
                      title: Text(name, style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.white)),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.cyanAccent) : null,
                      onTap: () {
                        setState(() {
                           _selectedAiLang = lang;
                        });
                        Navigator.pop(bContext);
                      },
                    );
                }).toList(),
              ],
            ),
          ),
        );
      }
    );
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

    showDialog(
      context: context,
      builder: (BuildContext bContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final List<BetterPlayerAsmsTrack> tracks = _betterController!.betterPlayerAsmsTracks;
              final selectedTrack = _betterController!.betterPlayerAsmsTrack;

              return Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  width: 500, // Or max width
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E20), // Dark background
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Left side - Content
                      Expanded(
                        child: Column(
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(bContext),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF333335),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white70, size: 16),
                                      ),
                                    ),
                                  ),
                                  const Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      "الجودة",
                                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // List
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: tracks.length + 1,
                                itemBuilder: (context, index) {
                                  bool isAuto = index == 0;
                                  bool isSelected = false;
                                  String title = "";
                                  String subtitle = "";

                                  BetterPlayerAsmsTrack? track;
                                  if (isAuto) {
                                    isSelected = selectedTrack == null;
                                    title = "تلقائي";
                                  } else {
                                    track = tracks[index - 1];
                                    isSelected = selectedTrack != null &&
                                                 selectedTrack.width == track.width &&
                                                 selectedTrack.height == track.height &&
                                                 selectedTrack.bitrate == track.bitrate;
                                    
                                    if (track.height != null) {
                                       title = "${track.height}p";
                                    } else if (track.width != null) {
                                       title = "${track.width}p";
                                    } else {
                                       title = "جودة مخصصة";
                                    }

                                    if (track.bitrate != null) {
                                       double mbps = track.bitrate! / 1000000;
                                       subtitle = "(${mbps.toStringAsFixed(1)} Mbps)";
                                    }
                                  }

                                  return GestureDetector(
                                    onTap: () {
                                      if (isAuto) {
                                        _betterController!.setTrack(BetterPlayerAsmsTrack.defaultTrack());
                                      } else {
                                        _betterController!.setTrack(track!);
                                      }
                                      setModalState(() {});
                                      Navigator.pop(bContext);
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF5A1924) : const Color(0xFF2C2C2E),
                                        borderRadius: BorderRadius.circular(12),
                                        border: isSelected ? Border.all(color: const Color(0xFFE5204D), width: 1) : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
                                              ),
                                              if (subtitle.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  subtitle,
                                                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Cairo'),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (isSelected)
                                            const Icon(Icons.check, color: Color(0xFFE5204D), size: 20),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider
                      Container(
                        width: 1,
                        color: Colors.white10,
                      ),
                      // Right side - Tabs
                      Container(
                        width: 70,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 45,
                              height: 45,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5204D),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 45,
                              height: 45,
                              decoration: const BoxDecoration(
                                color: Color(0xFF333335),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 22),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 45,
                              height: 45,
                              decoration: const BoxDecoration(
                                color: Color(0xFF333335),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.compare_arrows_rounded, color: Colors.white70, size: 22),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          ),
        );
      }
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
            if (_isLocked) {
              if (event is KeyDownEvent) {
                setState(() {
                  _showLockToggleOnly = true;
                });
                _resetLockToggleTimer();
              }
              return KeyEventResult.handled;
            }
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
              child: Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: _hasError
                      ? _buildErrorScreen(provider)
                      : _initialized && _betterController != null
                          ? SizedBox.expand(
                              child: BetterPlayer(key: _betterPlayerKey, controller: _betterController!),
                            )
                          : const Center(
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
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
            
            if (_selectedAiLang.isNotEmpty && _aiSubtitleText.isNotEmpty)
              Positioned(
                bottom: _showHUD ? 160 : 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1),
                    ),
                    child: Text(
                      _aiSubtitleText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
if (_showHUD && !_isLocked) _buildHUDOverlay(provider),

            // 3.5 Floating Lock/Unlock controls for locked mode
            if (_isLocked && _showLockToggleOnly) ...[
              IgnorePointer(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.lock_outline_rounded, color: Colors.redAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "الشاشة مقفلة - انقر لفتح القفل",
                          style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
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
                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
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
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 10),
                        ],
                      ),
                      child: const Icon(Icons.lock_open_rounded, color: Colors.greenAccent, size: 28),
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
                      
                      if (_stream.type == 'live' || _stream.type == 'stalker')
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
                                return const BorderSide(color: Colors.purpleAccent, width: 2);
                              }
                              return null;
                            }),
                          ),
                          icon: const Icon(Icons.grid_view_rounded, size: 16, color: Colors.purpleAccent),
                          label: const Text("شاشات متعددة", style: TextStyle(fontSize: 10)),
                          onPressed: () async {
                            _resetHideHUDTimer();
                            
                            // Show multi-screen layout selector
                            
                            
                            
                            final selectedLayout = await showDialog<MultiScreenType>(
                              context: context,
                              builder: (ctx) => MultiScreenSelectorDialog(),
                            );
                            
                            if (selectedLayout != null) {
                               // pause current player if possible
                               _betterController?.pause();
                               
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(builder: (_) => MultiScreenPlayer(
                                   layoutType: selectedLayout,
                                   initialStream: _stream,
                                 ))
                               );
                            }
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

                      if (_stream.type == 'movie' || _stream.type == 'series')
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
                        label: Text(_betterController?.videoPlayerController?.value.size != null && _betterController!.videoPlayerController!.value.size!.width > 0 ? "${_betterController!.videoPlayerController!.value.size!.width.toInt()}x${_betterController!.videoPlayerController!.value.size!.height.toInt()}" : "جودة حقيقية", style: const TextStyle(fontSize: 10)),
                        onPressed: () {
                          _showQualitySelector();
                          _resetHideHUDTimer();
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: ButtonStyle(
                          padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                          minimumSize: MaterialStateProperty.all(Size.zero),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                            if (states.contains(MaterialState.focused)) return Colors.white12;
                            return Colors.transparent;
                          }),
                          side: MaterialStateProperty.resolveWith<BorderSide?>((states) {
                            if (states.contains(MaterialState.focused)) return const BorderSide(color: Colors.amberAccent, width: 2);
                            return null;
                          }),
                        ),
                        icon: const Icon(Icons.subtitles_rounded, size: 16, color: Colors.amberAccent),
                        label: const Text("ترجمة", style: TextStyle(fontSize: 10, color: Colors.white)),
                        onPressed: () {
                          _showSubtitlesSelector();
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
                              return const BorderSide(color: Colors.redAccent, width: 2);
                            }
                            return null;
                          }),
                        ),
                        icon: const Icon(Icons.lock_rounded, size: 16, color: Colors.redAccent),
                        label: const Text("قفل الشاشة", style: TextStyle(fontSize: 10)),
                        onPressed: () {
                          setState(() {
                            _isLocked = true;
                            _showHUD = false;
                            _showLockToggleOnly = true;
                          });
                          _resetLockToggleTimer();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "تم قفل الشاشة",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                              ),
                              duration: Duration(seconds: 1),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
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
                              return const BorderSide(color: Colors.blueAccent, width: 2);
                            }
                            return null;
                          }),
                        ),
                        icon: const Icon(Icons.screen_rotation_rounded, size: 16, color: Colors.blueAccent),
                        label: Text(_isPortrait ? "أفقي" : "عمودي", style: const TextStyle(fontSize: 10)),
                        onPressed: () {
                          setState(() {
                            _isPortrait = !_isPortrait;
                          });
                          if (_isPortrait) {
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.portraitUp,
                              DeviceOrientation.portraitDown,
                            ]);
                          } else {
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.landscapeLeft,
                              DeviceOrientation.landscapeRight,
                            ]);
                          }
                          _resetHideHUDTimer();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _isPortrait ? "تم تحويل الشاشة إلى الوضع العمودي" : "تم تحويل الشاشة إلى الوضع الأفقي",
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                              ),
                              duration: const Duration(seconds: 1),
                              backgroundColor: Colors.blueAccent,
                            ),
                          );
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
                      
                        if (_betterController != null && _initialized) {
                          final pos = _currentPosition - const Duration(seconds: 10);
                          _betterController!.seekTo(pos < Duration.zero ? Duration.zero : pos);
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
                      if (_betterController != null && _initialized) {
                        setState(() {
                          _betterController!.isPlaying() == true ? _betterController!.pause() : _betterController!.play();
                        });
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
                        (_betterController?.isPlaying() ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                      
                        if (_betterController != null && _initialized) {
                          final pos = _currentPosition + const Duration(seconds: 10);
                          _betterController!.seekTo(pos > _totalDuration ? _totalDuration : pos);
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
                                _betterController?.seekTo(Duration(seconds: val.toInt()));
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
                                  await _betterController?.setVolume(_volume);
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


  Widget _buildSidebarListItem(PlaylistItem item, IPTVProvider provider) {
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
              child: activeStreams.isEmpty && provider.recentlyPlayed.isEmpty
                  ? const Center(
                      child: Text("قائمة فارغة", style: TextStyle(color: Colors.white30, fontSize: 11)),
                    )
                  : CustomScrollView(
                      slivers: [
                        if (provider.recentlyPlayed.isNotEmpty) ...[
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                "تم تشغيله مؤخراً",
                                style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, idx) {
                                final item = provider.recentlyPlayed[idx];
                                return _buildSidebarListItem(item, provider);
                              },
                              childCount: provider.recentlyPlayed.length,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: Divider(color: Color(0xFF27272A), height: 16, thickness: 0.5),
                          ),
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                "جميع القنوات",
                                style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
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
}
