// BenitoSticker: converte un'immagine qualsiasi (PNG, JPG, GIF, WebP, anche
// animati) in uno sticker WhatsApp valido: 512x512, WebP, max 100 kB statico /
// 500 kB animato, animazione max 10 s.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

const _channel = MethodChannel('it.andrelp99.benito/main');

const int stickerSize = 512;
const int maxStaticBytes = 100 * 1024;
const int maxAnimatedBytes = 500 * 1024;
const int maxAnimationMs = 10000;

class ProcessedSticker {
  final Uint8List data;
  final bool animated;
  final List<String>? emojis;

  ProcessedSticker(this.data, this.animated, {this.emojis});
}

class StickerConversionException implements Exception {
  final String message;

  StickerConversionException(this.message);

  @override
  String toString() => message;
}

/// Converte [input] in sticker. [tempDir] serve per i fotogrammi temporanei.
Future<ProcessedSticker> convertToSticker(Uint8List input, String tempDir) async {
  final probe = await compute(_probe, input);
  if (probe == null) throw StickerConversionException('Formato immagine non riconosciuto');
  final (info, width, height) = probe;
  // Già uno sticker WhatsApp valido (es. ricevuto su WhatsApp): lo tengo com'è.
  if (_isWebp(input) && width == stickerSize && height == stickerSize) {
    if (info > 1 && input.lengthInBytes <= maxAnimatedBytes) return ProcessedSticker(input, true);
    if (info == 1 && input.lengthInBytes <= maxStaticBytes) return ProcessedSticker(input, false);
  }
  if (info > 1) {
    try {
      final animated = await _encodeAnimated(input, tempDir);
      if (animated != null) return ProcessedSticker(animated, true);
    } catch (e) {
      // Animazione impossibile da far stare nei limiti: ripiego sul primo fotogramma.
      debugPrint('BenitoSticker: animato non riuscito, uso statico ($e)');
    }
  }
  return ProcessedSticker(await _encodeStatic(input), false);
}

/// Rende [input] valido per un pacchetto WhatsApp statico o animato.
/// Restituisce i byte (gli stessi se erano già validi) e se è stato ricodificato.
Future<(Uint8List, bool)> fitForPack(Uint8List input, bool animatedPack, String tempDir) async {
  final probe = await compute(_probe, input);
  if (probe == null) throw StickerConversionException('Formato immagine non riconosciuto');
  final (frames, width, height) = probe;
  final squareWebp = _isWebp(input) && width == stickerSize && height == stickerSize;
  if (!animatedPack) {
    if (squareWebp && frames == 1 && input.lengthInBytes <= maxStaticBytes) return (input, false);
    return (await _encodeStatic(input), true);
  }
  if (squareWebp && frames > 1 && input.lengthInBytes <= maxAnimatedBytes) return (input, false);
  if (frames > 1) {
    try {
      final animated = await _encodeAnimated(input, tempDir);
      if (animated != null) return (animated, true);
    } catch (e) {
      debugPrint('BenitoSticker: animato non riuscito ($e)');
    }
  }
  // Statico in un pacchetto animato: due fotogrammi uguali (WhatsApp vuole solo animati qui)
  return (await _staticAsAnimated(input, tempDir), true);
}

Future<Uint8List> _staticAsAnimated(Uint8List input, String tempDir) async {
  final rgba = await compute(_prepareStatic, input);
  final framesPath = '$tempDir/benito_still_${DateTime.now().microsecondsSinceEpoch}.raw';
  final f = File(framesPath);
  try {
    await f.writeAsBytes([...rgba, ...rgba], flush: true);
    for (final quality in [60.0, 40.0, 25.0, 15.0]) {
      final out = await _channel.invokeMethod<Uint8List>('encodeAnimated', {
        'framesPath': framesPath,
        'durations': [1000, 1000],
        'width': stickerSize,
        'height': stickerSize,
        'quality': quality,
      });
      if (out != null && out.lengthInBytes <= maxAnimatedBytes) return out;
    }
  } finally {
    if (f.existsSync()) f.deleteSync();
  }
  throw StickerConversionException('Sticker troppo grande anche a qualità minima');
}

/// Icona del pacchetto per WhatsApp: PNG 96x96, max 50 kB.
Future<Uint8List> makeTrayIcon(Uint8List sticker) => compute(_makeTray, sticker);

Uint8List _makeTray(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StickerConversionException('Icona non creata');
  final first = decoded.numFrames > 1 ? decoded.frames.first : decoded;
  for (final size in [96, 80, 64]) {
    final small = img.copyResize(first.numChannels == 4 ? first : first.convert(numChannels: 4),
        width: size, height: size, interpolation: img.Interpolation.average);
    final png = img.encodePng(small, level: 9);
    if (png.lengthInBytes <= 50 * 1024) return png;
  }
  throw StickerConversionException('Icona troppo grande');
}

