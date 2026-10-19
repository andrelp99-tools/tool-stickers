import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stickers/benito/pack_tools.dart'; // BenitoSticker
import 'package:stickers/benito/sticker_clipboard.dart'; // BenitoSticker
import 'package:stickers/benito/strings.dart'; // BenitoSticker
import 'package:stickers/benito/whatsapp_send.dart'; // BenitoSticker
import 'package:stickers/generated/intl/app_localizations.dart';
import 'package:stickers/src/checker_painter.dart';
import 'package:stickers/src/constants.dart';
import 'package:stickers/src/data/load_store.dart';
import 'package:stickers/src/data/sticker_pack.dart';
import 'package:stickers/src/dialogs/delete_confirm_dialog.dart';
import 'package:stickers/src/dialogs/edit_pack_dialog.dart';
import 'package:stickers/src/dialogs/edit_sticker_dialog.dart';
import 'package:stickers/src/dialogs/error_dialog.dart';
import 'package:stickers/src/globals.dart';
import 'package:stickers/src/pages/crop_page.dart';
import 'package:stickers/src/pages/default_page.dart';
import 'package:stickers/src/util.dart';
import 'package:stickers/src/data/sticker.dart'; // BenitoSticker

class StickerPackPage extends StatefulWidget {
  final StickerPack pack;
  final Function deleteCallback;

  const StickerPackPage(this.pack, this.deleteCallback, {super.key});

  static const routeName = "/pack";

  @override
  State<StickerPackPage> createState() => StickerPackPageState();
}

class StickerPackPageState extends State<StickerPackPage> {
  // BenitoSticker: selezione multipla (tieni premuto uno sticker)
  final Set<int> _sel = {};

  bool get _selecting => _sel.isNotEmpty;

  List<Sticker> get _selected => [for (final i in _sel.toList()..sort()) widget.pack.stickers[i]];

  void _toggle(int i) => setState(() => _sel.contains(i) ? _sel.remove(i) : _sel.add(i));

