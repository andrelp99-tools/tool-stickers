// BenitoSticker: importa gli sticker ricevuti su WhatsApp (cartella
// "WhatsApp Stickers"), così finiscono nei pacchetti e nella tastiera sticker.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickers/benito/select_stickers_page.dart';
import 'package:stickers/benito/strings.dart';

const _channel = MethodChannel('it.andrelp99.benito/main');

Future<void> openWhatsAppReceivedImport(BuildContext context, {bool forcePick = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final firstTime = !(prefs.getBool('benito_wa_folder_ok') ?? false);
  if ((firstTime || forcePick) && context.mounted) {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(BStr.importWhatsApp),
        content: Text('${BStr.waFolderHelp}\n\n${BStr.waFolderNotFound}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(BStr.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(BStr.cont)),
        ],
      ),
    );
    if (go != true) return;
  }

  final List<String>? paths;
  try {
    paths = (await _channel.invokeMethod<List<dynamic>>('loadWhatsAppStickers', {
      'forcePick': forcePick,
    }))
        ?.cast<String>();
  } on PlatformException catch (e) {
    debugPrint('BenitoSticker: cartella WhatsApp non leggibile: $e');
    return;
  }
  if (paths == null) return; // annullato
  await prefs.setBool('benito_wa_folder_ok', true);
  if (!context.mounted) return;

  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SelectStickersPage(
      importedPrefsKey: 'benito_wa_imported',
      baseTitle: BStr.packTitleWhatsApp,
      animatedTitle: BStr.packTitleWhatsAppAnimated,
      loader: (onProgress) async {
        final result = <CandidateImage>[];
        var failed = 0;
        for (var i = 0; i < paths!.length; i++) {
          try {
            final f = File(paths[i]);
            result.add(CandidateImage(f.uri.pathSegments.last, await f.readAsBytes()));
          } catch (_) {
            failed++;
          }
          onProgress(i + 1, paths.length, failed);
        }
        return result;
      },
    ),
  ));
}