bool _isWebp(Uint8List b) =>
    b.length > 12 &&
    b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && // RIFF
    b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50; // WEBP

/// (fotogrammi, larghezza, altezza), o null se l'immagine non si decodifica.
(int, int, int)? _probe(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return (decoded.numFrames, decoded.width, decoded.height);
}

Future<Uint8List> _encodeStatic(Uint8List input) async {
  final rgba = await compute(_prepareStatic, input);
  for (final quality in [80.0, 65.0, 50.0, 35.0, 20.0]) {
    final out = await _channel.invokeMethod<Uint8List>('encodeStatic', {
      'rgba': rgba,
      'width': stickerSize,
      'height': stickerSize,
      'quality': quality,
      'lossless': false,
    });
    if (out != null && out.lengthInBytes <= maxStaticBytes) return out;
  }
  throw StickerConversionException('Sticker troppo grande anche a qualità minima');
}

Future<Uint8List?> _encodeAnimated(Uint8List input, String tempDir) async {
  const attempts = [(60.0, 80), (45.0, 60), (35.0, 40), (25.0, 30), (15.0, 20)];
  final framesPath = '$tempDir/benito_frames_${DateTime.now().microsecondsSinceEpoch}.raw';
  try {
    for (final (quality, maxFrames) in attempts) {
      final durations = await compute(_prepareAnimated, (input, maxFrames, framesPath));
      if (durations == null || durations.length < 2) return null;
      final out = await _channel.invokeMethod<Uint8List>('encodeAnimated', {
        'framesPath': framesPath,
        'durations': durations,
        'width': stickerSize,
        'height': stickerSize,
        'quality': quality,
      });
      if (out != null && out.lengthInBytes <= maxAnimatedBytes) return out;
    }
    throw StickerConversionException('Sticker animato troppo grande anche a qualità minima');
  } finally {
    final f = File(framesPath);
    if (f.existsSync()) f.deleteSync();
  }
}

/// Mette [frame] al centro di una tela 512x512 trasparente, mantenendo le proporzioni.
img.Image _fit(img.Image frame) {
  final source = frame.numChannels == 4 ? frame : frame.convert(numChannels: 4);
  final scale = stickerSize / (source.width > source.height ? source.width : source.height);
  final w = (source.width * scale).round().clamp(1, stickerSize);
  final h = (source.height * scale).round().clamp(1, stickerSize);
  final resized = img.copyResize(source, width: w, height: h, interpolation: img.Interpolation.average);
  final canvas = img.Image(width: stickerSize, height: stickerSize, numChannels: 4);
  img.compositeImage(canvas, resized, dstX: (stickerSize - w) ~/ 2, dstY: (stickerSize - h) ~/ 2);
  return canvas;
}

Uint8List _prepareStatic(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StickerConversionException('Immagine non leggibile');
  final first = decoded.numFrames > 1 ? decoded.frames.first : decoded;
  return _fit(first).getBytes(order: img.ChannelOrder.rgba);
}

/// Scrive i fotogrammi RGBA 512x512 in [path] e restituisce le durate (ms).
/// Tiene al massimo [maxFrames] fotogrammi (unendo le durate di quelli saltati)
/// e al massimo [maxAnimationMs] di animazione.
List<int>? _prepareAnimated((Uint8List, int, String) args) {
  final (bytes, maxFrames, path) = args;
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.numFrames < 2) return null;

  final frames = <img.Image>[];
  final durations = <int>[];
  var total = 0;
  for (final f in decoded.frames) {
    var d = f.frameDuration <= 0 ? 100 : f.frameDuration;
    if (total + d > maxAnimationMs) d = maxAnimationMs - total;
    if (d <= 0) break;
    frames.add(f);
    durations.add(d);
    total += d;
  }

  // Riduce i fotogrammi tenendone uno ogni "step" e sommando le durate.
  final step = (frames.length / maxFrames).ceil().clamp(1, frames.length);
  final keptDurations = <int>[];
  final sink = File(path).openSync(mode: FileMode.write);
  try {
    for (var i = 0; i < frames.length; i += step) {
      var d = 0;
      for (var j = i; j < i + step && j < frames.length; j++) {
        d += durations[j];
      }
      sink.writeFromSync(_fit(frames[i]).getBytes(order: img.ChannelOrder.rgba));
      keptDurations.add(d < 8 ? 8 : d);
    }
  } finally {
    sink.closeSync();
  }
  return keptDurations;
}
