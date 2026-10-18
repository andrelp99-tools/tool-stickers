// BenitoSticker: scarica gli sticker raccolti da TikTok, li mostra, l'utente
// sceglie quali tenere, poi li converte e li mette nei pacchetti
// "TikTok" (statici) e "TikTok animati".
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickers/benito/pack_importer.dart';
import 'package:stickers/benito/strings.dart';
import 'package:stickers/benito/tiktok/tiktok_page.dart';
import 'package:stickers/benito/webp_codec.dart';
import 'package:stickers/src/globals.dart';

const _importedKey = 'benito_tiktok_imported';

class _Item {
  final String url;
  final Uint8List bytes;
  bool selected;
  final bool alreadyImported;

  _Item(this.url, this.bytes, {required this.selected, required this.alreadyImported});
}

class TikTokSelectPage extends StatefulWidget {
  final List<String> urls;

  const TikTokSelectPage({super.key, required this.urls});

  @override
  State<TikTokSelectPage> createState() => _TikTokSelectPageState();
}

class _TikTokSelectPageState extends State<TikTokSelectPage> {
  final List<_Item> _items = [];
  int _done = 0;
  int _failed = 0;
  bool _downloading = true;
  bool _converting = false;
  int _converted = 0;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    final prefs = await SharedPreferences.getInstance();
    final imported = (prefs.getStringList(_importedKey) ?? []).toSet();
    final client = http.Client();
    try {
      // 4 download alla volta.
      final queue = List<String>.from(widget.urls);
      Future<void> worker() async {
        while (queue.isNotEmpty) {
          final url = queue.removeAt(0);
          try {
            final res = await client.get(Uri.parse(url), headers: {
              'User-Agent': desktopUserAgent,
              'Referer': 'https://www.tiktok.com/',
            }).timeout(const Duration(seconds: 20));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              final already = imported.contains(stickerKey(url));
              _items.add(_Item(url, res.bodyBytes, selected: !already, alreadyImported: already));
            } else {
              _failed++;
            }
          } catch (_) {
            _failed++;
          }
          _done++;
          if (mounted) setState(() {});
        }
      }

      await Future.wait(List.generate(4, (_) => worker()));
    } finally {
      client.close();
    }
    if (mounted) setState(() => _downloading = false);
  }

  int get _selectedCount => _items.where((i) => i.selected).length;

  Future<void> _import() async {
    final chosen = _items.where((i) => i.selected).toList();
    setState(() {
      _converting = true;
      _converted = 0;
    });
    final processed = <ProcessedSticker>[];
    final keys = <String>[];
    var failed = 0;
    for (final item in chosen) {
      try {
        processed.add(await convertToSticker(item.bytes, mediaCacheDir));
        keys.add(stickerKey(item.url));
      } catch (e) {
        debugPrint('BenitoSticker: conversione fallita ${item.url}: $e');
        failed++;
      }
      if (mounted) setState(() => _converted++);
    }

    final summary = await addStickersToPacks(
      processed,
      baseTitle: BStr.packTitleTikTok,
      animatedTitle: BStr.packTitleTikTokAnimated,
    );

    final prefs = await SharedPreferences.getInstance();
    final imported = (prefs.getStringList(_importedKey) ?? []).toSet()..addAll(keys);
    await prefs.setStringList(_importedKey, imported.toList());

    if (!mounted) return;
    setState(() => _converting = false);
    final tooFew = packs.any((p) => summary.packTitles.contains(p.title) && p.stickers.length < 3);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(BStr.importDone),
        content: Text([
          BStr.importSummary(summary.added, summary.packTitles),
          if (failed > 0) BStr.failedN(failed),
          if (tooFew) BStr.tooFewWarning,
        ].join('\n\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(BStr.ok))],
      ),
    );
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(BStr.chooseStickers),
        actions: [
          if (!_downloading && _items.isNotEmpty)
            TextButton(
              onPressed: _converting
                  ? null
                  : () => setState(() {
                        final all = _selectedCount < _items.length;
                        for (final i in _items) {
                          i.selected = all;
                        }
                      }),
              child: Text(_selectedCount < _items.length ? BStr.selectAll : BStr.selectNone),
            ),
        ],
        bottom: (_downloading || _converting)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _downloading
                      ? (total == 0 ? null : _done / total)
                      : (_selectedCount == 0 ? null : _converted / _selectedCount),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          if (_downloading || _converting || _failed > 0)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _downloading
                    ? '${BStr.downloading} $_done/$total'
                    : _converting
                        ? '${BStr.converting} $_converted/$_selectedCount'
                        : BStr.failedN(_failed),
              ),
            ),
          Expanded(
            child: !_downloading && _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(BStr.nothingDownloaded, textAlign: TextAlign.center),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final scheme = Theme.of(context).colorScheme;
                      return GestureDetector(
                        onTap: _converting ? null : () => setState(() => item.selected = !item.selected),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: item.selected ? scheme.primary : scheme.outlineVariant,
                              width: item.selected ? 3 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Image.memory(
                                    item.bytes,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(
                                  item.selected ? Icons.check_circle : Icons.circle_outlined,
                                  color: item.selected ? scheme.primary : scheme.outline,
                                  size: 22,
                                ),
                              ),
                              if (item.alreadyImported)
                                Positioned(
                                  left: 4,
                                  bottom: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(BStr.alreadyImported, style: const TextStyle(fontSize: 9)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: (_downloading || _converting || _selectedCount == 0)
          ? null
          : FloatingActionButton.extended(
              onPressed: _import,
              icon: const Icon(Icons.download_done),
              label: Text(BStr.importN(_selectedCount)),
            ),
    );
  }
}
