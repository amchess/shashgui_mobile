# ShashGui Mobile: Beyond the Eval ♟️

> *"A chess engine tells you the best move. A coach tells you why."*

Welcome to the official repository of **ShashGui Mobile** — a chess application that goes far beyond displaying a cold numerical evaluation. Instead of raw centipawns, ShashGui translates the ruthless calculation of Neural Networks into **human concepts** (Space, Safety, Density, Material), categorising every position through the lens of **Alexander Shashin's Theory**: three archetypal playing styles embodied by three legendary world champions.

| Style | Champion | Philosophy |
|---|---|---|
| ⚔️ Dynamic / Tactical | **Tal** | Chaos, sacrifice, initiative at all costs |
| 🏛️ Positional / Strategic | **Capablanca** | Harmony, space, long-term domination |
| 🛡️ Defensive / Resilient | **Petrosian** | Safety, prophylaxis, fortress building |

Unlike traditional chess GUIs, ShashGui reads the engine's WDL (Win/Draw/Loss) model and maps the **thermodynamic state** of the position in real time — answering the question every player actually cares about: *"Am I playing like Tal or like Petrosian right now, and should I be?"*

---

## 🚀 Local Features (Free)

### ♟️ Real-Time Shashin Thermometer

`ShashinLogic.analyzeShashinZone()` receives the three raw WDL integers, computes the Win Probability (`wp = (w + d/2) / total * 100`), and maps it to one of the following named zones:

| WP range | Zone name | Symbol | Style |
|---|---|---|---|
| 0–5 | High Petrosian | `-+` | Severely losing |
| 6–10 | High-Middle Petrosian | `-+ \ -/+` | Strongly losing |
| 11–15 | Middle Petrosian | `-/+` | Losing |
| 16–20 | Middle-Low Petrosian | `-/+ \ =/+` | Slightly losing |
| 21–24 | Low Petrosian | `=/+` | Marginally losing |
| 25 | Petrosian Nugget | `⚱️` | Tactical landmark |
| 26–49 | Chaos: Capablanca-Petrosian | `↓` | Contested, black pressure |
| 50 | Capablanca | `=` | Perfect balance |
| 51–75 | Chaos: Capablanca-Tal | `↑` | Contested, white pressure |
| 75 | Tal Nugget | `⚱️` | Tactical landmark |
| 76–79 | Low Tal | `+/=` | Marginally winning |
| 80–84 | Middle-Low Tal | `+/= \ +/-` | Slightly winning |
| 85–89 | Middle Tal | `+/-` | Winning |
| 90–94 | High-Middle Tal | `+/- \ +-` | Strongly winning |
| 95–100 | High Tal | `+-` | Winning decisively |
| ~333/333/333 | Chaos: Capa-Petrosian-Tal | `∞` | Total chaos |

Nugget positions (`wp == 25` or `wp == 75`) surface as special `⚱️` zones and are flagged as candidates for the **Cloud Nugget Extraction** feature.

---

### ⚙️ Dual Engine Support (C++ Native Libraries)

Two engines are compiled as native shared libraries and distributed pre-built for three CPU architectures:

| Engine | Type | ABI targets | Key UCI options |
|---|---|---|---|
| **Alexander** | HCE (Hand-Crafted Evaluation) | `arm64-v8a`, `armeabi-v7a`, `x86_64` | `UCI_LimitStrength`, `UCI_Elo`, `ShashinMode` |
| **ShashChess** | NNUE (Neural Network) | `arm64-v8a`, `armeabi-v7a`, `x86_64` | `EvalFile`, `EvalFileSmall`, `ShashinMode` |

Engines are invoked via a `MethodChannel` (`com.shashgui.engine/native`). `EngineManager.initEngine()`:
1. Calls `getNativeLibDir` on the Android side to locate the correct `.so`
2. Extracts NNUE weight files (`nn-c288c895ea92.nnue`, `nn-37f18f62d772.nnue`) to the app's documents directory on first launch (size-checked to avoid redundant writes, executed on a background isolate via `compute`)
3. Spawns the engine process and connects `stdout` to a broadcast `Stream<String>`
4. Drains `stderr` to prevent OS buffer deadlocks
5. Sends `uci` + `setoption EvalFile` + `isready` and waits for `readyok` (60 s timeout)

On `dispose()`, the engine process is killed via `Future.microtask` to avoid blocking the main thread.

