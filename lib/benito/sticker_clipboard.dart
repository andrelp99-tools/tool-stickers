// BenitoSticker: copia / taglia / incolla sticker tra pacchetti, duplica e unisci pacchetti.
//
// Regole (scelte da Andrea):
//  - se il pacchetto di destinazione si riempie (30), il resto va in "Nome 2", "Nome 3"…
//  - sticker animati e fissi non si mescolano: quelli dell'altro tipo vanno in
//    "Nome animati" (o "Nome fissi" se la destinazione è animata).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:stickers/benito/pack_importer.dart';
import 'package:stickers/benito/strings.dart';
import 'package:stickers/benito/webp_codec.dart';
import 'package:stickers/src/constants.dart';
import 'package:stickers/src/data/load_store.dart';
import 'package:stickers/src/data/sticker.dart';
import 'package:stickers/src/data/sticker_pack.dart';
import 'package:stickers/src/globals.dart';

class ClipItem {
  /// Copia del file negli appunti (resta valida anche se l'originale viene eliminato)
  final String path;
  final List<String> emojis;
  final bool animated;

  /// File originale e pacchetto, per "Taglia"
  final String sourcePath;
  final String sourcePackId;

  ClipItem(this.path, this.emojis, this.animated, this.sourcePath, this.sourcePackId);
}

class StickerClipboard extends ChangeNotifier {
  StickerClipboard._();

  static final instance = StickerClipboard._();

  final List<ClipItem> _items = [];
  bool _cut = false;

  List<ClipItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  bool get isCut => _cut;

  int get length => _items.length;

  String get _dir => '$mediaCacheDir/../benito_clipboard';

  /// Mette negli appunti gli sticker [stickers] del pacchetto [pack].
  Future<void> put(StickerPack pack, List<Sticker> stickers, {required bool cut}) async {
    await clear(notify: false);
    final dir = Directory(_dir);
    await dir.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < stickers.length; i++) {
      final copy = '${dir.path}/${stamp}_$i.webp';
      await File(stickers[i].source).copy(copy);
      _items.add(ClipItem(copy, List.of(stickers[i].emojis), pack.animated, stickers[i].source, pack.id));
    }
    _cut = cut;
    notifyListeners();
  }

  Future<void> clear({bool notify = true}) async {
    for (final it in _items) {
      final f = File(it.path);
      if (f.existsSync()) f.deleteSync();
    }
    _items.clear();
    _cut = false;
    if (notify) notifyListeners();
  }

  /// Incolla nel pacchetto [target]. Restituisce i pacchetti toccati.
  Future<ImportSummary> pasteInto(StickerPack target) async {
    if (_cut && _items.every((it) => it.sourcePackId == target.id)) {
      throw StateError(BStr.cantPasteSame);
    }
    final summary = await pasteStickersInto(
      target,
      [for (final it in _items) (await File(it.path).readAsBytes(), it.animated, it.emojis)],
    );
    if (_cut) {
      final bySource = <String, Set<String>>{};
      for (final it in _items) {
        bySource.putIfAbsent(it.sourcePackId, () => {}).add(it.sourcePath);
      }
      bySource.forEach((packId, paths) {
        final src = packs.where((p) => p.id == packId).firstOrNull;
        if (src != null) removeStickers(src, paths);
      });
      await clear();
    } else {
      notifyListeners();
    }
    savePacks(packs);
    homeState?.update();
    return summary;
  }
}

/// Toglie dal pacchetto gli sticker con questi percorsi e cancella i file.
void removeStickers(StickerPack pack, Set<String> paths) {
  pack.stickers.removeWhere((s) => paths.contains(s.source));
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) f.deleteSync();
  }
  pack.onEdit();
  savePacks(packs);
}

/// Aggiunge sticker (byte, animato, emoji) a [target] seguendo le regole sopra.
Future<ImportSummary> pasteStickersInto(StickerPack target, List<(Uint8List, bool, List<String>)> stickers) {
  final sameTitle = target.title;
  final otherTitle = '${target.title} ${target.animated ? BStr.staticSuffix : BStr.animatedSuffix}';
  return addStickersToPacks(
    [for (final (data, animated, emojis) in stickers) ProcessedSticker(data, animated, emojis: emojis)],
    baseTitle: target.animated ? otherTitle : sameTitle,
    animatedTitle: target.animated ? sameTitle : otherTitle,
    preferred: target,
  );
}

/// Copia tutto [source] dentro [target] (unione). Con [move] svuota e cancella [source].
Future<ImportSummary> mergePack(StickerPack source, StickerPack target, {required bool move}) async {
  final items = [
    for (final s in source.stickers) (await File(s.source).readAsBytes(), source.animated, List.of(s.emojis)),
  ];
  final summary = await pasteStickersInto(target, items);
  if (move) {
    packs.remove(source);
    final dir = Directory('$packsDir/${source.id}');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
  savePacks(packs);
  homeState?.update();
  return summary;
}

/// Crea una copia identica di [source], subito dopo l'originale nell'elenco.
Future<StickerPack> duplicatePack(StickerPack source) async {
  var name = '${source.title} (${BStr.copySuffix})';
  var n = 2;
  while (packs.any((p) => p.title == name)) {
    name = '${source.title} (${BStr.copySuffix} $n)';
    n++;
  }
  final id = 'pack_${DateTime.now().microsecondsSinceEpoch}';
  final dir = Directory('$packsDir/$id');
  await dir.create(recursive: true);
  final stickers = <Sticker>[];
  for (var i = 0; i < source.stickers.length; i++) {
    final copy = '${dir.path}/sticker_${i}_${DateTime.now().millisecondsSinceEpoch}.webp';
    await File(source.stickers[i].source).copy(copy);
    stickers.add(Sticker(copy, List.of(source.stickers[i].emojis)));
  }
  String? tray;
  if (source.trayIcon != null && File(source.trayIcon!).existsSync()) {
    tray = '${dir.path}/tray_${DateTime.now().millisecondsSinceEpoch}.webp';
    await File(source.trayIcon!).copy(tray);
  }
  final pack = StickerPack(
    name,
    source.author,
    id,
    stickers,
    '0',
    source.animated,
    trayIcon: tray,
    publisherWebsite: source.publisherWebsite,
    privacyPolicyWebsite: source.privacyPolicyWebsite,
    licenseAgreementWebsite: source.licenseAgreementWebsite,
  );
  packs.insert(packs.indexOf(source) + 1, pack);
  savePacks(packs);
  homeState?.update();
  return pack;
}

/// Pacchetto nuovo e vuoto (per "Copia in… → Nuovo pacchetto").
StickerPack createEmptyPack(String title, bool animated) {
  final pack = StickerPack(
    title,
    settingsController.defaultAuthor.isEmpty ? 'BenitoSticker' : settingsController.defaultAuthor,
    'pack_${DateTime.now().microsecondsSinceEpoch}',
    [],
    '0',
    animated,
  );
  packs.add(pack);
  savePacks(packs);
  return pack;
}
