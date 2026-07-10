import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'providers/iptv_provider.dart';
import 'models/playlist_item.dart';
import 'screens/player_screen.dart';

// Global reference for analytics tracking (will remain null if firebase is not initialized)
FirebaseAnalytics? appAnalytics;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase gracefully (fails silently if google-services.json is missing or invalid)
  try {
    await Firebase.initializeApp();
    appAnalytics = FirebaseAnalytics.instance;
    await appAnalytics?.logAppOpen();
  } catch (e) {
    debugPrint("Firebase/Analytics initialization skipped or failed: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IPTVProvider()),
      ],
      child: const IPTVApp(),
    ),
  );
}

class TVFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isSelected;
  final double scale;
  final BorderRadius? borderRadius;

  const TVFocusable({
    super.key,
    required this.child,
    required this.onTap,
    this.isSelected = false,
    this.scale = 1.05,
    this.borderRadius,
  });

  @override
  State<TVFocusable> createState() => _TVFocusableState();
}

class _TVFocusableState extends State<TVFocusable> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final hasHighlight = _isFocused || widget.isSelected;
    return Focus(
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius ?? widget.borderRadius,
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class IPTVApp extends StatelessWidget {
  const IPTVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Stream Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF09090B),
        cardColor: const Color(0xFF18181B),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const IPTVMainNavigator(),
    );
  }
}

class IPTVMainNavigator extends StatefulWidget {
  const IPTVMainNavigator({super.key});

  @override
  State<IPTVMainNavigator> createState() => _IPTVMainNavigatorState();
}

class _IPTVMainNavigatorState extends State<IPTVMainNavigator> {
  final _m3uUrlController = TextEditingController();
  final _m3uTextController = TextEditingController();
  final _xtreamHostController = TextEditingController();
  final _xtreamUserController = TextEditingController();
  final _xtreamPassController = TextEditingController();
  final _playlistNameController = TextEditingController();
  final _searchController = TextEditingController();