---

### 🔁 Two-Phase FSM Analysis (`ShashinFsm`)

`ShashinFsm` drives the analysis loop through three states (`idle → phase1 → phase2`) for each iteration:

- **Phase 1** (`movetime = baseTimeMs × iteration`, capped at 30 s): thermodynamic read — WDL stream is parsed to classify the current `ShashinZone`.
- **Phase 2** (`movetime = baseTimeMs × iteration × 2`): strategic calculation — `setoption name ShashinMode value {Tal|Capablanca|Petrosian|Normal}` is sent before `go`, so the engine searches in the style appropriate for the detected zone.
- After `bestmove`, iteration counter increments and loops back to Phase 1 with proportionally longer time budgets.

`EngineStats` (depth, selDepth, nodes, nps, PV lines) are updated via a **200 ms debounce timer** to avoid UI jank from rapid `info` line floods. MultiPV lines are collected in a `Map<int, String>` keyed by `multipv` number and delivered as a sorted `List<String>` to the UI.

---

### 🎛️ UCI Engine Configuration (`UciOptionsModal`)

`UciOptionsModal` is a `ConsumerStatefulWidget` that:
1. Listens to the engine's `option name …` lines on startup
2. Renders a dynamic form (sliders, switches, text fields) for each reported option
3. Persists every value to `SharedPreferences` under `{engineName}_{optionName}`

On the next `startEngine()` call, `EngineController` reads all keys matching the `{engineName}_` prefix and sends `setoption name X value Y` before the `isready` barrier, guaranteeing the settings are applied even after a cold restart.

---

### 🔬 Cross-Analysis — Coach Mode (`CrossedEvalOrchestrator`)

A multi-phase evaluation pipeline that runs entirely on the device:

| State | Description |
|---|---|
| `staticEval` | Sends `eval` to Alexander, parses: Total Space (W/B), Center Type, deltaK (packing density), Delta Expansion (centre of gravity), Bishop pair flags, Makogonov worst-piece (HCE) |
| `baseEval` | `go movetime T` — reads WDL to establish the base `ShashinZone` |
| `studentThinking` | `UCI_LimitStrength=true` + `UCI_Elo={studentElo}` + `go movetime T` — simulates the player's level |
| `masterStaticEval` / `masterThinking` | If masterElo ≥ 3500: re-initialises to ShashChess, runs `eval` for NNUE worst-piece, then `go movetime T`; otherwise sends `UCI_Elo={masterElo}` on Alexander |

The **school ladder** (derived from `playerElo`):

| Player ELO | Student school | Master school |
|---|---|---|
| < 2000 | Beginner | Intermediate (ELO 2199) |
| 2000–2199 | Intermediate | Advanced (ELO 2399) |
| 2200–2499 | Advanced | Expert HCE (ELO 3190) |
| ≥ 2500 | Expert | Superhuman NNUE (ELO 3500) |

The final report is generated by `_generateStaticAnalysisText()` (NLP in natural language) and evaluated by `_finishAndReport()` which assigns NAG annotations:

| Zone-drop (master vs student) | NAG verdict |
|---|---|
| 0, same move | !! Excellent |
| 0, different move, WP diff > 8% | !? Interesting |
| 0, different move, WP diff ≤ 8% | ~ Equal alternative |
| 1 | ?! Inaccuracy |
| 2 | ? Mistake |
| ≥ 3 | ?? Blunder |

---

### 📝 Tree-Based Notation Editor (`NotationController`)

`NotationController` manages a `MoveNode` tree where each node holds `fen`, `san`, `comment`, `parent`, and `children[]`. When a new move is played at a branching point, `handleNewMove()` shows an `AlertDialog` with four choices:

- **New Main Line** — inserts at `children[0]`
- **Add Variant** — appends to `children`
- **Overwrite** — clears `children`, then appends
- **Cancel** — reloads the current FEN, discarding the move

Navigation methods: `goBack()`, `goForward()`, `goToStart()`, `goToEnd()`.

---

### ⚔️ Engine vs Engine Gauntlet (`AutoplayController` + `AutoplayOrchestrator`)

A full tournament framework for engine-vs-engine matches:

- Configurable: white/black engine, Livebook toggle per colour, time control (movetime or clock+increment), number of rounds, optional colour reversal between rounds, optional start from current position
- `AutoplayOrchestrator` manages: Livebook Oracle Roulette (weighted random among top-3 moves with WP ≥ 45%), watchdog timer (10 s, resolves via zone-based heuristic), threefold-repetition detection, insufficient material detection, 50-move rule
- Live clock updates via `onClockUpdate(wTimeMs, bTimeMs)` callback
- Each completed game is appended to `gauntlet_results.pgn` in the app's documents directory with full PGN headers
- Moves are forwarded to `NotationController` via `onMovePlayed(san, fen)` for real-time display in the notation panel
- `_handleEndOfGame` includes a `context.mounted` guard after every `await` to prevent state updates on unmounted widgets

---

### 🎮 Play vs Engine (`PlayController` + `CustomChessBoard`)

Human-vs-engine games with a fully custom interactive board:

**`CustomChessBoard`** (built on `chess ^0.7.0` + `chess_vectors_flutter ^1.1.0`):
- **Tap-to-move**: first tap selects the piece and highlights valid destinations with dot overlays; second tap on a highlighted square executes the move
- **Drag-and-drop**: `Draggable<String>` carries the square name; `DragTarget` on each square calls `onDragMove(from, to)`
- **Promotion**: detected by `isPawn && isPromotionRank`; a UCI sentinel `"e7e8?"` is returned to trigger a dialog with SVG piece icons (Queen, Rook, Bishop, Knight) — result appended as `"e7e8q"`
- **Board orientation**: `isWhiteBottom` flag mirrors file/rank index computation in `GridView.builder`
- Colour scheme: light squares `#F0D9B5`, dark squares `#B58863` (Lichess classic)
- Pieces rendered at 85% of square size via `chess_vectors_flutter`

`PlayController` state fields and their `SharedPreferences` keys:

| Field | Key | Default |
|---|---|---|
| `selectedEngine` | `play_engine` | `"alexander"` |
| `tcType` | `play_tcType` | `1` (movetime) |
| `baseTime` | `play_baseTime` | `3` |
| `increment` | `play_increment` | `0` |
| `useLivebook` | `play_useLivebook` | `true` |
| `limitStrength` | `play_limitStrength` | `false` |
| `eloValue` | `play_eloValue` | `1500.0` |

`PlayScreen` bridges two board states: `playBoardProvider` (`ChessBoardController`, used for game logic) and `customBoardProvider` (`CustomBoardController`, used for rendering). A `_syncBoard()` listener on `playBoardProvider` calls `customBoardProvider.notifier.updateFen()` after every move, keeping both in sync.

---

### 📂 PGN / FEN Import & Export (`ImportExportService`)

`file_picker` opens `pgn`, `epd`, `fen`, `txt` files from the device filesystem. Lichess games are fetched by URL supporting:
- Standard game URL → `/game/export/{id}?evals=0&clocks=0`
- Broadcast URL → `/broadcast/{slug}/{id}` via the Broadcast API

---

### 🌐 Livebook Integration (`LiveBookScanner` + `LiveBookOracle`)

`LiveBookScanner.scan()` queries two cloud sources:
- **Lichess Masters** (`explorer.lichess.ovh/masters`) — for HCE engines (human-style moves)
- **ChessDB** (`chessdb.cn/cdb.php?action=queryall`) — for NNUE engines (neural moves)

`LiveBookOracle` adds an in-memory cache keyed by `"{fen}_{isNeural}"` to avoid redundant API calls.

The **Oracle Roulette** algorithm: if the top move has WP < 40%, always play it; otherwise take the top-3 moves with WP ≥ 45% and apply exponential weights `[9, 3, 1]` for weighted-random selection, adding human-like unpredictability.

---

### 📖 In-App Help Manual

HTML manuals (`assets/help/help_en.html`, `help_it.html`) rendered natively with `flutter_widget_from_html`. Content shareable via `share_plus`.

---

### 🌍 Language Switching (IT / EN)

Language switches at runtime from the Settings screen. Persisted under key `"language"` in `SharedPreferences`. Restored at startup via a `ValueNotifier<Locale> appLocale` in `main.dart`, which drives a `ValueListenableBuilder` wrapping `MaterialApp` — no hot-restart required.

---

## ☁️ Cloud Ecosystem (Premium)

ShashGui Mobile acts as the gateway to a high-performance Cloud infrastructure that unlocks **Data Science** and **Explainable AI (XAI)** features impossible to run on a mobile device alone.

