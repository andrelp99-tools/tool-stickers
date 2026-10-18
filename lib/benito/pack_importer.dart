// BenitoSticker: aggiunge sticker già convertiti ai pacchetti, dividendo
// statici e animati (WhatsApp non li mescola) e riempiendo fino a 30 per pacchetto.
import 'dart:io';

import 'package:stickers/benito/webp_codec.dart';
import 'package:stickers/src/data/load_store.dart';
import 'package:stickers/src/data/sticker.dart';
import 'package:stickers/src/data/sticker_pack.dart';
import 'package:stickers/src/globals.dart';

const int maxStickersPerPack = 30;

class ImportSummary {
  final int added;
  final List<String> packTitles;

  ImportSummary(this.added, this.packTitles);
}

/// [baseTitle] es. "TikTok" → pacchetti "TikTok", "TikTok 2"... e
/// [animatedTitle] es. "TikTok animati".
/// Se [appendToExisting] riempie prima i pacchetti con lo stesso nome.
Future<ImportSummary> addStickersToPacks(
  List<ProcessedSticker> stickers, {
  required String baseTitle,
  required String animatedTitle,
  bool appendToExisting = true,
}) async {
  final touched = <String>{};
  var added = 0;
  for (final animated in [false, true]) {
    final group = stickers.where((s) => s.animated == animated).toList();
    if (group.isEmpty) continue;
    final title = animated ? animatedTitle : baseTitle;
    var index = 0;
    while (index < group.length) {
      final pack = _packWithRoom(title, animated, appendToExisting);
      final room = maxStickersPerPack - pack.stickers.length;
      final chunk = group.skip(index).take(room).toList();
      await Directory('$packsDir/${pack.id}').create(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < chunk.length; i++) {
        final file = File('$packsDir/${pack.id}/benito_${stamp}_$i.webp');
        await file.writeAsBytes(chunk[i].data);
        pack.stickers.add(Sticker(file.path, ['❤']));
      }
      pack.onEdit();
      touched.add(pack.title);
      added += chunk.length;
      index += chunk.length;
    }
  }
  savePacks(packs);
  homeState?.update();
  return ImportSummary(added, touched.toList());
}

StickerPack _packWithRoom(String title, bool animated, bool appendToExisting) {
  if (appendToExisting) {
    for (final p in packs) {
      if (p.animated == animated &&
          p.stickers.length < maxStickersPerPack &&
          (p.title == title || RegExp('^${RegExp.escape(title)} \\d+\$').hasMatch(p.title))) {
        return p;
      }
    }
  }
  var name = title;
  var n = 2;
  while (packs.any((p) => p.title == name)) {
    name = '$title $n';
    n++;
  }
  final pack = StickerPack(
    name,
    settingsController.defaultAuthor.isEmpty ? 'BenitoSticker' : settingsController.defaultAuthor,
    'pack_${DateTime.now().microsecondsSinceEpoch}',
    [],
    '0',
    animated,
  );
  packs.add(pack);
  return pack;
}
