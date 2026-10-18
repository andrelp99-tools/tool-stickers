// BenitoSticker: pagina comune di scelta sticker. Carica le immagini da una
// fonte (TikTok, sticker ricevuti su WhatsApp...), l'utente sceglie quali
// tenere, poi vengono convertite e messe nei pacchetti (statici / animati).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickers/benito/pack_importer.dart';
import 'package:stickers/benito/strings.dart';
import 'package:stickers/benito/webp_codec.dart';
import 'package:stickers/src/globals.dart';

/// Un'immagine candidata: [key] la riconosce tra un import e l'altro.
class CandidateImage {
  final String key;
  final Uint8List bytes;

  CandidateImage(this.key, this.bytes);
}

/// Carica le immagini; chiama [onProgress](fatte, totale, fallite) mentre procede.
typedef CandidateLoader = Future<List<CandidateImage>> Function(
    void Function(int done, int total, int failed) onProgress);

class _Item {
  final String key;
  final Uint8List bytes;
  bool selected;
  final bool alreadyImported;

  _Item(this.key, this.bytes, {required this.selected, required this.alreadyImported});
}

class SelectStickersPage extends StatefulWidget {
  final CandidateLoader loader;

  /// Chiave SharedPreferences dove ricordare cosa è già stato importato.
  final String importedPrefsKey;
  final String baseTitle;
  final String animatedTitle;

  const SelectStickersPage({
    super.key,
    required this.loader,
    required this.importedPrefsKey,
    required this.baseTitle,
    required this.animatedTitle,
  });

  @override
  State<SelectStickersPage> createState() => _SelectStickersPageState();
}

class _SelectStickersPageState extends State<SelectStickersPage> {
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

  int _total = 0;

  Future<void> _download() async {
    final prefs = await SharedPreferences.getInstance();
    final imported = (prefs.getStringList(widget.importedPrefsKey) ?? []).toSet();
    List<CandidateImage> loaded = [];
    try {
      loaded = await widget.loader((done, total, failed) {
        if (!mounted) return;
        setState(() {
          _done = done;
          _total = total;
          _failed = failed;
        });
      });
    } catch (e) {
      debugPrint('BenitoSticker: caricamento fallito: $e');
    }
    final seen = <String>{};
    for (final c in loaded) {
      if (!seen.add(c.key)) continue;
      final already = imported.contains(c.key);
      _items.add(_Item(c.key, c.bytes, selected: !already, alreadyImported: already));
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
        keys.add(item.key);
      } catch (e) {
        debugPrint('BenitoSticker: conversione fallita ${item.key}: $e');
        failed++;
      }
      if (mounted) setState(() => _converted++);
    }

    final summary = await addStickersToPacks(
      processed,
      baseTitle: widget.baseTitle,
      animatedTitle: widget.animatedTitle,
    );

    final prefs = await SharedPreferences.getInstance();
    final imported = (prefs.getStringList(widget.importedPrefsKey) ?? []).toSet()..addAll(keys);
    await prefs.setStringList(widget.importedPrefsKey, imported.toList());

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
    final total = _total;
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
