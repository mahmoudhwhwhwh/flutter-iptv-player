import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'providers/iptv_provider.dart';
import 'screens/settings_screen.dart';
import 'screens/player_screen.dart';
import 'models/playlist_item.dart';
import 'package:url_launcher/url_launcher.dart';

FirebaseAnalytics? appAnalytics;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  try {
    await Firebase.initializeApp();
    appAnalytics = FirebaseAnalytics.instance;
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IPTVProvider()..init()),
      ],
      child: const LiveFootballApp(),
    ),
  );
}

class LiveFootballApp extends StatelessWidget {
  const LiveFootballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<IPTVProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'live stream pro',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF141414), // Netflix Background Color
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE50914), // Netflix Red
              secondary: Color(0xFFE50914),
              surface: Color(0xFF181818),
              background: Color(0xFF141414),
            ),
            textTheme: GoogleFonts.cairoTextTheme().apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
          ),
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE50914),
              secondary: Color(0xFFE50914),
              surface: Color(0xFFFFFFFF),
              background: Color(0xFFF5F5F5),
            ),
            textTheme: GoogleFonts.cairoTextTheme().apply(
              bodyColor: Colors.black,
              displayColor: Colors.black,
            ),
          ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl, // دعم العربية بشكل قسري ومرتب
          child: Consumer<IPTVProvider>(
            builder: (context, provider, _) {
              if (provider.snifferDetected || provider.vpnDetected || provider.isVersionBlocked) {
                String message = "";
                if (provider.snifferDetected) {
                  message = "🚨 تم اكتشاف برنامج التقاط حزم أو بيئة تشغيل غير آمنة!";
                } else if (provider.vpnDetected) {
                  message = "🚨 يرجى إيقاف تشغيل VPN أو البروكسي للاستمرار!";
                } else if (provider.isVersionBlocked) {
                  message = provider.remoteBlockMessage;
                }
                return Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE50914), size: 80),
                          const SizedBox(height: 20),
                          Text(
                            message,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return child!;
            },
          ),
        );
      },
      home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<IPTVProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.isLoggedIn) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))),
          );
        }
        if (provider.isLoggedIn && !provider.isExpired) {
          return const MainDashboard();
        }
        return const LoginScreen();
      },
    );
  }
}

