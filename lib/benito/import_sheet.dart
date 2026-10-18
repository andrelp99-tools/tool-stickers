// BenitoSticker: menu "Importa" con le fonti aggiunte dal fork.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stickers/benito/strings.dart';
import 'package:stickers/benito/tiktok/tiktok_page.dart';
import 'package:stickers/benito/whatsapp_received.dart';

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
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: Text(BStr.importWhatsApp),
            subtitle: Text(BStr.importWhatsAppDesc),
            trailing: IconButton(
              tooltip: BStr.changeFolder,
              icon: const Icon(Icons.folder_open_outlined),
              onPressed: () {
                Navigator.pop(sheetContext);
                openWhatsAppReceivedImport(context, forcePick: true);
              },
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              openWhatsAppReceivedImport(context);
            },
          ),
          const Divider(),
          const _KeyboardTile(),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

const _channel = MethodChannel('it.andrelp99.benito/main');

class _KeyboardTile extends StatefulWidget {
  const _KeyboardTile();

  @override
  State<_KeyboardTile> createState() => _KeyboardTileState();
}

class _KeyboardTileState extends State<_KeyboardTile> with WidgetsBindingObserver {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    try {
      final v = await _channel.invokeMethod<bool>('keyboardEnabled');
      if (mounted) setState(() => _enabled = v);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final on = _enabled == true;
    return ListTile(
      leading: Icon(on ? Icons.keyboard : Icons.keyboard_outlined),
      title: Text(BStr.keyboard),
      subtitle: Text(on ? BStr.keyboardOn : BStr.keyboardOff),
      onTap: () => _channel.invokeMethod(on ? 'showKeyboardPicker' : 'openKeyboardSettings'),
    );
  }
}
