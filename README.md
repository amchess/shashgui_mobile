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

## 🚀 Current Status

| Platform | Status | Notes |
|---|---|---|
| **Android** | ✅ Beta-ready | Native `.so` via `MethodChannel`, 3 ABI targets, Android 15 compliant (16 KB page size) |
| **iOS** | 🔜 Roadmap Phase 2 | Requires Dart FFI migration — `Process.start()` is incompatible with App Store sandboxing |

---

## 🚀 Local Features (Free)

### ♟️ Real-Time Shashin Thermometer

`ShashinLogic.analyzeShashinZone()` receives the three raw WDL integers from the engine, computes the Win Probability (`wp = (w + d/2) / total * 100`), and maps it to one of the following named zones:

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
| ~333/333/334 | Chaos: Capa-Petrosian-Tal | `∞` | Total chaos |

Nugget positions (`wp == 25` or `wp == 75`) surface as special `⚱️` zones and are flagged as candidates for the **Cloud Nugget Extraction** feature.

> **Implementation note:** the Chaos check uses a ±5 tolerance to accommodate the asymmetric WDL distributions engines produce at rounding boundaries (e.g. 333/334/333). The zero-division edge case (`0/0/0`) is handled with a safe fallback to `"Calcolo..."` / `wp = 50.0`.

---

### ⚙️ Dual Engine Support (C++ Native Libraries)

Two engines are compiled as native shared libraries and distributed pre-built for three CPU architectures:

| Engine | Type | ABI targets | Key UCI options |
|---|---|---|---|
| **Alexander** | HCE (Hand-Crafted Evaluation) | `arm64-v8a`, `armeabi-v7a`, `x86_64` | `UCI_LimitStrength`, `UCI_Elo`, `ShashinMode` |
| **ShashChess** | NNUE (Neural Network) | `arm64-v8a`, `armeabi-v7a`, `x86_64` | `EvalFile`, `EvalFileSmall`, `ShashinMode` |

`EngineManager.initEngine()` lifecycle:
1. Calls `getNativeLibDir` via `MethodChannel` on the Android side to locate the correct `.so`
2. Extracts NNUE weight files (`nn-c288c895ea92.nnue`, `nn-37f18f62d772.nnue`) to the app's documents directory on first launch — checked by file size to skip redundant writes, executed in a background `Isolate` via `compute()`
3. Spawns the engine process and connects `stdout` to a broadcast `Stream<String>`
4. Drains `stderr` to prevent OS buffer deadlocks
5. Sends `uci` → `setoption EvalFile` → `isready` and awaits `readyok` (**15 s timeout** — throws `TimeoutException` on failure)

On `dispose()`, the process kill is dispatched via `Future.microtask` to avoid blocking the main thread.

---

### 🔁 Two-Phase FSM Analysis (`ShashinFsm`)

`ShashinFsm` drives the analysis loop through three states (`idle → phase1 → phase2`) per iteration:

- **Phase 1** (`movetime = baseTimeMs × iteration`, capped at 30 s): thermodynamic read — WDL stream is parsed to classify the current `ShashinZone`.
- **Phase 2** (`movetime = baseTimeMs × iteration × 2`): strategic calculation — `setoption name ShashinMode value {Tal|Capablanca|Petrosian|Normal}` is sent before `go`, so the engine searches in the style appropriate for the detected zone.
- After `bestmove`, the iteration counter increments and loops back to Phase 1 with proportionally longer time budgets, enabling progressive deepening without user input.

**Concurrency:** `EngineStats` updates are batched via a **200 ms debounce timer** to avoid UI jank from rapid `info` line floods. The `_multiPvMap` is cleared at the start of each `startAnalysis()` call to prevent stale PV contamination across consecutive positions.

```dart
// Reset on every new analysis — prevents PV bleed between positions
_multiPvMap.clear();
```

---

### 🎛️ UCI Engine Configuration (`UciOptionsModal`)

`UciOptionsModal` is a `ConsumerStatefulWidget` that:
1. Listens to the engine's `option name …` lines on startup
2. Renders a dynamic form (sliders, switches, text fields) for each reported option
3. Persists every value to `SharedPreferences` under `{engineName}_{optionName}`

On the next `startEngine()` call, `EngineController` reads all keys matching the `{engineName}_` prefix and sends `setoption name X value Y` before the `isready` barrier.

---

### 🔬 Cross-Analysis — Coach Mode (`CrossedEvalOrchestrator`)

A multi-phase evaluation pipeline running entirely on-device:

