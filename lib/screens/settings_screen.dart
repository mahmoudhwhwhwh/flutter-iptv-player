import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/iptv_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

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
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("المتقدمة VORTEX إعدادات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              // Warning box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF081C22), // Dark greenish/teal background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                ),
                child: const Column(
                  children: [
                    Text(
                      "تحذير: تفعيل هذه الخيارات يؤدي الى زيادة استهلاك البطارية",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
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

              // --- Theme Toggle ---
              Consumer<IPTVProvider>(
                builder: (context, provider, child) {
                  return ListTile(
                    leading: Icon(provider.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFFE50914)),
                    title: const Text("المظهر (داكن/فاتح)", style: TextStyle(color: Colors.white)),
                    trailing: Switch(
                      value: provider.isDarkMode,
                      activeColor: const Color(0xFFE50914),
                      onChanged: (val) {
                        provider.toggleTheme();
                      },
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white12),
              
              _buildSettingItem(
                title: "1. تقنية الربط الحيوي المتقدم (Bio-Link)",
                description: "تعمل على تحسين استجابة الخادم بشكل فوري لضمان عدم تأخير البث المباشر.",
                value: _bioLink,
                activeColor: Colors.deepPurpleAccent,
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
                activeColor: Colors.greenAccent.shade400,
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
                activeColor: Colors.deepOrangeAccent,
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
                activeColor: Colors.lightBlueAccent,
                onChanged: (val) {
                  setState(() => _quantumRouting = val);
                  _saveSetting('quantum_routing', val);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? activeColor.withOpacity(0.3) : Colors.white10),
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
                  style: TextStyle(color: value ? activeColor : Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
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
            inactiveTrackColor: Colors.white10,
            onChanged: onChanged,
          ),
        ],
      ),
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
      backgroundColor: const Color(0xFF2D2D2D),
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
                  color: Colors.red,
                  alignment: Alignment.center,
                  child: const Text("R", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Reezn", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("New version ${widget.version}", style: TextStyle(color: Colors.redAccent, fontSize: 14)),
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
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
              ),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(color: Colors.white54, fontSize: 12), textDirection: TextDirection.rtl),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("لاحقاً", style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
