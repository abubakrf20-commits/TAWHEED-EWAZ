import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/shared/services/share_service.dart';

/// Arguments passed through go_router [GoRoute.extra].
class InAppBrowserArgs {
  final String title;
  final String url;
  const InAppBrowserArgs({required this.title, required this.url});
}

/// ═══════════════════════════════════════════════════════════════
/// InAppBrowserScreen — opens an external website INSIDE the app
/// (e.g. هوش مصنوعی شرعی قاف → qaf.ai) instead of the system browser.
///
/// Compared with the old thin wrapper this is a small but real browser:
///   • a reliable bottom toolbar (back / forward / reload / home / share)
///     that is always visible and sits inside the safe area, so the site's
///     own bottom controls are never hidden under the 3-button nav bar;
///   • a persistent per-URL [WebViewController] cache, so re-opening a site
///     (e.g. the Qaf chat) shows the SAME page instead of reloading a fresh
///     one and dropping the conversation;
///   • find-in-page, a desktop-user-agent toggle and text zoom, sharing,
///     copying the address and an «open in browser» escape hatch.
/// All of it stays on top of [webview_flutter] — no heavy new dependency.
/// ═══════════════════════════════════════════════════════════════
class InAppBrowserScreen extends StatefulWidget {
  final String title;
  final String url;
  final bool initialDesktopMode;

  const InAppBrowserScreen({
    super.key,
    required this.title,
    required this.url,
    this.initialDesktopMode = false,
  });

  /// Whether a main-frame navigation to [url] stays on the origin [rootUrl]
  /// was opened from: only http(s), only the root host or a subdomain of it.
  /// Kept as a pure function so the gate is unit-testable without a WebView.
  @visibleForTesting
  static bool allowNavigation(String rootUrl, String url) {
    final root = Uri.tryParse(rootUrl)?.host.toLowerCase() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    if (root.isEmpty) return true;
    return host == root || host.endsWith('.$root');
  }

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  // One controller per URL, kept alive across screen opens. This is what lets a
  // chat site (Qaf) keep its conversation when the user pops and reopens it,
  // instead of every open being a cold reload that wipes the message list.
  static final Map<String, WebViewController> _tabs = {};
  static const int _kMaxTabs = 8;
  static const String _kDesktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  late final WebViewController _controller;
  late bool _desktopMode;
  int _progress = 0;
  bool _failed = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _showFind = false;
  bool _showUrl = false;
  double _zoom = 1.0;
  final TextEditingController _findCtrl = TextEditingController();
  final GlobalKey<PopupMenuButtonState<String>> _moreKey =
      GlobalKey<PopupMenuButtonState<String>>();

