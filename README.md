# ShashGui Mobile: Beyond the Eval ♟️

Benvenuto nel repository ufficiale di **ShashGui Mobile**, l'applicazione scacchistica che non si limita a mostrarti una fredda valutazione numerica, ma ti spiega *come* e *perché* giocare attraverso la **Teoria di Alexander Shashin**.

A differenza delle tradizionali GUI scacchistiche, ShashGui traduce il calcolo spietato delle Reti Neurali in concetti umani (Spazio, Sicurezza, Densit, Materiale), categorizzando la partita negli stili di tre leggendari campioni: Tal, Capablanca e Petrosian.

## 🚀 Funzionalità Locali (Gratuite)
Il frontend mobile è progettato per essere un "coach tascabile" intelligente ed efficiente, eseguendo il codice nativamente sul dispositivo:
* **Termometro Shashin in Tempo Reale:** Lettura del modello WDL (Win/Draw/Loss) e mappatura istantanea dello stato termodinamico della posizione.
* **Motori Integrati (C++ via Dart FFI):** Supporto nativo per **Alexander (HCE)** per simulare le debolezze umane e **ShashChess (NNUE)** per la verità matematica assoluta.
* **Analisi Incrociata Singola:** Confronta l'intuizione dell'allievo con il calcolo del motore.

## ☁️ Ecosistema Cloud (Premium)
ShashGui Mobile funge da ponte verso la nostra infrastruttura Cloud ad alte prestazioni, che sblocca funzionalit di Data Science e Explainable AI (XAI):
* **ChessBeauty (Qualimetria):** Misura l'audacia, l'armonia e la profondità strategica delle tue partite.
* **Estrazione Nuggets:** Trova automaticamente le "pepite d'oro" tattiche nei tuoi archivi PGN.
* **Dossier Divergenze (XAI):** Scopri dove il dogma umano fallisce contro la comprensione neurale.

## 🛠️ Stack Tecnologico
* **Frontend:** Flutter / Dart
* **Motori Locali:** C++ (compilati per ARM64, invocati tramite Dart FFI / Platform Channels)
* **Backend / Cloud (Esterno al repo):** Python, SQLite, AWS/GCP

## 📝 Licenza
Questo progetto include e si interfaccia con i motori scacchistici ShashChess e Alexander, derivati dal progetto open-source Stockfish. Pertanto, l'applicazione mobile è rilasciata sotto licenza **GNU GPLv3**. Vedi il file `LICENSE` per i dettagli completi.