- **ChessBeauty (Qualimetry):** Measures the aesthetic and strategic quality of a game along three axes — Audacity, Harmony, and Depth.
- **Nugget Extraction:** Automatically scans PGN archives to surface positions where `wp == 25` (Petrosian Nugget) or `wp == 75` (Tal Nugget).
- **Divergence Dossier (XAI):** Identifies recurring patterns where human dogma systematically fails against neural understanding across an entire opening repertoire.

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| **Mobile Frontend** | Flutter / Dart (SDK `^3.11.5`) |
| **Local Engines** | C++ native `.so` (`libalexander`, `libshashchess`), 3 ABI targets, via `MethodChannel` |
| **State Management** | Riverpod `^2.6.1` — `StateNotifierProvider`, `Provider`, `ConsumerWidget`, `ConsumerStatefulWidget` |
| **Persistence** | `shared_preferences ^2.5.5`, injected app-wide via `sharedPrefsProvider` + `ProviderScope.overrides` |
| **Chess Logic** | `chess ^0.7.0` — move generation, FEN parsing, game-state checks |
| **Chess Pieces** | `chess_vectors_flutter ^1.1.0` — Lichess-style SVG widgets |
| **Chess Board (Analysis)** | `flutter_chess_board ^1.0.1` |
| **File I/O** | `file_picker ^11.0.2`, `path_provider ^2.1.5`, `path ^1.9.1` |
| **Networking** | `http ^1.2.0` (Lichess API, ChessDB, Livebook) |
| **HTML Rendering** | `flutter_widget_from_html ^0.15.1`, `html ^0.15.4` |
| **Sharing** | `share_plus ^12.0.2` |
| **Audio** | `audioplayers ^5.2.1` |
| **Localisation** | `flutter_localizations` SDK + `intl 0.20.2` — English 🇬🇧 & Italian 🇮🇹 |
| **Splash / Icons** | `flutter_native_splash ^2.4.1`, `flutter_launcher_icons ^0.13.1` |
| **Backend / Cloud** | Python, SQLite, AWS / GCP *(external to this repo)* |

---

## 📝 Licence

