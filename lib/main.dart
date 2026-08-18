import 'dart:async';
import 'dart:ui';
import 'dart:convert';
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
            scaffoldBackgroundColor: Colors.white,
            colorScheme: ColorScheme.light(
              primary: themeProvider.accentColor,
              secondary: themeProvider.accentColor,
            ),
            textTheme: GoogleFonts.cairoTextTheme(),
          ),
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
    final provider = Provider.of<IPTVProvider>(context);
    if (provider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: PremiumPalette.violet),
        ),
      );
    }
    if (provider.isVersionBlocked) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, color: Colors.red, size: 80),
                const SizedBox(height: 24),
                Text(
                  provider.remoteBlockMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const LoginScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumPalette.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.tv, color: PremiumPalette.violet, size: 100),
              const SizedBox(height: 40),
              const Text(
                'LIVE STREAM PREMIUM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _codeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'أدخل كود الدخول',
                  hintStyle: const TextStyle(color: PremiumPalette.textMuted),
                  filled: true,
                  fillColor: PremiumPalette.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.vpn_key, color: PremiumPalette.violet),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumPalette.violet,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'دخول',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_codeController.text.isEmpty) return;
    setState(() => _isLoading = true);
    final success = await Provider.of<IPTVProvider>(context, listen: false).loginWithCode(_codeController.text);
    setState(() => _isLoading = false);
    if (!success) {
      final error = Provider.of<IPTVProvider>(context, listen: false).lastError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'كود غير صحيح')),
      );
    }
  }
}
