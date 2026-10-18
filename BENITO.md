# BenitoSticker

Fork personale di [Stickers](https://github.com/lolocomotive/stickers) (lolocomotive, GPL-3.0).

## Modifiche rispetto all'originale
- Nome app **BenitoSticker**, applicationId `it.andrelp99.benitosticker` (namespace Kotlin invariato per facilitare il sync).
- Traduzione italiana (`lib/l10n/app_it.arb`), italiano predefinito.
- Firma opzionale in `android/app/build.gradle` (senza `key.properties` → firma debug).
- Build e release automatiche con GitHub Actions (`.github/workflows/build.yml`), aggiornamenti via Obtainium.

## In arrivo
- Import sticker da TikTok, tastiera sticker, rimozione sfondo, import sticker ricevuti su WhatsApp, import LINE/Signal.