| State | Description |
|---|---|
| `staticEval` | Sends `eval` to Alexander — parses: Total Space (W/B), Center Type, deltaK (packing density), Delta Expansion (centre of gravity), Bishop pair flags, Makogonov worst-piece (HCE) |
| `baseEval` | `go movetime T` — reads WDL to establish the base `ShashinZone` |
| `studentThinking` | `UCI_LimitStrength=true` + `UCI_Elo={studentElo}` + `go movetime T` — simulates the player's strength |
| `masterStaticEval` / `masterThinking` | If `masterElo ≥ 3500`: re-initialises to ShashChess, runs `eval` for NNUE worst-piece, then `go movetime T`; otherwise sends `UCI_Elo={masterElo}` on Alexander |

**School ladder** (derived from `playerElo`):

| Player ELO | Student school | Master school |
|---|---|---|
| < 2000 | Beginner | Intermediate (ELO 2199) |
| 2000–2199 | Intermediate | Advanced (ELO 2399) |
| 2200–2499 | Advanced | Expert HCE (ELO 3190) |
| ≥ 2500 | Expert | Superhuman NNUE (ELO 3500) |

**NAG assignment:**

| Zone-drop (master vs student) | NAG verdict |
|---|---|
| 0, same move | `!!` Excellent |
| 0, different move, WP diff > 8% | `!?` Interesting |
| 0, different move, WP diff ≤ 8% | `~` Equal alternative |
| 1 | `?!` Inaccuracy |
| 2 | `?` Mistake |
| ≥ 3 | `??` Blunder |

---

### 📝 Tree-Based Notation Editor (`NotationController`)

`NotationController` manages a `MoveNode` tree where each node holds `fen`, `san`, `comment`, `parent`, and `children[]`. When a new move is played at a branching point, `handleNewMove()` shows an `AlertDialog` with four choices:

- **New Main Line** — inserts at `children[0]`
- **Add Variant** — appends to `children`
- **Overwrite** — clears `children`, then appends
- **Cancel** — reloads the current FEN, discarding the move

Navigation: `goBack()`, `goForward()`, `goToStart()`, `goToEnd()`.

---

### ⚔️ Engine vs Engine Gauntlet (`AutoplayController` + `AutoplayOrchestrator`)

A full tournament framework for engine-vs-engine matches:

- Configurable: white/black engine, Livebook toggle per colour, time control (movetime or clock+increment), number of rounds, optional colour reversal, optional start from current position
- `AutoplayOrchestrator` manages: **Livebook Oracle Roulette** (exponential weights `[9, 3, 1]` among top-3 moves with WP ≥ 45%), watchdog timer (10 s, resolves via zone-based heuristic), threefold-repetition detection, insufficient material detection, 50-move rule
- Live clock updates via `onClockUpdate(wTimeMs, bTimeMs)` callback
- Each completed game is appended to `gauntlet_results.pgn` in the app's documents directory with full PGN headers
- Moves are forwarded to `NotationController` via `onMovePlayed(san, fen)` for real-time notation display
- `_handleEndOfGame` includes `context.mounted` guards after every `await` to prevent state updates on unmounted widgets

---

### 🎮 Play vs Engine (`PlayController` + `CustomChessBoard`)

Human-vs-engine games with a fully custom interactive board:

**`CustomChessBoard`** (built on `chess ^0.7.0` + `chess_vectors_flutter ^1.1.0`):
- **Tap-to-move**: first tap selects the piece and highlights valid destinations with dot overlays; second tap executes
- **Drag-and-drop**: `Draggable<String>` carries the square name; `DragTarget` calls `onDragMove(from, to)`
- **Promotion**: detected by `isPawn && isPromotionRank`; a UCI sentinel `"e7e8?"` triggers a dialog with SVG piece icons — result appended as `"e7e8q"`
- **Board orientation**: `isWhiteBottom` flag mirrors file/rank index computation in `GridView.builder`
- Colour scheme: light squares `#F0D9B5`, dark squares `#B58863` (Lichess classic)
- Pieces rendered at 85% of square size

`PlayController` state and `SharedPreferences` keys:

| Field | Key | Default |
|---|---|---|
| `selectedEngine` | `play_engine` | `"alexander"` |
| `tcType` | `play_tcType` | `1` (movetime) |
| `baseTime` | `play_baseTime` | `3` |
| `increment` | `play_increment` | `0` |
| `useLivebook` | `play_useLivebook` | `true` |
| `limitStrength` | `play_limitStrength` | `false` |
| `eloValue` | `play_eloValue` | `1500.0` |

---

### 📂 PGN / FEN Import & Export (`ImportExportService`)

`file_picker` opens `pgn`, `epd`, `fen`, `txt` files. Lichess games are fetched by URL supporting:
- Standard game URL → `/game/export/{id}?evals=0&clocks=0`
- Broadcast URL → `/broadcast/{slug}/{id}` via the Broadcast API

