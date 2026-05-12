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
- **Dual Engine Support (C++ via Dart FFI):** Native support for **Alexander (HCE)** to simulate human-like weaknesses, and **ShashChess (NNUE)** for absolute mathematical truth. Both compiled for ARM64 and invoked through Dart FFI / Platform Channels.
- **Single-Game Cross-Analysis:** Place both engines on the same position and compare their assessments side by side. Divergences between Alexander and ShashChess are the most instructive moments in any training session.
- **PGN / FEN Import & Export:** Load games from file, paste raw FEN strings, or export annotated analysis sessions. All I/O is handled by a dedicated `ImportExportService`, cleanly decoupled from the UI layer.
- **Livebook Integration:** Query the online opening book in real time to contextualise any position within known theory before diving into engine analysis.

---

## ☁️ Cloud Ecosystem (Premium)

ShashGui Mobile acts as the gateway to a high-performance Cloud infrastructure that unlocks **Data Science** and **Explainable AI (XAI)** features impossible to run on a mobile device alone.

- **ChessBeauty (Qualimetry):** Measures the *aesthetic* and *strategic* quality of a game along three axes — Audacity, Harmony, and Depth. Goes beyond accuracy percentage to capture how *beautiful* the play actually was.
- **Nugget Extraction:** Automatically scans PGN archives to surface tactical and strategic gems — positions of exceptional instructional value. Stop scrolling through hundreds of games manually; let the engine find the gold for you.
- **Divergence Dossier (XAI):** The most advanced feature in the ecosystem. The Dossier identifies positions where **human dogma systematically fails** against neural understanding — not just one blunder in one game, but recurring patterns across an entire opening repertoire or playing style.

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| **Mobile Frontend** | Flutter / Dart |
| **Local Engines** | C++ (ARM64), Dart FFI & Platform Channels |
| **State Management** | Riverpod (`StateNotifier` / `ConsumerWidget`) |
| **Backend / Cloud** | Python, SQLite, AWS / GCP *(external to this repo)* |
| **Localisation** | Flutter `l10n` (English & Italian) |

---

## 📝 Licence