  @override
  void initState() {
    super.initState();
    _desktopMode = widget.initialDesktopMode;
    final cached = _tabs[widget.url];
    if (cached != null) {
      _controller = cached;
      _progress = _failed ? 0 : 100;
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white);
      _tabs[widget.url] = _controller;
      _evictIfNeeded();
      _controller.loadRequest(Uri.parse(widget.url));
    }
    _controller.setNavigationDelegate(_delegate());
    if (_desktopMode) _controller.setUserAgent(_kDesktopUserAgent);
    _refreshNavState();
  }

  void _evictIfNeeded() {
    while (_tabs.length > _kMaxTabs) {
      _tabs.remove(_tabs.keys.first);
    }
  }

  NavigationDelegate _delegate() => NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (_) => _refreshNavState(),
        // Confine top-level navigation to the opened origin (see
        // [allowNavigation]); the AppBar browser hatch still reaches
        // anywhere. Off-site sub-resources are unaffected.
        onNavigationRequest: (request) =>
            InAppBrowserScreen.allowNavigation(widget.url, request.url)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
        onWebResourceError: (_) {
          if (mounted) setState(() => _failed = true);
        },
      );

  Future<void> _refreshNavState() async {
    final back = await _controller.canGoBack();
    final fwd = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = fwd;
    });
  }

  void _reload() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller.reload();
  }

  void _goHome() => _controller.loadRequest(Uri.parse(widget.url));

  Future<void> _share() =>
      ShareService.shareText(widget.url, subject: widget.title);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('نشانی صفحه کپی شد')),
    );
  }

  Future<void> _find() async {
    final q = _findCtrl.text.trim();
    if (q.isEmpty) return;
    await _controller.runJavaScript('window.find(${_jsLiteral(q)})');
  }

  void _toggleDesktop() {
    setState(() => _desktopMode = !_desktopMode);
    _controller.setUserAgent(_desktopMode ? _kDesktopUserAgent : null);
    _controller.reload();
  }

  void _zoomBy(double factor) {
    _zoom = (_zoom * factor).clamp(0.5, 2.5);
    _controller
        .runJavaScript('document.documentElement.style.zoom = $_zoom');
  }

  /// Minimal JS string literal escaping for window.find().
  String _jsLiteral(String s) {
    final out = s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll("'", r"\'")
        .replaceAll('\n', ' ');
    return '"$out"';
  }

  @override
  void dispose() {
    _findCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SectionAppBar(
        title: widget.title,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _progress < 100
              ? LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 2,
                  color: scheme.primary,
                )
              : const SizedBox(height: 2),
        ),
        actions: [
          IconButton(
            tooltip: 'پیدا کردن در صفحه',
            icon: const Icon(Icons.search_outlined),
            onPressed: () => setState(() => _showFind = !_showFind),
          ),
          IconButton(
            tooltip: 'نشانی صفحه',
            icon: const Icon(Icons.link_outlined),
            onPressed: () => setState(() => _showUrl = !_showUrl),
          ),
          IconButton(
            tooltip: 'باز کردن در مرورگر',
            icon: const Icon(Icons.open_in_browser_outlined),
            onPressed: () => launchUrl(
              Uri.parse(widget.url),
              mode: LaunchMode.externalApplication,
            ),
          ),
          _moreMenu(scheme, key: _moreKey),
        ],
      ),
      body: Column(
        children: [
          if (_showUrl)
            _UrlBar(
              url: widget.url,
              onCopy: _copy,
            ),
          if (_showFind)
            _FindBar(
              controller: _findCtrl,
              onFind: _find,
              onClose: () => setState(() => _showFind = false),
            ),
          Expanded(
            // The WebView owns the space above our toolbar; the site's own
            // bottom controls therefore sit above the toolbar and are never
            // hidden under the system navigation bar.
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: false,
              child: _failed
                  ? _ErrorView(onRetry: _reload)
                  : WebViewWidget(controller: _controller),
            ),
          ),
          _BottomToolbar(
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            onBack: () => _controller.goBack(),
            onForward: () => _controller.goForward(),
            onReload: _reload,
            onHome: _goHome,
            onShare: _share,
            onMore: () => _moreKey.currentState?.showButtonMenu(),
          ),
        ],
      ),
    );
  }

  Widget _moreMenu(ColorScheme scheme, {Key? key}) => PopupMenuButton<String>(
        key: key,
        tooltip: 'بیشتر',
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'desktop':
              _toggleDesktop();
            case 'zoom_in':
              _zoomBy(1.25);
            case 'zoom_out':
              _zoomBy(0.8);
            case 'copy':
              _copy();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'desktop',
            child: Row(
              children: [
                Icon(_desktopMode ? Icons.check : Icons.desktop_windows_outlined,
                    size: 18),
                const SizedBox(width: 8),
                const Text('حالت دسکتاپ'),
              ],
            ),
          ),
          const PopupMenuItem(
              value: 'zoom_in', child: Text('بزرگ‌نمایی متن (+)')),
          const PopupMenuItem(
              value: 'zoom_out', child: Text('کوچک‌نمایی متن (−)')),
          const PopupMenuItem(value: 'copy', child: Text('کپی نشانی')),
        ],
      );
}

/// Read-only address line revealed by the link button.
class _UrlBar extends StatelessWidget {
  const _UrlBar({required this.url, required this.onCopy});

  final String url;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: .5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              url,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'کپی نشانی',
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

/// Find-in-page bar: type a query and step through matches via window.find().
class _FindBar extends StatelessWidget {
  const _FindBar({
    required this.controller,
    required this.onFind,
    required this.onClose,
  });

  final TextEditingController controller;
  final VoidCallback onFind;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: .5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'جستجو در صفحه…',
                isCollapsed: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (_) => onFind(),
            ),
          ),
          IconButton(
            tooltip: 'یافتن',
            icon: const Icon(Icons.search_outlined, size: 18),
            onPressed: onFind,
          ),
          IconButton(
            tooltip: 'بستن',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Always-visible bottom navigation bar, kept inside the safe area so it never
/// hides under the system navigation bar on 3-button phones.
class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    required this.onHome,
    required this.onShare,
    required this.onMore,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final VoidCallback onHome;
  final VoidCallback onShare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(color: scheme.outline.withValues(alpha: .25)),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _toolBtn(context, Icons.arrow_back_outlined, 'بازگشت', canGoBack ? onBack : null),
            _toolBtn(context, Icons.arrow_forward_outlined, 'جلو', canGoForward ? onForward : null),
            _toolBtn(context, Icons.refresh_outlined, 'بارگذاری دوباره', onReload),
            _toolBtn(context, Icons.home_outlined, 'خانه', onHome),
            _toolBtn(context, Icons.share_outlined, 'اشتراک‌گذاری', onShare),
            _toolBtn(context, Icons.more_vert, 'بیشتر', onMore),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(BuildContext context, IconData icon, String tooltip, VoidCallback? onPressed) =>
      IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        color: onPressed == null ? null : Theme.of(context).colorScheme.primary,
      );
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Was three hardcoded greys that ignored both the time theme and dark
    // mode. The browser is a network surface, so the glyph says so.
    return FailureView(
      id: 'in_app_browser_load',
      title: 'اتصال اینترنت برقرار نیست',
      detail: 'صفحه از وب خوانده می‌شود و به اتصال نیاز دارد؛ با تلاش دوباره '
          'از نو بارگذاری می‌شود.',
      onRetry: onRetry,
      layout: FailureLayout.page,
      icon: Icons.wifi_off_outlined,
    );
  }
}