// -----------------------------------------------------------------------------
// LOGIN SCREEN (Responsive Glassmorphism Design - Compact)
// -----------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  bool _obscureCode = true;

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Movie Collage
          CachedNetworkImage(
            imageUrl: "https://iili.io/Cj6L3fp.jpg",
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.70),
            colorBlendMode: BlendMode.darken,
            errorWidget: (c, u, e) => Container(color: const Color(0xFF141414)),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: isMobile ? screenW * 0.9 : 400,
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF4A148C).withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Text(
                            "live stream pro",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (provider.lastError != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(provider.lastError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                              ],
                            ),
                          ),
                        TextField(
                          controller: _codeController,
                          obscureText: _obscureCode,
                          style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16, letterSpacing: 1),
                          decoration: InputDecoration(
                            hintText: "أدخل كود الاشتراك",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                            prefixIcon: const Icon(Icons.vpn_key_rounded, color: Colors.white54, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureCode ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 18),
                              onPressed: () => setState(() => _obscureCode = !_obscureCode),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            contentPadding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16, horizontal: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE50914), width: 2)),
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 24),
                        SizedBox(
                          width: double.infinity,
                          height: isMobile ? 40 : 48,
                          child: ElevatedButton(
                            onPressed: provider.isLoading
                                ? null
                                : () async {
                                    final success = await provider.loginWithCode(_codeController.text);
                                    if (success) FocusScope.of(context).unfocus();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: provider.isLoading
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                : Text("تسجيل الدخول", style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () => _launchURL("https://t.me/+f9NsIzGjN_hjYWRi"),
                              icon: Icon(Icons.telegram, color: Colors.blueAccent, size: isMobile ? 18 : 20),
                              label: Text("القناة الرسمية", style: TextStyle(color: Colors.blueAccent, fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold)),
                            ),
                            TextButton.icon(
                              onPressed: () => _launchURL("https://t.me/+uryaRDBEm4lmYWZi"),
                              icon: Icon(Icons.star, color: Colors.amber, size: isMobile ? 18 : 20),
                              label: Text("الاشتراك Premium", style: TextStyle(color: Colors.amber, fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN DASHBOARD (Responsive Sidebar + Dynamic Content)
// -----------------------------------------------------------------------------
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _selectedIndex = 0;

  void updateIndex(int i) {
    if (i > 0) {
      String t = ["", "live", "movie", "series", "favorites"][i];
      Provider.of<IPTVProvider>(context, listen: false).setTab(t);
    }
    setState(() => _selectedIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          ModernSidebar(
            selectedIndex: _selectedIndex,
            onSelected: updateIndex,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const HomeTab();
      case 1:
        return const StreamsListScreen(title: "البث المباشر", tab: "live");
      case 2:
        return const StreamsListScreen(title: "الأفلام", tab: "movie");
      case 3:
        return const StreamsListScreen(title: "المسلسلات", tab: "series", isSeries: true);
      case 4:
        return const FavoritesScreen();
      default:
        return const HomeTab();
    }
  }
}

// -----------------------------------------------------------------------------
// SIDEBAR (Responsive Width & Icons - Compact)
// -----------------------------------------------------------------------------
class ModernSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelected;

  const ModernSidebar({super.key, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    return Container(
      width: isMobile ? 55 : 75,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          SizedBox(height: isMobile ? 12 : 20),
          RotatedBox(
            quarterTurns: -1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.0),
              ),
              child: Text(
                "PRO",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 32),
          _buildItem(Icons.home_rounded, 0, isMobile),
          _buildItem(Icons.live_tv_rounded, 1, isMobile),
          _buildItem(Icons.movie_filter_rounded, 2, isMobile),
          _buildItem(Icons.video_library_rounded, 3, isMobile),
          _buildItem(Icons.favorite_rounded, 4, isMobile),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white54, size: isMobile ? 18 : 20),
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          SizedBox(height: isMobile ? 4 : 8),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white54, size: isMobile ? 18 : 20),
            onPressed: () => Provider.of<IPTVProvider>(context, listen: false).logout(),
          ),
          SizedBox(height: isMobile ? 12 : 16),
        ],
      ),
    );
  }

  Widget _buildItem(IconData icon, int index, bool isMobile) {
    bool isSel = selectedIndex == index;
    return ScaleOnFocus(
      onTap: () => onSelected(index),
      child: Container(
        height: isMobile ? 40 : 50,
        margin: EdgeInsets.symmetric(vertical: isMobile ? 2 : 4),
        child: Row(
          children: [
            Container(
              width: 3,
              height: isMobile ? 20 : 24,
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFFE50914) : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(2)),
              ),
            ),
            Expanded(child: Icon(icon, color: isSel ? Colors.white : Colors.white54, size: isMobile ? 20 : 24)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HOME TAB (Responsive Layout - Compact)
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// SCROLLING ANNOUNCEMENT BAR (Marquee)
// -----------------------------------------------------------------------------
class MarqueeAnnouncementWidget extends StatefulWidget {
  final String text;
  const MarqueeAnnouncementWidget({super.key, required this.text});

  @override
  State<MarqueeAnnouncementWidget> createState() => _MarqueeAnnouncementWidgetState();
}

class _MarqueeAnnouncementWidgetState extends State<MarqueeAnnouncementWidget> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() {
    if (!_scrollController.hasClients) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_scrollController.hasClients) return;
      double maxScroll = _scrollController.position.maxScrollExtent;
      double currentScroll = _scrollController.position.pixels;
      double delta = 1.0;
      if (currentScroll >= maxScroll) {
        _scrollController.jumpTo(0.0);
      } else {
        _scrollController.animateTo(
          currentScroll + delta,
          duration: const Duration(milliseconds: 50),
          curve: Curves.linear,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE50914).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE50914).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFE50914),
              borderRadius: BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.campaign, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text("إعلان هام", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 1,
                itemBuilder: (context, index) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 120, right: 16),
                      child: Text(
                        widget.text,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HOME TAB (Responsive Layout - Compact & Stateful)
// -----------------------------------------------------------------------------
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _globalSearchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    final provider = Provider.of<IPTVProvider>(context);
    final expiryText = provider.activationDurationHours > 0 
        ? "صلاحية الاشتراك: ${provider.expirationDateFormatted}"
        : "اشتراك دائم أو غير محدد";

    // Fast global matching across allLoaded streams
    List<PlaylistItem> searchResults = [];
    if (_globalSearchQuery.isNotEmpty) {
      searchResults = provider.allStreams.where((item) {
        return item.name.toLowerCase().contains(_globalSearchQuery.toLowerCase());
      }).take(20).toList();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("كود الاشتراك: ${provider.activationCode}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(expiryText, style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => provider.logout(),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text("تغيير الاشتراك"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 18),

          // 1. Marquee Announcement Bar (Dynamic)
          if (provider.announcementText.isNotEmpty) ...[
            MarqueeAnnouncementWidget(text: provider.announcementText),
            SizedBox(height: isMobile ? 8 : 12),
          ],

          // 2. Global Unified Search Box
          Container(
            height: isMobile ? 42 : 48,
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _globalSearchQuery = val;
                });
              },
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: "البحث السريع المباشر عن القنوات والأفلام والمسلسلات...",
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE50914), size: 18),
                suffixIcon: _globalSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _globalSearchQuery = "";
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search results block
          if (_globalSearchQuery.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.search, color: Color(0xFFE50914), size: 18),
                const SizedBox(width: 8),
                Text("نتائج البحث السريع", style: TextStyle(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 10),
            searchResults.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text("لا توجد قنوات أو عروض مطابقة", style: TextStyle(color: Colors.white30, fontSize: 13))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: searchResults.length,
                    itemBuilder: (context, idx) {
                      final item = searchResults[idx];
                      IconData typeIcon = Icons.live_tv;
                      String typeLabel = "بث مباشر";
                      if (item.type == 'movie') {
                        typeIcon = Icons.movie;
                        typeLabel = "فيلم";
                      } else if (item.type == 'series') {
                        typeIcon = Icons.video_library;
                        typeLabel = "مسلسل";
                      }
                      return ScaleOnFocus(
                        onTap: () {
                          if (item.type == 'series') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailsScreen(series: item)));
                          } else {
                            provider.selectStream(item);
                            provider.addToRecentlyPlayed(item);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(stream: item)));
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141416),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.03)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  color: Colors.white10,
                                  child: item.streamIcon.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: item.streamIcon,
                                          fit: BoxFit.contain,
                                          placeholder: (c, u) => const Center(child: CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 1)),
                                          errorWidget: (c, u, e) => Icon(typeIcon, color: Colors.white24, size: 20),
                                        )
                                      : Icon(typeIcon, color: Colors.white24, size: 20),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(typeIcon, size: 10, color: const Color(0xFFE50914)),
                                        const SizedBox(width: 4),
                                        Text(typeLabel, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                        const SizedBox(width: 12),
                                        Text(item.categoryName, style: const TextStyle(color: Colors.white30, fontSize: 10)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 16),
          ],

          // 3. Continue Watching Row (Offline state retention)
          if (_globalSearchQuery.isEmpty && provider.recentlyPlayed.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFFE50914), size: 18),
                const SizedBox(width: 8),
                Text("واصل المشاهدة", style: TextStyle(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: isMobile ? 110 : 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provider.recentlyPlayed.length,
                itemBuilder: (context, idx) {
                  final item = provider.recentlyPlayed[idx];
                  return Container(
                    width: isMobile ? 80 : 100,
                    margin: const EdgeInsets.only(left: 8),
                    child: buildStreamCardLocal(context, provider, item, isSeries: item.type == 'series', isMobile: isMobile),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Default dashboard grid if not searching
          if (_globalSearchQuery.isEmpty) ...[
            Text("أبرز الإضافات", style: TextStyle(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: isMobile ? 4 : 8),
            const BannerSliderWidget(),
            SizedBox(height: isMobile ? 12 : 20),
            Text("تصفح الأقسام", style: TextStyle(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: isMobile ? 6 : 10),
            const DynamicSectionsWidget(),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// BANNER SLIDER (Full Image Visibility - No Crop - Compact)
// -----------------------------------------------------------------------------
class BannerSliderWidget extends StatefulWidget {
  const BannerSliderWidget({super.key});

  @override
  State<BannerSliderWidget> createState() => _BannerSliderWidgetState();
}

class _BannerSliderWidgetState extends State<BannerSliderWidget> {
  final PageController _pageController = PageController(viewportFraction: 0.95);
  int _currentPage = 0;
  Timer? _timer;

  // الروابط الجديدة
  List<String> _banners = [];
  bool _isLoadingBanners = true;

  Future<void> _fetchBanners() async {
    try {
      final url = Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/app_Slider.json?t=${DateTime.now().millisecondsSinceEpoch}");
      final res = await http.get(url, headers: {"Authorization": "token ${IPTVProvider.githubToken}"});
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        setState(() {
          _banners = data.map((e) => e.toString().trim()).toList();
          _isLoadingBanners = false;
        });
        _startTimer();
      } else {
        setState(() => _isLoadingBanners = false);
      }
    } catch (e) {
      setState(() => _isLoadingBanners = false);
    }
  }

  void _startTimer() {
    if (_banners.length > 1) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
        if (_currentPage < _banners.length - 1) _currentPage++;
        else _currentPage = 0;
        if (_pageController.hasClients) {
          _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 800), curve: Curves.fastOutSlowIn);
        }
      });
    }
  }


  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;
    final isTablet = screenW >= 600 && screenW < 900;

    // ارتفاع أصغر للواجهة المصغرة
    double bannerHeight = isMobile ? 140 : (isTablet ? 200 : 280);

    if (_isLoadingBanners) {
      return SizedBox(height: bannerHeight, child: const Center(child: CircularProgressIndicator(color: Colors.amber)));
    }
    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: bannerHeight,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (idx) => setState(() => _currentPage = idx),
        itemCount: _banners.length,
        itemBuilder: (context, index) {
          bool active = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            margin: EdgeInsets.symmetric(horizontal: isMobile ? 2 : 4, vertical: active ? 0 : (isMobile ? 4 : 8)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: active ? [const BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5))] : [],
              color: Colors.black, // خلفية سوداء لضمان عدم ظهور فراغات بيضاء
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // استخدام BoxFit.contain لعرض الصورة كاملة بدون قص
                  CachedNetworkImage(
                    imageUrl: _banners[index],
                    fit: BoxFit.contain, 
                    alignment: Alignment.center,
                    placeholder: (context, url) => Container(color: Colors.grey[900]),
                    errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                  ),
                  // تدرج خفيف في الأسفل لتحسين قراءة النصوص إذا أضفتها لاحقاً
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: bannerHeight * 0.3,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STREAMS LIST (Responsive Grid - Compact)
// -----------------------------------------------------------------------------
class StreamsListScreen extends StatelessWidget {
  final String title;
  final String tab;
  final bool isSeries;

  const StreamsListScreen({super.key, required this.title, required this.tab, this.isSeries = false});

  int _getCrossAxisCount(double width) {
    if (width < 600) return 3; // Phone (more items per row for compact view)
    if (width < 900) return 4; // Tablet Portrait
    if (width < 1200) return 5; // Tablet Landscape
    return 6; // TV / Desktop
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);
    final streams = provider.streams;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    return Column(
      children: [
        // Modern Top Bar (Compact)
        Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 12 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold, color: Colors.white)),
              Container(
                width: isMobile ? 140 : 250,
                height: isMobile ? 36 : 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  onChanged: (val) => provider.setSearchQuery(val),
                  style: TextStyle(color: Colors.white, fontSize: isMobile ? 12 : 14),
                  decoration: InputDecoration(
                    hintText: "بحث...",
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                    prefixIcon: Icon(Icons.search, color: Colors.white54, size: isMobile ? 18 : 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 8 : 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Body (Categories + Grid)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categories List (Compact)
              Container(
                width: isMobile ? 80 : 160,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ListView.builder(
                  itemCount: provider.categories.length + 1,
                  itemBuilder: (ctx, i) {
                    String catId = i == 0 ? "all" : provider.categories[i - 1];
                    String catName = i == 0 ? "الكل" : provider.categories[i - 1];
                    bool isSel = provider.selectedCategory == catId;
                    return ScaleOnFocus(
                      onTap: () => provider.setCategory(catId),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10, horizontal: isMobile ? 6 : 12),
                        margin: EdgeInsets.only(bottom: isMobile ? 2 : 4),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFE50914) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          catName,
                          style: TextStyle(
                              color: isSel ? Colors.white : Colors.white70,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: isMobile ? 11 : 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Content Grid
              Expanded(
                child: provider.isFetchingData
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                    : GridView.builder(
                        padding: EdgeInsets.only(right: 8, left: isMobile ? 12 : 16, bottom: 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _getCrossAxisCount(screenW),
                          childAspectRatio: 0.65, // Slightly taller cards for better visibility
                          crossAxisSpacing: isMobile ? 6 : 12,
                          mainAxisSpacing: isMobile ? 6 : 12,
                        ),
                        itemCount: streams.length,
                        itemBuilder: (ctx, i) => buildStreamCardLocal(context, provider, streams[i], isSeries: isSeries, isMobile: isMobile),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// FAVORITES SCREEN (Responsive - Compact)
// -----------------------------------------------------------------------------
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  int _getCrossAxisCount(double width) {
    if (width < 600) return 3;
    if (width < 900) return 4;
    if (width < 1200) return 5;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);
    final streams = provider.streams;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 12 : 16),
          alignment: Alignment.centerRight,
          child: Text("المفضلة", style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        Expanded(
          child: streams.isEmpty
              ? Center(child: Text("لا توجد قنوات أو عروض في المفضلة", style: TextStyle(fontSize: isMobile ? 14 : 16, color: Colors.white54)))
              : GridView.builder(
                  padding: EdgeInsets.all(isMobile ? 12 : 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _getCrossAxisCount(screenW),
                    childAspectRatio: 0.65,
                    crossAxisSpacing: isMobile ? 6 : 12,
                    mainAxisSpacing: isMobile ? 6 : 12,
                  ),
                  itemCount: streams.length,
                  itemBuilder: (ctx, i) => buildStreamCardLocal(context, provider, streams[i], isSeries: streams[i].type == "series", isMobile: isMobile),
                ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SERIES DETAILS (Responsive - Compact)
// -----------------------------------------------------------------------------
class SeriesDetailsScreen extends StatefulWidget {
  final PlaylistItem series;

  const SeriesDetailsScreen({super.key, required this.series});

  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _seriesData;
  String _selectedSeason = "";

  @override
  void initState() {
    super.initState();
    _fetchSeriesInfo();
  }

  Future<void> _fetchSeriesInfo() async {
    try {
      final s = widget.series;
      var seriesId = s.streamId.replaceAll('series_', '');
      String streamUrl = s.url;
      if (streamUrl.isNotEmpty && streamUrl.contains('/series/')) {
        final uri = Uri.parse(streamUrl);
        final host = "${uri.scheme}://${uri.host}:${uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80)}";
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 4) {
          final username = pathSegments[1];
          final password = pathSegments[2];
          final url = "$host/player_api.php?username=$username&password=$password&action=get_series_info&series_id=$seriesId";
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            List<dynamic> parsedSeasons = [];
            Map<String, dynamic> parsedEpisodes = {};

            if (data['episodes'] != null) {
              if (data['episodes'] is Map) {
                parsedEpisodes = Map<String, dynamic>.from(data['episodes']);
              } else if (data['episodes'] is List) {
                parsedEpisodes["1"] = List<dynamic>.from(data['episodes']);
              }
            }

            if (data['seasons'] != null && data['seasons'] is List && (data['seasons'] as List).isNotEmpty) {
              parsedSeasons = List<dynamic>.from(data['seasons']);
            } else if (data['seasons'] != null && data['seasons'] is Map && (data['seasons'] as Map).isNotEmpty) {
              parsedSeasons = (data['seasons'] as Map).values.toList();
            } else {
              parsedEpisodes.keys.forEach((key) {
                parsedSeasons.add({
                  "season_number": key,
                  "name": "الموسم $key",
                  "cover": data['info']?['cover'] ?? "",
                  "episode_count": (parsedEpisodes[key] as List).length
                });
              });
            }

            parsedSeasons.sort((a, b) {
              int sA = int.tryParse(a['season_number']?.toString() ?? '0') ?? 0;
              int sB = int.tryParse(b['season_number']?.toString() ?? '0') ?? 0;
              return sA.compareTo(sB);
            });

            for (var season in parsedSeasons) {
              String sNum = season['season_number'].toString();
              if (!parsedEpisodes.containsKey(sNum)) parsedEpisodes[sNum] = [];
            }

            if (mounted) {
              setState(() {
                _seriesData = {"info": data['info'] ?? {}, "seasons": parsedSeasons, "episodes": parsedEpisodes};
                _isLoading = false;
              });
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching series info: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _playEpisode(dynamic ep) {
    String host = "";
    String user = "";
    String pass = "";
    try {
      final uri = Uri.parse(widget.series.url);
      host = "${uri.scheme}://${uri.host}:${uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80)}";
      if (uri.pathSegments.length >= 4) {
        user = uri.pathSegments[1];
        pass = uri.pathSegments[2];
      }
    } catch (e) {}
    final epId = ep['id'];
    final ext = ep['container_extension'] ?? "mp4";
    final epUrl = "$host/series/$user/$pass/$epId.$ext";
    final stream = PlaylistItem(
      streamId: epId.toString(),
      name: "${widget.series.name} - ${ep['title'] ?? 'الحلقة'}",
      url: epUrl,
      type: "series",
      streamIcon: ep['info']?['movie_image'] ?? widget.series.streamIcon,
      categoryId: "",
      categoryName: "مسلسلات",
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)));
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final isMobile = screenW < 600;
    final pad = isMobile ? 16.0 : 32.0;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))));
    }

    if (_seriesData == null || (_seriesData!['seasons'] as List).isEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(child: Text("عذراً، لا توجد حلقات متاحة لهذا المسلسل", style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16))),
      );
    }

    final info = _seriesData!['info'] ?? {};
    final seasons = _seriesData!['seasons'] as List<dynamic>;
    final episodesMap = _seriesData!['episodes'] as Map<String, dynamic>;

    String cover = info['cover'] ?? widget.series.streamIcon ?? "";
    String name = info['name'] ?? widget.series.name;
    String plot = info['plot'] ?? "لا يوجد وصف متاح لهذا المسلسل.";
    String rating = info['rating']?.toString() ?? "";
    String year = info['releaseDate']?.toString() ?? info['year']?.toString() ?? "";

    if (_selectedSeason.isEmpty && seasons.isNotEmpty) {
      _selectedSeason = seasons.first['season_number'].toString();
    }

    List<dynamic> currentEpisodes = episodesMap[_selectedSeason] ?? [];

    return Scaffold(
      body: Stack(
        children: [
          // Hero Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: isMobile ? screenH * 0.5 : screenH * 0.6,
            child: cover.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    errorWidget: (c, u, e) => Container(color: Colors.black),
                  )
                : Container(color: Colors.black),
          ),
          // Netflix Style Gradient Fade
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: isMobile ? screenH * 0.55 : screenH * 0.65,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xFF141414)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.2, 1.0],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 8 : 12),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white, size: isMobile ? 20 : 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  // Details Block
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                              fontSize: isMobile ? 24 : 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: const [Shadow(color: Colors.black87, blurRadius: 10)]),
                        ),
                        SizedBox(height: isMobile ? 8 : 12),
                        Row(
                          children: [
                            if (year.isNotEmpty) ...[
                              Text(year, style: TextStyle(color: const Color(0xFF46D369), fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 14)),
                              SizedBox(width: isMobile ? 8 : 12)
                            ],
                            Text("${seasons.length} مواسم", style: TextStyle(color: Colors.white70, fontSize: isMobile ? 12 : 14)),
                            SizedBox(width: isMobile ? 8 : 12),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(2)),
                                child: Text("HD", style: TextStyle(color: Colors.white, fontSize: isMobile ? 9 : 10))),
                            if (rating.isNotEmpty && rating != "0" && rating != "0.0") ...[
                              SizedBox(width: isMobile ? 8 : 12),
                              Icon(Icons.star, color: Colors.amber, size: isMobile ? 12 : 14),
                              const SizedBox(width: 2),
                              Text(rating, style: TextStyle(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                            ]
                          ],
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        SizedBox(
                          width: isMobile ? screenW * 0.9 : screenW * 0.6,
                          child: Text(plot,
                              style: TextStyle(color: Colors.white, fontSize: isMobile ? 12 : 14, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
                        ),
                        SizedBox(height: isMobile ? 16 : 24),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 8 : 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              icon: Icon(Icons.play_arrow, size: isMobile ? 20 : 24),
                              label: Text("تشغيل", style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                if (currentEpisodes.isNotEmpty) _playEpisode(currentEpisodes.first);
                              },
                            ),
                            SizedBox(width: isMobile ? 8 : 12),
                            Container(
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white54, width: 1.5)),
                              child: IconButton(
                                icon: Icon(Icons.favorite_border, color: Colors.white, size: isMobile ? 18 : 20),
                                onPressed: () {
                                  Provider.of<IPTVProvider>(context, listen: false).toggleFavorite(widget.series.streamId ?? "");
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 24 : 32),
                  // Seasons Horizontal Tabs
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    child: SizedBox(
                      height: isMobile ? 36 : 45,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: seasons.length,
                        itemBuilder: (ctx, i) {
                          String sNum = seasons[i]['season_number'].toString();
                          String sName = seasons[i]['name'] ?? "الموسم $sNum";
                          bool isSel = _selectedSeason == sNum;
                          return Padding(
                            padding: EdgeInsets.only(left: isMobile ? 12 : 24),
                            child: InkWell(
                              onTap: () => setState(() => _selectedSeason = sNum),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(sName,
                                      style: TextStyle(
                                          fontSize: isMobile ? 14 : 16, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? Colors.white : Colors.white54)),
                                  const SizedBox(height: 4),
                                  if (isSel)
                                    Container(
                                        width: isMobile ? 20 : 30,
                                        height: isMobile ? 2 : 3,
                                        decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(1))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  // Episodes List
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentEpisodes.length,
                      itemBuilder: (ctx, i) {
                        final ep = currentEpisodes[i];
                        String epTitle = ep['title'] ?? "الحلقة ${i + 1}";
                        String epCover = ep['info']?['movie_image'] ?? "";
                        String epDuration = ep['info']?['duration'] ?? "";
                        String epPlot = ep['info']?['plot'] ?? "";

                        return ScaleOnFocus(
                          onTap: () => _playEpisode(ep),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(isMobile ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.02)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: isMobile ? 24 : 32, child: Text("${i + 1}", style: TextStyle(fontSize: isMobile ? 16 : 20, color: Colors.white54, fontWeight: FontWeight.bold))),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: isMobile ? 80 : 120,
                                    height: isMobile ? 50 : 70,
                                    child: epCover.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: epCover,
                                            fit: BoxFit.contain,
                                            placeholder: (c, u) => Container(color: Colors.white10),
                                            errorWidget: (c, u, e) => Container(color: Colors.white10, child: const Icon(Icons.play_circle_outline, color: Colors.white54)))
                                        : Container(color: Colors.white10, child: const Icon(Icons.play_circle_outline, color: Colors.white54, size: 24)),
                                  ),
                                ),
                                SizedBox(width: isMobile ? 12 : 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                              child: Text(epTitle,
                                                  style: TextStyle(fontSize: isMobile ? 13 : 16, fontWeight: FontWeight.bold, color: Colors.white),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis)),
                                          Text(epDuration, style: TextStyle(color: Colors.white54, fontSize: isMobile ? 10 : 12)),
                                        ],
                                      ),
                                      if (epPlot.isNotEmpty) ...[
                                        SizedBox(height: isMobile ? 2 : 4),
                                        Text(epPlot, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white70, fontSize: isMobile ? 10 : 11)),
                                      ]
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 48), // Scroll padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UTILS & SHARED WIDGETS
// -----------------------------------------------------------------------------
// Widget for hover & remote control focus scaling
class ScaleOnFocus extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const ScaleOnFocus({super.key, required this.child, required this.onTap});

  @override
  State<ScaleOnFocus> createState() => _ScaleOnFocusState();
}

class _ScaleOnFocusState extends State<ScaleOnFocus> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onHover: (isHovering) => setState(() => _isFocused = isHovering),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedScale(
        scale: _isFocused ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _isFocused ? Colors.white70 : Colors.transparent, width: 1.5),
            boxShadow: _isFocused ? [const BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 5))] : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// Beautiful Movie/Stream Card (Compact)
Widget buildStreamCardLocal(BuildContext context, IPTVProvider provider, dynamic stream, {bool isSeries = false, bool isMobile = false}) {
  String name = "";
  String imageUrl = "";
  String streamId = "";
  try {
    name = stream.name ?? stream.title ?? "بدون اسم";
    imageUrl = stream.streamIcon ?? stream.cover ?? "";
    streamId = stream.streamId ?? stream.id ?? "";
  } catch (e) {}
  bool isFav = provider.favorites.contains(streamId);

  return ScaleOnFocus(
    onTap: () {
      if (isSeries) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailsScreen(series: stream)));
      } else {
        provider.selectStream(stream);
        provider.addToRecentlyPlayed(stream);
        Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)));
      }
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain, // Prevent cropping
                  placeholder: (context, url) => Container(color: Colors.white10, child: const Center(child: CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 2))),
                  errorWidget: (context, url, error) => Container(color: Colors.white10, child: const Icon(Icons.movie, size: 40, color: Colors.white24)),
                )
              : Container(color: Colors.white10, child: const Icon(Icons.movie, size: 40, color: Colors.white24)),
          // Gradient Name Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6, vertical: isMobile ? 6 : 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: isMobile ? 10 : 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          // Fav Icon
          Positioned(
            top: 4,
            left: 4,
            child: InkWell(
              onTap: () => provider.toggleFavorite(streamId),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 3 : 4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                child: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? const Color(0xFFE50914) : Colors.white,
                  size: isMobile ? 14 : 16,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


// -----------------------------------------------------------------------------
// DYNAMIC SECTIONS WIDGET (Main_menu.json support for 2027)
// -----------------------------------------------------------------------------
class DynamicSectionsWidget extends StatelessWidget {
  const DynamicSectionsWidget({super.key});

  IconData _getIconForCategory(String categoryName) {
    final lower = categoryName.toLowerCase();
    if (lower.contains('sports') || lower.contains('رياضة') || lower.contains('بين سبورت')) return Icons.sports_soccer;
    if (lower.contains('movie') || lower.contains('أفلام')) return Icons.movie;
    if (lower.contains('kids') || lower.contains('أطفال')) return Icons.child_care;
    if (lower.contains('islam') || lower.contains('إسلام') || lower.contains('قرآن')) return Icons.mosque;
    if (lower.contains('news') || lower.contains('أخبار')) return Icons.public;
    if (lower.contains('doc') || lower.contains('وثائق')) return Icons.landscape;
    if (lower.contains('entert') || lower.contains('ترفيه')) return Icons.local_activity;
    return Icons.live_tv;
  }

  List<Color> _getColorForCategory(String categoryName, int index) {
    final colors = [
      [const Color(0xFFE50914), const Color(0xFF8E040B)],
      [const Color(0xFF1E88E5), const Color(0xFF1565C0)],
      [const Color(0xFF00B4DB), const Color(0xFF0083B0)],
      [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
      [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
      [const Color(0xFF9C27B0), const Color(0xFF6A1B9A)],
      [const Color(0xFFFF9800), const Color(0xFFF57C00)],
      [const Color(0xFF607D8B), const Color(0xFF455A64)],
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    if (provider.activationCode != "2027" || provider.liveCategories.isEmpty) {
      // Default Sections
      if (isMobile) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.4,
          children: [
            _buildStaticCard(context, "بث مباشر", Icons.live_tv, 1, const [Color(0xFFE50914), Color(0xFF8E040B)], isMobile),
            _buildStaticCard(context, "أفلام", Icons.movie, 2, const [Color(0xFF1E88E5), Color(0xFF1565C0)], isMobile),
            _buildStaticCard(context, "مسلسلات", Icons.video_library, 3, const [Color(0xFF00B4DB), Color(0xFF0083B0)], isMobile),
            _buildStaticCard(context, "المفضلة", Icons.favorite, 4, const [Color(0xFFFF416C), Color(0xFFFF4B2B)], isMobile),
          ],
        );
      } else {
        return Row(
          children: [
            Expanded(child: _buildStaticCard(context, "بث مباشر", Icons.live_tv, 1, const [Color(0xFFE50914), Color(0xFF8E040B)], isMobile)),
            const SizedBox(width: 8),
            Expanded(child: _buildStaticCard(context, "أفلام", Icons.movie, 2, const [Color(0xFF1E88E5), Color(0xFF1565C0)], isMobile)),
            const SizedBox(width: 8),
            Expanded(child: _buildStaticCard(context, "مسلسلات", Icons.video_library, 3, const [Color(0xFF00B4DB), Color(0xFF0083B0)], isMobile)),
            const SizedBox(width: 8),
            Expanded(child: _buildStaticCard(context, "المفضلة", Icons.favorite, 4, const [Color(0xFFFF416C), Color(0xFFFF4B2B)], isMobile)),
          ],
        );
      }
    }

    // Custom JSON Sections (Code 2027)
    final cats = provider.liveCategories;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: isMobile ? 1.4 : 1.6,
      ),
      itemCount: cats.length,
      itemBuilder: (context, index) {
        final section = cats[index];
        final title = section['category_name'] ?? 'Section';
        return _buildDynamicCard(context, title, _getIconForCategory(title), _getColorForCategory(title, index), isMobile, section);
      },
    );
  }

  Widget _buildStaticCard(BuildContext context, String title, IconData icon, int index, List<Color> gradient, bool isMobile) {
    return ScaleOnFocus(
      onTap: () {
        context.findAncestorStateOfType<_MainDashboardState>()?.updateIndex(index);
      },
      child: Container(
        height: isMobile ? 80 : 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isMobile ? 24 : 32, color: Colors.white),
            SizedBox(height: isMobile ? 4 : 8),
            Text(title, style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicCard(BuildContext context, String title, IconData icon, List<Color> gradient, bool isMobile, dynamic sectionData) {
    return ScaleOnFocus(
      onTap: () {
        final provider = Provider.of<IPTVProvider>(context, listen: false);
        if (sectionData['category_name'] != null) {
          provider.setCategory(sectionData['category_name']);
        }
        context.findAncestorStateOfType<_MainDashboardState>()?.updateIndex(1);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isMobile ? 24 : 32, color: Colors.white),
            SizedBox(height: isMobile ? 4 : 8),
            Text(title, style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
