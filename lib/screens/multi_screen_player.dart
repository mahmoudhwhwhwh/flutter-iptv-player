import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/iptv_provider.dart';
import '../models/playlist_item.dart';
import 'multi_screen_layout.dart';
import 'package:better_player_plus/better_player_plus.dart';

class MultiScreenPlayer extends StatefulWidget {
  final MultiScreenType layoutType;
  final PlaylistItem? initialStream;

  const MultiScreenPlayer({Key? key, required this.layoutType, this.initialStream}) : super(key: key);

  @override
  State<MultiScreenPlayer> createState() => _MultiScreenPlayerState();
}

class _MultiScreenPlayerState extends State<MultiScreenPlayer> {
  late int _screenCount;
  List<PlaylistItem?> _streams = [];

  @override
  void initState() {
    super.initState();
    _screenCount = _getScreenCount(widget.layoutType);
    _streams = List.filled(_screenCount, null);
    if (widget.initialStream != null && _screenCount > 0) {
      _streams[0] = widget.initialStream;
    }
  }

  int _getScreenCount(MultiScreenType type) {
    switch (type) {
      case MultiScreenType.grid2x2: return 4;
      case MultiScreenType.top1Bottom3: return 4;
      case MultiScreenType.top1Bottom2: return 3;
      case MultiScreenType.top2Bottom1: return 3;
      case MultiScreenType.left1Right1: return 2;
      case MultiScreenType.top1Bottom1: return 2;
    }
  }

  void _selectStreamForSlot(int index) async {
    final iptvProvider = Provider.of<IPTVProvider>(context, listen: false);
    
    // Show a dialog to select a live stream
    final selected = await showDialog<PlaylistItem>(
      context: context,
      builder: (ctx) => _StreamSelectionDialog(provider: iptvProvider),
    );

    if (selected != null) {
      setState(() {
        _streams[index] = selected;
      });
    }
  }

