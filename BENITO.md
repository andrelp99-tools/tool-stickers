# BenitoSticker

Fork personale di [Stickers](https://github.com/lolocomotive/stickers) (lolocomotive, GPL-3.0).

## Modifiche rispetto all'originale
- Nome app **BenitoSticker**, applicationId `it.andrelp99.benitosticker` (namespace Kotlin invariato per facilitare il sync).
- Traduzione italiana (`lib/l10n/app_it.arb`), italiano predefinito.
- Firma opzionale in `android/app/build.gradle` (senza `key.properties` → firma debug).
- Build e release automatiche con GitHub Actions (`.github/workflows/build.yml`), aggiornamenti via Obtainium.

- Menu **Importa** (icona in alto nella home):
  - **Da TikTok**: TikTok web (versione desktop) dentro l'app, raccolta automatica degli sticker delle chat, scelta, conversione e pacchetti "TikTok" / "TikTok animati".
  - **Sticker ricevuti su WhatsApp**: cartella "WhatsApp Stickers" via selettore di sistema → pacchetti "Ricevuti WhatsApp".
  - **Tastiera sticker**: attivazione della tastiera Android con i pacchetti dell'app (+ recenti).
- **Rimuovi sfondo** (ML Kit, sul telefono) nella schermata di ritaglio.
- **Aggiungi a WhatsApp riscritto** (`lib/benito/whatsapp_send.dart`, `kotlin/.../benito/whatsapp/`): la libreria originale
  (whatsapp_stickers_plus) non funzionava più con WhatsApp recente ("handleStickerPackPreviewResult/failed" anche con
  sticker validi). Ora provider proprio `${applicationId}.benito.stickers` col formato del progetto ufficiale
  WhatsApp/stickers (nov 2025, colonna `sticker_accessibility_text` inclusa) e intent diretto a WhatsApp.
  Prima dell'invio ogni sticker viene controllato e, se serve, ricodificato (512x512, ≤100/500 kB, tipo del pacchetto);
  file pronti in `packs/<id>/wa/`, elenco in `packs/whatsapp.json`. Se WhatsApp rifiuta: pulsante "Copia diagnosi".
- **Copia / taglia / incolla sticker** (tieni premuto per selezionare): Copia, Taglia, Copia in…, Sposta in…, Elimina;
  pulsante Incolla nei pacchetti. Menu ⋮ del pacchetto: copia tutti, copia/sposta tutto in un altro, duplica.
  Pacchetto pieno → il resto va in "Nome 2"; animati e fissi non si mescolano ("Nome animati" / "Nome fissi").
- **Icona**: foto scelta da Andrea (icona adattiva in `mipmap-anydpi-v26`, sfondo nero).
- Codice aggiunto in `lib/benito/`, `android/.../kotlin/it/andrelp99/benito/`, `android/.../cpp/benito_webp.cpp`; nei file originali solo poche righe marcate "BenitoSticker".

## In sospeso
- (nulla)
