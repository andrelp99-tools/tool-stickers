// BenitoSticker: importa gli sticker dalle chat di TikTok.
// Apre TikTok web (versione desktop) dentro l'app; uno script osserva la pagina
// e raccoglie gli indirizzi delle immagini-sticker visibili nelle chat.
// Codice scritto da zero (idea ispirata a Itsnicee/tiktok-to-whatsapp-stickers).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickers/benito/strings.dart';
import 'package:stickers/benito/tiktok/tiktok_select_page.dart';
import 'package:webview_flutter/webview_flutter.dart';

const tiktokMessagesUrl = 'https://www.tiktok.com/messages';
const desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/141.0.0.0 Safari/537.36';

/// Script iniettato nella pagina. Invia a Flutter (canale "Benito") gli
/// indirizzi nuovi trovati, in JSON. Con window.__benitoAll = true prende
/// tutte le immagini abbastanza grandi (modalità di riserva).
const _collectorJs = r'''
(function () {
  try {
    var vp = document.querySelector('meta[name=viewport]');
    if (vp) vp.setAttribute('content', 'width=1200');
  } catch (e) {}
  if (window.__benito) { window.__benito.scan(); return; }
  var seen = {};
  function looksLikeSticker(img) {
    var alt = (img.getAttribute('alt') || '').toLowerCase();
    if (alt.indexOf('sticker') >= 0) return true;
    var el = img, depth = 0;
    while (el && depth < 4) {
      var c = (typeof el.className === 'string') ? el.className : '';
      var t = el.getAttribute ? (el.getAttribute('data-e2e') || '') : '';
      if (/sticker/i.test(c) || /sticker/i.test(t)) return true;
      el = el.parentElement; depth++;
    }
    return false;
  }
  function bigEnough(img) {
    var r = img.getBoundingClientRect();
    return r.width >= 48 && r.height >= 48;
  }
  function scan() {
    var found = [];
    var imgs = document.querySelectorAll('img');
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.src;
      if (!src || src.indexOf('http') !== 0) continue;
      var ok = looksLikeSticker(img) || (window.__benitoAll && bigEnough(img));
      if (!ok || seen[src]) continue;
      seen[src] = 1;
      found.push(src);
    }
    if (found.length) Benito.postMessage(JSON.stringify(found));
  }
  window.__benito = { scan: scan };
  new MutationObserver(function () { scan(); }).observe(document.documentElement,
    { subtree: true, childList: true, attributes: true, attributeFilter: ['src'] });
  setInterval(scan, 1500);
  scan();
})();
''';

/// Chiave per riconoscere lo stesso sticker anche se cambia la firma nell'URL.
String stickerKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  return uri.path;
}

class TikTokImportPage extends StatefulWidget {
  const TikTokImportPage({super.key});

  @override
  State<TikTokImportPage> createState() => _TikTokImportPageState();
}

class _TikTokImportPageState extends State<TikTokImportPage> {
  late final WebViewController _controller;
  final Map<String, String> _found = {}; // chiave -> url
  int _progress = 0;
  bool _allImages = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(desktopUserAgent)
      ..enableZoom(true)
      ..addJavaScriptChannel('Benito', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageFinished: (_) => _inject(),
        onUrlChange: (_) => _inject(),
      ))
      ..loadRequest(Uri.parse(tiktokMessagesUrl));
    _maybeShowHelp();
  }

  Future<void> _inject() async {
    try {
      if (_allImages) await _controller.runJavaScript('window.__benitoAll = true;');
      await _controller.runJavaScript(_collectorJs);
    } catch (_) {}
  }

  void _onMessage(JavaScriptMessage message) {
    try {
      final urls = (jsonDecode(message.message) as List).cast<String>();
      var changed = false;
      for (final url in urls) {
        final key = stickerKey(url);
        if (!_found.containsKey(key)) {
          _found[key] = url;
          changed = true;
        }
      }
      if (changed && mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _maybeShowHelp() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('benito_tiktok_help_seen') ?? false) return;
    await prefs.setBool('benito_tiktok_help_seen', true);
    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _showHelp());
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(BStr.tiktokTitle),
        content: Text(BStr.tiktokHelp),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(BStr.gotIt))],
      ),
    );
  }

  Future<void> _enableAllImages() async {
    setState(() => _allImages = true);
    await _inject();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(BStr.tiktokTitle),
          actions: [
            IconButton(tooltip: BStr.help, icon: const Icon(Icons.help_outline), onPressed: _showHelp),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'reload') _controller.reload();
                if (v == 'all') _enableAllImages();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'reload', child: Text(BStr.reload)),
                CheckedPopupMenuItem(
                  value: 'all',
                  checked: _allImages,
                  child: Text(BStr.allImages),
                ),
              ],
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _found.isEmpty
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TikTokSelectPage(urls: _found.values.toList()),
                  )),
          backgroundColor: _found.isEmpty ? Theme.of(context).disabledColor : null,
          icon: Badge(
            label: Text('${_found.length}'),
            isLabelVisible: _found.isNotEmpty,
            child: const Icon(Icons.collections_outlined),
          ),
          label: Text(_found.isEmpty ? BStr.found(0) : BStr.next),
        ),
      ),
    );
  }
}