  Widget _buildSlot(int index) {
    final stream = _streams[index];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24, width: 2),
        color: Colors.black,
      ),
      child: stream == null
          ? Center(
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 48, color: Colors.white54),
                onPressed: () => _selectStreamForSlot(index),
              ),
            )
          : Stack(
              children: [
                _MultiPlayerSlot(stream: stream),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                    onPressed: () {
                      setState(() {
                        _streams[index] = null;
                      });
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Text(
                    stream.name,
                    style: const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                  ),
                )
              ],
            ),
    );
  }

  Widget _buildLayout() {
    switch (widget.layoutType) {
      case MultiScreenType.grid2x2:
        return Column(
          children: [
            Expanded(child: Row(children: [Expanded(child: _buildSlot(0)), Expanded(child: _buildSlot(1))])),
            Expanded(child: Row(children: [Expanded(child: _buildSlot(2)), Expanded(child: _buildSlot(3))])),
          ],
        );
      case MultiScreenType.top1Bottom3:
        return Column(
          children: [
            Expanded(flex: 2, child: _buildSlot(0)),
            Expanded(flex: 1, child: Row(children: [Expanded(child: _buildSlot(1)), Expanded(child: _buildSlot(2)), Expanded(child: _buildSlot(3))])),
          ],
        );
      case MultiScreenType.top1Bottom2:
        return Column(
          children: [
            Expanded(flex: 2, child: _buildSlot(0)),
            Expanded(flex: 1, child: Row(children: [Expanded(child: _buildSlot(1)), Expanded(child: _buildSlot(2))])),
          ],
        );
      case MultiScreenType.top2Bottom1:
        return Column(
          children: [
            Expanded(flex: 1, child: Row(children: [Expanded(child: _buildSlot(0)), Expanded(child: _buildSlot(1))])),
            Expanded(flex: 2, child: _buildSlot(2)),
          ],
        );
      case MultiScreenType.left1Right1:
        return Row(
          children: [
            Expanded(child: _buildSlot(0)),
            Expanded(child: _buildSlot(1)),
          ],
        );
      case MultiScreenType.top1Bottom1:
        return Column(
          children: [
            Expanded(child: _buildSlot(0)),
            Expanded(child: _buildSlot(1)),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildLayout(),
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamSelectionDialog extends StatefulWidget {
  final IPTVProvider provider;
  const _StreamSelectionDialog({required this.provider});

  @override
  State<_StreamSelectionDialog> createState() => _StreamSelectionDialogState();
}

class _StreamSelectionDialogState extends State<_StreamSelectionDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final liveStreams = widget.provider.allStreams.where((s) => s.type == 'live' || s.type == 'stalker').toList();
    final filtered = liveStreams.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search Channel...",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final s = filtered[i];
                  return ListTile(
                    title: Text(s.name, style: const TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(context, s),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _MultiPlayerSlot extends StatefulWidget {
  final PlaylistItem stream;
  const _MultiPlayerSlot({required this.stream});

  @override
  State<_MultiPlayerSlot> createState() => _MultiPlayerSlotState();
}

class _MultiPlayerSlotState extends State<_MultiPlayerSlot> {
  BetterPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant _MultiPlayerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream.url != widget.stream.url) {
      _initPlayer();
    }
  }

  void _initPlayer() async {
    _controller?.dispose();
    
    double subSizeVal = 16.0;
    Color subColorVal = Colors.white;
    Color subBgColorVal = Colors.transparent;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      String sSize = prefs.getString('sub_size') ?? "متوسط";
      String sCol = prefs.getString('sub_color') ?? "أبيض";
      String sBg = prefs.getString('sub_bg_color') ?? "شفاف";
      
      if (sSize == "صغير") subSizeVal = 12.0;
      else if (sSize == "متوسط") subSizeVal = 16.0;
      else if (sSize == "كبير") subSizeVal = 22.0;
      else if (sSize == "ضخم") subSizeVal = 28.0;
      else subSizeVal = 16.0;
      
      if (sCol == "أصفر") subColorVal = Colors.yellow;
      else if (sCol == "أزرق سماوي") subColorVal = Colors.cyanAccent;
      else if (sCol == "أخضر") subColorVal = Colors.greenAccent;
      else if (sCol == "أحمر") subColorVal = Colors.redAccent;
      else if (sCol == "أزرق") subColorVal = Colors.blueAccent;
      else if (sCol == "وردي") subColorVal = Colors.pinkAccent;
      else subColorVal = Colors.white;
      
      if (sBg == "أسود") subBgColorVal = Colors.black87;
      else if (sBg == "رمادي داكن") subBgColorVal = Colors.black54;
      else if (sBg == "أحمر داكن") subBgColorVal = Colors.red[900]!.withOpacity(0.8);
      else if (sBg == "أزرق داكن") subBgColorVal = Colors.blue[900]!.withOpacity(0.8);
      else if (sBg == "أخضر داكن") subBgColorVal = Colors.green[900]!.withOpacity(0.8);
      else if (sBg == "أرجواني داكن") subBgColorVal = Colors.purple[900]!.withOpacity(0.8);
      else subBgColorVal = Colors.transparent;
    } catch (e) {
      debugPrint("Error loading subtitle settings in multi-player: $e");
    }

    BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: false,
      subtitlesConfiguration: BetterPlayerSubtitlesConfiguration(
        fontSize: subSizeVal,
        fontColor: subColorVal,
        backgroundColor: subBgColorVal,
        outlineColor: Colors.black,
        outlineSize: 2.0,
        fontFamily: "Arial",
      ),
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        showControls: false,
      ),
    );

    String finalUrl = widget.stream.url;
    
    if (widget.stream.type == "stalker" || widget.stream.type == "stalker_movie" || widget.stream.type == "stalker_series") {
        try {
            final provider = Provider.of<IPTVProvider>(context, listen: false);
            final host = provider.savedPlaylists.firstWhere((p) => p.id == provider.activePlaylistId).host;
            final mac = provider.savedPlaylists.firstWhere((p) => p.id == provider.activePlaylistId).username;
            
            String sType = "itv";
            if (widget.stream.type == "stalker_movie" || widget.stream.type == "stalker_series") sType = "vod";
            final linkUrl = Uri.parse("$host/server/load.php?type=$sType&action=create_link&cmd=${Uri.encodeComponent(finalUrl)}&JsHttpRequest=1-xml");
            final reqHeaders = {
              "Cookie": "mac=$mac", 
              "Authorization": "Bearer ${provider.stalkerToken}",
              "User-Agent": "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3"
            };
            
            final res = await http.get(linkUrl, headers: reqHeaders);
            if (res.statusCode == 200) {
               final data = json.decode(res.body);
               if (data['js'] != null && data['js']['cmd'] != null) {
                   finalUrl = data['js']['cmd'].toString().replaceAll("ffmpeg ", "");
               }
            }
        } catch (e) {
            print("Error resolving stalker link: $e");
        }
    }

    final iptvProvider = Provider.of<IPTVProvider>(context, listen: false);
    Map<String, String> headers = {
      'User-Agent': widget.stream.customUserAgent != null && widget.stream.customUserAgent!.isNotEmpty
          ? widget.stream.customUserAgent!
          : (iptvProvider.globalUserAgent.isNotEmpty
               ? iptvProvider.globalUserAgent
               : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'),
    };
    
    final customRef = widget.stream.customReferer ?? iptvProvider.globalReferer;
    if (customRef.isNotEmpty) {
      headers['Referer'] = customRef;
    }

    if (widget.stream.type == "stalker" || finalUrl.contains("mac=") || finalUrl.contains("play/live.php")) {
      headers['User-Agent'] = 'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3';
      try {
        if (finalUrl.contains("mac=")) {
          final uri = Uri.parse(finalUrl);
          final macParam = uri.queryParameters['mac'];
          if (macParam != null && macParam.isNotEmpty) {
            headers["Cookie"] = "mac=$macParam";
          }
        } else {
          final mac = iptvProvider.savedPlaylists.firstWhere((p) => p.id == iptvProvider.activePlaylistId).username;
          headers["Cookie"] = "mac=$mac";
        }
      } catch (e) {}
    }

    final bool isMpdStream = finalUrl.toLowerCase().contains('.mpd');
    if (isMpdStream) {
      if (widget.stream.customUserAgent == null || widget.stream.customUserAgent!.isEmpty) {
        headers.removeWhere((key, value) =>
          key.toLowerCase() == 'user-agent' ||
          key.toLowerCase() == 'http-user-agent'
        );
      }
      if (widget.stream.customReferer == null || widget.stream.customReferer!.isEmpty) {
        headers.removeWhere((key, value) =>
          key.toLowerCase() == 'referer' ||
          key.toLowerCase() == 'http-referer'
        );
      }
    }

    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      finalUrl,
      headers: headers,
      useAsmsTracks: true,
      useAsmsSubtitles: true,
      useAsmsAudioTracks: true,
      drmConfiguration: widget.stream.clearKeys != null && widget.stream.clearKeys!.isNotEmpty
          ? BetterPlayerDrmConfiguration(
              drmType: BetterPlayerDrmType.clearKey,
              clearKey: _prepareClearKeyString(widget.stream.clearKeys!),
            )
          : null,
    );

    _controller = BetterPlayerController(betterPlayerConfiguration);
    _controller!.setupDataSource(dataSource);
    
    if (mounted) {
      setState(() {});
    }
  }

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
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return const Center(child: CircularProgressIndicator());
    return BetterPlayer(controller: _controller!);
  }
}
