import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:shared_preferences/shared_preferences.dart'; // ⚠️ AGGIUNGI QUESTO IMPORT!
import '../../../core/engine/engine_manager.dart';
import '../../../core/orchestrators/play_orchestrator.dart';
import '../../../core/services/shared_prefs_provider.dart';

final playBoardProvider = Provider<ChessBoardController>((ref) {
  return ChessBoardController();
});

class PlayState {
  final bool isPlaying;
  final String selectedEngine;
  final PlayerColor userColor;
  final String logMessage;

  final int tcType;
  final int baseTime;
  final int increment;

  // --- NUOVI PARAMETRI RECUPERATI ---
  final bool useLivebook;
  final bool limitStrength;
  final double eloValue;

  PlayState({
    this.isPlaying = false,
    this.selectedEngine = 'alexander',
    this.userColor = PlayerColor.white,
    this.logMessage = "Imposta la partita e premi Gioca",
    this.tcType = 1,
    this.baseTime = 3,
    this.increment = 0,
    this.useLivebook = true,
    this.limitStrength = false,
    this.eloValue = 1500,
  });

  PlayState copyWith({
    bool? isPlaying,
    String? selectedEngine,
    PlayerColor? userColor,
    String? logMessage,
    int? tcType,
    int? baseTime,
    int? increment,
    bool? useLivebook,
    bool? limitStrength,
    double? eloValue,
  }) {
    return PlayState(
      isPlaying: isPlaying ?? this.isPlaying,
      selectedEngine: selectedEngine ?? this.selectedEngine,
      userColor: userColor ?? this.userColor,
      logMessage: logMessage ?? this.logMessage,
      tcType: tcType ?? this.tcType,
      baseTime: baseTime ?? this.baseTime,
      increment: increment ?? this.increment,
      useLivebook: useLivebook ?? this.useLivebook,
      limitStrength: limitStrength ?? this.limitStrength,
      eloValue: eloValue ?? this.eloValue,
    );
  }
}

final playControllerProvider = StateNotifierProvider<PlayController, PlayState>(
  (ref) {
    return PlayController(ref);
  },
);

class PlayController extends StateNotifier<PlayState> {
  final Ref ref;
  final EngineManager _engineManager = EngineManager();
  PlayOrchestrator? _orchestrator;
  late final SharedPreferences _prefs; // Variabile per la memoria

  PlayController(this.ref) : super(PlayState()) {
    // Recuperiamo le preferenze istantaneamente grazie a Riverpod
    _prefs = ref.read(sharedPrefsProvider);
    _loadPreferences();
  }

  // --- CARICAMENTO MEMORIA ---
  void _loadPreferences() {
    state = state.copyWith(
      selectedEngine: _prefs.getString('play_engine') ?? 'alexander',
      tcType: _prefs.getInt('play_tcType') ?? 1,
      baseTime: _prefs.getInt('play_baseTime') ?? 3,
      increment: _prefs.getInt('play_increment') ?? 0,
      useLivebook: _prefs.getBool('play_useLivebook') ?? true,
      limitStrength: _prefs.getBool('play_limitStrength') ?? false,
      eloValue: _prefs.getDouble('play_eloValue') ?? 1500.0,
    );
  }

  // --- SETTER CON SALVATAGGIO IN MEMORIA ---
  void setUserColor(PlayerColor color) {
    // Non salviamo il colore, di solito l'utente lo sceglie al momento
    state = state.copyWith(userColor: color);
  }

  void setEngine(String engine) {
    _prefs.setString('play_engine', engine);
    state = state.copyWith(selectedEngine: engine);
  }

  void setTcType(int type) {
    _prefs.setInt('play_tcType', type);
    int newBaseTime = type == 0
        ? 5
        : 3; // Reset dei tempi di default in base alla cadenza
    _prefs.setInt('play_baseTime', newBaseTime);
    _prefs.setInt('play_increment', 0);
    state = state.copyWith(tcType: type, baseTime: newBaseTime, increment: 0);
  }

  void setBaseTime(int time) {
    _prefs.setInt('play_baseTime', time);
    state = state.copyWith(baseTime: time);
  }

  void setIncrement(int inc) {
    _prefs.setInt('play_increment', inc);
    state = state.copyWith(increment: inc);
  }

  void toggleLivebook(bool val) {
    _prefs.setBool('play_useLivebook', val);
    state = state.copyWith(useLivebook: val);
  }

  void toggleLimitStrength(bool val) {
    _prefs.setBool('play_limitStrength', val);
    state = state.copyWith(limitStrength: val);
  }

  void setEloValue(double val) {
    _prefs.setDouble('play_eloValue', val);
    state = state.copyWith(eloValue: val);
  }

  Future<void> startGame() async {
    state = state.copyWith(
      isPlaying: true,
      logMessage: "Avvio motore in corso...",
    );
    final boardCtrl = ref.read(playBoardProvider);
    boardCtrl.resetBoard();

    await _engineManager.initEngine(state.selectedEngine, [
      'nn-c288c895ea92.nnue',
      'nn-37f18f62d772.nnue',
    ]);

    // --- IMPOSTAZIONE ELO PER ALEXANDER ---
    if (state.selectedEngine == 'alexander') {
      if (state.limitStrength) {
        _engineManager.sendCommand(
          'setoption name UCI_LimitStrength value true',
        );
        _engineManager.sendCommand(
          'setoption name UCI_Elo value ${state.eloValue.toInt()}',
        );
      } else {
        _engineManager.sendCommand(
          'setoption name UCI_LimitStrength value false',
        );
      }
    }

    _orchestrator = PlayOrchestrator(
      engineManager: _engineManager,
      boardController: boardCtrl,
      onLog: (msg) => state = state.copyWith(logMessage: msg),
      onGameOver: (msg) => state = state.copyWith(
        isPlaying: false,
        logMessage: msg ?? "Partita Terminata!",
      ),
      useLivebook: state.useLivebook, // <--- ORA È DINAMICO!
      tcType: state.tcType,
      baseTimeMs: state.tcType == 0
          ? (state.baseTime * 60 * 1000)
          : (state.baseTime * 1000),
      incMs: state.increment * 1000,
    );

    _orchestrator!.startGame();

    if (state.userColor == PlayerColor.black) {
      _orchestrator!.playCycle();
    }
  }

  void onUserMove() {
    if (state.isPlaying) _orchestrator?.playCycle();
  }

  void stopGame() {
    _orchestrator?.stop();
    _engineManager.sendCommand('stop');
    state = state.copyWith(isPlaying: false, logMessage: "Partita interrotta.");
  }

  @override
  void dispose() {
    _orchestrator?.dispose();
    _engineManager.dispose();
    super.dispose();
  }
}