This project includes and interfaces with the **ShashChess** and **Alexander** chess engines, both derived from the open-source [Stockfish](https://stockfishchess.org/) project. In accordance with Stockfish's licence terms, this application is released under the **GNU General Public Licence v3.0**.

See the [`LICENSE`](./LICENSE) file for full details.

---

## ⚙️ Getting Started

### Prerequisites

Before running ShashGui Mobile, ensure the following tools are installed on your development machine.

#### 1. Flutter SDK

The project requires **Flutter 3.22 or later** (Dart 3.4+).

```bash
# macOS / Linux — clone the stable channel
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Verify installation and check for missing dependencies
flutter doctor
```

> On **Windows**, download the Flutter SDK zip from [flutter.dev](https://docs.flutter.dev/get-started/install/windows) and add the `flutter\bin` folder to your `PATH` environment variable.

`flutter doctor` will report any missing dependencies. Address each warning before proceeding.

#### 2. Android Toolchain (for Android builds)

- Install **Android Studio** from [developer.android.com](https://developer.android.com/studio)
- Open Android Studio → SDK Manager → install **Android SDK**, **Android SDK Command-line Tools**, and **Android SDK Build-Tools 34+**
- Accept all SDK licences:

```bash
flutter doctor --android-licenses
```

#### 3. Xcode (for iOS builds — macOS only)

```bash
# Install Xcode from the Mac App Store, then run:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Install CocoaPods (required for iOS native dependencies):

```bash
sudo gem install cocoapods
```

#### 4. Android NDK — Native C++ Engine Support

The local chess engines are precompiled C++ shared libraries (`.so`). The **Android NDK** is required to link them correctly at build time.

In Android Studio: **SDK Manager → SDK Tools → NDK (Side by side) → Apply**.

Or via the command line:

```bash
sdkmanager "ndk;27.0.12077973"
```

Set the environment variable in your shell profile:

```bash
export ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/27.0.12077973"
```

---

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-org/shashgui_mobile.git
cd shashgui_mobile

# 2. Install all Dart / Flutter dependencies declared in pubspec.yaml
flutter pub get

# 3. (iOS only) Install CocoaPods native dependencies
cd ios && pod install && cd ..
```

---

## 🧰 Common Flutter Commands

### Running the App

```bash
# List all connected devices and emulators
flutter devices

# Run the app in debug mode on the default connected device
flutter run

# Run on a specific device by ID
flutter run -d <device-id>

# Run in release mode directly (no debugger, full performance)
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

### Code Generation

Some packages (Riverpod generators, Freezed, `json_serializable`) require a build step:

```bash
# Run once — regenerate all generated files
dart run build_runner build --delete-conflicting-outputs

# Watch mode — regenerate automatically on file changes during development
dart run build_runner watch --delete-conflicting-outputs
```

### Localisation

```bash
# Regenerate Dart localisation classes from .arb files
flutter gen-l10n
```

### Cleaning

```bash
# Remove all build artefacts and caches
flutter clean

# Always re-fetch dependencies after a clean
flutter pub get
```

> **When to run `flutter clean`:** whenever you change native code, update the Flutter SDK, pull a branch with modified `pubspec.yaml`, or encounter unexplained build failures. It is slow, but almost always the right first step when something strange happens.

### Testing

```bash
# Run all unit and widget tests
flutter test

# Run tests with a coverage report
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

# Check formatting without modifying files (useful in CI pipelines)
dart format --output=none --set-exit-if-changed .
```

### Building Releases

#### Android

```bash
# Release APK — single file, larger (useful for direct side-loading)
flutter build apk --release

# Release APKs split by ABI — smaller download per device (recommended for direct distribution)
flutter build apk --release --split-per-abi

# Release App Bundle — required for Google Play Store submission
flutter build appbundle --release
```

Output paths:
- APK → `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle → `build/app/outputs/bundle/release/app-release.aab`

> **Signing:** configure your keystore in `android/key.properties` and reference it in `android/app/build.gradle` before publishing to the Play Store. **Never commit `key.properties` or `.jks` files to version control.** Add them to `.gitignore`.

#### iOS

```bash
# Build a release iOS app (requires a valid Apple Developer certificate)
flutter build ios --release

# Build without code signing (for CI or simulator testing)
flutter build ios --release --no-codesign
```

For App Store submission, open `ios/Runner.xcworkspace` in Xcode, select the **Runner** target, configure your provisioning profile, and use **Product → Archive**.

---

## 🏗️ Code Architecture (`lib/`)

The codebase was re-engineered from a single-file monolith (`main.dart`, ~128 KB) into a layered, feature-sliced architecture following **Clean Architecture** principles.

### 📐 The Dependency Rule

> *"Source code dependencies must point only inward, toward higher-level policies."*
> — Robert C. Martin

Commands flow inward; knowledge never leaks outward:

```
UI (Widget) ──► Controller (Riverpod) ──► Orchestrator (Core / Native C++)
```

No layer knows about the layer above it. The UI knows Controllers. Controllers know Orchestrators. Orchestrators know only engines and platform APIs — never Flutter widgets or Riverpod state.

---

### 📁 Directory Structure

```
shashgui_mobile/
│
├── android/                              # Android native project
│   └── app/
│       ├── src/main/
│       │   └── jniLibs/arm64-v8a/        # Compiled C++ engine .so libraries
│       └── build.gradle
│
├── ios/                                  # iOS native project
│   ├── Runner/
│   └── Podfile
│
├── lib/                                  # All Dart application code
│   │
│   ├── main.dart                         # Bootstrap only — ProviderScope + MaterialApp
│   │
│   ├── core/                             # Shared infrastructure (feature-agnostic)
│   │   ├── engine/
│   │   │   └── engine_manager.dart           # Low-level engine process lifecycle
│   │   ├── logic/
│   │   │   ├── shashin_logic.dart            # Shashin zone computation (pure Dart, no Flutter)
│   │   │   ├── livebook_oracle.dart          # Online opening book queries
│   │   │   └── livebook_scanner.dart         # Local opening book scanning
│   │   ├── orchestrators/
│   │   │   ├── shashin_fsm.dart              # FSM: idle → analysing → phase1 → phase2
│   │   │   ├── autoplay_orchestrator.dart    # Drives autoplay sessions
│   │   │   ├── play_orchestrator.dart        # Drives human-vs-engine games
│   │   │   └── crossed_eval.dart             # Dual-engine cross-analysis logic
│   │   ├── services/
│   │   │   └── import_export_service.dart    # PGN / FEN file I/O
│   │   └── widgets/                          # Shared widgets (used by 2+ features)
│   │       ├── about_dialog.dart             # ⚠️ Candidate → features/settings/
│   │       └── setup_position_dialog.dart    # Shared: Analysis + Play
│   │
│   ├── features/                         # Vertical feature slices
│   │   ├── analysis/
│   │   │   ├── domain/                       # Business logic — zero Flutter widgets here
│   │   │   │   ├── engine_controller.dart        # StateNotifier: engine lifecycle
│   │   │   │   ├── engine_state.dart             # Immutable state DTO
│   │   │   │   ├── board_provider.dart           # Board position & move history
│   │   │   │   ├── notation_controller.dart      # PGN notation management
│   │   │   │   └── autoplay_controller.dart      # Autoplay session management
│   │   │   └── presentation/
│   │   │       ├── analysis_screen.dart          # Top-level ConsumerWidget
│   │   │       └── widgets/
│   │   │           ├── board_section.dart
│   │   │           ├── engine_controls.dart
│   │   │           ├── analysis_panel.dart
│   │   │           ├── notation_panel.dart
│   │   │           ├── analysis_setup_modal.dart
│   │   │           ├── autoplay_modal.dart
│   │   │           ├── livebook_modal.dart
│   │   │           └── coach_modal.dart
│   │   ├── play/
│   │   │   ├── domain/
│   │   │   │   └── play_controller.dart
│   │   │   └── presentation/
│   │   │       └── play_screen.dart
│   │   ├── settings/
│   │   │   └── presentation/
│   │   │       └── settings_screen.dart
│   │   └── navigation/
│   │       └── presentation/
│   │           └── main_navigation_screen.dart
│   │
│   └── l10n/                             # Localisation (EN + IT)
│       ├── app_en.arb
│       ├── app_it.arb
│       ├── app_localizations.dart
│       ├── app_localizations_en.dart
│       └── app_localizations_it.dart
│
├── test/                                 # Unit & widget tests
│   ├── unit/
│   └── widget/
│
├── integration_test/                     # End-to-end tests on real devices
│
├── assets/                               # Static assets bundled with the app
│   ├── pieces/                           # Chess piece SVGs
│   ├── sounds/                           # Move / capture audio
│   └── books/                            # Bundled opening book files
│
├── analysis_options.yaml                 # Dart linter rules
├── pubspec.yaml                          # Dependencies & project metadata
└── README.md
```

---

### 🔄 Layer Responsibilities

#### Presentation & Domain — `features/`

Each feature owns its state. The **Controller** (a Riverpod `StateNotifier`) is the entry point for all user-initiated actions within that feature. It:

- Receives commands from the UI (`startAnalysis()`, `stopEngine()`, `loadPgn()`)
- Delegates execution to the relevant Orchestrator in `core/`
- Listens to callbacks and **updates the immutable State object**
- Never touches platform APIs or engine processes directly

**The Controller commands** — it decides *what* should happen and *when*.

#### Infrastructure — `core/orchestrators/`

Orchestrators manage the messy reality of native processes: spawning engine subprocesses, writing UCI commands, parsing stdout streams, handling timeouts, and driving Finite State Machines. They:

- Know nothing about Flutter, Riverpod, or UI state
- Expose a clean callback-based API to their callers
- Can be reused across multiple features (e.g. `PlayOrchestrator` serves both `play/` and `analysis/`)

**The Orchestrator executes** — it knows *how* to talk to the C++ engine.

> **Future evolution:** if an orchestrator ends up serving only one feature, it can be migrated inside `features/<name>/domain/` without breaking anything else. The Clean Architecture boundary makes this refactor mechanical and safe.

---

### 🧩 Widget Placement Policy

A simple, enforceable rule governs where every widget lives:

| Condition | Location |
|---|---|
| Widget used by **exactly one feature** | `features/<name>/presentation/widgets/` |
| Widget used by **two or more features** | `lib/core/widgets/` (Shared Widget) |

**Examples in this project:**
- `BoardSection`, `EngineControls`, `NotationPanel` → `features/analysis/presentation/widgets/` ✅
- `SetupPositionDialog` → `lib/core/widgets/` (used by both Analysis and Play) ✅
- `AboutDialog` → currently in `core/widgets/`, candidate to move to `features/settings/presentation/widgets/` if Settings is its only consumer

---

### 💬 Comment Policy

A Finite State Machine (`ShashinFsm`) is non-trivial by nature. All non-obvious logic — state transitions, guard conditions, throttle timers, WDL mapping heuristics — must carry **explanatory comments** or Dart doc comments (`///`). Code that was clear at 2 AM during a refactor sprint will not be clear to a fresh reader six months later.

Rule of thumb: **if you had to think for more than 30 seconds before writing a line, that line deserves a comment.**

---

## 🤝 Contributing

Pull requests are welcome. For significant architectural changes, please open an issue first to discuss the proposed direction. When in doubt, follow the Dependency Rule: **dependencies point inward, never outward**.

---

*ShashGui Mobile — making the engine speak human.*