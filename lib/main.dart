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
import 'widgets/pin_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

FirebaseAnalytics? appAnalytics;

class PremiumPalette {
  PremiumPalette._();

  static const Color background = Color(0xFF09091A);
  static const Color surface = Color(0xFF14112B);
  static const Color surfaceElevated = Color(0xFF211C42);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetBright = Color(0xFFA78BFA);
  static const Color gold = Color(0xFFFFC857);
  static const Color textMuted = Color(0xFFB7B1D6);
}

class PremiumSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? actionLabel;

  const PremiumSectionTitle({super.key, required this.title, required this.icon, this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: PremiumPalette.violet.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: PremiumPalette.violetBright),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17))),
        if (actionLabel != null)
          Text(actionLabel!, style: const TextStyle(color: PremiumPalette.gold, fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedOrient = prefs.getString('app_orientation') ?? 'تلقائي';
    if (savedOrient == 'أفقي') {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (savedOrient == 'عمودي') {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  } catch (_) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
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
          title: 'LIVE STREAM PREMIUM',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: PremiumPalette.background,
            colorScheme: const ColorScheme.dark(
              primary: PremiumPalette.violet,
              secondary: PremiumPalette.gold,
              surface: PremiumPalette.surface,
              background: PremiumPalette.background,
            ),
            textTheme: GoogleFonts.cairoTextTheme().apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
          ),
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF7F5FF),
            colorScheme: const ColorScheme.light(
              primary: PremiumPalette.violet,
              secondary: Color(0xFFB7791F),
              surface: Colors.white,
              background: Color(0xFFF7F5FF),
            ),
            textTheme: GoogleFonts.cairoTextTheme().apply(
              bodyColor: const Color(0xFF17122F),
              displayColor: const Color(0xFF17122F),
            ),
          ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl, // دعم العربية بشكل قسري ومرتب
          child: Consumer<IPTVProvider>(
            builder: (context, provider, _) {
              if (provider.snifferDetected || provider.vpnDetected || provider.isVersionBlocked || !provider.isSecured) {
                String message = "";
                if (provider.snifferDetected) {
                  message = "🚨 تم اكتشاف برنامج التقاط حزم أو بيئة تشغيل غير آمنة!";
                } else if (!provider.isSecured) {
                  message = provider.securityMessage.isNotEmpty ? provider.securityMessage : "🚨 تم كشف تلاعب بأمان التطبيق أو استخدام بيئة هندسة عكسية!";
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
      backgroundColor: PremiumPalette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF09091A), Color(0xFF17122F), Color(0xFF09091A)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
          Positioned(
            top: -screenW * 0.22,
            right: -screenW * 0.15,
            child: _LoginGlow(size: screenW * 0.72, color: PremiumPalette.violet),
          ),
          Positioned(
            bottom: -screenW * 0.20,
            left: -screenW * 0.18,
            child: _LoginGlow(size: screenW * 0.65, color: PremiumPalette.gold),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [PremiumPalette.violetBright, PremiumPalette.violet],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.24)),
                          boxShadow: [BoxShadow(color: PremiumPalette.violet.withOpacity(0.45), blurRadius: 28, offset: const Offset(0, 10))],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 46),
                      ),
                      const SizedBox(height: 16),
                      const Text("LIVE STREAM PREMIUM", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      const Text("منصة مشاهدة حصرية بتجربة مستقرة", style: TextStyle(color: PremiumPalette.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isMobile ? 20 : 26),
                            decoration: BoxDecoration(
                              color: PremiumPalette.surface.withOpacity(0.82),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.13)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 36, offset: const Offset(0, 16))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text("تسجيل الدخول", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 5),
                                const Text("أدخل كود اشتراكك للمتابعة", style: TextStyle(color: PremiumPalette.textMuted, fontSize: 12)),
                                const SizedBox(height: 20),
                                if (provider.lastError != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
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
                                    hintText: "كود الاشتراك",
                                    hintStyle: const TextStyle(color: PremiumPalette.textMuted, fontSize: 13),
                                    prefixIcon: const Icon(Icons.key_rounded, color: PremiumPalette.gold, size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureCode ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: PremiumPalette.textMuted, size: 20),
                                      onPressed: () => setState(() => _obscureCode = !_obscureCode),
                                    ),
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.18),
                                    contentPadding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 17, horizontal: 16),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.10))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: PremiumPalette.violetBright, width: 1.5)),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  height: isMobile ? 48 : 52,
                                  child: ElevatedButton.icon(
                                    onPressed: provider.isLoading
                                        ? null
                                        : () async {
                                            final success = await provider.loginWithCode(_codeController.text);
                                            if (success) FocusScope.of(context).unfocus();
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: PremiumPalette.violet,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    icon: provider.isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.login_rounded),
                                    label: Text(provider.isLoading ? "جارٍ التحقق..." : "دخول آمن", style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Divider(color: Color(0x334D446E)),
                                const SizedBox(height: 10),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  runSpacing: 4,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _launchURL("https://t.me/+f9NsIzGjN_hjYWRi"),
                                      icon: const Icon(Icons.telegram, color: Color(0xFF38BDF8), size: 18),
                                      label: const Text("القناة الرسمية", style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _launchURL("https://t.me/+uryaRDBEm4lmYWZi"),
                                      icon: const Icon(Icons.workspace_premium_rounded, color: PremiumPalette.gold, size: 18),
                                      label: const Text("الاشتراك المميز", style: TextStyle(color: PremiumPalette.gold, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text("LIVE STREAM PREMIUM • SECURE ACCESS", style: TextStyle(color: Color(0xFF817AA5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ],
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

class _LoginGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _LoginGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.25), color.withOpacity(0.05), Colors.transparent],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
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
    final bool useBottomNav = MediaQuery.of(context).size.width < 600 || MediaQuery.of(context).orientation == Orientation.portrait;
    final provider = Provider.of<IPTVProvider>(context);
    final showMoviesSeries = provider.showMoviesSeries;

    final List<Map<String, dynamic>> tabs = [
      {"icon": Icons.home_rounded, "label": "الرئيسية", "index": 0},
      {"icon": Icons.live_tv_rounded, "label": "مباشر", "index": 1},
      if (showMoviesSeries) {"icon": Icons.movie_filter_rounded, "label": "أفلام", "index": 2},
      if (showMoviesSeries) {"icon": Icons.video_library_rounded, "label": "مسلسلات", "index": 3},
      {"icon": Icons.favorite_rounded, "label": "مفضلة", "index": 4},
    ];

    int localIndex = tabs.indexWhere((t) => t['index'] == _selectedIndex);
    if (localIndex == -1) {
      localIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _selectedIndex = 0);
      });
    }

    return Scaffold(
      backgroundColor: PremiumPalette.background,
      drawer: useBottomNav
          ? PremiumDrawer(
              selectedIndex: _selectedIndex,
              onSelected: (index) {
                Navigator.pop(context);
                updateIndex(index);
              },
            )
          : null,
      appBar: useBottomNav ? AppBar(
        backgroundColor: PremiumPalette.surface,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [PremiumPalette.violetBright, PremiumPalette.violet]), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 21),
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text("LIVE STREAM", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.4))),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: PremiumPalette.gold.withOpacity(0.14), borderRadius: BorderRadius.circular(9)),
            child: const Row(children: [Icon(Icons.workspace_premium_rounded, color: PremiumPalette.gold, size: 15), SizedBox(width: 3), Text('Premium', style: TextStyle(color: PremiumPalette.gold, fontSize: 10, fontWeight: FontWeight.bold))]),
          ),
          const SizedBox(width: 7),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          )
        ],
      ) : null,
      body: Row(
        children: [
          if (!useBottomNav)
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
      bottomNavigationBar: useBottomNav
          ? BottomNavigationBar(
              currentIndex: localIndex,
              onTap: (val) => updateIndex(tabs[val]['index']),
              backgroundColor: PremiumPalette.surface,
              selectedItemColor: PremiumPalette.violetBright,
              unselectedItemColor: const Color(0xFF8B84A9),
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              selectedFontSize: 10,
              unselectedFontSize: 10,
              items: tabs.map((t) {
                return BottomNavigationBarItem(icon: Icon(t['icon']), label: t['label']);
              }).toList(),
            )
          : null,
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

class PremiumDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const PremiumDrawer({super.key, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);
    final showMoviesSeries = provider.showMoviesSeries;
    final items = <Map<String, dynamic>>[
      {'index': 0, 'label': 'الرئيسية', 'icon': Icons.home_rounded},
      {'index': 1, 'label': 'القنوات المباشرة', 'icon': Icons.live_tv_rounded},
      if (showMoviesSeries) {'index': 2, 'label': 'الأفلام', 'icon': Icons.movie_filter_rounded},
      if (showMoviesSeries) {'index': 3, 'label': 'المسلسلات', 'icon': Icons.video_library_rounded},
      {'index': 4, 'label': 'المفضلة', 'icon': Icons.favorite_rounded},
    ];

    return Drawer(
      backgroundColor: PremiumPalette.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(26))),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF30215F), PremiumPalette.surfaceElevated]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: PremiumPalette.gold, borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF2A174D), size: 28),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LIVE STREAM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                        SizedBox(height: 2),
                        Text('Premium Member', style: TextStyle(color: PremiumPalette.gold, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ...items.map((item) {
                    final selected = selectedIndex == item['index'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: selected ? PremiumPalette.violet.withOpacity(0.22) : Colors.transparent,
                        leading: Icon(item['icon'], color: selected ? PremiumPalette.violetBright : Colors.white60),
                        title: Text(item['label'], style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.w600, fontSize: 13)),
                        onTap: () => onSelected(item['index']),
                      ),
                    );
                  }),
                  const Divider(color: Color(0x1FFFFFFF), height: 26),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: const Icon(Icons.settings_outlined, color: Colors.white60),
                    title: const Text('الإعدادات', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: const Icon(Icons.headset_mic_outlined, color: PremiumPalette.gold),
                    title: const Text('الدعم الفني', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                    onTap: () => launchUrl(Uri.parse('https://t.me/+f9NsIzGjN_hjYWRi'), mode: LaunchMode.externalApplication),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: Colors.redAccent.withOpacity(0.08),
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                onTap: provider.logout,
              ),
            ),
          ],
        ),
      ),
    );
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
    final provider = Provider.of<IPTVProvider>(context);
    final showMoviesSeries = provider.showMoviesSeries;

    final List<Map<String, dynamic>> items = [
      {"icon": Icons.home_rounded, "index": 0},
      {"icon": Icons.live_tv_rounded, "index": 1},
      if (showMoviesSeries) {"icon": Icons.movie_filter_rounded, "index": 2},
      if (showMoviesSeries) {"icon": Icons.video_library_rounded, "index": 3},
      {"icon": Icons.favorite_rounded, "index": 4},
    ];

    return Container(
      width: isMobile ? 55 : 82,
      decoration: BoxDecoration(
        color: PremiumPalette.surface,
        border: Border(left: BorderSide(color: PremiumPalette.violet.withOpacity(0.18))),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: isMobile ? 12 : 18, bottom: isMobile ? 6 : 10),
            child: Container(
              width: isMobile ? 34 : 42,
              height: isMobile ? 34 : 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [PremiumPalette.violetBright, PremiumPalette.violet]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: PremiumPalette.violet.withOpacity(0.35), blurRadius: 14)],
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white54, size: isMobile ? 18 : 20),
            tooltip: 'الإعدادات',
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          SizedBox(height: isMobile ? 4 : 8),
          IconButton(
            icon: Icon(Icons.tune_rounded, color: Colors.white54, size: isMobile ? 18 : 20),
            tooltip: 'التفضيلات',
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          SizedBox(height: isMobile ? 16 : 32),
          ...items.map((item) => _buildItem(item['icon'], item['index'], isMobile)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white54, size: isMobile ? 18 : 20),
            tooltip: 'تسجيل الخروج',
            onPressed: () => provider.logout(),
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
                color: isSel ? PremiumPalette.gold : Colors.transparent,
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
        color: PremiumPalette.violet.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PremiumPalette.violet.withOpacity(0.3)),
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
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 16 : 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF30215F), PremiumPalette.surfaceElevated], begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: PremiumPalette.violetBright.withOpacity(0.22)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: Row(
              children: [
                Container(
                  width: isMobile ? 48 : 58,
                  height: isMobile ? 48 : 58,
                  decoration: BoxDecoration(color: PremiumPalette.gold, borderRadius: BorderRadius.circular(17)),
                  child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF2A174D), size: 31),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أهلاً بك في LIVE STREAM', style: TextStyle(color: Colors.white, fontSize: isMobile ? 15 : 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(expiryText, style: const TextStyle(color: PremiumPalette.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('كود الاشتراك: ${provider.activationCode}', style: const TextStyle(color: PremiumPalette.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'تغيير الاشتراك',
                  onPressed: provider.logout,
                  icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white70),
                ),
              ],
            ),
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
              color: PremiumPalette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PremiumPalette.violet.withOpacity(0.18)),
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
                prefixIcon: const Icon(Icons.search_rounded, color: PremiumPalette.violetBright, size: 20),
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
            const PremiumSectionTitle(title: 'نتائج البحث السريع', icon: Icons.search_rounded),
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
                        onTap: () async {
                          final categoryName = item.categoryName;
                          if (provider.isCategoryLocked(categoryName)) {
                            bool ok = await showPinDialog(context, provider);
                            if (!ok) return;
                            provider.unlockCategorySession(categoryName);
                          }
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
                                        Icon(typeIcon, size: 10, color: PremiumPalette.violet),
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
            const PremiumSectionTitle(title: 'واصل المشاهدة', icon: Icons.history_rounded, actionLabel: 'استكمل الآن'),
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
            const PremiumSectionTitle(title: 'أبرز الإضافات', icon: Icons.auto_awesome_rounded, actionLabel: 'مختارات Premium'),
            SizedBox(height: isMobile ? 8 : 12),
            const BannerSliderWidget(),
            SizedBox(height: isMobile ? 12 : 20),
            const PremiumSectionTitle(title: 'تصفح الأقسام', icon: Icons.grid_view_rounded, actionLabel: 'عرض الكل'),
            SizedBox(height: isMobile ? 9 : 12),
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
      final res = await http.get(url);
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
                      onTap: () async {
                        if (provider.isCategoryLocked(catName)) {
                          bool ok = await showPinDialog(context, provider);
                          if (ok) {
                            provider.unlockCategorySession(catName);
                            provider.setCategory(catId);
                          }
                        } else {
                          provider.setCategory(catId);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10, horizontal: isMobile ? 6 : 12),
                        margin: EdgeInsets.only(bottom: isMobile ? 2 : 4),
                        decoration: BoxDecoration(
                          color: isSel ? PremiumPalette.violet : Colors.transparent,
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

  void _playEpisode(dynamic ep) async {
    final provider = Provider.of<IPTVProvider>(context, listen: false);
    final categoryName = widget.series.categoryName;
    if (provider.isCategoryLocked(categoryName)) {
      bool ok = await showPinDialog(context, provider);
      if (!ok) return;
      provider.unlockCategorySession(categoryName);
    }

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
                                        decoration: BoxDecoration(color: PremiumPalette.violet, borderRadius: BorderRadius.circular(1))),
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
  String categoryName = "";
  try {
    name = stream.name ?? stream.title ?? "بدون اسم";
    imageUrl = stream.streamIcon ?? stream.cover ?? "";
    streamId = stream.streamId ?? stream.id ?? "";
    categoryName = stream.categoryName ?? "";
  } catch (e) {}
  bool isFav = provider.favorites.contains(streamId);

  return ScaleOnFocus(
    onTap: () async {
      if (provider.isCategoryLocked(categoryName)) {
        bool ok = await showPinDialog(context, provider);
        if (!ok) return;
        provider.unlockCategorySession(categoryName);
      }
      if (isSeries) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailsScreen(series: stream)));
      } else {
        provider.selectStream(stream);
        provider.addToRecentlyPlayed(stream);
        Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)));
      }
    },
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PremiumPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain, // Prevent cropping
                  placeholder: (context, url) => Container(color: PremiumPalette.surfaceElevated, child: const Center(child: CircularProgressIndicator(color: PremiumPalette.violetBright, strokeWidth: 2))),
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
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.68), borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.white.withOpacity(0.12))),
              child: Text(isSeries ? 'HD' : 'FHD', style: TextStyle(color: PremiumPalette.gold, fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.w900)),
            ),
          ),
          // Fav Icon
          Positioned(
            top: 6,
            left: 6,
            child: InkWell(
              onTap: () => provider.toggleFavorite(streamId),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 3 : 4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.68), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.12))),
                child: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? PremiumPalette.gold : Colors.white,
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
      [PremiumPalette.violet, const Color(0xFF8E040B)],
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
      final showMoviesSeries = provider.showMoviesSeries;
      final List<Widget> staticCards = [
        _buildStaticCard(context, "بث مباشر", Icons.live_tv, 1, const [Color(0xFFE50914), Color(0xFF8E040B)], isMobile),
        if (showMoviesSeries)
          _buildStaticCard(context, "أفلام", Icons.movie, 2, const [Color(0xFF1E88E5), Color(0xFF1565C0)], isMobile),
        if (showMoviesSeries)
          _buildStaticCard(context, "مسلسلات", Icons.video_library, 3, const [Color(0xFF00B4DB), Color(0xFF0083B0)], isMobile),
        _buildStaticCard(context, "المفضلة", Icons.favorite, 4, const [Color(0xFFFF416C), Color(0xFFFF4B2B)], isMobile),
      ];

      if (isMobile) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.4,
          children: staticCards,
        );
      } else {
        return Row(
          children: staticCards.map((w) => Expanded(child: w)).toList(),
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