  Timer? _expirationCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeDialogIfNeeded();
    });
    _expirationCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        final provider = Provider.of<IPTVProvider>(context, listen: false);
        if (provider.isLoggedIn && provider.isExpired) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _expirationCheckTimer?.cancel();
    _m3uUrlController.dispose();
    _m3uTextController.dispose();
    _xtreamHostController.dispose();
    _xtreamUserController.dispose();
    _xtreamPassController.dispose();
    _playlistNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  final _activationController = TextEditingController();
  bool _loginError = false;
  String _errorMessage = "";
  bool _obscureActivationCode = true;

  void _launchTelegram() async {
    // Dynamic URL loading (Telegram support)
    final url = ""; 
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showWelcomeDialogIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final welcomed = prefs.getBool('shown_welcome_pro_v3_main') ?? false;
    final provider = Provider.of<IPTVProvider>(context, listen: false);
    if (!welcomed && provider.isLoggedIn && !provider.isExpired) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF27272A)),
            ),
            title: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.blueAccent, size: 28),
                const SizedBox(width: 10),
                const Text(
                  "أهلاً بك في live strem pro",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                )
              ],
            ),
            content: const Text(
              "مرحباً بك في النسخة المدفوعة والآمنة بالكامل. نتمنى لك تجربة ممتعة وقنوات مستقرة تليق باختيارك.\n\nيرجى الاشتراك في قناة التلقرام الرسمية ليصلك كل جديد من تحديثات وسيرفرات إضافية بانتظام.",
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.6),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _launchTelegram();
                },
                child: const Text("انضمام للتلكرام", style: TextStyle(color: Colors.blueAccent)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  await prefs.setBool('shown_welcome_pro_v3_main', true);
                  if (mounted && context.mounted) Navigator.of(context).pop();
                },
                child: const Text("دخول التطبيق"),
              )
            ],
          );
        }
      );
    }
  }

  Widget _buildVersionBlockScreen(IPTVProvider provider) {
    return Scaffold(
      backgroundColor: const Color(0xFF6E6E6E), // Solid medium-dark grey background as shown in image
      body: Center(
        child: Container(
          width: 310, // Standard AlertDialog width on mobile screens
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4), // Slightly rounded corners like standard Android dialog
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content: Dynamic block message from blocked_versions.json
              Text(
                provider.remoteBlockMessage,
                style: const TextStyle(
                  color: Color(0xFF212121), // Dark charcoal black text
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              // Action buttons: "CLOSE" at bottom right
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF757575), // Medium grey text like in the image
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      // Exit application when CLOSE is clicked
                      SystemNavigator.pop();
                    },
                    child: const Text(
                      "CLOSE",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVpnBlockScreen(IPTVProvider provider) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_rounded, color: Colors.redAccent, size: 64),
              const SizedBox(height: 20),
              const Text(
                "تم اكتشاف اتصال VPN نشط ⚠️",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "عذراً، تشغيل التطبيق أثناء استخدام شبكة الـ VPN أو البروكسي غير مسموح به لضمان استقرار البث والامتثال لمعايير الأمان وحماية اشتراكك السحابي.",
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("إعادة الفحص والتحقق / RETRY"),
                  onPressed: () {
                    provider.retryVpnCheck();
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Color(0xFF27272A)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: const Text("إغلاق التطبيق / EXIT"),
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnifferBlockScreen(IPTVProvider provider) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300), // Pure Canary Yellow
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withOpacity(0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    )
                  ],
                ),
                padding: const EdgeInsets.all(28),
                child: CustomPaint(
                  size: const Size(80, 80),
                  painter: HummingbirdPainter(),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "يرجى حذف تطبيق كناري للاستمرار التطبيق في العمل",
                style: TextStyle(
                  color: Colors.black, 
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              const Text(
                "تم كشف بيئة تشغيل غير آمنة أو تطبيق لتسجيل وتحليل البيانات (HttpCanary). يرجى إزالة التطبيق لإكمال تصفح القنوات الآمنة وحماية حسابك.",
                style: TextStyle(
                  color: Colors.black54, 
                  fontSize: 13, 
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text(
                    "إعادة فحص الأمان / Check Again",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    provider.checkSecurity();
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 240,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black54,
                    side: const BorderSide(color: Colors.black12),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  child: const Text(
                    "إغلاق التطبيق / Exit",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredSubscriptionScreen(IPTVProvider provider) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_disabled_rounded, color: Colors.orangeAccent, size: 64),
              const SizedBox(height: 20),
              const Text(
                "انتهت مدة صلاحية الكود ⚠️",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "عذراً، رمز التفعيل المستخدم (${provider.activationCode}) قد انتهت صلاحيته بالكامل.\nيرجى تجديد الباقة أو التواصل معنا للحصول على كود جديد.",
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088CC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text("انضم لقناة كود بلا حدود تيليجرام"),
                  onPressed: _launchTelegram,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Color(0xFF27272A)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text("تسجيل الخروج واستخدام كود آخر"),
                  onPressed: () {
                    provider.logout();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);

    if (provider.isVersionBlocked) {
      return _buildVersionBlockScreen(provider);
    }

    if (provider.vpnDetected) {
      return _buildVpnBlockScreen(provider);
    }

    if (provider.snifferDetected) {
      return _buildSnifferBlockScreen(provider);
    }

    // Displays a beautiful, premium splash/loading screen first if provider is initializing
    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F12),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: Color(0xFFFFB300),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "جاري تهيئة الاشتراك والبيانات...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.isLoggedIn && provider.isExpired) {
      return _buildExpiredSubscriptionScreen(provider);
    }

    if (!provider.isLoggedIn) {
      return _buildLoginWall(provider);
    }

    // Schedule the welcome dialog to show once on successful login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeDialogIfNeeded();
    });

    Widget activeView;
    if (provider.isLoading) {
      activeView = const Center(
        child: CircularProgressIndicator(
          color: Colors.blueAccent,
          strokeWidth: 3,
        ),
      );
    } else if (provider.activeTab == "playlists") {
      activeView = _buildPlaylistsSetup(provider);
    } else if (provider.activeTab == "custom_pro") {
      activeView = _buildLiveStreamProScreen(provider);
    } else {
      activeView = _buildStreamsDashboard(provider);
    }

    return Scaffold(
      body: Row(
        children: [
          if (MediaQuery.of(context).size.width >= 600) _buildSidebar(provider),
          Expanded(
            child: activeView,
          ),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 600
          ? _buildBottomBar(provider)
          : null,
    );
  }

  Widget _buildLoginWall(IPTVProvider provider) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF27272A)),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.08),
                  blurRadius: 30,
                  spreadRadius: 2,
                )
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.indigoAccent]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 1,
                      )
                    ]
                  ),
                  child: const Icon(Icons.tv_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  "live strem pro",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                const Text(
                  "مشغل ذكي متكامل القنوات والمحتوى",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 24),

                if (_loginError)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage.isNotEmpty ? _errorMessage : "فشل تسجيل الدخول، تأكد من الرمز والمحاولة.",
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(bottom: 6),
                  child: const Text(
                    "رمز التفعيل السريع / Activation Code",
                    style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                TextField(
                  controller: _activationController,
                  obscureText: _obscureActivationCode,
                  style: const TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: "أدخل كود لروية القنوات الفورية",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 0),
                    prefixIcon: const Icon(Icons.vpn_key_rounded, color: Colors.blueAccent, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureActivationCode ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureActivationCode = !_obscureActivationCode;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFF09090B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF27272A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      final code = _activationController.text.trim();
                      if (code.isEmpty) {
                        setState(() {
                          _loginError = true;
                          _errorMessage = "الرجاء كتابة كود التفعيل أولاً.";
                        });
                        return;
                      }
                      setState(() {
                        _loginError = false;
                      });

                      bool success = await provider.loginWithActivation(code);

                      if (!success) {
                        setState(() {
                          _loginError = true;
                          _errorMessage = "كود التفعيل غير صحيح، يرجى المحاولة مرة أخرى.";
                        });
                      }
                    },
                    child: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "دخول التطبيق / ENTER APP",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0088CC),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 22, color: Colors.white),
                    label: const Text(
                      "قناة التلكرام الرسمية / TELEGRAM",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _launchTelegram,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutItem(IPTVProvider provider) {
    return InkWell(
      onTap: () async {
        await provider.logout();
      },
      borderRadius: BorderRadius.circular(12),
      focusColor: Colors.redAccent.withOpacity(0.25),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "تسجيل الخروج / Logout",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(IPTVProvider provider) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F12),
        border: Border(right: BorderSide(color: Color(0xFF27272A))),
      ),
      child: Column(
        children: [
          _buildLogoHeader(),
          const Divider(color: Color(0xFF27272A)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                _buildNavItem(provider, "live", Icons.live_tv_rounded, "البث المباشر / Live TV"),
                _buildNavItem(provider, "favorites", Icons.favorite_rounded, "المفضلة / My Favorites ❤️"),
                const Divider(color: Color(0xFF27272A), height: 32),
                _buildLogoutItem(provider),
              ],
            ),
          ),
          _buildActivePlaylistBadge(provider),
        ],
      ),
    );
  }

  Widget _buildBottomBar(IPTVProvider provider) {
    int getIndex() {
      switch (provider.activeTab) {
        case "live": return 0;
        case "favorites": return 1;
        default: return 0;
      }
    }

    return BottomNavigationBar(
      currentIndex: getIndex(),
      onTap: (idx) {
        final tabs = ["live", "favorites"];
        provider.setTab(tabs[idx]);
      },
      backgroundColor: const Color(0xFF0F0F12),
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 9,
      unselectedFontSize: 9,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.live_tv_rounded, size: 20), label: "البث المباشر"),
        BottomNavigationBarItem(icon: Icon(Icons.favorite, size: 20, color: Colors.redAccent), label: "المفضلة"),
      ],
    );
  }

  Widget _buildNavItem(IPTVProvider provider, String tabId, IconData icon, String title) {
    final isSelected = provider.activeTab == tabId;
    return InkWell(
      onTap: () => provider.setTab(tabId),
      borderRadius: BorderRadius.circular(12),
      focusColor: Colors.blueAccent.withOpacity(0.25),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blueAccent.withOpacity(0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey[400], size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[300],
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.blue, Colors.indigo]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tv_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "IPTV PRO PLAYER",
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
              Text(
                "AUTOMATED ENGINE",
                style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionChip(IPTVProvider provider) {
    if (!provider.isLoggedIn) return const SizedBox.shrink();
    
    final remainingHours = provider.subscriptionHoursRemaining;
    String timeText = "";
    Color chipColor = Colors.greenAccent;
    IconData icon = Icons.verified_user_rounded;

    if (remainingHours > 5000) {
      timeText = "مدى الحياة / Lifetime 🛡️";
      chipColor = Colors.amberAccent;
      icon = Icons.security_rounded;
    } else {
      final days = (remainingHours / 24).floor();
      final hours = (remainingHours % 24).floor();
      final mins = ((remainingHours * 60) % 60).floor();
      
      if (days > 0) {
        timeText = "$days يوم و $hours ساعة";
        chipColor = Colors.blueAccent;
      } else if (hours > 0) {
        timeText = "$hours ساعة و $mins دقيقة";
        chipColor = Colors.orangeAccent;
        icon = Icons.timer_outlined;
      } else {
        timeText = "$mins دقيقة متبقية";
        chipColor = Colors.redAccent;
        icon = Icons.timer_outlined;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: chipColor, size: 11),
          const SizedBox(width: 4),
          Text(
            timeText,
            style: TextStyle(
              color: chipColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePlaylistBadge(IPTVProvider provider) {
    final activeId = provider.activePlaylistId;
    final activeList = provider.savedPlaylists.firstWhere(
      (p) => p.id == activeId,
      orElse: () => UserPlaylist(id: '', name: 'مستعرض افتراضي', type: ''),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF040406),
        border: Border(top: BorderSide(color: Color(0xFF1E1E24))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("المصدر النشط / ACTIVE", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            activeList.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          if (provider.isLoggedIn) ...[
            const SizedBox(height: 12),
            const Text("حالة الاشتراك / SUBSCRIPTION", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _buildSubscriptionChip(provider),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamsDashboard(IPTVProvider provider) {
    if (provider.streams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_collection_outlined, size: 60, color: Colors.grey[700]),
              const SizedBox(height: 16),
              const Text(
                "قائمة القنوات والملفات فارغة",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "الرجاء إضافة ملف M3U أو روابط مخصصة من تبويب 'المنصات' لتفعيل خدمات البث",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => provider.setTab("playlists"),
                icon: const Icon(Icons.add),
                label: const Text("تهيئة مصادر القنوات والاشتراكات"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => provider.loadDemoPlaylist(),
                icon: const Icon(Icons.play_circle_outline, color: Colors.blueAccent),
                label: const Text("استعراض القنوات التجريبية المجانية (NASA/Bloomberg)", style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        ),
      );
    }

    final activeStreams = provider.streams;
    final availableCategories = ["all", ...provider.categories];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 12),
          child: MediaQuery.of(context).size.width < 600
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            provider.activeTab == "live"
                                ? "البث التلفزيوني المباشر / Live TV"
                                : provider.activeTab == "movie"
                                    ? "صالة سينما الأفلام / Movies"
                                    : provider.activeTab == "series"
                                        ? "مسلسلات تلفزيونية / TV Series"
                                        : "المفضلة / My Favorites",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildSubscriptionChip(provider),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "يتوفر ${activeStreams.length} مادة في هذا التبويب",
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => provider.setSearchQuery(val),
                        decoration: InputDecoration(
                          hintText: "بحث عن قناة أو فيلم...",
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                          prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                          fillColor: const Color(0xFF18181C),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          isDense: true,
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF27272A)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.blueAccent),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.activeTab == "live"
                                ? "البث التلفزيوني المباشر / Live TV"
                                : provider.activeTab == "movie"
                                    ? "صالة سينما الأفلام / Movies"
                                    : provider.activeTab == "series"
                                        ? "مسلسلات تلفزيونية / TV Series"
                                        : "المفضلة / My Favorites",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "يتوفر ${activeStreams.length} مادة في هذا التبويب",
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 220,
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => provider.setSearchQuery(val),
                        decoration: InputDecoration(
                          hintText: "بحث عن قناة أو فيلم...",
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                          prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                          fillColor: const Color(0xFF18181C),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          isDense: true,
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF27272A)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.blueAccent),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
        ),

        // Categories scroll bar
        if (availableCategories.length > 1)
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: availableCategories.length,
              itemBuilder: (context, idx) {
                final catName = availableCategories[idx];
                final isSelected = provider.selectedCategory == catName;
                final displayName = catName == "all" ? "كل الأقسام / All" : catName;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TVFocusable(
                    onTap: () => provider.setCategory(catName),
                    isSelected: isSelected,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blueAccent : const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.blueAccent : const Color(0xFF27272A),
                        ),
                      ),
                      child: Text(
                        displayName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[400],
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Grid contents
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width >= 1200
                  ? 6
                  : MediaQuery.of(context).size.width >= 900
                      ? 4
                      : MediaQuery.of(context).size.width >= 600
                          ? 3
                          : 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: provider.activeTab == "live" ? 1.0 : 0.72,
            ),
            itemCount: activeStreams.length,
            itemBuilder: (context, idx) {
              final stream = activeStreams[idx];
              final isFav = provider.favorites.contains(stream.streamId);

              return _buildStreamCard(provider, stream, isFav);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStreamCard(IPTVProvider provider, PlaylistItem stream, bool isFav) {
    final isSelected = provider.currentStream?.streamId == stream.streamId;

    return TVFocusable(
      onTap: () {
        provider.selectStream(stream);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(stream: stream),
          ),
        );
      },
      isSelected: isSelected,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131316),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : const Color(0xFF27272A),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: const Color(0xFF1E1E24),
                    child: stream.streamIcon.isNotEmpty
                        ? Image.network(
                            stream.streamIcon,
                            fit: BoxFit.cover,
                            cacheWidth: 160,
                            cacheHeight: 160,
                            errorBuilder: (context, error, stackTrace) => _buildFallbackPoster(stream),
                          )
                        : _buildFallbackPoster(stream),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stream.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              stream.categoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 9),
                            ),
                          ),
                          if (stream.rating != null)
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  stream.rating!,
                                  style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
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
            Positioned(
              top: 4,
              right: 4,
              child: ClipOval(
                child: Material(
                  color: Colors.black.withOpacity(0.4),
                  child: InkWell(
                    onTap: () => provider.toggleFavorite(stream.streamId),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? Colors.redAccent : Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (stream.type == "live")
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                  child: const Text(
                    "LIVE",
                    style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackPoster(PlaylistItem stream) {
    final icon = stream.type == "movie"
        ? Icons.movie_filter_outlined
        : stream.type == "series"
            ? Icons.collections_bookmark_rounded
            : Icons.live_tv;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blueAccent.withOpacity(0.4), size: 30),
          const SizedBox(height: 4),
          const Text("IPTV LIVE", style: TextStyle(color: Colors.grey, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildPlaylistsSetup(IPTVProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "إدارة مصادر قوائم القنوات / IPTV Sources Manager",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            "اربط اشتراكات ومصادر خدمات ومزودي البث المباشر والمحتوى الترفيهي",
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131316),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TabBar(
                          indicatorColor: Colors.blueAccent,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey,
                          tabs: [
                            Tab(text: "ملف M3U (الصق الكود)"),
                            Tab(text: "محرك البث والبروكسي VIP"),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 320,
                          child: TabBarView(
                            children: [
                              _buildM3uForm(provider),
                              _buildEngineSettingsForm(provider),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131316),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "الحقائب والمصادر المسجلة / Playlists",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      provider.savedPlaylists.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  "لا يوجد قوائم مضافة حتى الآن",
                                  style: TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: provider.savedPlaylists.length,
                              itemBuilder: (context, idx) {
                                final list = provider.savedPlaylists[idx];
                                final isCurrent = provider.activePlaylistId == list.id;

                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isCurrent ? Colors.blueAccent.withOpacity(0.05) : const Color(0xFF1C1C22),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCurrent ? Colors.blueAccent.withOpacity(0.4) : const Color(0xFF27272A),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        list.type == "github" ? Icons.cloud_done_rounded : Icons.playlist_play_rounded,
                                        color: isCurrent ? Colors.blueAccent : Colors.grey[500],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              list.name,
                                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              list.type == "github" ? "سيرفر VIP السحابي" : "M3U List",
                                              style: const TextStyle(color: Colors.grey, fontSize: 9),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isCurrent)
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_outline, color: Colors.grey, size: 18),
                                          onPressed: () => provider.loadPlaylistStreams(list.id),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                        onPressed: () => provider.deletePlaylist(list.id),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFF27272A)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => provider.loadDemoPlaylist(),
                          icon: const Icon(Icons.flash_on_rounded, size: 16),
                          label: const Text("استرجاع البث التجريبي للامتحان"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueAccent,
                            side: const BorderSide(color: Colors.blueAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngineSettingsForm(IPTVProvider provider) {
    return const _AdvancedEngineSettingsWidget();
  }

  Widget _buildLiveStreamProScreen(IPTVProvider provider) {
    return _LiveStreamProScreenWidget(provider: provider);
  }

  Widget _buildM3uForm(IPTVProvider provider) {
    return Column(
      children: [
        TextField(
          controller: _playlistNameController,
          decoration: const InputDecoration(labelText: "اسم قائمة التشغيل الخاص بك", labelStyle: TextStyle(fontSize: 11)),
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _m3uTextController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: "الصق أكواد ملف الـ M3U المنسق هنا:",
            labelStyle: TextStyle(fontSize: 11),
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () {
              if (_playlistNameController.text.isNotEmpty && _m3uTextController.text.isNotEmpty) {
                final list = UserPlaylist(
                  id: "m3u_${DateTime.now().millisecondsSinceEpoch}",
                  name: _playlistNameController.text,
                  type: "m3u",
                );
                provider.addPlaylist(list, m3uContent: _m3uTextController.text);
                _playlistNameController.clear();
                _m3uTextController.clear();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text("حفظ وتفعيل القائمة / SAVE"),
          ),
        ),
      ],
    );
  }

  Widget _buildXtreamForm(IPTVProvider provider) {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            controller: _playlistNameController,
            decoration: const InputDecoration(labelText: "اسم الحساب المستعار", labelStyle: TextStyle(fontSize: 11)),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          TextField(
            controller: _xtreamHostController,
            decoration: const InputDecoration(labelText: "خادم الموزع / Host URL", hintText: "http://host.com:port", labelStyle: TextStyle(fontSize: 11)),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          TextField(
            controller: _xtreamUserController,
            decoration: const InputDecoration(labelText: "اسم المستخدم / User", labelStyle: TextStyle(fontSize: 11)),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          TextField(
            controller: _xtreamPassController,
            decoration: const InputDecoration(labelText: "كلمة المرور / Pass", labelStyle: TextStyle(fontSize: 11)),
            obscureText: true,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                if (_playlistNameController.text.isNotEmpty &&
                    _xtreamHostController.text.isNotEmpty &&
                    _xtreamUserController.text.isNotEmpty &&
                    _xtreamPassController.text.isNotEmpty) {
                  final list = UserPlaylist(
                    id: "xtream_${DateTime.now().millisecondsSinceEpoch}",
                    name: _playlistNameController.text,
                    type: "xtream",
                    host: _xtreamHostController.text,
                    username: _xtreamUserController.text,
                    password: _xtreamPassController.text,
                  );
                  provider.addPlaylist(list);
                  _playlistNameController.clear();
                  _xtreamHostController.clear();
                  _xtreamUserController.clear();
                  _xtreamPassController.clear();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text("تنفيذ مزامنة إكستريم / CONNECT"),
            ),
          ),
        ],
      ),
    );
  }
}

class HummingbirdPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.15, h * 0.43);
    path.lineTo(w * 0.40, h * 0.41);
    path.quadraticBezierTo(w * 0.45, h * 0.35, w * 0.52, h * 0.39);
    path.lineTo(w * 0.70, h * 0.18);
    path.quadraticBezierTo(w * 0.65, h * 0.35, w * 0.58, h * 0.45);
    path.lineTo(w * 0.85, h * 0.48);
    path.quadraticBezierTo(w * 0.70, h * 0.54, w * 0.56, h * 0.54);
    path.quadraticBezierTo(w * 0.62, h * 0.68, w * 0.65, h * 0.82);
    path.quadraticBezierTo(w * 0.60, h * 0.80, w * 0.53, h * 0.70);
    path.quadraticBezierTo(w * 0.46, h * 0.60, w * 0.44, h * 0.53);
    path.quadraticBezierTo(w * 0.38, h * 0.47, w * 0.15, h * 0.43);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AdvancedEngineSettingsWidget extends StatefulWidget {
  const _AdvancedEngineSettingsWidget();

  @override
  State<_AdvancedEngineSettingsWidget> createState() => _AdvancedEngineSettingsWidgetState();
}

class _AdvancedEngineSettingsWidgetState extends State<_AdvancedEngineSettingsWidget> {
  final _uaController = TextEditingController();
  final _refController = TextEditingController();
  final _proxyController = TextEditingController();
  final _githubUsernameController = TextEditingController();
  final _githubRepoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<IPTVProvider>(context, listen: false);
    _uaController.text = provider.globalUserAgent;
    _refController.text = provider.globalReferer;
    _proxyController.text = provider.globalProxy;
    _githubUsernameController.text = provider.githubUsername;
    _githubRepoController.text = provider.githubRepo;
  }

  @override
  void dispose() {
    _uaController.dispose();
    _refController.dispose();
    _proxyController.dispose();
    _githubUsernameController.dispose();
    _githubRepoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "إعدادات محرك البث والوكيل المتقدم / VIP Streaming Engine Settings",
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "تحكم في إعدادات الاتصال والبروكسي ووكيل المستخدم لتخطي حظر القنوات الجغرافي وحماية البث.",
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _uaController,
            decoration: InputDecoration(
              labelText: "وكيل المستخدم المخصص (User-Agent)",
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
              hintText: "مثال: VLC/3.0.18 أو Custom IPTV Engine",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              fillColor: const Color(0xFF1B1B1F),
              filled: true,
              prefixIcon: const Icon(Icons.http_rounded, color: Colors.grey, size: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _refController,
            decoration: InputDecoration(
              labelText: "المرجعية المخصصة للروابط (Referer)",
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
              hintText: "مثال: https://mydomain.com",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              fillColor: const Color(0xFF1B1B1F),
              filled: true,
              prefixIcon: const Icon(Icons.link_rounded, color: Colors.grey, size: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _proxyController,
            decoration: InputDecoration(
              labelText: "خادم البروكسي (Proxy SOCKS5 / HTTP)",
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
              hintText: "مثال: 45.67.56.78:3128",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              fillColor: const Color(0xFF1B1B1F),
              filled: true,
              prefixIcon: const Icon(Icons.private_connectivity_rounded, color: Colors.grey, size: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          const Text(
            "إعدادات مستودع البيانات الديناميكي (GitHub)",
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _githubUsernameController,
            decoration: InputDecoration(
              labelText: "اسم المستخدم في جيت هاب (GitHub Username)",
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
              hintText: "الافتراضي: mahmoudhwhwhwh",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              fillColor: const Color(0xFF1B1B1F),
              filled: true,
              prefixIcon: const Icon(Icons.account_circle, color: Colors.grey, size: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _githubRepoController,
            decoration: InputDecoration(
              labelText: "اسم المستودع (Repository Name)",
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
              hintText: "الافتراضي: flutter-iptv-player",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              fillColor: const Color(0xFF1B1B1F),
              filled: true,
              prefixIcon: const Icon(Icons.folder_shared_rounded, color: Colors.grey, size: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await provider.saveEngineSettings(
                  _uaController.text,
                  _refController.text,
                  _proxyController.text,
                );
                await provider.saveGithubConfig(
                  _githubUsernameController.text,
                  _githubRepoController.text,
                );
                await provider.fetchDynamicSections();
                provider.fetchGitHubNotifications();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ تم حفظ جميع الإعدادات وتحديث الأقسام الديناميكية بنجاح!"),
                    backgroundColor: Colors.indigoAccent,
                  ),
                );
              },
              icon: const Icon(Icons.offline_bolt_rounded, size: 16),
              label: const Text("حفظ وتحديث ملف التشغيل المباشر والأقسام"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStreamProScreenWidget extends StatefulWidget {
  final IPTVProvider provider;
  const _LiveStreamProScreenWidget({required this.provider});

  @override
  State<_LiveStreamProScreenWidget> createState() => _LiveStreamProScreenWidgetState();
}

class _LiveStreamProScreenWidgetState extends State<_LiveStreamProScreenWidget> {
  String _searchQuery = "";
  final _searchController = TextEditingController();

  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _categoryController = TextEditingController(text: "✅ قنوات مخصصة مضافة");
  final _logoController = TextEditingController();
  final _uaController = TextEditingController();
  final _refController = TextEditingController();

  int _selectedSectionIndex = 0;
  final List<String> _sections = [
    "Match time",
    "أفلام وقنوات أطفال",
    "قنوات الأخبار والأحداث",
    "الرياضة العربية",
    "القنوات الإسلامية والقرآن",
    "الوثائقية والثقافية",
    "القنوات الترفيهية",
    "مسلسلات ودراما",
  ];

  void _showAddChannelDialog() {
    _categoryController.text = _selectedSectionIndex == 0 ? IPTVProvider.getSectionName(1) : IPTVProvider.getSectionName(_selectedSectionIndex);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131316),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "➕ إضافة قناة أو سيرفر بث خاص للتشغيل",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "اسم القناة والناقل",
                      labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: "رابط البث (m3u8 / http / https)",
                      labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: "القسم / المجموعة",
                      labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _logoController,
                    decoration: const InputDecoration(
                      labelText: "رابط شعار القناة (اختياري)",
                      labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _uaController,
                    decoration: const InputDecoration(
                      labelText: "وكيل مستخدم مخصص للبث (User-Agent)",
                      labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _refController,
                    decoration: const InputDecoration(
                      labelText: "مرجع مخصص للبث (Referer)",
                      labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                if (_nameController.text.trim().isEmpty || _urlController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("⚠️ يرجى تعبئة اسم الصفحة ورابط البث على الأقل")),
                  );
                  return;
                }

                await widget.provider.addCustomProStream(
                  name: _nameController.text,
                  url: _urlController.text,
                  category: _categoryController.text,
                  logo: _logoController.text,
                  userAgent: _uaController.text,
                  referer: _refController.text,
                  categoryId: 'custom_pro_${_selectedSectionIndex + 1}',
                );

                // clear
                _nameController.clear();
                _urlController.clear();
                _logoController.clear();
                _uaController.clear();
                _refController.clear();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ تم حفظ القناة الخاصة بنجاح"), backgroundColor: Colors.green),
                );
              },
              child: const Text("حجز وتثبيت السيرفر", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Combine raw streams fetched from GitHub with local custom streams
    final List<PlaylistItem> sourceList = [];
    sourceList.addAll(widget.provider.allStreams);
    // Add local ones while ensuring no duplicate stream IDs
    for (final item in widget.provider.customProStreams) {
      if (!sourceList.any((e) => e.streamId == item.streamId)) {
        sourceList.add(item);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "قسم السيرفرات الخاصة ⚡ VIP Cloud Sections",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "8 أقسام سحابية رئيسية معزولة ومنسقة بشكل مستقل للوصول السريع والتشغيل بدون تقطيع.",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddChannelDialog,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text("إضافة قناة مخصصة", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Selector chips with index 0 as "all in vertical shelves"
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 9,
              itemBuilder: (context, index) {
                final isSelected = _selectedSectionIndex == index;
                final textLabel = index == 0 ? "الأقسام بصفوف (الكل)" : IPTVProvider.getSectionName(index);
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TVFocusable(
                    onTap: () {
                      setState(() {
                        _selectedSectionIndex = index;
                      });
                    },
                    isSelected: isSelected,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blueAccent : const Color(0xFF131316),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.blueAccent : const Color(0xFF27272A),
                        ),
                      ),
                      child: Text(
                        textLabel,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: "بحث سريع في جميع الأقسام الخاصة...",
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
              fillColor: const Color(0xFF131316),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _selectedSectionIndex == 0
                ? ListView.builder(
                    itemCount: 8,
                    itemBuilder: (context, sectionIdx) {
                      final sectionName = IPTVProvider.getSectionName(sectionIdx + 1);
                      final sectionId = "custom_pro_${sectionIdx + 1}";
                      
                      final sectionStreams = sourceList.where((e) {
                        final bool isCurrentSec = e.categoryId == sectionId || (sectionId == 'custom_pro_1' && e.categoryId == 'my_custom_sports');
                        if (!isCurrentSec) return false;
                        if (_searchQuery.isEmpty) return true;
                        return e.name.toLowerCase().contains(_searchQuery.toLowerCase());
                      }).toList();
                      
                      sectionStreams.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                      
                      if (sectionStreams.isEmpty && _searchQuery.isNotEmpty) {
                        return const SizedBox.shrink(); 
                      }

                      final customLogoUrl = IPTVProvider.getSectionLogo(sectionIdx + 1);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    customLogoUrl.isNotEmpty
                                        ? Image.network(
                                            customLogoUrl,
                                            width: 24,
                                            height: 24,
                                            errorBuilder: (ctx, err, stack) => Icon(
                                              sectionIdx == 0 ? Icons.sports_soccer_rounded :
                                              sectionIdx == 1 ? Icons.child_care_rounded :
                                              sectionIdx == 2 ? Icons.newspaper_rounded :
                                              sectionIdx == 3 ? Icons.sports_tennis_rounded :
                                              sectionIdx == 4 ? Icons.mosque_rounded :
                                              sectionIdx == 5 ? Icons.menu_book_rounded :
                                              sectionIdx == 6 ? Icons.movie_filter_rounded : Icons.slideshow_rounded,
                                              color: Colors.blueAccent,
                                              size: 18,
                                            ),
                                          )
                                        : Icon(
                                            sectionIdx == 0 ? Icons.sports_soccer_rounded :
                                            sectionIdx == 1 ? Icons.child_care_rounded :
                                            sectionIdx == 2 ? Icons.newspaper_rounded :
                                            sectionIdx == 3 ? Icons.sports_tennis_rounded :
                                            sectionIdx == 4 ? Icons.mosque_rounded :
                                            sectionIdx == 5 ? Icons.menu_book_rounded :
                                            sectionIdx == 6 ? Icons.movie_filter_rounded : Icons.slideshow_rounded,
                                            color: Colors.blueAccent,
                                            size: 18,
                                          ),
                                    const SizedBox(width: 8),
                                    Text(
                                      sectionName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "${sectionStreams.length} قنوات",
                                    style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (sectionStreams.isEmpty)
                            Container(
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF131316),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF27272A)),
                              ),
                              child: const Text(
                                "لا توجد قنوات مدرجة في هذا القسم حالياً.",
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            )
                          else
                            SizedBox(
                              height: 105,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: sectionStreams.length,
                                itemBuilder: (context, streamIdx) {
                                  final item = sectionStreams[streamIdx];
                                  final isUserAdded = item.streamId.startsWith('local_custom_');
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: TVFocusable(
                                      onTap: () {
                                        widget.provider.selectStream(item);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PlayerScreen(stream: item),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 190,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF131316),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF27272A)),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 28,
                                                        height: 28,
                                                        decoration: BoxDecoration(
                                                          color: Colors.black26,
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Image.network(
                                                          item.streamIcon ?? '',
                                                          errorBuilder: (_, __, ___) => const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                                          loadingBuilder: (context, child, progress) {
                                                            if (progress == null) return child;
                                                            return const Icon(Icons.star_rounded, color: Colors.amber, size: 16);
                                                          },
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          "[ ${streamIdx + 1} ] ${item.name}",
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    item.url,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(color: Colors.white24, fontSize: 8, fontFamily: 'monospace'),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      if (item.customUserAgent != null)
                                                        Container(
                                                          margin: const EdgeInsets.only(right: 6),
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                          decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.4), borderRadius: BorderRadius.circular(3)),
                                                          child: const Text("UA", style: TextStyle(color: Colors.white70, fontSize: 6)),
                                                        ),
                                                      if (item.customReferer != null)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                          decoration: BoxDecoration(color: Colors.teal.withOpacity(0.4), borderRadius: BorderRadius.circular(3)),
                                                          child: const Text("REF", style: TextStyle(color: Colors.white70, fontSize: 6)),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isUserAdded)
                                              Positioned(
                                                top: 2,
                                                right: 2,
                                                child: IconButton(
                                                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 14),
                                                  onPressed: () {
                                                    widget.provider.deleteCustomProStream(item.streamId);
                                                  },
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const Divider(color: Color(0xFF27272A), height: 24),
                        ],
                      );
                    },
                  )
                : (() {
                    final String currentSecId = "custom_pro_${_selectedSectionIndex}";
                    final list = sourceList.where((e) {
                      final bool isCurrentSec = e.categoryId == currentSecId || (currentSecId == 'custom_pro_1' && e.categoryId == 'my_custom_sports');
                      if (!isCurrentSec) return false;
                      if (_searchQuery.isEmpty) return true;
                      return e.name.toLowerCase().contains(_searchQuery.toLowerCase());
                    }).toList();

                    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                    return list.isEmpty
                        ? const Center(
                            child: Text(
                              "لا توجد قنوات مطابقة للبحث أو مضافة في هذا الفهرس.",
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 240,
                              childAspectRatio: 1.4,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: list.length,
                            itemBuilder: (context, idx) {
                              final item = list[idx];
                              final isUserAdded = item.streamId.startsWith('local_custom_');
                              return Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131316),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF27272A)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
                                    widget.provider.selectStream(item);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PlayerScreen(stream: item),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black26,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Image.network(
                                                    item.streamIcon ?? '',
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                                    loadingBuilder: (context, child, progress) {
                                                      if (progress == null) return child;
                                                      return const Icon(Icons.star_rounded, color: Colors.amber, size: 20);
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "[ ${idx + 1} ] ${item.name}",
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        item.categoryName ?? 'قناة بث خاص',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(color: Colors.blueAccent, fontSize: 9),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              item.url,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'monospace'),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (item.customUserAgent != null)
                                                  Container(
                                                    margin: const EdgeInsets.only(right: 6),
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.4), borderRadius: BorderRadius.circular(3)),
                                                    child: const Text("UA", style: TextStyle(color: Colors.white70, fontSize: 7)),
                                                  ),
                                                if (item.customReferer != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.4), borderRadius: BorderRadius.circular(3)),
                                                    child: const Text("REF", style: TextStyle(color: Colors.white70, fontSize: 7)),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isUserAdded)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: IconButton(
                                            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 16),
                                            onPressed: () {
                                              widget.provider.deleteCustomProStream(item.streamId);
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                  })(),
          ),
        ],
      ),
    );
  }
}