**PGN parsing runs in a separate `Isolate`** via `compute(_parsePgnInBackground, text)`, keeping the main thread free for rendering even with large files.

> **Known limitation:** the Regex-based parser handles linear PGN reliably but cannot correctly process deeply nested RAV (Recursive Annotation Variations) due to the mathematical limitations of finite-state machines on context-free grammars. An AST-based parser is planned for the Cloud batch-analysis phase.

---

### 🌐 Livebook Integration (`LiveBookScanner` + `LiveBookOracle`)

`LiveBookScanner.scan()` queries two cloud sources concurrently:
- **Lichess Masters** (`explorer.lichess.ovh/masters`) — human-style moves (HCE engines)
- **ChessDB** (`chessdb.cn/cdb.php?action=queryall`) — neural moves (NNUE engines)

`LiveBookOracle` adds an **LRU-style in-memory cache** (max 200 entries, FIFO eviction) keyed by `"{fen}_{isNeural}"` to avoid redundant API calls.

**Effective Win Probability formula (`pEff`):**
```dart
pEff = (winProbability * 0.70) + (popularityScore * 0.30)
```
This 70/30 blend prevents statistical outliers (moves with 100% WP but played once) from dominating the ranking. Moves with popularity < 0.5% of total games are discarded entirely.

**Oracle Roulette:** if the top move has WP < 40%, always play it; otherwise apply exponential weights `[9, 3, 1]` to the top-3 moves (WP ≥ 45%) for weighted-random selection, introducing human-like unpredictability in the Autoplay gauntlet.

---

### 📖 In-App Help Manual

HTML manuals (`assets/help/help_en.html`, `help_it.html`) rendered natively with `flutter_widget_from_html`. Content shareable via `share_plus`.

---

### 🌍 Language Switching (IT / EN)

Language switches at runtime from the Settings screen. Persisted under key `"language"` in `SharedPreferences`. Restored at startup via a `ValueNotifier<Locale> appLocale` in `main.dart`, which drives a `ValueListenableBuilder` wrapping `MaterialApp` — no hot-restart required.

---

## ☁️ Cloud Ecosystem (Premium)

ShashGui Mobile acts as the gateway to a high-performance Cloud infrastructure that unlocks **Data Science** and **Explainable AI (XAI)** features impossible to run on a mobile device alone.

- **ChessBeauty (Qualimetry):** Measures the aesthetic and strategic quality of a game — Audacity, Harmony, and Depth.
- **Nugget Extraction:** Scans PGN archives to surface `wp == 25` (Petrosian Nugget) or `wp == 75` (Tal Nugget) positions.
- **Divergence Dossier (XAI):** Identifies patterns where human intuition and neural understanding systematically diverge across an opening repertoire.
- **ShashQL:** A proprietary query language for searching positional databases using thermodynamic conditions.

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| **Mobile Frontend** | Flutter / Dart (SDK `^3.11.5`) |
| **Local Engines** | C++ native `.so` (`libalexander`, `libshashchess`), 3 ABI targets, via `MethodChannel` |
| **State Management** | Riverpod `^2.6.1` — `StateNotifierProvider`, `Provider`, `ConsumerWidget` |
| **Persistence** | `shared_preferences ^2.5.5`, injected app-wide via `ProviderScope.overrides` |
| **Chess Logic** | `chess ^0.7.0` — move generation, FEN parsing, game-state checks |
| **Chess Pieces** | `chess_vectors_flutter ^1.1.0` — Lichess-style SVG widgets |
| **Chess Board (Analysis)** | `flutter_chess_board ^1.0.1` |
| **File I/O** | `file_picker ^11.0.2`, `path_provider ^2.1.5` |
| **Networking** | `http ^1.2.0` (Lichess API, ChessDB, Livebook) |
| **HTML Rendering** | `flutter_widget_from_html ^0.15.1` |
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

The native engine `.so` files are pre-compiled and already present in `android/app/src/main/jniLibs/` for all three ABI targets. No NDK compilation step is required unless rebuilding engines from source.

#### 3. Xcode (iOS — macOS only, Phase 2)

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods
```

> ⚠️ **iOS support requires the Dart FFI migration** (replacing `Process.start()` with `dart:ffi` + static `.a` libraries). This is planned for Phase 2. Building for iOS in the current state will not pass App Store review.

#### 4. One-time asset generation

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

# 4. (iOS only — Phase 2) Install CocoaPods native dependencies
cd ios && pod install && cd ..
```

---

## 🧰 Common Flutter Commands

```bash
# List connected devices / emulators
flutter devices

# Run in debug mode
flutter run

# Run in release mode
flutter run --release

# Install / restore all packages
flutter pub get

# Regenerate .arb localisation classes
flutter gen-l10n

# Full clean
flutter clean && flutter pub get

# Analyse codebase
flutter analyze

# Format all Dart source files
dart format .

# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

### Building Releases

#### Android

```bash
# Split APKs by ABI (recommended — smaller download per device)
flutter build apk --release --split-per-abi

