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

  static String get importWhatsApp => _t('Sticker ricevuti su WhatsApp', 'Stickers received on WhatsApp');
  static String get importWhatsAppDesc => _t(
      'Mettili nei tuoi pacchetti, così li usi anche su Instagram e TikTok',
      'Put them in your packs, so you can use them on Instagram and TikTok too');
  static String get waFolderHelp => _t(
      'Si apre la cartella "WhatsApp Stickers": tocca "Usa questa cartella" e poi "Consenti". '
          'Va fatto solo la prima volta.',
      'The "WhatsApp Stickers" folder opens: tap "Use this folder", then "Allow". Only needed the first time.');
  static String get waFolderNotFound => _t(
      'Se la cartella non si apre da sola: Android → media → com.whatsapp → WhatsApp → Media → WhatsApp Stickers.',
      'If the folder does not open automatically: Android → media → com.whatsapp → WhatsApp → Media → WhatsApp Stickers.');
  static String get changeFolder => _t('Cambia cartella', 'Change folder');
  static String get packTitleWhatsApp => _t('Ricevuti WhatsApp', 'WhatsApp received');
  static String get packTitleWhatsAppAnimated => _t('Ricevuti WhatsApp animati', 'WhatsApp received animated');
  static String get cont => _t('Continua', 'Continue');
  static String get cancel => _t('Annulla', 'Cancel');

  // Tastiera
  static String get keyboard => _t('Tastiera sticker', 'Sticker keyboard');
  static String get keyboardOff => _t(
      'Non attiva: tocca per attivarla (Impostazioni → BenitoSticker)',
      'Not enabled: tap to enable it (Settings → BenitoSticker)');
  static String get keyboardOn => _t(
      'Attiva. In una chat tieni premuto il tasto tastiera/globo di Gboard per sceglierla',
      'Enabled. In a chat, long-press the keyboard/globe key in Gboard to pick it');

  // Rimuovi sfondo
  static String get removeBg => _t('Rimuovi sfondo', 'Remove background');
  static String get removeBgFailed => _t(
      'Sfondo non rimosso. Se è il primo utilizzo, il modello si sta scaricando: riprova tra poco.',
      'Background not removed. If this is the first use, the model is downloading: try again shortly.');

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

  // Aggiungi a WhatsApp
  static String get waPreparing => _t('Preparo il pacchetto per WhatsApp…', 'Preparing the pack for WhatsApp…');
  static String get waAdded => _t('Pacchetto aggiunto a WhatsApp', 'Pack added to WhatsApp');
  static String get waAlready => _t('Il pacchetto è già in WhatsApp', 'The pack is already in WhatsApp');
  static String get waFailed => _t('WhatsApp non ha accettato il pacchetto', 'WhatsApp did not accept the pack');
  static String get waNotInstalled => _t('WhatsApp non è installato', 'WhatsApp is not installed');
  static String get waTooFew => _t('Servono almeno 3 sticker', 'At least 3 stickers are needed');
  static String waRepaired(int n) => _t('$n sticker sistemati per WhatsApp', '$n stickers fixed for WhatsApp');
  static String get copyDiagnosis => _t('Copia diagnosi', 'Copy diagnosis');
  static String get diagnosisCopied => _t(
      'Diagnosi copiata: incollala nella chat con Claude', 'Diagnosis copied: paste it in the chat with Claude');
  static String get close => _t('Chiudi', 'Close');

  // Copia / sposta
  static String selectedN(int n) => _t('$n selezionati', '$n selected');
  static String get copy => _t('Copia', 'Copy');
  static String get cut => _t('Taglia', 'Cut');
  static String get copyTo => _t('Copia in…', 'Copy to…');
  static String get moveTo => _t('Sposta in…', 'Move to…');
  static String get deleteSelected => _t('Elimina selezionati', 'Delete selected');
  static String deleteNConfirm(int n) => _t('Eliminare $n sticker?', 'Delete $n stickers?');
  static String pasteN(int n) => _t('Incolla ($n)', 'Paste ($n)');
  static String copiedN(int n) => _t('$n sticker copiati: apri un pacchetto e tocca Incolla',
      '$n stickers copied: open a pack and tap Paste');
  static String cutN(int n) => _t('$n sticker tagliati: apri un pacchetto e tocca Incolla',
      '$n stickers cut: open a pack and tap Paste');
  static String get clearClipboard => _t('Svuota appunti', 'Clear clipboard');
  static String pastedSummary(int n, List<String> packs) =>
      _t('$n sticker in: ${packs.join(', ')}', '$n stickers in: ${packs.join(', ')}');
  static String get chooseTargetPack => _t('Scegli il pacchetto', 'Choose the pack');
  static String get newPack => _t('Nuovo pacchetto', 'New pack');
  static String get packName => _t('Nome del pacchetto', 'Pack name');
  static String get create => _t('Crea', 'Create');
  static String get packMenu => _t('Altro', 'More');
  static String get copyAllStickers => _t('Copia tutti gli sticker', 'Copy all stickers');
  static String get copyPackInto => _t('Copia tutto in un altro pacchetto…', 'Copy all into another pack…');
  static String get movePackInto => _t('Sposta tutto in un altro pacchetto…', 'Move all into another pack…');
  static String get duplicatePack => _t('Duplica pacchetto', 'Duplicate pack');
  static String get copySuffix => _t('copia', 'copy');
  static String get animatedSuffix => _t('animati', 'animated');
  static String get staticSuffix => _t('fissi', 'static');
  static String get cantPasteSame => _t('Sono già in questo pacchetto', 'They are already in this pack');
  static String get full => _t('pieno', 'full');
}
