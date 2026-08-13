import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/iptv_provider.dart';
import '../widgets/pin_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// لوحة موحّدة لشاشة الإعدادات؛ تبقي واجهة LIVE STREAM PREMIUM متسقة.
class _SettingsPalette {
  const _SettingsPalette._();

  static const Color background = Color(0xFF0B0E15);
  static const Color surface = Color(0xFF17171A);
  static const Color surfaceElevated = Color(0xFF201A22);
  static const Color purple = Color(0xFFA855F7);
  static const Color purpleBright = Color(0xFFC084FC);
  static const Color gold = Color(0xFFFFC857);
  static const Color cyan = Color(0xFF24DCE0);
  static const Color danger = Color(0xFFFF4D5A);
  static const Color textMuted = Color(0xFFAEAFB7);
  static const Color divider = Color(0xFF34343A);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _bioLink = false;
  bool _quantumEntanglement = true;
  bool _selfHealing = true;
  bool _quantumRouting = true;
  
  bool _hwAcceleration = true;
  bool _autoPlay = true;
  String _subSize = "متوسط";
  String _subFont = 'Cairo';
  String _subColor = "أبيض";
  String _subBgColor = "شفاف";
  String _subLang = "تلقائي";
  String _appOrientation = "تلقائي";
  bool _remoteControlEnabled = true;
  bool _mouseControlEnabled = true;
  bool _tvBoxFocusEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bioLink = prefs.getBool('bio_link') ?? false;
      _quantumEntanglement = prefs.getBool('quantum_entanglement') ?? true;
      _selfHealing = prefs.getBool('self_healing') ?? true;
      _quantumRouting = prefs.getBool('quantum_routing') ?? true;