# App Bundle for Google Play Store
flutter build appbundle --release
```

Outputs:
- APK → `build/app/outputs/flutter-apk/app-release.apk`
- AAB → `build/app/outputs/bundle/release/app-release.aab`

> **Signing:** keystore is configured in `android/key.properties` and `upload-keystore.jks`. **Never commit these files.**

#### iOS (Phase 2 — after FFI migration)

```bash
flutter build ios --release
```

---

## 🏗️ Code Architecture (`lib/`)

### 📐 The Dependency Rule

```
Widget  ──►  Controller (Riverpod)  ──►  Orchestrator (Core)  ──►  EngineManager (Native)
```

No layer knows about the layer above it. Orchestrators speak only UCI; they have no knowledge of Flutter, Riverpod, or UI state.

---

### 📁 Directory Structure

```
shashgui_mobile/
│
├── android/app/src/main/
│   ├── jniLibs/
│   │   ├── arm64-v8a/   libalexander.so  libshashchess.so
│   │   ├── armeabi-v7a/ libalexander.so  libshashchess.so
│   │   └── x86_64/      libalexander.so  libshashchess.so
│   ├── kotlin/.../MainActivity.kt        ← MethodChannel: getNativeLibDir
│   └── AndroidManifest.xml
│
├── assets/
│   ├── engine/   nn-c288c895ea92.nnue  nn-37f18f62d772.nnue
│   ├── help/     help_en.html  help_it.html
│   └── images/   avatars, icons, splash
│
├── lib/
│   ├── main.dart                         ← Bootstrap + locale restore + ProviderScope
│   │
│   ├── core/
│   │   ├── engine/       engine_manager.dart
│   │   ├── logic/        shashin_logic.dart  livebook_oracle.dart  livebook_scanner.dart
│   │   ├── orchestrators/ shashin_fsm.dart  autoplay_orchestrator.dart
│   │   │                  play_orchestrator.dart  crossed_eval.dart
│   │   ├── services/     import_export_service.dart  shared_prefs_provider.dart
│   │   └── widgets/      setup_position_dialog.dart
│   │
│   ├── features/
│   │   ├── analysis/     domain/ + presentation/widgets/
│   │   ├── play/         domain/ + presentation/
│   │   ├── settings/     presentation/
│   │   └── navigation/   main_navigation_screen.dart
│   │
│   └── l10n/             app_en.arb  app_it.arb  (+ generated files)
│
├── test/
│   ├── shashin_logic_test.dart           ← 6 parametric unit tests
│   └── core/logic/livebook_oracle_test.dart  ← pEff formula + outlier rejection
│
└── integration_test/
```

---

### 🔄 Layer Responsibilities

| Layer | Knows about | Never knows about |
|---|---|---|
| Widget (`features/*/presentation/`) | Controller state, AppLocalizations | Engine process, UCI protocol |
| Controller (`features/*/domain/`) | Orchestrators, SharedPreferences | Flutter widgets, rendering |
| Orchestrator (`core/orchestrators/`) | EngineManager, chess logic | Flutter, Riverpod, UI state |
| EngineManager (`core/engine/`) | MethodChannel, Process, Stream | Everything else |

---

### 🗄️ Persistence Architecture

All user preferences flow through a single `SharedPreferences` instance injected at startup:

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
| `play_tcType` | `int` | Time control type |
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

---

### 💬 Comment Policy

Non-obvious logic — FSM transitions, guard conditions, debounce timers, WDL zone boundaries, promotion sentinel detection, `context.mounted` guards after `async` gaps, process kill strategy — must carry inline or Dart doc comments (`///`).

> **Rule of thumb:** if you had to think for more than 30 seconds before writing a line, that line deserves a comment.

---

## 🧪 Testing

```bash
# Run all unit tests
flutter test

# Run with coverage report
flutter test --coverage
```

Current unit test coverage:

| File | Tests | What is verified |
|---|---|---|
| `test/shashin_logic_test.dart` | 6 | Capablanca (50%), Total Chaos, High Tal (95%), High Petrosian (5%), Petrosian Nugget (25%), division-by-zero safety |
| `test/core/logic/livebook_oracle_test.dart` | 3+ | pEff formula (White), pEff formula (Black), popularity filter (< 0.5% discarded) |

---

## 🤝 Contributing

Pull requests are welcome. For significant architectural changes, please open an issue first. When in doubt, follow the Dependency Rule: **dependencies point inward, never outward**.

---

*ShashGui Mobile — making the engine speak human.*