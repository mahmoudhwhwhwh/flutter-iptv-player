import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ذاكرة صور أكبر تقلل إعادة تحميل شعارات Xtream أثناء التنقل بين الأقسام.
  PaintingBinding.instance.imageCache.maximumSize = 260;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 96 << 20;
  unawaited(_restoreStartupOrientation());
  unawaited(_initializeFirebaseInBackground());
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IPTVProvider()..init()),
      ],
      child: const LiveFootballApp(),
    ),
  );
}

Future<void> _restoreStartupOrientation() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedOrient = prefs.getString('app_orientation') ?? 'تلقائي';
    if (savedOrient == 'أفقي') {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else if (savedOrient == 'عمودي') {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    }
  } catch (_) {}
}

Future<void> _initializeFirebaseInBackground() async {
  try {
    await Firebase.initializeApp();
    appAnalytics = FirebaseAnalytics.instance;
  } catch (_) {}
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
          locale: Locale(themeProvider.appLanguage == 'English' ? 'en' : 'ar'),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: themeProvider.themeBackground,
            colorScheme: ColorScheme.dark(
              primary: themeProvider.accentColor,
              secondary: themeProvider.accentColor,
              surface: themeProvider.themeSurface,
              background: themeProvider.themeBackground,
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
            colorScheme: ColorScheme.light(
              primary: themeProvider.accentColor,
              secondary: themeProvider.accentColor,
              surface: Colors.white,
              background: const Color(0xFFF7F5FF),
            ),
            textTheme: GoogleFonts.cairoTextTheme().apply(
              bodyColor: const Color(0xFF17122F),
              displayColor: const Color(0xFF17122F),
            ),
          ),
      builder: (context, child) {
        return Directionality(
          textDirection: themeProvider.appLanguage == 'English' ? TextDirection.ltr : TextDirection.rtl,
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
                          const Icon(Icons.warning_amber_rounded, color: PremiumPalette.violet, size: 80),
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
            body: Center(child: CircularProgressIndicator(color: PremiumPalette.violet)),
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
      backgroundColor: const Color(0xFF090A12),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 80 : 56),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(isMobile ? 28 : 36, isMobile ? 38 : 46, isMobile ? 28 : 36, isMobile ? 34 : 42),
                decoration: BoxDecoration(
                  color: const Color(0xFF050509),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF2A2A38), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          width: isMobile ? 58 : 66,
                          height: isMobile ? 58 : 66,
                          decoration: const BoxDecoration(color: Color(0xFFA855F7), shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 38),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            "LIVE STREAM PREMIUM",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 48 : 58),
                    if (provider.lastError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.55)),
                        ),
                        child: Text(provider.lastError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ),
                    TextField(
                      controller: _codeController,
                      obscureText: _obscureCode,
                      style: TextStyle(color: Colors.white, fontSize: isMobile ? 18 : 20),
                      decoration: InputDecoration(
                        hintText: "أدخل كود الاشتراك",
                        hintStyle: const TextStyle(color: Color(0xFF74747E), fontSize: 18),
                        prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFFD1D1D5), size: 30),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureCode ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFFD1D1D5), size: 30),
                          onPressed: () => setState(() => _obscureCode = !_obscureCode),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF15151B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 23),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFFA855F7), width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: isMobile ? 68 : 74,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF7C2CEB), Color(0xFFA855F7)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () async {
                                  final success = await provider.loginWithCode(_codeController.text);
                                  if (success) FocusScope.of(context).unfocus();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.transparent,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          ),
                          child: provider.isLoading
                              ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text("تسجيل الدخول", style: TextStyle(fontSize: 25, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    const Center(
                      child: Text("تابعنا على Telegram", style: TextStyle(color: Color(0xFFB7B7C1), fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _launchURL("https://t.me/+f9NsIzGjN_hjYWRi"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFA855F7),
                            side: const BorderSide(color: Color(0xFFA855F7)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.telegram_rounded, size: 20),
                          label: const Text("القناة الرسمية", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _launchURL("https://t.me/+uryaRDBEm4lmYWZi"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF211B2E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFC857), size: 20),
                          label: const Text("قناة الاشتراك", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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

  @override
  void initState() {
    super.initState();
    _showWelcomeAfterLogin();
  }

  Future<void> _openTelegram(String link) async {
    final uri = Uri.parse(link);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showWelcomeAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final showWelcome = prefs.getBool('show_welcome_after_login') ?? false;
    if (!showWelcome) return;
    await prefs.remove('show_welcome_after_login');
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<IPTVProvider>(context, listen: false);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
            decoration: BoxDecoration(
              color: const Color(0xFF11111B),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFA855F7), width: 1.3),
              boxShadow: [BoxShadow(color: const Color(0xFFA855F7).withOpacity(0.18), blurRadius: 28, spreadRadius: 2)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(color: Color(0xFFA855F7), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 50),
                ),
                const SizedBox(height: 18),
                const Text('أهلاً بك في LIVE STREAM PREMIUM', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  provider.subscriptionType.isEmpty ? 'تم تفعيل اشتراكك بنجاح' : 'اشتراكك: ${provider.subscriptionType}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFC8C8D0), fontSize: 15),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openTelegram('https://t.me/+f9NsIzGjN_hjYWRi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA855F7),
                          side: const BorderSide(color: Color(0xFFA855F7)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.telegram_rounded, size: 19),
                        label: const Text('القناة الرسمية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openTelegram('https://t.me/+uryaRDBEm4lmYWZi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF251B36),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFC857), size: 19),
                        label: const Text('قناة الاشتراك', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA855F7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('ابدأ المشاهدة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

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
    final colorScheme = Theme.of(context).colorScheme;
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
      backgroundColor: colorScheme.background,
      drawer: _buildReferenceDrawer(context, provider, showMoviesSeries),
      appBar: AppBar(
        toolbarHeight: 78,
        backgroundColor: colorScheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: "القائمة",
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 33),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const Expanded(
              child: Text(
                "LIVE STREAM PREMIUM",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 0.45),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 1.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("PREMIUM", style: TextStyle(color: Color(0xFFFFC857), fontSize: 13, fontWeight: FontWeight.w800)),
                  SizedBox(width: 5),
                  Icon(Icons.star_rounded, color: Color(0xFFFFC857), size: 19),
                ],
              ),
            ),
            IconButton(
              tooltip: "بحث",
              icon: const Icon(Icons.search_rounded, color: Colors.white, size: 31),
              onPressed: () => updateIndex(1),
            ),
            IconButton(
              tooltip: "الإعدادات",
              icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 29),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
      ),
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: _buildContent(),
        ),
      ),
      bottomNavigationBar: useBottomNav
          ? BottomNavigationBar(
              currentIndex: localIndex,
              onTap: (val) => updateIndex(tabs[val]['index']),
              backgroundColor: colorScheme.background,
              selectedItemColor: colorScheme.primary,
              unselectedItemColor: const Color(0xFFB7B7C1),
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
              elevation: 0,
              items: tabs.map((t) => BottomNavigationBarItem(icon: Icon(t['icon'], size: 28), label: t['label'])).toList(),
            )
          : null,
    );
  }

  Widget _buildReferenceDrawer(BuildContext context, IPTVProvider provider, bool showMoviesSeries) {
    final accent = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    Widget entry({required IconData icon, required String label, required int index}) {
      final bool selected = _selectedIndex == index;
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
        leading: Icon(icon, color: selected ? accent : const Color(0xFFD0D0D7), size: 31),
        title: Text(label, style: TextStyle(color: selected ? accent : const Color(0xFFD0D0D7), fontSize: 21, fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
        onTap: () {
          Navigator.pop(context);
          updateIndex(index);
        },
      );
    }

    final profileImage = provider.profileImagePath.isNotEmpty && File(provider.profileImagePath).existsSync()
        ? FileImage(File(provider.profileImagePath))
        : null;

    return Drawer(
      width: 340,
      backgroundColor: surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A37),
                      shape: BoxShape.circle,
                      image: profileImage == null ? null : DecorationImage(image: profileImage, fit: BoxFit.cover),
                    ),
                    child: profileImage == null
                        ? Icon(
                            provider.profileLogo == 'star'
                                ? Icons.star_rounded
                                : provider.profileLogo == 'shield'
                                    ? Icons.shield_rounded
                                    : provider.profileLogo == 'bolt'
                                        ? Icons.bolt_rounded
                                        : Icons.play_arrow_rounded,
                            color: const Color(0xFFA855F7),
                            size: 44,
                          )
                        : null,
                  ),
                  const SizedBox(width: 17),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(provider.profileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                        SizedBox(height: 11),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFA855F7), width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("PREMIUM", style: TextStyle(color: Color(0xFFFFC857), fontSize: 12, fontWeight: FontWeight.w800)),
                              SizedBox(width: 4),
                              Icon(Icons.star_rounded, color: Color(0xFFFFC857), size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2C2D38), height: 1),
            const SizedBox(height: 12),
            entry(icon: Icons.home_rounded, label: "الرئيسية", index: 0),
            entry(icon: Icons.live_tv_rounded, label: "قنوات مباشرة", index: 1),
            if (showMoviesSeries) entry(icon: Icons.movie_rounded, label: "الأفلام", index: 2),
            if (showMoviesSeries) entry(icon: Icons.video_library_rounded, label: "المسلسلات", index: 3),
            entry(icon: Icons.favorite_rounded, label: "المفضلة", index: 4),
            const Divider(color: Color(0xFF2C2D38), height: 34),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
              leading: const Icon(Icons.settings_rounded, color: Color(0xFFD0D0D7), size: 31),
              title: const Text("الإعدادات", style: TextStyle(color: Color(0xFFD0D0D7), fontSize: 21, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
              leading: const Icon(Icons.telegram_rounded, color: Color(0xFFA855F7), size: 31),
              title: const Text("القناة الرسمية", style: TextStyle(color: Color(0xFFD0D0D7), fontSize: 21, fontWeight: FontWeight.w500)),
              onTap: () => _openTelegram('https://t.me/+f9NsIzGjN_hjYWRi'),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
              leading: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFC857), size: 31),
              title: const Text("قناة الاشتراك", style: TextStyle(color: Color(0xFFD0D0D7), fontSize: 21, fontWeight: FontWeight.w500)),
              onTap: () => _openTelegram('https://t.me/+uryaRDBEm4lmYWZi'),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
              leading: const Icon(Icons.support_agent_rounded, color: Color(0xFFD0D0D7), size: 31),
              title: const Text("الدعم والمساعدة", style: TextStyle(color: Color(0xFFD0D0D7), fontSize: 21, fontWeight: FontWeight.w500)),
              onTap: () => _openTelegram('https://t.me/+uryaRDBEm4lmYWZi'),
            ),
            const Spacer(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 17),
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFD0D0D7), size: 31),
              title: const Text("تسجيل خروج", style: TextStyle(color: Color(0xFFD0D0D7), fontSize: 21, fontWeight: FontWeight.w500)),
              onTap: provider.logout,
            ),
          ],
        ),
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

  Future<void> _startScrolling() async {
    // حركة واحدة متواصلة بدلاً من مؤقّت يعيد بناء الواجهة 20 مرة في الثانية.
    while (mounted) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) continue;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) continue;
      await _scrollController.animateTo(
        maxScroll,
        duration: const Duration(seconds: 18),
        curve: Curves.linear,
      );
      if (mounted && _scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
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
    final provider = Provider.of<IPTVProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final liveItems = provider.allStreams
        .where((item) => item.type == 'live' || item.type == 'channel' || item.type.isEmpty)
        .take(12)
        .toList();
    final movieItems = provider.allStreams.where((item) => item.type == 'movie').take(12).toList();
    final seriesItems = provider.allStreams.where((item) => item.type == 'series').take(12).toList();

    return Container(
      color: Theme.of(context).colorScheme.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BannerSliderWidget(),
            Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, 18, isMobile ? 14 : 24, 0),
              child: _buildQuickAccessRow(context),
            ),
            _buildReferenceSection(
              context: context,
              provider: provider,
              title: 'قنوات مباشرة رائجة',
              items: liveItems,
              tabIndex: 1,
              isSeries: false,
              cardWidth: isMobile ? 126 : 166,
              cardHeight: isMobile ? 154 : 198,
            ),
            if (provider.showMoviesSeries)
              _buildReferenceSection(
                context: context,
                provider: provider,
                title: 'أحدث الأفلام',
                items: movieItems,
                tabIndex: 2,
                isSeries: false,
                cardWidth: isMobile ? 118 : 152,
                cardHeight: isMobile ? 174 : 226,
              ),
            if (provider.showMoviesSeries)
              _buildReferenceSection(
                context: context,
                provider: provider,
                title: 'أحدث المسلسلات',
                items: seriesItems,
                tabIndex: 3,
                isSeries: true,
                cardWidth: isMobile ? 118 : 152,
                cardHeight: isMobile ? 174 : 226,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessRow(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final entries = <({String english, String arabic, IconData icon, int index})>[
      (english: 'LIVE', arabic: 'قنوات مباشرة', icon: Icons.live_tv_rounded, index: 1),
      (english: 'MOVIES', arabic: 'أفلام', icon: Icons.movie_rounded, index: 2),
      (english: 'SERIES', arabic: 'مسلسلات', icon: Icons.video_library_rounded, index: 3),
      (english: 'FAVOURITES', arabic: 'المفضلة', icon: Icons.favorite_rounded, index: 4),
    ];

    return SizedBox(
      height: 132,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            Expanded(
              child: ScaleOnFocus(
                autofocus: i == 0,
                onTap: () => context.findAncestorStateOfType<_MainDashboardState>()?.updateIndex(entries[i].index),
                child: Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withOpacity(0.22)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(entries[i].icon, color: accent, size: 38),
                        const SizedBox(height: 9),
                        Text(entries[i].english, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.45)),
                        const SizedBox(height: 3),
                        Text(entries[i].arabic, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC0C0CA), fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (i < entries.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildReferenceSection({
    required BuildContext context,
    required IPTVProvider provider,
    required String title,
    required List<PlaylistItem> items,
    required int tabIndex,
    required bool isSeries,
    required double cardWidth,
    required double cardHeight,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))),
                TextButton(
                  onPressed: () => context.findAncestorStateOfType<_MainDashboardState>()?.updateIndex(tabIndex),
                  child: Text('عرض الكل', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              reverse: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: cardWidth,
                child: buildStreamCardLocal(context, provider, items[index], isSeries: isSeries, isMobile: true),
              ),
            ),
          ),
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
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  // الروابط الجديدة
  List<String> _banners = [];
  bool _isLoadingBanners = true;

  Future<void> _fetchBanners() async {
    try {
      final url = Uri.parse("https://iptv-subscription-api.tvkora56.workers.dev/v1/slider?t=${DateTime.now().millisecondsSinceEpoch}");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final List<dynamic> data = await Isolate.run(() => json.decode(res.body));
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
          _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
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
    final bannerHeight = isMobile ? 238.0 : (screenW < 900 ? 330.0 : 440.0);

    if (_isLoadingBanners) {
      return SizedBox(
        height: bannerHeight,
        child: const Center(child: CircularProgressIndicator(color: Color(0xFFA855F7))),
      );
    }
    if (_banners.isEmpty) {
      return SizedBox(height: bannerHeight);
    }

    final dotCount = _banners.length > 10 ? 10 : _banners.length;
    return SizedBox(
      height: bannerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _banners[index],
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: (_, __) => const ColoredBox(color: Color(0xFF171324)),
                    errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF171324)),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.38, 1],
                        colors: [Colors.transparent, Color(0xE6000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: isMobile ? 20 : 34,
                    left: isMobile ? 20 : 34,
                    bottom: isMobile ? 42 : 58,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIVE STREAM PREMIUM',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: isMobile ? 28 : 38, fontWeight: FontWeight.w500, letterSpacing: 0.2),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'استمتع بأفضل القنوات والأفلام والمسلسلات',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: const Color(0xFFE5E5EA), fontSize: isMobile ? 16 : 21, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: isMobile ? 8 : 13,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFF9A7612).withOpacity(0.82), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(dotCount, (index) {
                    final isActive = (_currentPage % dotCount) == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 110),
                      width: isActive ? 24 : 9,
                      height: 9,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }),
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
// STREAMS LIST (Responsive Grid - Compact)
// -----------------------------------------------------------------------------
class StreamsListScreen extends StatelessWidget {
  final String title;
  final String tab;
  final bool isSeries;

  const StreamsListScreen({super.key, required this.title, required this.tab, this.isSeries = false});

  int _getCrossAxisCount(double width) {
    if (width < 600) return tab == 'live' ? 2 : 3;
    if (width < 900) return tab == 'live' ? 3 : 4;
    if (width < 1200) return 5;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);
    final accent = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final streams = provider.streams;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;
    final categories = <String>['الكل', ...provider.categories];

    return Container(
      color: Theme.of(context).colorScheme.background,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 10),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(child: Text(title, style: TextStyle(fontSize: isMobile ? 25 : 31, fontWeight: FontWeight.w800, color: Colors.white))),
                SizedBox(
                  width: isMobile ? 138 : 240,
                  height: 43,
                  child: TextField(
                    onChanged: provider.setSearchQuery,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'بحث...',
                      hintStyle: const TextStyle(color: Color(0xFFB6B7C2), fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: accent, size: 22),
                      filled: true,
                      fillColor: surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 55,
            child: ListView.separated(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final category = categories[index];
                final categoryId = index == 0 ? 'all' : category;
                final selected = provider.selectedCategory == categoryId;
                return ScaleOnFocus(
                  autofocus: index == 0,
                  onTap: () async {
                    if (provider.isCategoryLocked(category)) {
                      final allowed = await showPinDialog(context, provider);
                      if (!allowed) return;
                      provider.unlockCategorySession(category);
                    }
                    provider.setCategory(categoryId);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? accent : surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: selected ? accent : accent.withOpacity(0.22)),
                    ),
                    child: Text(category, style: TextStyle(color: selected ? Colors.white : const Color(0xFFD2D2DA), fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: provider.isFetchingData
                ? Center(child: CircularProgressIndicator(color: accent))
                : GridView.builder(
                    padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, 8, isMobile ? 14 : 24, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _getCrossAxisCount(screenW),
                      childAspectRatio: tab == 'live' ? 0.90 : 0.64,
                      crossAxisSpacing: isMobile ? 12 : 16,
                      mainAxisSpacing: isMobile ? 14 : 18,
                    ),
                    itemCount: streams.length,
                    itemBuilder: (context, index) => buildStreamCardLocal(context, provider, streams[index], isSeries: isSeries, isMobile: isMobile),
                  ),
          ),
        ],
      ),
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
      final provider = Provider.of<IPTVProvider>(context, listen: false);
      final activePlaylist = provider.savedPlaylists.firstWhere((p) => p.id == provider.activePlaylistId);
      final s = widget.series;
      var seriesId = s.streamId.replaceAll('series_', '');
      
      String host = activePlaylist.host ?? "";
      if (host.endsWith('/')) host = host.substring(0, host.length - 1);
      String username = activePlaylist.username ?? "";
      String password = activePlaylist.password ?? "";
      
      if (host.isNotEmpty && username.isNotEmpty && password.isNotEmpty) {
          final url = "$host/player_api.php?username=$username&password=$password&action=get_series_info&series_id=$seriesId";
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final data = await Isolate.run(() => json.decode(response.body));
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

    
    final activePlaylist = provider.savedPlaylists.firstWhere((p) => p.id == provider.activePlaylistId);
    String host = activePlaylist.host ?? "";
    if (host.endsWith('/')) host = host.substring(0, host.length - 1);
    String user = activePlaylist.username ?? "";
    String pass = activePlaylist.password ?? "";

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
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: PremiumPalette.violet)));
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
                                backgroundColor: PremiumPalette.violet,
                                foregroundColor: Colors.white,
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
  final bool autofocus;

  const ScaleOnFocus({
    super.key,
    required this.child,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<ScaleOnFocus> createState() => _ScaleOnFocusState();
}

class _ScaleOnFocusState extends State<ScaleOnFocus> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  void _setFocus(bool hasFocus) {
    if (_isFocused != hasFocus && mounted) setState(() => _isFocused = hasFocus);
    if (hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            alignment: 0.5,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tvBoxFocusEnabled = context.select<IPTVProvider, bool>((provider) => provider.tvBoxFocusEnabled);
    return InkWell(
      focusNode: _focusNode,
      canRequestFocus: tvBoxFocusEnabled,
      autofocus: widget.autofocus && tvBoxFocusEnabled,
      onTap: widget.onTap,
      onFocusChange: _setFocus,
      onHover: (isHovering) {
        if (isHovering && _focusNode.canRequestFocus) _focusNode.requestFocus();
        _setFocus(isHovering || _focusNode.hasFocus);
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedScale(
        scale: _isFocused ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
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
  final accent = Theme.of(context).colorScheme.primary;
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
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: isMobile ? 300 : 420,
                  maxWidthDiskCache: isMobile ? 300 : 420,
                  fadeInDuration: const Duration(milliseconds: 80),
                  placeholder: (context, url) => Container(color: Colors.white10, child: Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2))),
                  errorWidget: (context, url, error) => Container(color: Colors.white10, child: const Icon(Icons.movie, size: 40, color: Colors.white24)),
                )
              : Container(color: Colors.white10, child: const Icon(Icons.movie, size: 40, color: Colors.white24)),
          // Gradient Name Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 7 : 9, vertical: isMobile ? 8 : 10),
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
                style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.w700, color: Colors.white),
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
                  color: isFav ? accent : Colors.white,
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
        _buildStaticCard(context, "بث مباشر", Icons.live_tv, 1, const [PremiumPalette.violet, Color(0xFF5B258A)], isMobile),
        if (showMoviesSeries)
          _buildStaticCard(context, "أفلام", Icons.movie, 2, const [Color(0xFF9B59B6), Color(0xFF6D3586)], isMobile),
        if (showMoviesSeries)
          _buildStaticCard(context, "مسلسلات", Icons.video_library, 3, const [Color(0xFFA78BFA), Color(0xFF7C3AED)], isMobile),
        _buildStaticCard(context, "المفضلة", Icons.favorite, 4, const [Color(0xFF8E44AD), Color(0xFF5B258A)], isMobile),
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