  Future<void> _clip(bool cut) async {
    final n = _sel.length;
    await StickerClipboard.instance.put(widget.pack, _selected, cut: cut);
    setState(_sel.clear);
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(cut ? BStr.cutN(n) : BStr.copiedN(n))));
    }
  }

  Future<void> _sendTo(bool move) async {
    final chosen = _selected;
    final target = await pickTargetPack(context,
        exclude: move ? widget.pack : null, animatedForNew: widget.pack.animated, suggestedName: widget.pack.title);
    if (target == null) return;
    final s = await addToPack(target, [
      for (final st in chosen) (await File(st.source).readAsBytes(), widget.pack.animated, List.of(st.emojis)),
    ]);
    if (move) removeStickers(widget.pack, chosen.map((e) => e.source).toSet());
    savePacks(packs);
    homeState?.update();
    setState(_sel.clear);
    if (mounted) showPasteSummary(context, s);
  }

  Future<void> _deleteSelected() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(BStr.deleteNConfirm(_sel.length)),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(BStr.cancel)),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: Text(AppLocalizations.of(context)!.delete)),
        ],
      ),
    );
    if (ok != true) return;
    removeStickers(widget.pack, _selected.map((e) => e.source).toSet());
    homeState?.update();
    setState(_sel.clear);
  }

  List<Widget> _selectionActions() => [
        IconButton(
          tooltip: _sel.length == widget.pack.stickers.length ? BStr.selectNone : BStr.selectAll,
          icon: const Icon(Icons.select_all),
          onPressed: () => setState(() {
            if (_sel.length == widget.pack.stickers.length) {
              _sel.clear();
            } else {
              _sel.addAll(List.generate(widget.pack.stickers.length, (i) => i));
            }
          }),
        ),
        IconButton(tooltip: BStr.copy, icon: const Icon(Icons.copy), onPressed: () => _clip(false)),
        IconButton(tooltip: BStr.cut, icon: const Icon(Icons.content_cut), onPressed: () => _clip(true)),
        PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'copyTo':
                _sendTo(false);
              case 'moveTo':
                _sendTo(true);
              case 'delete':
                _deleteSelected();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'copyTo', child: Text(BStr.copyTo)),
            PopupMenuItem(value: 'moveTo', child: Text(BStr.moveTo)),
            PopupMenuItem(value: 'delete', child: Text(BStr.deleteSelected)),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: DefaultSliverActivity(
              leading: _selecting
                  ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_sel.clear))
                  : null,
              actions: _selecting ? _selectionActions() : [
                PasteButton(widget.pack, () => setState(() {})), // BenitoSticker
                IconButton(
                  tooltip: AppLocalizations.of(context)!.edit,
                  onPressed: () {
                    showDialog(context: context, builder: (context) => EditPackDialog(widget.pack))
                        .then((value) => setState(() {}));
                  },
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.delete,
                  onPressed: () {
                    showDialog<bool>(
                        context: context,
                        builder: (context) => DeleteConfirmDialog(widget.pack.title)).then(
                      (value) async {
                        if (value == true) {
                          packs.remove(widget.pack);
                          widget.deleteCallback();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                          Directory("$packsDir/${widget.pack.id}").delete(recursive: true);
                          savePacks(packs);
                        }
                      },
                    );
                  },
                  icon: const Icon(Icons.delete),
                ),
                PackMenuButton(widget.pack, () => setState(() {}), onPackGone: () {
                  widget.deleteCallback();
                  Navigator.of(context).pop();
                }), // BenitoSticker
              ],
              title: _selecting ? BStr.selectedN(_sel.length) : widget.pack.title,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                    itemCount: widget.pack.stickers.length + 1,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: colCount(MediaQuery.of(context).size.width),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      if (index == widget.pack.stickers.length) {
                        bool disabled = widget.pack.stickers.length >= 30;
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: disabled ? Colors.grey : Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: disabled ? null : () => _createSticker(index),
                            child: Icon(
                              Icons.add,
                              size: 40,
                              color: disabled ? Colors.grey : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        );
                      }
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Color.lerp(Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.surface, .7),
                          boxShadow: [
                            BoxShadow(
                              offset: Offset(1, 1),
                              blurRadius: 3,
                              color: Theme.of(context).brightness == Brightness.light
                                  ? Colors.black26
                                  : Colors.black12,
                            )
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: index >= widget.pack.stickers.length
                            ? null
                            : CustomPaint(
                                painter: CheckerPainter(context),
                                child: GestureDetector(
                                  onLongPress: () => _toggle(index), // BenitoSticker: selezione
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(File(widget.pack.stickers[index].source)),
                                      if (_sel.contains(index))
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withValues(alpha: .25),
                                            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 4),
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          alignment: Alignment.topRight,
                                          padding: const EdgeInsets.all(6),
                                          child: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                                        ),
                                    ],
                                  ),
                                  onTap: () {
                                    if (_selecting) {
                                      _toggle(index);
                                      return;
                                    }
                                    showDialog(
                                      context: context,
                                      builder: ((context) => EditStickerDialog(widget.pack, index)),
                                    ).then(
                                      (_) => setState(() {}),
                                    );
                                  },
                                ),
                              ),
                      );
                    }),
              ),
            ),
          ),
          Material(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.pack.stickers.length < 3)
                    Opacity(
                      opacity: .7,
                      child: Text(
                        AppLocalizations.of(context)!.youNeedAtLeast3Stickers,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (widget.pack.stickers.length >= 30)
                    Opacity(
                      opacity: .7,
                      child: Text(
                        AppLocalizations.of(context)!.youCanTHaveMoreThan30Stickers,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.share),
                        onPressed: () {
                          exportPack(widget.pack);
                        },
                        label: Text(AppLocalizations.of(context)!.export),
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: widget.pack.stickers.length < 3
                              ? null
                              : () => benitoAddToWhatsApp(widget.pack, context), // BenitoSticker
                          child: Text(AppLocalizations.of(context)!.addToWhatsapp),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _createSticker(int index) async {
    try {
      final ImagePicker picker = ImagePicker();
      if (widget.pack.animated) {
        final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
        if (video == null) return;
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          "/crop_video",
          arguments: EditArguments(
            pack: widget.pack,
            index: index,
            mediaPath: video.path,
          ),
        ).then((value) => setState(() {}));
      } else {
        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
        if (image == null) return; //TODO add Snackbar warning
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          "/crop",
          arguments: EditArguments(
            pack: widget.pack,
            index: index,
            mediaPath: image.path,
          ),
        ).then((value) => setState(() {}));
      }
    } on Exception catch (e) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (context) {
              return ErrorDialog(
                title: AppLocalizations.of(context)!.couldntLoadMedia,
                message: e.toString(),
              );
            });
      }
    }
  }
}
