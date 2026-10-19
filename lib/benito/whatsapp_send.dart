// BenitoSticker: "Aggiungi a WhatsApp" riscritto sul formato del progetto ufficiale
// WhatsApp/stickers (la libreria originale non va più con le versioni recenti di WhatsApp).
//
// Prima dell'invio ogni sticker viene controllato e, se serve, ricodificato:
// 512x512, WebP, max 100 kB (statici) / 500 kB (animati), tutti dello stesso tipo
// del pacchetto. I file pronti finiscono in <pacchetto>/wa/ e l'elenco in
// packs/whatsapp.json, che il provider Android (BenitoWaProvider) mostra a WhatsApp.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stickers/benito/strings.dart';
import 'package:stickers/benito/webp_codec.dart';
import 'package:stickers/src/constants.dart';
import 'package:stickers/src/data/sticker_pack.dart';
import 'package:stickers/src/globals.dart';

const _channel = MethodChannel('it.andrelp99.benito/main');

String _clean(String s, String fallback) {
  final t = s.trim();
  if (t.isEmpty) return fallback;
  return t.length > 120 ? t.substring(0, 120) : t;
}

/// Prepara i file per WhatsApp. Restituisce quanti sticker sono stati ricodificati.
Future<int> _prepare(StickerPack pack) async {
  final waDir = Directory('$packsDir/${pack.id}/wa');
  if (waDir.existsSync()) waDir.deleteSync(recursive: true);
  waDir.createSync(recursive: true);
  await Directory(mediaCacheDir).create(recursive: true);

  var repaired = 0;
  final stickers = <Map<String, dynamic>>[];
  Uint8List? first;
  for (var i = 0; i < pack.stickers.length && i < 30; i++) {
    final s = pack.stickers[i];
    final (bytes, changed) = await fitForPack(await File(s.source).readAsBytes(), pack.animated, mediaCacheDir);
    if (changed) repaired++;
    first ??= bytes;
    final name = '${i + 1}.webp';
    await File('${waDir.path}/$name').writeAsBytes(bytes, flush: true);
    var emojis = s.emojis.where((e) => e.trim().isNotEmpty).take(3).toList();
    if (emojis.isEmpty) emojis = ['❤'];
    stickers.add({'file': name, 'emojis': emojis});
  }

  // Icona: quella scelta per il pacchetto, altrimenti il primo sticker
  Uint8List traySource = first!;
  if (pack.trayIcon != null && File(pack.trayIcon!).existsSync()) {
    traySource = await File(pack.trayIcon!).readAsBytes();
  }
  await File('${waDir.path}/tray.png').writeAsBytes(await makeTrayIcon(traySource), flush: true);

  // Aggiorna l'elenco letto dal provider (mantiene gli altri pacchetti già aggiunti)
  final config = File('$packsDir/whatsapp.json');
  List<dynamic> list = [];
  if (config.existsSync()) {
    try {
      list = (jsonDecode(await config.readAsString())['packs'] as List<dynamic>?) ?? [];
    } catch (_) {}
  }
  list.removeWhere((p) => p is Map && p['identifier'] == pack.id);
  list.add({
    'identifier': pack.id,
    'name': _clean(pack.title, 'BenitoSticker'),
    'publisher': _clean(pack.author, 'BenitoSticker'),
    'tray': 'tray.png',
    // Cambia a ogni invio: così WhatsApp ricarica sempre le immagini aggiornate
    'image_data_version': '${pack.imageDataVersion}.${DateTime.now().millisecondsSinceEpoch}',
    'animated': pack.animated,
    'stickers': stickers,
  });
  await config.writeAsString(jsonEncode({'packs': list}), flush: true);
  return repaired;
}

Future<void> benitoAddToWhatsApp(StickerPack pack, BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (pack.stickers.length < 3) {
    messenger?.showSnackBar(SnackBar(content: Text(BStr.waTooFew)));
    return;
  }
  final nav = navigatorKey.currentState;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(BStr.waPreparing)),
        ]),
      ),
    ),
  );
  int repaired;
  try {
    repaired = await _prepare(pack);
  } catch (e) {
    nav?.pop();
    _showError(pack, e.toString(), withDiagnosis: false);
    return;
  }
  nav?.pop();
  if (repaired > 0) messenger?.showSnackBar(SnackBar(content: Text(BStr.waRepaired(repaired))));

  Map<dynamic, dynamic>? res;
  try {
    res = await _channel.invokeMethod<Map<dynamic, dynamic>>('waSend', {
      'identifier': pack.id,
      'name': _clean(pack.title, 'BenitoSticker'),
    });
  } on PlatformException catch (e) {
    _showError(pack, e.message ?? e.code);
    return;
  }
  switch (res?['status']) {
    case 'added':
      messenger?.showSnackBar(SnackBar(content: Text(BStr.waAdded)));
    case 'already':
      messenger?.showSnackBar(SnackBar(content: Text(BStr.waAlready)));
    case 'no_whatsapp':
      _showError(pack, BStr.waNotInstalled, withDiagnosis: false);
    case 'error':
      _showError(pack, '${res?['error'] ?? ''}');
    default:
      break; // annullato dall'utente
  }
}

void _showError(StickerPack pack, String message, {bool withDiagnosis = true}) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  showDialog(
    context: ctx,
    builder: (dialogContext) => AlertDialog(
      title: Text(BStr.waFailed),
      content: Text(message),
      actions: [
        if (withDiagnosis)
          TextButton(
            onPressed: () async {
              String text;
              try {
                text = await _channel.invokeMethod<String>('waDiagnose', {
                      'identifier': pack.id,
                      'error': message,
                    }) ??
                    '';
              } catch (e) {
                text = 'Diagnosi non riuscita: $e';
              }
              await Clipboard.setData(ClipboardData(text: text));
              if (dialogContext.mounted) {
                ScaffoldMessenger.maybeOf(dialogContext)
                    ?.showSnackBar(SnackBar(content: Text(BStr.diagnosisCopied)));
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(BStr.copyDiagnosis),
          ),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(BStr.close)),
      ],
    ),
  );
}
