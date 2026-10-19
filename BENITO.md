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
- Codice aggiunto in `lib/benito/`, `android/.../kotlin/it/andrelp99/benito/`, `android/.../cpp/benito_webp.cpp`; nei file originali solo poche righe marcate "BenitoSticker".

## In sospeso
- Icona app (la fornisce Andrea).