This project includes and interfaces with the **ShashChess** and **Alexander** chess engines, both derived from the open-source [Stockfish](https://stockfishchess.org/) project. In accordance with Stockfish's licence terms, this application is released under the **GNU General Public Licence v3.0**.

See the [`LICENSE`](./LICENSE) file for full details.

---

## ⚙️ Getting Started

### Prerequisites

#### 1. Flutter SDK (≥ 3.22, Dart `^3.11.5`)

```bash
# macOS / Linux
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
export PATH="$PATH:$HOME/flutter/bin"
flutter doctor
```

> On **Windows**: download from [flutter.dev](https://docs.flutter.dev/get-started/install/windows) and add `flutter\bin` to `PATH`.

#### 2. Android Toolchain

- Install **Android Studio** → SDK Manager → **Android SDK**, **Command-line Tools**, **Build-Tools 34+**
- Accept all licences: `flutter doctor --android-licenses`

The native engine `.so` files are pre-compiled and already present in `android/app/src/main/jniLibs/` for all three ABI targets (`arm64-v8a`, `armeabi-v7a`, `x86_64`). No NDK compilation step is required unless rebuilding engines from source.

#### 3. Xcode (iOS — macOS only)

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods
```

#### 4. One-time asset generation

Run once after cloning, or whenever icon/splash config changes in `pubspec.yaml`:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

---

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-org/shashgui_mobile.git
cd shashgui_mobile

# 2. Install all Dart / Flutter dependencies
flutter pub get

# 3. Regenerate localisation files
flutter gen-l10n

# 4. (iOS only) Install CocoaPods native dependencies
cd ios && pod install && cd ..
```

---

## 🧰 Common Flutter Commands

```bash
# List connected devices / emulators
flutter devices

# Run in debug mode
flutter run

# Run on a specific device
flutter run -d <device-id>

# Run in release mode (no debugger)
flutter run --release

# Install / restore all packages
flutter pub get

# Upgrade packages to latest compatible versions
flutter pub upgrade

# Add / remove a package
flutter pub add <package_name>
flutter pub remove <package_name>

# Outdated packages report
flutter pub outdated

# Regenerate .arb localisation classes
flutter gen-l10n

# Full clean (remove build artefacts and cache)
flutter clean && flutter pub get

# Analyse codebase (uses analysis_options.yaml)
flutter analyze

# Format all Dart source files
dart format .

# Check formatting without modifying (CI-friendly)
dart format --output=none --set-exit-if-changed .

# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run integration tests on device
flutter test integration_test/app_test.dart
```

### Building Releases

#### Android

```bash
# Single APK (direct side-loading)
flutter build apk --release

# Split APKs by ABI — smaller download per device (recommended)
flutter build apk --release --split-per-abi

# App Bundle — required for Google Play Store
flutter build appbundle --release
```

Outputs:
- APK → `build/app/outputs/flutter-apk/app-release.apk`
- AAB → `build/app/outputs/bundle/release/app-release.aab`

> **Signing:** keystore is configured in `android/key.properties` and `upload-keystore.jks` (present but not committed to git). **Never commit these files.**

#### iOS

```bash
# Release build (requires valid Apple Developer certificate)
flutter build ios --release

# Without code signing (CI / simulator)
flutter build ios --release --no-codesign
```

For App Store: open `ios/Runner.xcworkspace` → configure provisioning profile → **Product → Archive**.

---

## 🏗️ Code Architecture (`lib/`)

The codebase was re-engineered from a single-file monolith (`main.dart`, ~128 KB) into a layered, feature-sliced architecture following **Clean Architecture** principles.

### 📐 The Dependency Rule

```
UI (Widget) ──► Controller (Riverpod) ──► Orchestrator (Core) ──► EngineManager (Native .so)
```

No layer knows about the layer above it. Orchestrators know nothing about Flutter or Riverpod; they speak only UCI to the native engines and report results via callbacks.

---

### 📁 Directory Structure

```
shashgui_mobile/
│
├── android/
│   └── app/src/main/
│       ├── jniLibs/
│       │   ├── arm64-v8a/
│       │   │   ├── libalexander.so        # HCE engine — ARM 64-bit
│       │   │   └── libshashchess.so       # NNUE engine — ARM 64-bit
│       │   ├── armeabi-v7a/
│       │   │   ├── libalexander.so        # HCE engine — ARM 32-bit
│       │   │   └── libshashchess.so       # NNUE engine — ARM 32-bit
│       │   └── x86_64/
│       │       ├── libalexander.so        # HCE engine — x86_64 / emulator
│       │       └── libshashchess.so       # NNUE engine — x86_64 / emulator
│       ├── kotlin/.../MainActivity.kt     # MethodChannel host: getNativeLibDir
│       └── AndroidManifest.xml
│
├── ios/Runner/ + Podfile
│
├── assets/
│   ├── demo/                              # Demo PGN games
│   ├── engine/
│   │   ├── nn-c288c895ea92.nnue           # NNUE weights (ShashChess, large net)
│   │   └── nn-37f18f62d772.nnue           # NNUE weights (ShashChess, small net)
│   ├── help/
│   │   ├── help_en.html                   # In-app manual (English)
│   │   └── help_it.html                   # In-app manual (Italian)
│   └── images/
│       ├── icon.png / splash.jpg          # Launcher icon & splash source
│       ├── capablanca.png / tal.png / petrosian.png   # Shashin zone avatars
│       ├── nugget.png                     # Nugget badge
│       └── alexander.bmp / shashchess.bmp             # Engine avatars
│
├── doc/
│   ├── 1.AnalisiRequisiti.docx
│   ├── 2.SpecificaRequisiti.docx
│   ├── 3.ProgettazioneArchitetturale.docx
│   ├── 4.ProgettazioneDettagliata.docx
│   └── 5.BusinessPlan.docx
│
├── lib/
│   │
│   ├── main.dart                          # Bootstrap:
│   │                                      #  1. WidgetsFlutterBinding.ensureInitialized()
│   │                                      #  2. SharedPreferences.getInstance()
│   │                                      #  3. Restore language → appLocale (ValueNotifier)
│   │                                      #  4. ProviderScope.overrides[sharedPrefsProvider]
│   │                                      #  5. ValueListenableBuilder<Locale> → MaterialApp
│   │
│   ├── core/
│   │   ├── engine/
│   │   │   └── engine_manager.dart        # MethodChannel + Process spawn + Stream<String>
│   │   │                                  # NNUE extraction via compute() isolate
│   │   │                                  # dispose() uses Future.microtask for safe kill
│   │   │
│   │   ├── logic/
│   │   │   ├── shashin_logic.dart         # Pure Dart: WDL → ShashinZone (15 zones + Nuggets)
│   │   │   ├── livebook_oracle.dart       # RAM-cached cloud best-move queries
│   │   │   └── livebook_scanner.dart      # Full Livebook result (moves list + opening name)
│   │   │                                  # Oracle Roulette: exponential weights [9,3,1]
│   │   │
│   │   ├── orchestrators/
│   │   │   ├── shashin_fsm.dart           # FSM idle→phase1→phase2 with 200ms debounce
│   │   │   │                              # MultiPV map, ShashinMode setoption, loop
│   │   │   ├── autoplay_orchestrator.dart # Engine-vs-engine: Livebook, watchdog 10s,
│   │   │   │                              # insufficient-material check, onMovePlayed cb
│   │   │   ├── play_orchestrator.dart     # Human-vs-engine: Livebook, threefold rep,
│   │   │   │                              # 50-move rule, clock management
│   │   │   └── crossed_eval.dart          # 5-phase coach: staticEval→baseEval→student
│   │   │                                  # →masterStaticEval→masterThinking; NLP report;
│   │   │                                  # NAG table; full l10n via AppLocalizations
│   │   │
│   │   ├── services/
│   │   │   ├── import_export_service.dart # file_picker (pgn/epd/fen/txt) +
│   │   │   │                              # Lichess URL fetch (game + broadcast)
│   │   │   └── shared_prefs_provider.dart # Provider<SharedPreferences>:
│   │   │                                  # throws UnimplementedError if not overridden
│   │   │
│   │   └── widgets/
│   │       └── setup_position_dialog.dart # Shared: used by Analysis AND Play
│   │
│   ├── features/
│   │   │
│   │   ├── analysis/
│   │   │   ├── domain/
│   │   │   │   ├── engine_state.dart          # Immutable DTO: isRunning, selectedEngine,
│   │   │   │   │                              # EngineStats, ShashinZone, outputLines
│   │   │   │   ├── engine_controller.dart     # StateNotifier<EngineState>:
│   │   │   │   │                              # startEngine() → read {engine}_* prefs →
│   │   │   │   │                              # setoption → isready (50ms) → FSM;
│   │   │   │   │                              # setUciOption() for real-time updates
│   │   │   │   ├── board_provider.dart        # Provider<ChessBoardController> (singleton)
│   │   │   │   ├── notation_controller.dart   # StateNotifier<NotationState>:
│   │   │   │   │                              # MoveNode tree (fen/san/parent/children[]);
│   │   │   │   │                              # branching dialog (Main/Variant/Overwrite/Cancel)
│   │   │   │   └── autoplay_controller.dart   # StateNotifier<AutoplayState>:
│   │   │   │                                  # round lifecycle, score (W/D/L+0.5),
│   │   │   │                                  # colour reversal, PGN save, context.mounted guards
│   │   │   └── presentation/
│   │   │       ├── analysis_screen.dart       # Top-level ConsumerWidget
│   │   │       └── widgets/
│   │   │           ├── board_section.dart
│   │   │           ├── engine_controls.dart   # Start/stop, setup, autoplay, livebook,
│   │   │           │                          # coach, import/export buttons
│   │   │           ├── analysis_panel.dart    # Shashin zone display + WDL bar
│   │   │           ├── notation_panel.dart    # MoveNode tree renderer + navigation
│   │   │           ├── analysis_setup_modal.dart  # Engine + time + UCI config button
│   │   │           ├── uci_options_modal.dart     # Dynamic UCI form + SharedPrefs persist
│   │   │           ├── autoplay_modal.dart        # Gauntlet setup UI
│   │   │           ├── livebook_modal.dart        # Online book viewer
│   │   │           └── coach_modal.dart           # CrossedEval report display
│   │   │
│   │   ├── play/
│   │   │   ├── domain/
│   │   │   │   └── play_controller.dart       # StateNotifier<PlayState>:
│   │   │   │                                  # all settings persisted to play_* prefs;
│   │   │   │                                  # ELO strength limiting; PlayOrchestrator
│   │   │   └── presentation/
│   │   │       ├── custom_chess_board.dart    # CustomBoardState + CustomBoardController
│   │   │       │                              # (tap + drag, promotion sentinel "uci?")
│   │   │       │                              # CustomChessBoard ConsumerWidget:
│   │   │       │                              # GridView 8×8, Draggable/DragTarget,
│   │   │       │                              # SVG pieces @ 85%, Lichess colours
│   │   │       └── play_screen.dart           # ConsumerStatefulWidget:
│   │   │                                      # _syncBoard() bridges playBoard → customBoard
│   │   │
│   │   ├── settings/
│   │   │   └── presentation/
│   │   │       ├── settings_screen.dart       # Language switcher + About button
│   │   │       └── widgets/
│   │   │           └── about_dialog.dart      # Logo, version, credits (fully localised)
│   │   │
│   │   └── navigation/
│   │       └── presentation/
│   │           └── main_navigation_screen.dart # BottomNavigationBar:
│   │                                           # Analysis | Play | Settings +
│   │                                           # PlaceholderScreen for upcoming tabs
│   │
│   └── l10n/
│       ├── app_en.arb                     # English string keys
│       ├── app_it.arb                     # Italian string keys
│       ├── app_localizations.dart         # Generated base class
│       ├── app_localizations_en.dart      # Generated EN implementation
│       └── app_localizations_it.dart      # Generated IT implementation
│
├── test/                                  # Unit & widget tests
├── integration_test/                      # End-to-end device tests
├── analysis_options.yaml
├── l10n.yaml                              # arb-dir, output-dir, template-arb-file
├── pubspec.yaml
└── README.md
```

---

### 🔄 Layer Responsibilities

**Controller commands — Orchestrator executes.**

| Layer | Knows about | Never knows about |
|---|---|---|
| Widget (`features/*/presentation/`) | Controller state, AppLocalizations | Engine process, UCI |
| Controller (`features/*/domain/`) | Orchestrators, SharedPreferences | Flutter widgets, rendering |
| Orchestrator (`core/orchestrators/`) | EngineManager, chess logic | Flutter, Riverpod, UI state |
| EngineManager (`core/engine/`) | MethodChannel, Process, Stream | Everything else |

---

### 🗄️ Persistence Architecture

All user preferences flow through a single `SharedPreferences` instance injected at startup.

**Bootstrap sequence (`main.dart`):**
```dart
final prefs = await SharedPreferences.getInstance();
appLocale.value = Locale(prefs.getString('language') ?? 'it');
runApp(ProviderScope(
  overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
  child: const ShashGuiApp(),
));
```

**Complete key registry:**

| Key | Type | Description |
|---|---|---|
| `language` | `String` | Active UI locale (`"it"` / `"en"`) |
| `play_engine` | `String` | Last engine selected in Play |
| `play_tcType` | `int` | Time control type (0=clock, 1=movetime) |
| `play_baseTime` | `int` | Base time value |
| `play_increment` | `int` | Fischer increment (s) |
| `play_useLivebook` | `bool` | Livebook toggle in Play |
| `play_limitStrength` | `bool` | ELO limiter toggle |
| `play_eloValue` | `double` | Target ELO when limiter is on |
| `{engine}_{optionName}` | `String` | Per-engine UCI option (e.g. `shashchess_Threads`) |

---

### 🧩 Widget Placement Policy

| Condition | Location |
|---|---|
| Widget used by **one feature only** | `features/<name>/presentation/widgets/` |
| Widget used by **two or more features** | `lib/core/widgets/` |

Current state:
- All Analysis widgets → `features/analysis/presentation/widgets/` ✅
- `CustomChessBoard` + controller → `features/play/presentation/` ✅
- `AboutDialog` → `features/settings/presentation/widgets/` ✅
- `SetupPositionDialog` → `lib/core/widgets/` ✅ *(shared: Analysis + Play)*

---

### 💬 Comment Policy

Non-obvious logic — FSM transitions, guard conditions, debounce timers, WDL zone boundaries, promotion sentinel detection, `context.mounted` guards after `async` gaps, process kill strategy — must carry inline comments or Dart doc comments (`///`).

Rule of thumb: **if you had to think for more than 30 seconds before writing a line, that line deserves a comment.**

---

## 🤝 Contributing

Pull requests are welcome. For significant architectural changes, please open an issue first to discuss the proposed direction. When in doubt, follow the Dependency Rule: **dependencies point inward, never outward**.

---

*ShashGui Mobile — making the engine speak human.*