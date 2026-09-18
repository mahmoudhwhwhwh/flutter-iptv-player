import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CatalogWebViewScreen extends StatefulWidget {
  final String title;
  final Uri url;

  const CatalogWebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<CatalogWebViewScreen> createState() => _CatalogWebViewScreenState();
}

class _CatalogWebViewScreenState extends State<CatalogWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0E15))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _error = null);
        },
        onWebResourceError: (error) {
          if (mounted && error.isForMainFrame == true) {
            setState(() => _error =
                'تعذر تحميل الصفحة. تحقق من الإنترنت أو شغّل VPN خارجي.');
          }
        },
      ))
      ..loadRequest(widget.url);
  }

  Future<bool> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _goBack,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E15),
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: const Color(0xFF0B0E15),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _controller.reload,
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: _progress / 100),
                )
              : null,
        ),
        body: _error == null
            ? WebViewWidget(controller: _controller)
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white54, size: 50),
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _controller.reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

bool supportsIntegratedCatalog(String code) =>
    code.trim() == '2026' || code.trim() == '2027';

Uri catalogUrl(String tab) => Uri.parse(
    tab == 'movie' ? 'https://m.filmcity12.com/' : 'https://starcima.cc/');

String catalogTitle(String tab) => tab == 'movie' ? 'الأفلام' : 'المسلسلات';
