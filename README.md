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

The mobile frontend is designed to be an intelligent, offline-capable **pocket coach**, running all computation natively on-device with no server round-trip required.

- **Real-Time Shashin Thermometer:** Reads the engine's WDL output and instantly maps the position to one of Shashin's zones. The thermometer shifts colour and style label as the game evolves, giving continuous feedback without interrupting the flow of thought.
- **Dual Engine Support (C++ via native library):** Two engines run natively as compiled shared libraries (`.so`), invoked through a `MethodChannel`:
  - **Alexander (HCE)** — classical hand-crafted evaluation, calibrated to simulate human-like weaknesses and heuristics.
  - **ShashChess (NNUE)** — neural-network engine derived from Stockfish, representing mathematical ground truth.
- **UCI Engine Configuration:** `UciOptionsModal` probes the engine at startup, dynamically renders all its UCI options (sliders, switches, dropdowns), and persists each setting to `SharedPreferences` under the key `{engineName}_{optionName}`. Options are automatically applied on the next `startEngine()` call.
- **Cross-Analysis (Crossed Eval):** `CrossedEvalOrchestrator` runs a multi-phase evaluation — static eval, base eval, "student" move, master move — comparing human-calibrated Alexander against neural ShashChess. Enriched with spatial metrics (`centerType`, packing density `deltaK`) and fully internationalised via `AppLocalizations`.
- **Tree-Based Notation Editor:** `NotationController` manages a `MoveNode` tree supporting main lines, variants, and overwrite. When a new move is played at a branching point, a dialog prompts the user to choose: *New Main Line*, *Add Variant*, *Overwrite*, or *Cancel*. Navigation: `goBack`, `goForward`, `goToStart`, `goToEnd`.
- **Engine vs Engine Gauntlet (Autoplay):** `AutoplayController` manages full multi-game matches between any two engines, with configurable time controls (movetime or clock+increment), optional Livebook, colour-reversal between rounds, live score tracking (W/D/L), and automatic PGN export to `gauntlet_results.pgn` in the app's documents directory.
- **Play vs Engine:** `PlayController` supports human-vs-engine games with configurable engine, player colour, time control, Livebook, and optional strength limitation (`limitStrength` / `eloValue`). Settings are persisted via `sharedPrefsProvider`.
- **PGN / FEN Import & Export:** `ImportExportService` uses `file_picker` to open PGN, EPD, FEN, and TXT files from the device filesystem. Also fetches games directly from Lichess by URL via the `http` package.
- **Livebook Integration:** Both single-analysis and autoplay modes can query the online opening book in real time, with per-engine toggles for white and black.
- **In-App Help Manual:** HTML manuals (`assets/help/help_en.html`, `help_it.html`) are rendered natively inside the app using `flutter_widget_from_html`, with content shareable via `share_plus`.
- **Language Switching (IT / EN):** The interface language switches at runtime from the Settings screen. The choice is persisted in `SharedPreferences` under the key `language` and restored on startup via a `ValueNotifier<Locale>` in `main.dart`.

---

## ☁️ Cloud Ecosystem (Premium)

ShashGui Mobile acts as the gateway to a high-performance Cloud infrastructure that unlocks **Data Science** and **Explainable AI (XAI)** features impossible to run on a mobile device alone.

- **ChessBeauty (Qualimetry):** Measures the *aesthetic* and *strategic* quality of a game along three axes — Audacity, Harmony, and Depth.
- **Nugget Extraction:** Automatically scans PGN archives to surface tactical and strategic gems. Special WDL states (`wp == 25` or `wp == 75`) are flagged as "Nugget" positions.
- **Divergence Dossier (XAI):** Identifies positions where human dogma systematically fails against neural understanding — recurring patterns across an entire opening repertoire or playing style.

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| **Mobile Frontend** | Flutter / Dart (SDK `^3.11.5`) |
| **Local Engines** | C++ native shared libs (`libalexander.so`, `libshashchess.so`), invoked via `MethodChannel` |
| **State Management** | Riverpod `^2.6.1` — `StateNotifierProvider`, `Provider`, `ConsumerWidget`, `ConsumerStatefulWidget` |
| **Persistence** | `shared_preferences ^2.5.5`, injected app-wide via `sharedPrefsProvider` + `ProviderScope.overrides` |
| **File I/O** | `file_picker ^11.0.2`, `path_provider ^2.1.5`, `path ^1.9.1` |
| **Networking** | `http ^1.2.0` (Lichess API, Livebook) |
| **Chess UI** | `flutter_chess_board ^1.0.1` |
| **HTML Rendering** | `flutter_widget_from_html ^0.15.1` (in-app manual), `html ^0.15.4` |
| **Sharing** | `share_plus ^12.0.2` |
| **Audio** | `audioplayers ^5.2.1` |
| **Localisation** | Flutter `l10n` + `flutter_localizations` + `intl 0.20.2` — English 🇬🇧 & Italian 🇮🇹 |
| **Splash / Icons** | `flutter_native_splash ^2.4.1`, `flutter_launcher_icons ^0.13.1` |
| **Backend / Cloud** | Python, SQLite, AWS / GCP *(external to this repo)* |

