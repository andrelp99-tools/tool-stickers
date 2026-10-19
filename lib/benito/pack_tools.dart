// BenitoSticker: pulsanti e finestre per copia / sposta / incolla / duplica.
import 'package:flutter/material.dart';
import 'package:stickers/benito/pack_importer.dart';
import 'package:stickers/benito/sticker_clipboard.dart';
import 'package:stickers/benito/strings.dart';
import 'package:stickers/src/data/sticker_pack.dart';
import 'package:stickers/src/globals.dart';

void showPasteSummary(BuildContext context, ImportSummary s) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(BStr.pastedSummary(s.added, s.packTitles))));
}

void _error(BuildContext context, Object e) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(e is StateError ? e.message : '$e')));
}

/// Elenco pacchetti + "Nuovo pacchetto". [exclude] non compare nell'elenco.
Future<StickerPack?> pickTargetPack(BuildContext context,
    {StickerPack? exclude, required bool animatedForNew, String? suggestedName}) async {
  final choice = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * .7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(BStr.chooseTargetPack, style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(BStr.newPack),
              onTap: () => Navigator.of(sheetContext).pop('new'),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in packs)
                    if (p != exclude)
                      ListTile(
                        leading: Icon(p.animated ? Icons.gif_box_outlined : Icons.image_outlined),
                        title: Text(p.title),
                        subtitle: Text('${p.stickers.length}/30${p.stickers.length >= 30 ? ' · ${BStr.full}' : ''}'),
                        onTap: () => Navigator.of(sheetContext).pop(p),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice is StickerPack) return choice;
  if (choice == 'new' && context.mounted) {
    final name = await _askName(context, suggestedName ?? BStr.newPack);
    if (name == null || name.trim().isEmpty) return null;
    return createEmptyPack(name.trim(), animatedForNew);
  }
  return null;
}

Future<String?> _askName(BuildContext context, String initial) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(BStr.newPack),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: BStr.packName),
        onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(BStr.cancel)),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text), child: Text(BStr.create)),
      ],
    ),
  );
}

/// Pulsante "Incolla (N)": compare solo se negli appunti ci sono sticker.
class PasteButton extends StatelessWidget {
  final StickerPack target;
  final VoidCallback onDone;

  const PasteButton(this.target, this.onDone, {super.key});

  @override
  Widget build(BuildContext context) {
    final clip = StickerClipboard.instance;
    return ListenableBuilder(
      listenable: clip,
      builder: (context, _) {
        if (clip.isEmpty) return const SizedBox.shrink();
        return IconButton(
          tooltip: BStr.pasteN(clip.length),
          icon: Badge(
            label: Text('${clip.length}'),
            child: Icon(clip.isCut ? Icons.content_cut : Icons.content_paste),
          ),
          onPressed: () async {
            try {
              final s = await clip.pasteInto(target);
              onDone();
              if (context.mounted) showPasteSummary(context, s);
            } catch (e) {
              if (context.mounted) _error(context, e);
            }
          },
        );
      },
    );
  }
}

/// Menu "⋮" del pacchetto: copia tutti, copia/sposta tutto in…, duplica, svuota appunti.
class PackMenuButton extends StatelessWidget {
  final StickerPack pack;
  final VoidCallback onChanged;

  /// Chiamato se il pacchetto è stato spostato tutto in un altro (quindi non esiste più)
  final VoidCallback? onPackGone;

  const PackMenuButton(this.pack, this.onChanged, {this.onPackGone, super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: BStr.packMenu,
      onSelected: (v) async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        try {
          switch (v) {
            case 'copyAll':
              await StickerClipboard.instance.put(pack, pack.stickers, cut: false);
              messenger?.showSnackBar(SnackBar(content: Text(BStr.copiedN(pack.stickers.length))));
            case 'copyInto':
            case 'moveInto':
              final target = await pickTargetPack(context,
                  exclude: pack, animatedForNew: pack.animated, suggestedName: pack.title);
              if (target == null) return;
              final s = await mergePack(pack, target, move: v == 'moveInto');
              messenger?.showSnackBar(SnackBar(content: Text(BStr.pastedSummary(s.added, s.packTitles))));
              if (v == 'moveInto') onPackGone?.call();
            case 'duplicate':
              final copy = await duplicatePack(pack);
              messenger?.showSnackBar(SnackBar(content: Text(copy.title)));
            case 'clearClip':
              await StickerClipboard.instance.clear();
          }
          onChanged();
        } catch (e) {
          if (context.mounted) _error(context, e);
        }
      },
      itemBuilder: (_) => [
        if (pack.stickers.isNotEmpty) PopupMenuItem(value: 'copyAll', child: Text(BStr.copyAllStickers)),
        if (pack.stickers.isNotEmpty) PopupMenuItem(value: 'copyInto', child: Text(BStr.copyPackInto)),
        if (pack.stickers.isNotEmpty) PopupMenuItem(value: 'moveInto', child: Text(BStr.movePackInto)),
        PopupMenuItem(value: 'duplicate', child: Text(BStr.duplicatePack)),
        if (!StickerClipboard.instance.isEmpty) PopupMenuItem(value: 'clearClip', child: Text(BStr.clearClipboard)),
      ],
    );
  }
}
