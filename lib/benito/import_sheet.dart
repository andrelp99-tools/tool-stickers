// BenitoSticker: menu "Importa" con le fonti aggiunte dal fork.
import 'package:flutter/material.dart';
import 'package:stickers/benito/strings.dart';
import 'package:stickers/benito/tiktok/tiktok_page.dart';

/// Pulsante per la barra in alto della home.
class BenitoImportButton extends StatelessWidget {
  const BenitoImportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: BStr.importFrom,
      icon: const Icon(Icons.add_photo_alternate_outlined),
      onPressed: () => showBenitoImportSheet(context),
    );
  }
}

void showBenitoImportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(BStr.importFrom, style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: Text(BStr.importTikTok),
            subtitle: Text(BStr.importTikTokDesc),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TikTokImportPage()));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