---

## 📝 Licence

This project includes and interfaces with the **ShashChess** and **Alexander** chess engines, both derived from the open-source [Stockfish](https://stockfishchess.org/) project. In accordance with Stockfish's licence terms, this application is released under the **GNU General Public Licence v3.0**.

See the [`LICENSE`](./LICENSE) file for full details.

---

## ⚙️ Getting Started

### Prerequisites

Before running ShashGui Mobile, ensure the following tools are installed on your development machine.

#### 1. Flutter SDK

The project requires **Flutter 3.22 or later** (Dart `^3.11.5`).

```bash
# macOS / Linux — clone the stable channel
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Verify installation and check for missing dependencies
flutter doctor
```

> On **Windows**, download the Flutter SDK zip from [flutter.dev](https://docs.flutter.dev/get-started/install/windows) and add the `flutter\bin` folder to your `PATH`.

`flutter doctor` will report any missing dependencies. Address each warning before proceeding.

#### 2. Android Toolchain (for Android builds)

- Install **Android Studio** from [developer.android.com](https://developer.android.com/studio)
- SDK Manager → install **Android SDK**, **Android SDK Command-line Tools**, **Android SDK Build-Tools 34+**
- Accept all SDK licences:

```bash
flutter doctor --android-licenses
```

The native engine shared libraries (`libalexander.so`, `libshashchess.so`) are already pre-compiled and placed in `android/app/src/main/jniLibs/`. No NDK compilation step is required unless you need to rebuild the engines from source.

#### 3. Xcode (for iOS builds — macOS only)

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods
```

#### 4. Generate Splash Screen & Launcher Icon

Run these once after cloning, or whenever `pubspec.yaml`'s icon/splash config changes:

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

### Running the App

```bash
# List all connected devices and emulators
flutter devices

# Run in debug mode on the default connected device
flutter run

# Run on a specific device by ID
flutter run -d <device-id>

# Run in release mode (no debugger, full performance)
flutter run --release
```

### Managing Dependencies

```bash
# Install / restore all packages from pubspec.yaml
flutter pub get

# Upgrade all packages to the latest compatible versions
flutter pub upgrade

# Add a new package
flutter pub add <package_name>

# Remove a package
flutter pub remove <package_name>

# List outdated packages
flutter pub outdated
```

### Localisation

```bash
# Regenerate Dart localisation classes from .arb files (l10n.yaml controls output path)
flutter gen-l10n
```

> After adding or renaming a key in `lib/l10n/app_en.arb` or `app_it.arb`, always re-run `flutter gen-l10n` before building.

### Cleaning

```bash
# Remove all build artefacts and caches
flutter clean

# Always re-fetch dependencies after a clean
flutter pub get
```

> **When to run `flutter clean`:** after changing native code, updating the Flutter SDK, pulling a branch with modified `pubspec.yaml`, or when facing unexplained build failures.

### Testing

```bash
# Run all unit and widget tests
flutter test

# Run with coverage report
flutter test --coverage

# Run a specific test file
flutter test test/unit/shashin_logic_test.dart

# Run integration tests on a connected device
flutter test integration_test/app_test.dart
```

### Static Analysis & Formatting

```bash
# Analyse the whole codebase (uses analysis_options.yaml)
flutter analyze

# Auto-format all Dart source files
dart format .

# Check formatting without modifying files (useful in CI)
dart format --output=none --set-exit-if-changed .
```

### Building Releases

#### Android

```bash
# Release APK — single file (useful for direct side-loading)
flutter build apk --release

# Release APKs split by ABI — smaller download per device
flutter build apk --release --split-per-abi

# Release App Bundle — required for Google Play Store submission
flutter build appbundle --release
```

Output paths:
- APK → `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle → `build/app/outputs/bundle/release/app-release.aab`

> **Signing:** the keystore is configured in `android/key.properties` (already present, not committed to git). Reference it in `android/app/build.gradle.kts`. **Never commit `key.properties` or `.jks` files.**

#### iOS

```bash
# Build a release iOS app (requires a valid Apple Developer certificate)
flutter build ios --release

# Build without code signing (for CI or simulator testing)
flutter build ios --release --no-codesign
```

For App Store submission, open `ios/Runner.xcworkspace` in Xcode → select **Runner** target → configure provisioning profile → **Product → Archive**.

---

## 🏗️ Code Architecture (`lib/`)

The codebase was re-engineered from a single-file monolith (`main.dart`, ~128 KB) into a layered, feature-sliced architecture following **Clean Architecture** principles.

### 📐 The Dependency Rule

> *"Source code dependencies must point only inward, toward higher-level policies."*
> — Robert C. Martin

```
UI (Widget) ──► Controller (Riverpod) ──► Orchestrator (Core) ──► EngineManager (Native)
```

No layer knows about the layer above it. Orchestrators know nothing about Flutter widgets or Riverpod state; they only speak UCI to the native engines and report results via callbacks.

---

### 📁 Directory Structure

```
shashgui_mobile/
│
├── android/
│   └── app/src/main/
│       ├── jniLibs/
│       │   └── x86_64/
│       │       ├── libalexander.so          # HCE engine — pre-compiled C++
│       │       └── libshashchess.so         # NNUE engine — pre-compiled C++
│       ├── kotlin/.../MainActivity.kt       # MethodChannel host: getNativeLibDir
│       └── AndroidManifest.xml
│
├── ios/
│   ├── Runner/
│   └── Podfile
│
├── assets/
│   ├── demo/                                # Demo PGN games
│   ├── engine/
│   │   ├── nn-c288c895ea92.nnue             # NNUE network file (ShashChess)
│   │   └── nn-37f18f62d772.nnue             # NNUE network file (ShashChess)
│   ├── help/
│   │   ├── help_en.html                     # In-app manual (English)
│   │   └── help_it.html                     # In-app manual (Italian)
│   └── images/
│       ├── icon.png                         # App icon / launcher icon source
│       ├── splash.jpg                       # Native splash screen source
│       ├── capablanca.png                   # Shashin zone avatar
│       ├── tal.png                          # Shashin zone avatar
│       ├── petrosian.png                    # Shashin zone avatar
│       ├── nugget.png                       # Nugget position badge
│       ├── alexander.bmp                    # Engine avatar
│       └── shashchess.bmp                   # Engine avatar
│
├── doc/                                     # Design documentation
│   ├── 1.AnalisiRequisiti.docx
│   ├── 2.SpecificaRequisiti.docx
│   ├── 3.ProgettazioneArchitetturale.docx
│   ├── 4.ProgettazioneDettagliata.docx
│   └── 5.BusinessPlan.docx
│
├── lib/
│   │
│   ├── main.dart                            # Bootstrap:
│   │                                        #   1. Load SharedPreferences
│   │                                        #   2. Restore saved language → appLocale
│   │                                        #   3. Inject prefs via ProviderScope.overrides
│   │                                        #   4. Wrap app in ValueListenableBuilder<Locale>
│   │
│   ├── core/                                # Shared infrastructure — feature-agnostic
│   │   │
│   │   ├── engine/
│   │   │   └── engine_manager.dart          # Spawns the native .so process via MethodChannel,
│   │   │                                    # extracts NNUE files to documents dir on first run,
│   │   │                                    # exposes Stream<String> engineOutput + sendCommand()
│   │   │
│   │   ├── logic/
│   │   │   ├── shashin_logic.dart           # Pure Dart: WDL → ShashinZone mapping,
│   │   │   │                                # avatar selection, Nugget detection (wp==25/75)
│   │   │   ├── livebook_oracle.dart         # Online Livebook queries (Lichess / ChessDB)
│   │   │   └── livebook_scanner.dart        # Local Livebook opening book scanning
│   │   │
│   │   ├── orchestrators/
│   │   │   ├── shashin_fsm.dart             # FSM (idle → phase1 → phase2):
│   │   │   │                                # drives go/stop commands, parses UCI info lines,
│   │   │   │                                # updates ShashinZone + EngineStats via callbacks
│   │   │   ├── autoplay_orchestrator.dart   # Engine-vs-engine match loop:
│   │   │   │                                # time control (movetime or clock+inc),
│   │   │   │                                # Livebook, watchdog timer, game-over detection,
│   │   │   │                                # live clock updates (onClockUpdate callback)
│   │   │   ├── play_orchestrator.dart       # Human-vs-engine game loop:
│   │   │   │                                # Livebook, threefold-repetition detection,
│   │   │   │                                # time control, position count map
│   │   │   └── crossed_eval.dart            # CrossedEvalOrchestrator — multi-phase analysis:
│   │   │                                    # static eval, base eval, student move, master move;
│   │   │                                    # computes centerType, deltaK, spatial metrics;
│   │   │                                    # fully localised via AppLocalizations
│   │   │
│   │   ├── services/
│   │   │   ├── import_export_service.dart   # file_picker (PGN/EPD/FEN/TXT) +
│   │   │   │                                # Lichess game fetch by URL
│   │   │   └── shared_prefs_provider.dart   # Provider<SharedPreferences> — throws
│   │   │                                    # UnimplementedError if not overridden;
│   │   │                                    # always injected in main() via overrides[]
│   │   │
│   │   └── widgets/
│   │       └── setup_position_dialog.dart   # Shared: used by Analysis AND Play
│   │
│   ├── features/
│   │   │
│   │   ├── analysis/
│   │   │   ├── domain/
│   │   │   │   ├── engine_state.dart            # Immutable DTO:
│   │   │   │   │                                # isRunning, selectedEngine, EngineStats,
│   │   │   │   │                                # ShashinZone, outputLines + copyWith()
│   │   │   │   ├── engine_controller.dart       # StateNotifier<EngineState>:
│   │   │   │   │                                # startEngine() → loads UCI options from
│   │   │   │   │                                # SharedPreferences, sends setoption commands,
│   │   │   │   │                                # fires isready barrier, delegates to ShashinFsm;
│   │   │   │   │                                # setUciOption() for real-time option updates
│   │   │   │   ├── board_provider.dart          # Provider<ChessBoardController> — single
│   │   │   │   │                                # board instance shared across Analysis
│   │   │   │   ├── notation_controller.dart     # StateNotifier<NotationState>:
│   │   │   │   │                                # MoveNode tree (fen, san, parent, children[]);
│   │   │   │   │                                # addMove(), setCurrentNode(), goBack/Forward/
│   │   │   │   │                                # Start/End(), handleNewMove() with branching
│   │   │   │   │                                # dialog (Main / Variant / Overwrite / Cancel)
│   │   │   │   └── autoplay_controller.dart     # StateNotifier<AutoplayState>:
│   │   │   │                                    # full match lifecycle (start/stop/restart),
│   │   │   │                                    # score tracking (W/D/L + 0.5 for draws),
│   │   │   │                                    # colour reversal between rounds,
│   │   │   │                                    # saves each game to gauntlet_results.pgn
│   │   │   │
│   │   │   └── presentation/
│   │   │       ├── analysis_screen.dart         # Top-level ConsumerWidget — composes all panels
│   │   │       └── widgets/
│   │   │           ├── board_section.dart        # Interactive chessboard + move handler
│   │   │           ├── engine_controls.dart      # Start/stop, setup, autoplay, livebook,
│   │   │           │                             # coach, import/export action buttons
│   │   │           ├── analysis_panel.dart       # Shashin zone display + WDL bar
│   │   │           ├── notation_panel.dart       # Move tree renderer + navigation controls
│   │   │           ├── analysis_setup_modal.dart # Engine selector + time slider +
│   │   │           │                             # "Configure UCI" button → UciOptionsModal
│   │   │           ├── uci_options_modal.dart    # ConsumerStatefulWidget: probes engine
│   │   │           │                             # for all UCI options, renders dynamic form,
│   │   │           │                             # persists values to SharedPreferences
│   │   │           ├── autoplay_modal.dart       # Gauntlet setup: engines, TC, games, Livebook
│   │   │           ├── livebook_modal.dart       # Online opening book viewer
│   │   │           └── coach_modal.dart          # Crossed-eval coach panel
│   │   │
│   │   ├── play/
│   │   │   ├── domain/
│   │   │   │   └── play_controller.dart          # StateNotifier<PlayState>:
│   │   │   │                                     # engine, colour, TC, Livebook, limitStrength,
│   │   │   │                                     # eloValue; reads/writes sharedPrefsProvider;
│   │   │   │                                     # delegates game loop to PlayOrchestrator
│   │   │   └── presentation/
│   │   │       └── play_screen.dart              # ConsumerWidget — human vs engine UI
│   │   │
│   │   ├── settings/
│   │   │   └── presentation/
│   │   │       ├── settings_screen.dart          # Language switcher (IT/EN) dropdown,
│   │   │       │                                 # persists via SharedPreferences,
│   │   │       │                                 # triggers appLocale ValueNotifier
│   │   │       └── widgets/
│   │   │           └── about_dialog.dart         # App logo, version, credits dialog
│   │   │                                         # (localised via AppLocalizations)
│   │   │
│   │   └── navigation/
│   │       └── presentation/
│   │           └── main_navigation_screen.dart   # StatefulWidget with BottomNavigationBar:
│   │                                             # Analysis | Play | Settings
│   │                                             # + PlaceholderScreen for upcoming tabs
│   │
│   └── l10n/
│       ├── app_en.arb                            # English string keys
│       ├── app_it.arb                            # Italian string keys
│       ├── app_localizations.dart                # Generated base class
│       ├── app_localizations_en.dart             # Generated EN implementation
│       └── app_localizations_it.dart             # Generated IT implementation
│
├── test/                                         # Unit & widget tests
├── integration_test/                             # End-to-end device tests
│
├── analysis_options.yaml                         # Dart linter rules
├── l10n.yaml                                     # Localisation config (arb-dir, output-dir)
├── pubspec.yaml                                  # Dependencies, assets, icons, splash config
└── README.md
```

---

### 🔄 Layer Responsibilities

#### Presentation & Domain — `features/`

Each feature owns its state. The **Controller** (a Riverpod `StateNotifier`) is the single entry point for all user-initiated actions within that feature. It:

- Receives commands from the UI (`startEngine()`, `stopMatch()`, `handleNewMove()`)
- Delegates execution to the relevant Orchestrator in `core/`
- Listens to callbacks and updates the **immutable State object** via `copyWith()`
- Never touches platform APIs directly

**The Controller commands** — it decides *what* should happen and *when*.

#### Infrastructure — `core/orchestrators/`

Orchestrators manage the messy reality of native processes: spawning the engine, writing UCI commands to stdin, parsing stdout streams, handling timeouts and watchdog timers, and driving Finite State Machines. They:

- Know nothing about Flutter, Riverpod, or UI state
- Expose a clean callback-based API (`onLog`, `onZoneChanged`, `onStatsUpdate`, `onGameOver`, `onClockUpdate`)
- Are designed to be reusable across features (e.g. `AutoplayOrchestrator` is used from `features/analysis/`, `PlayOrchestrator` from `features/play/`)

**The Orchestrator executes** — it knows *how* to talk to the C++ engine.

---

### 🗄️ Persistence Architecture

All persistent user preferences flow through a single `SharedPreferences` instance injected at startup.

**Bootstrap sequence (`main.dart`):**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();   // load once at startup
  appLocale.value = Locale(prefs.getString('language') ?? 'it');  // restore language
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],  // inject globally
      child: const ShashGuiApp(),
    ),
  );
}
```

**Key naming conventions:**

| Key | Type | Description |
|---|---|---|
| `language` | `String` | Active UI language (`"it"` or `"en"`) |
| `{engineName}_{optionName}` | `String` | UCI option for a specific engine |

**UCI option apply sequence (`EngineController.startEngine`):**

```
1. initEngine()              → spawn process, load NNUE files
2. Read all prefs keys        → filter by "{engineName}_" prefix
3. sendCommand(setoption …)  → apply each persisted option
4. sendCommand(isready)      → synchronisation barrier
5. await 50 ms               → let engine digest options (e.g. MultiPV)
6. fsm.startAnalysis(fen)    → begin analysis
```

---

### 🧩 Widget Placement Policy

| Condition | Location |
|---|---|
| Widget used by **exactly one feature** | `features/<name>/presentation/widgets/` |
| Widget used by **two or more features** | `lib/core/widgets/` |

**Current state:**
- All Analysis widgets → `features/analysis/presentation/widgets/` ✅
- `AboutDialog` → `features/settings/presentation/widgets/` ✅ *(migrated from `core/widgets/`)*
- `SetupPositionDialog` → `lib/core/widgets/` ✅ *(shared: Analysis + Play)*

---

### 💬 Comment Policy

Non-obvious logic — FSM state transitions, guard conditions, throttle timers, WDL zone boundaries, `context.mounted` safety checks after `async` gaps — must carry inline comments or Dart doc comments (`///`).

Rule of thumb: **if you had to think for more than 30 seconds before writing a line, that line deserves a comment.**

---

## 🤝 Contributing

Pull requests are welcome. For significant architectural changes, please open an issue first to discuss the proposed direction. When in doubt, follow the Dependency Rule: **dependencies point inward, never outward**.

---

*ShashGui Mobile — making the engine speak human.*