      _hwAcceleration = prefs.getBool('hw_acceleration') ?? true;
      _autoPlay = prefs.getBool('auto_play') ?? true;
      _subSize = prefs.getString('sub_size') ?? "متوسط";
      _subFont = prefs.getString('sub_font') ?? 'Cairo';
      _subColor = prefs.getString('sub_color') ?? "أبيض";
      _subBgColor = prefs.getString('sub_bg_color') ?? "شفاف";
      _subLang = prefs.getString('sub_lang') ?? "تلقائي";
      _appOrientation = prefs.getString('app_orientation') ?? "تلقائي";
      _remoteControlEnabled = prefs.getBool('remote_control_enabled') ?? true;
      _mouseControlEnabled = prefs.getBool('mouse_control_enabled') ?? true;
      _tvBoxFocusEnabled = prefs.getBool('tv_box_focus_enabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveStringSetting(String key, String value) async {
    await context.read<IPTVProvider>().setPlayerStringPreference(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = context.watch<IPTVProvider>();
    return Scaffold(
      backgroundColor: activeTheme.themeBackground,
      appBar: AppBar(
        backgroundColor: activeTheme.themeBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          "إعدادات LIVE STREAM PREMIUM",
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: 0.1,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer<IPTVProvider>(
                builder: (context, provider, child) {
                  return Column(
                    children: [
                      _buildProfileCard(provider),
                      const SizedBox(height: 14),
                      _buildDropdownItem(
                        title: 'لغة الواجهة',
                        value: provider.appLanguage,
                        items: const ['العربية', 'English'],
                        onChanged: (value) {
                          if (value != null) provider.setAppLanguage(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDropdownItem(
                        title: 'ثيم التطبيق',
                        value: provider.premiumTheme,
                        items: const [
                          'البنفسجي الملكي',
                          'الأزرق الليلي',
                          'الذهبي الفاخر',
                          'الزمردي الداكن',
                          'الروبي السينمائي',
                          'السماوي الكهربائي',
                          'الغروب البرتقالي',
                        ],
                        onChanged: (value) {
                          if (value != null) provider.setPremiumTheme(value);
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Consumer<IPTVProvider>(
                builder: (context, provider, child) {
                  return _buildThemeSettingCard(
                    isDarkMode: provider.isDarkMode,
                    onChanged: (_) => provider.toggleTheme(),
                  );
                },
              ),
              const SizedBox(height: 12),
              Consumer<IPTVProvider>(
                builder: (context, provider, child) => _buildActionButtonSettingCard(
                  title: 'تغيير الاشتراك',
                  description: 'إدخال كود اشتراك جديد. سيتم حذف القنوات والمفضلة الخاصة بالكود السابق، مع الاحتفاظ بالثيم واللغة وإعدادات المشغّل.',
                  actionLabel: 'تغيير الكود',
                  icon: Icons.swap_horiz_rounded,
                  onTap: () => _confirmSubscriptionChange(provider),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader("إعدادات المشغّل الأساسية", ""),
              const SizedBox(height: 12),
              _buildSettingItem(
                title: "تسريع الأجهزة (HW Acceleration)",
                description: "استخدام أجهزة الجهاز لتشغيل الفيديو بسلاسة أكبر وتقليل استهلاك البطارية.",
                value: _hwAcceleration,
                activeColor: _SettingsPalette.purpleBright,
                onChanged: (val) {
                  setState(() => _hwAcceleration = val);
                  _saveSetting('hw_acceleration', val);
                },
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                title: "التشغيل التلقائي",
                description: "تشغيل القناة أو الفيلم تلقائياً عند فتحه.",
                value: _autoPlay,
                activeColor: _SettingsPalette.gold,
                onChanged: (val) {
                  setState(() => _autoPlay = val);
                  _saveSetting('auto_play', val);
                },
              ),
              const SizedBox(height: 12),
              _buildDropdownItem(
                title: "حجم خط الترجمة",
                value: _subSize,
                items: const ["صغير", "متوسط", "كبير", "ضخم"],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _subSize = val);
                    _saveStringSetting('sub_size', val);
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildDropdownItem(
                title: "خط الترجمة",
                value: _subFont,
                items: const ['Cairo', 'Arial', 'Tahoma', 'Roboto'],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _subFont = val);
                    _saveStringSetting('sub_font', val);
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildDropdownItem(
                title: "لون الترجمة",
                value: _subColor,
                items: const ["أبيض", "أصفر", "أزرق سماوي", "أخضر", "أحمر", "أزرق", "وردي", "برتقالي", "بنفسجي", "أسود", "رمادي"],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _subColor = val);
                    _saveStringSetting('sub_color', val);
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildDropdownItem(
                title: "لون خلفية الترجمة",
                value: _subBgColor,
                items: const ["شفاف", "أسود", "رمادي داكن", "أحمر داكن", "أزرق داكن", "أخضر داكن", "أرجواني داكن", "أبيض"],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _subBgColor = val);
                    _saveStringSetting('sub_bg_color', val);
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildDropdownItem(
                title: "لغة الترجمة المفضلة",
                value: _subLang,
                items: const ["تلقائي", "Arabic", "English", "French", "Spanish", "Turkish", "Persian"],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _subLang = val);
                    _saveStringSetting('sub_lang', val);
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildOrientationSettingCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('التحكم والأجهزة', ''),
              const SizedBox(height: 12),
              _buildSettingItem(
                title: 'تحكم الريموت',
                description: 'تشغيل أزرار الأسهم وOK وBack والتقديم والتأخير على الشاشات وTV Box.',
                value: _remoteControlEnabled,
                activeColor: _SettingsPalette.purpleBright,
                onChanged: (value) {
                  setState(() => _remoteControlEnabled = value);
                  _saveSetting('remote_control_enabled', value);
                },
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                title: 'تحكم الماوس',
                description: 'إظهار المؤشر والتفاعل بالنقر والتمرير لفتح الأدوات والتنقل في الواجهات الكبيرة.',
                value: _mouseControlEnabled,
                activeColor: _SettingsPalette.cyan,
                onChanged: (value) {
                  setState(() => _mouseControlEnabled = value);
                  _saveSetting('mouse_control_enabled', value);
                },
              ),
              const SizedBox(height: 12),
              Consumer<IPTVProvider>(
                builder: (context, provider, child) => _buildSettingItem(
                  title: 'تركيز TV Box والشاشات',
                  description: 'ينقل التركيز تلقائياً بين الأقسام والبطاقات عند استعمال الأسهم بدون ماوس.',
                  value: provider.tvBoxFocusEnabled,
                  activeColor: _SettingsPalette.gold,
                  onChanged: provider.setTvBoxFocusEnabled,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: _SettingsPalette.divider),
              const SizedBox(height: 24),

              _buildSectionHeader("تصفية وتصفح المحتوى", ""),
              const SizedBox(height: 12),

              Consumer<IPTVProvider>(
                builder: (context, provider, child) {
                  return _buildSettingItem(
                    title: "عرض الأفلام والمسلسلات",
                    description: "إظهار أو إخفاء أقسام وأبواب الأفلام والمسلسلات تماماً من واجهات التطبيق.",
                    value: provider.showMoviesSeries,
                    activeColor: _SettingsPalette.danger,
                    onChanged: (val) {
                      provider.setShowMoviesSeries(val);
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              Consumer<IPTVProvider>(
                builder: (context, provider, child) {
                  return _buildDropdownItem(
                    title: "تصفية القنوات (البث المباشر)",
                    value: provider.channelFilter,
                    items: const [
                      "الكل",
                      "القنوات العربية فقط",
                      "القنوات الأجنبية فقط",
                      "قنوات الرياضة فقط",
                      "القنوات الرياضية العربية فقط",
                      "القنوات الإخبارية فقط",
                      "قنوات Alwan فقط"
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        provider.setChannelFilter(val);
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              Consumer<IPTVProvider>(
                builder: (context, provider, child) {
                  return _buildSettingItem(
                    title: "الوضع العائلي المحمي",
                    description: "يفحص أسماء القنوات والفئات وبيانات القوائم ويخفي المحتوى المقيّد قبل أن يظهر في أي قسم.",
                    value: provider.blockAdultContent,
                    activeColor: _SettingsPalette.purple,
                    onChanged: (val) async {
                      if (!val && provider.isParentalEnabled) {
                        final verified = await showPinDialog(context, provider);
                        if (!verified) return;
                      }
                      provider.setBlockAdultContent(val);
                    },
                  );
                },
              ),

              const SizedBox(height: 24),
              const Divider(color: _SettingsPalette.divider),
              const SizedBox(height: 24),

              _buildSectionHeader("الرقابة الأبوية وحماية الأقسام", ""),
              const SizedBox(height: 12),

              Consumer<IPTVProvider>(
                builder: (context, provider, child) {
                  final isEnabled = provider.isParentalEnabled;
                  return Column(
                    children: [
                      _buildSettingItem(
                        title: "تفعيل الرقابة الأبوية (رمز الأمان)",
                        description: isEnabled 
                            ? "الرقابة الأبوية مفعلة برمز أمان. قم بإلغاء التفعيل لتعطيل قفل الأقسام." 
                            : "قم بتعيين رمز أمان PIN مكون من 4 أرقام لقفل وحماية الأقسام والتحكم بالوصول إليها.",
                        value: isEnabled,
                        activeColor: _SettingsPalette.purple,
                        onChanged: (val) async {
                          if (val) {
                            await showPinDialog(context, provider, isCreating: true);
                          } else {
                            bool correct = await showPinDialog(context, provider);
                            if (correct) {
                              await provider.clearParentalSettings();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("تم إلغاء تفعيل رمز الأمان بنجاح", style: TextStyle(fontFamily: 'Cairo'))),
                                );
                              }
                            }
                          }
                        },
                      ),
                      if (isEnabled) ...[
                        const SizedBox(height: 12),
                        _buildActionButtonSettingCard(
                          title: "تغيير رمز الأمان (PIN)",
                          description: "تعديل الرمز المكون من 4 أرقام المستخدم لحماية الأقسام الخاصة بك.",
                          actionLabel: "تغيير الرمز",
                          icon: Icons.lock_reset_rounded,
                          onTap: () async {
                            bool correct = await showPinDialog(context, provider);
                            if (correct) {
                              await showPinDialog(context, provider, isCreating: true, customTitle: "تعيين رمز جديد");
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("تم تغيير رمز الأمان بنجاح", style: TextStyle(fontFamily: 'Cairo'))),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildActionButtonSettingCard(
                          title: "إدارة الأقسام المقفلة",
                          description: "تحديد واختيار الأقسام وقنوات البث المباشر أو الأفلام والمسلسلات المراد قفلها.",
                          actionLabel: "تحديد الأقسام",
                          icon: Icons.category_rounded,
                          onTap: () async {
                            bool correct = await showPinDialog(context, provider);
                            if (correct) {
                              _showCategoryLockDialog(context, provider);
                            }
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),
              const Divider(color: _SettingsPalette.divider),
              const SizedBox(height: 24),

              _buildSectionHeader("live stream premium", ""),
              const SizedBox(height: 12),

              // Warning box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _SettingsPalette.cyan.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _SettingsPalette.cyan.withOpacity(0.58)),
                ),
                child: const Column(
                  children: [
                    Text(
                      "تحذير: تفعيل هذه الخيارات يؤدي الى زيادة استهلاك البطارية",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _SettingsPalette.cyan, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "للحصول على أفضل اداء قم بتفعيل كافة المميزات يمكنك الغاء اي شيء حسب الذي تفضله واختيار الطريقة الانسب لك.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildSettingItem(
                title: "1. تقنية الربط الحيوي المتقدم (Bio-Link)",
                description: "تعمل على تحسين استجابة الخادم بشكل فوري لضمان عدم تأخير البث المباشر.",
                value: _bioLink,
                activeColor: _SettingsPalette.purple,
                onChanged: (val) {
                  setState(() => _bioLink = val);
                  _saveSetting('bio_link', val);
                },
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                title: "2. التشابك الكمي للبث (Quantum Entanglement)",
                description: "ميزة ثورية تزيد من سرعة تدفق البيانات لضمان أعلى جودة ممكنة دون انقطاع.",
                value: _quantumEntanglement,
                activeColor: _SettingsPalette.purpleBright,
                onChanged: (val) {
                  setState(() => _quantumEntanglement = val);
                  _saveSetting('quantum_entanglement', val);
                },
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                title: "3. نواة المعالجة الذاتية (Self-Healing)",
                description: "نظام ذكي يقوم باكتشاف وإصلاح أعطال البث تلقائياً دون أي تدخل يدوي.",
                value: _selfHealing,
                activeColor: _SettingsPalette.purpleBright,
                onChanged: (val) {
                  setState(() => _selfHealing = val);
                  _saveSetting('self_healing', val);
                },
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                title: "4. توجيه المسارات الكمي (Quantum Routing)",
                description: "يعيد توجيه اتصالك عبر أسرع المسارات العالمية المتاحة لفتح القنوات في أقل من ثانية.",
                value: _quantumRouting,
                activeColor: _SettingsPalette.purpleBright,
                onChanged: (val) {
                  setState(() => _quantumRouting = val);
                  _saveSetting('quantum_routing', val);
                },
              ),
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  "LIVE STREAM PREMIUM",
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_SettingsPalette.surfaceElevated, _SettingsPalette.surface],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _SettingsPalette.purple.withOpacity(0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: _SettingsPalette.purple,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: Icon(Icons.tune_rounded, color: Colors.white, size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "تفضيلات المشاهدة",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 3),
                Text(
                  "خصّص التجربة بما يناسبك",
                  style: TextStyle(color: _SettingsPalette.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Icon(Icons.workspace_premium_rounded, color: _SettingsPalette.gold, size: 21),
        ],
      ),
    );
  }

  IconData _profileIcon(String value) {
    switch (value) {
      case 'star':
        return Icons.star_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      default:
        return Icons.play_arrow_rounded;
    }
  }

  Future<void> _confirmSubscriptionChange(IPTVProvider provider) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _SettingsPalette.surfaceElevated,
        title: const Text('تغيير الاشتراك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'سيتم إنهاء الاشتراك الحالي وإرجاعك إلى شاشة إدخال الكود الجديد. ستبقى اللغة والثيم وإعدادات المشغّل محفوظة.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _SettingsPalette.purple, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    await provider.changeSubscription();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _pickProfileImage(IPTVProvider provider) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 900,
    );
    if (picked == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final avatar = File('${directory.path}/premium_profile_avatar.jpg');
    await File(picked.path).copy(avatar.path);
    await provider.setProfileImagePath(avatar.path);
  }

  Future<void> _showProfileEditor(IPTVProvider provider) async {
    final nameController = TextEditingController(text: provider.profileName);
    var selectedLogo = provider.profileLogo;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _SettingsPalette.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _SettingsPalette.purple.withOpacity(0.65)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تخصيص ملف الحساب', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'اسم العرض',
                    labelStyle: const TextStyle(color: _SettingsPalette.textMuted),
                    filled: true,
                    fillColor: const Color(0xFF11111B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _SettingsPalette.purpleBright,
                    side: BorderSide(color: _SettingsPalette.purple.withOpacity(0.65)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await _pickProfileImage(provider);
                    if (dialogContext.mounted) setDialogState(() {});
                  },
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('اختيار صورة من المعرض'),
                ),
                const SizedBox(height: 18),
                const Text('شعار الحساب', style: TextStyle(color: _SettingsPalette.textMuted, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: ['play', 'star', 'shield', 'bolt'].map((logo) {
                    final selected = selectedLogo == logo;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setDialogState(() => selectedLogo = logo),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: selected ? _SettingsPalette.purple : const Color(0xFF11111B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: selected ? _SettingsPalette.purpleBright : _SettingsPalette.divider),
                        ),
                        child: Icon(_profileIcon(logo), color: selected ? Colors.white : _SettingsPalette.textMuted),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _SettingsPalette.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () async {
                      await provider.setProfileName(nameController.text);
                      await provider.setProfileLogo(selectedLogo);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    child: const Text('حفظ التعديلات'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    nameController.dispose();
  }

  Widget _buildProfileCard(IPTVProvider provider) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _showProfileEditor(provider),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
        gradient: LinearGradient(colors: [provider.accentColor.withOpacity(0.34), provider.themeSurface], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: provider.accentColor.withOpacity(0.65)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: provider.accentColor,
                shape: BoxShape.circle,
                image: provider.profileImagePath.isNotEmpty && File(provider.profileImagePath).existsSync()
                    ? DecorationImage(image: FileImage(File(provider.profileImagePath)), fit: BoxFit.cover)
                    : null,
              ),
              child: provider.profileImagePath.isNotEmpty && File(provider.profileImagePath).existsSync()
                  ? null
                  : Icon(_profileIcon(provider.profileLogo), color: Colors.white, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.profileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(provider.subscriptionType.isEmpty ? 'حساب Premium' : provider.subscriptionType, style: const TextStyle(color: _SettingsPalette.gold, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('ينتهي: ${provider.expirationDateFormatted}', style: const TextStyle(color: _SettingsPalette.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.edit_rounded, color: provider.accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSettingCard({
    required bool isDarkMode,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _SettingsPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _SettingsPalette.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _SettingsPalette.purple.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: _SettingsPalette.purpleBright,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("المظهر", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text("التبديل بين النمط الداكن والفاتح", style: TextStyle(color: _SettingsPalette.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Switch.adaptive(
            value: isDarkMode,
            activeColor: _SettingsPalette.purpleBright,
            activeTrackColor: _SettingsPalette.purple,
            inactiveThumbColor: Colors.white70,
            inactiveTrackColor: Colors.white12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildOrientationSettingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _SettingsPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _SettingsPalette.divider),
      ),
      child: InkWell(
        onTap: () => _showOrientationDialog(),
        child: Row(
          children: [
            const Icon(Icons.screen_rotation_rounded, color: _SettingsPalette.purpleBright, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "اتجاه التطبيق (الشاشة)",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _appOrientation,
                    style: const TextStyle(color: _SettingsPalette.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: _SettingsPalette.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  void _showOrientationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _SettingsPalette.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "اتجاه الشاشة",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.right,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOrientationRadioOption(setDialogState, "تلقائي"),
                  _buildOrientationRadioOption(setDialogState, "أفقي"),
                  _buildOrientationRadioOption(setDialogState, "عمودي"),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrientationRadioOption(StateSetter setDialogState, String option) {
    final bool isSelected = _appOrientation == option;
    return InkWell(
      onTap: () async {
        setState(() {
          _appOrientation = option;
        });
        setDialogState(() {});
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_orientation', option);
        
        // Apply orientation preference
        if (option == "أفقي") {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        } else if (option == "عمودي") {
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
        
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Since it is RTL, we swap positions so circle is on the right and text is on the left
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _SettingsPalette.purple : Colors.white30,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _SettingsPalette.purple,
                        ),
                      ),
                    )
                  : null,
            ),
            Text(
              option,
              style: TextStyle(
                color: isSelected ? _SettingsPalette.purple : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownItem({
    required String title,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _SettingsPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _SettingsPalette.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          DropdownButton<String>(
            value: value,
            dropdownColor: _SettingsPalette.surfaceElevated,
            style: const TextStyle(color: _SettingsPalette.purpleBright, fontSize: 14),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: _SettingsPalette.purpleBright),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required String title, 
    required String description, 
    required bool value, 
    required Color activeColor,
    required void Function(bool) onChanged
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: _SettingsPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: value ? activeColor.withOpacity(0.55) : _SettingsPalette.divider, width: value ? 1.4 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: value ? activeColor : Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: _SettingsPalette.textMuted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: activeColor,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: _SettingsPalette.divider,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonSettingCard({
    required String title,
    required String description,
    required String actionLabel,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _SettingsPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _SettingsPalette.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: _SettingsPalette.textMuted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _SettingsPalette.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(
              actionLabel,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryLockDialog(BuildContext context, IPTVProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String filterText = "";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final liveCats = provider.liveCategories.map((c) => c['category_name'] ?? '').where((c) => c.isNotEmpty).toList();
            final movieCats = provider.movieCategories.map((c) => c['category_name'] ?? '').where((c) => c.isNotEmpty).toList();
            final seriesCats = provider.seriesCategories.map((c) => c['category_name'] ?? '').where((c) => c.isNotEmpty).toList();

            final List<String> filteredLive = liveCats.where((c) => c.toLowerCase().contains(filterText.toLowerCase())).toList();
            final List<String> filteredMovies = movieCats.where((c) => c.toLowerCase().contains(filterText.toLowerCase())).toList();
            final List<String> filteredSeries = seriesCats.where((c) => c.toLowerCase().contains(filterText.toLowerCase())).toList();

            return DefaultTabController(
              length: 3,
              child: AlertDialog(
                backgroundColor: _SettingsPalette.surfaceElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white12, width: 1),
                ),
                title: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          "إدارة الأقسام المقفلة",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.settings_suggest, color: _SettingsPalette.purple),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setDialogState(() {
                            filterText = val;
                          });
                        },
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo'),
                        decoration: InputDecoration(
                          hintText: "ابحث عن قسم...",
                          hintStyle: TextStyle(color: _SettingsPalette.textMuted.withOpacity(0.65), fontSize: 12, fontFamily: 'Cairo'),
                          prefixIcon: Icon(Icons.search, color: _SettingsPalette.textMuted.withOpacity(0.65), size: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const TabBar(
                      indicatorColor: _SettingsPalette.purple,
                      labelColor: Colors.white,
                      unselectedLabelColor: _SettingsPalette.textMuted,
                      labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                      unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      tabs: [
                        Tab(text: "مسلسلات"),
                        Tab(text: "أفلام"),
                        Tab(text: "مباشر"),
                      ],
                    ),
                  ],
                ),
                content: Container(
                  width: 400,
                  height: 350,
                  child: TabBarView(
                    children: [
                      _buildCategoryList(filteredSeries, provider, setDialogState),
                      _buildCategoryList(filteredMovies, provider, setDialogState),
                      _buildCategoryList(filteredLive, provider, setDialogState),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "إغلاق",
                      style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryList(List<String> categories, IPTVProvider provider, StateSetter setDialogState) {
    if (categories.isEmpty) {
      return Center(
        child: Text(
          "لا توجد أقسام مطابقة",
          style: TextStyle(color: _SettingsPalette.textMuted.withOpacity(0.65), fontFamily: 'Cairo', fontSize: 13),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: categories.length,
      itemBuilder: (ctx, idx) {
        final cat = categories[idx];
        final isLocked = provider.lockedCategories.contains(cat);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            title: Text(
              cat,
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 13),
              textAlign: TextAlign.right,
            ),
            leading: Switch(
              value: isLocked,
              activeColor: _SettingsPalette.purple,
              onChanged: (val) async {
                await provider.toggleCategoryLock(cat);
                setDialogState(() {});
              },
            ),
            trailing: Icon(
              isLocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
              color: isLocked ? _SettingsPalette.purple : Colors.white30,
              size: 18,
            ),
          ),
        );
      },
    );
  }
}

class UpdateDialog extends StatefulWidget {
  final String version;
  final String message;
  final String url;

  const UpdateDialog({Key? key, required this.version, required this.message, required this.url}) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double _progress = 0;
  bool _isDownloading = false;
  String _status = "";

  void _startDownload() async {
    setState(() {
      _isDownloading = true;
      _status = "جاري التحميل...";
    });

    try {
      final dio = Dio();
      final dir = await getExternalStorageDirectory();
      final savePath = "${dir?.path}/update_${widget.version}.apk";

      await dio.download(
        widget.url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      setState(() {
        _status = "اكتمل التحميل، جاري التثبيت...";
      });

      // Install APK
      await OpenFilex.open(savePath);
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _status = "فشل التحميل. هل ترغب في فتحه في المتصفح؟";
        _isDownloading = false;
      });
      // Fallback to url launcher
      launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _SettingsPalette.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  color: _SettingsPalette.purple,
                  alignment: Alignment.center,
                  child: const Text("L", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("LIVE STREAM PREMIUM", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("New version ${widget.version}", style: TextStyle(color: _SettingsPalette.purple, fontSize: 14)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text("What's new", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              widget.message,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 24),
            if (_isDownloading) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text("${(_progress * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(_SettingsPalette.purple),
              ),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(color: _SettingsPalette.textMuted, fontSize: 12), textDirection: TextDirection.rtl),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("لاحقاً", style: TextStyle(color: _SettingsPalette.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _SettingsPalette.purple),
                    onPressed: _startDownload,
                    child: const Text("تحديث الآن", style: TextStyle(color: Colors.white)),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}
