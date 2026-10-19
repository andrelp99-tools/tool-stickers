# BenitoSticker (tool-stickers)

App Android personale per sticker WhatsApp, installata sul telefono di Andrea (Nothing Phone) tramite **Obtainium**.
- Base: fork di Stickers (lolocomotive/stickers, Flutter, **GPL-3.0**). applicationId `it.andrelp99.benitosticker`.
- Funzioni aggiunte: import da TikTok (chat web), sticker ricevuti WhatsApp, tastiera sticker, rimuovi sfondo (ML Kit), invio a WhatsApp riscritto, copia/taglia/incolla tra pacchetti, ponte da BenitoTools. Dettagli: **BENITO.md**.
- Codice aggiunto in `lib/benito/`, `android/.../kotlin/it/andrelp99/benito/`, `android/.../cpp/benito_webp.cpp`; nei file originali solo righe marcate "BenitoSticker".
- Build e release firmate da GitHub Actions (`.github/workflows/build.yml`). Obtainium filtra `arm64-v8a\.apk$` e controlla l'hash della firma: **la chiave di firma non va mai cambiata** (copia su Google Drive, cartella privata "BenitoSticker - chiave firma"; 4 segreti nella repo). Senza la stessa chiave gli aggiornamenti non si installano.
- Per rilasciare: alzare `version` in `pubspec.yaml`, push, la release esce da sola.
- Scartato: import pacchetti da link Telegram/LINE/Signal (non li usa).
- Stato 19/10/2026: v2.0.6 installata, test sul telefono in corso.

## Regole di lavoro di Andrea
- Rispondi in italiano, stile **caveman max** (risposte corte, solo sostanza). Plugin `caveman@benito` se installato.
- Prima di agire fai domande per capire contesto, richieste, scopi. Proponi idee sensate quando servono.
- Lavora sempre inline: **mai sub-agenti** (vale anche per le skill di superpowers che li usano).
- Modifiche grafiche, anteprime di come verrebbe una funzione o lunghe serie di domande con esempi: mostrale in una pagina HTML/mockup invece che a testo.
- Ogni libreria o repo esterna nuova: prima controlla codice, licenza, sicurezza, permessi; poi proponi.
- Commit firmati `Claude <noreply@anthropic.com>`, **mai con l'email personale**: il profilo GitHub personale (andrelp99) è collegato a LinkedIn e il lavoro dell'org non deve comparire lì.
- PC Windows di casa, spesso spento, niente Docker/WSL. Andrea non ama la riga di comando: comandi pronti da incollare, spiegati in breve.
- A fine lavoro aggiorna **BENITO.md** (note tecniche) e la sezione "In sospeso".
- Contesto completo (scelte, storico, altre app): progetto "Implementazioni app da Github" nell'app Claude.
