// BenitoSticker: testi delle funzioni aggiunte (italiano + inglese), separati
// dai file .arb originali per non creare conflitti negli aggiornamenti del fork.
import 'package:stickers/src/globals.dart';

class BStr {
  static bool get _it => settingsController.locale != 'en' &&
      settingsController.locale != 'de' &&
      settingsController.locale != 'fr' &&
      settingsController.locale != 'ru';

  static String _t(String it, String en) => _it ? it : en;

  // Menu importa
  static String get importFrom => _t('Importa', 'Import');
  static String get importFile => _t('Da file (.zip, .wastickers…)', 'From file (.zip, .wastickers…)');
  static String get importTikTok => _t('Da TikTok (sticker in chat)', 'From TikTok (chat stickers)');
  static String get importTikTokDesc =>
      _t('Accedi a TikTok, apri una chat e scorri: gli sticker vengono raccolti da soli',
          'Log in to TikTok, open a chat and scroll: stickers are collected automatically');

  // Pagina TikTok
  static String get tiktokTitle => _t('Sticker da TikTok', 'TikTok stickers');
  static String found(int n) => _t('$n trovati', '$n found');
  static String get next => _t('Avanti', 'Next');
  static String get tiktokHelp => _t(
      'Accedi con email e password, vai su Messaggi e apri una chat. Scorri la chat: '
          'ogni sticker visibile viene raccolto. Poi tocca Avanti.',
      'Log in with email and password, go to Messages and open a chat. Scroll the chat: '
          'every visible sticker is collected. Then tap Next.');
  static String get gotIt => _t('Ho capito', 'Got it');
  static String get allImages => _t('Prendi tutte le immagini della chat', 'Grab all chat images');
  static String get allImagesDesc => _t(
      'Se gli sticker non vengono trovati, raccoglie tutte le immagini visibili. Poi scegli tu quali tenere.',
      'If stickers are not detected, collects every visible image. You choose which ones to keep.');
  static String get reload => _t('Ricarica', 'Reload');
  static String get help => _t('Aiuto', 'Help');

  // Selezione
  static String get chooseStickers => _t('Scegli gli sticker', 'Choose stickers');
  static String get downloading => _t('Scarico gli sticker…', 'Downloading stickers…');
  static String get converting => _t('Converto per WhatsApp…', 'Converting for WhatsApp…');
  static String importN(int n) => _t('Importa ($n)', 'Import ($n)');
  static String get selectAll => _t('Seleziona tutti', 'Select all');
  static String get selectNone => _t('Deseleziona tutti', 'Select none');
  static String get alreadyImported => _t('già importato', 'already imported');
  static String get nothingDownloaded =>
      _t('Nessuno sticker scaricato. Riprova o usa "Prendi tutte le immagini".',
          'No stickers downloaded. Try again or use "Grab all images".');
  static String failedN(int n) => _t('$n non riusciti', '$n failed');
  static String get importDone => _t('Importazione completata', 'Import complete');
  static String importSummary(int n, List<String> packs) => _t(
      '$n sticker aggiunti a: ${packs.join(', ')}.\n\nApri il pacchetto e tocca "Aggiungi a WhatsApp".',
      '$n stickers added to: ${packs.join(', ')}.\n\nOpen the pack and tap "Add to WhatsApp".');
  static String get tooFewWarning => _t(
      'Nota: WhatsApp accetta pacchetti con almeno 3 sticker.',
      'Note: WhatsApp only accepts packs with at least 3 stickers.');
  static String get packTitleTikTok => 'TikTok';
  static String get packTitleTikTokAnimated => _t('TikTok animati', 'TikTok animated');
  static String get ok => 'OK';
}
