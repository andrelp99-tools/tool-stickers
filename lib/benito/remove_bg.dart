// BenitoSticker: pulsante "Rimuovi sfondo" (ML Kit sul telefono, offline dopo
// il primo download del modello da Google Play services).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stickers/benito/strings.dart';

const _channel = MethodChannel('it.andrelp99.benito/main');

class RemoveBackgroundButton extends StatefulWidget {
  final String imagePath;
  final ValueChanged<String> onDone;

  const RemoveBackgroundButton({super.key, required this.imagePath, required this.onDone});

  @override
  State<RemoveBackgroundButton> createState() => _RemoveBackgroundButtonState();
}

class _RemoveBackgroundButtonState extends State<RemoveBackgroundButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final out = await _channel.invokeMethod<String>('removeBackground', {'path': widget.imagePath});
      if (out != null) widget.onDone(out);
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${BStr.removeBgFailed}\n${e.message ?? ''}'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return IconButton(
      tooltip: BStr.removeBg,
      icon: const Icon(Icons.auto_fix_high),
      onPressed: _run,
    );
  }
}
