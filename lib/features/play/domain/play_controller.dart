import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../../../l10n/app_localizations.dart';
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

  final bool useLivebook;
  final bool limitStrength;
  final double eloValue;
  final bool useCurrentPosition;

  final int whiteTime;
  final int blackTime;

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
    this.useCurrentPosition = false,
    this.whiteTime = 0,
    this.blackTime = 0,
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
    bool? useCurrentPosition,
    int? whiteTime,
    int? blackTime,
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
      useCurrentPosition: useCurrentPosition ?? this.useCurrentPosition,
      whiteTime: whiteTime ?? this.whiteTime,
      blackTime: blackTime ?? this.blackTime,
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
  late final SharedPreferences _prefs;

  PlayController(this.ref) : super(PlayState()) {
    _prefs = ref.read(sharedPrefsProvider);
    _loadPreferences();
  }

  void _loadPreferences() {
    state = state.copyWith(
      selectedEngine: _prefs.getString('play_engine') ?? 'alexander',
      tcType: _prefs.getInt('play_tcType') ?? 1,
      baseTime: _prefs.getInt('play_baseTime') ?? 3,
      increment: _prefs.getInt('play_increment') ?? 0,
      useLivebook: _prefs.getBool('play_useLivebook') ?? true,
      limitStrength: _prefs.getBool('play_limitStrength') ?? false,
      eloValue: _prefs.getDouble('play_eloValue') ?? 1500.0,
      useCurrentPosition: _prefs.getBool('play_useCurrentPosition') ?? false,
    );
  }

  void setUserColor(PlayerColor color) {
    state = state.copyWith(userColor: color);
  }

  void setEngine(String engine) {
    _prefs.setString('play_engine', engine);
    state = state.copyWith(selectedEngine: engine);
  }

  void setTcType(int type) {
    _prefs.setInt('play_tcType', type);
    int newBaseTime = type == 0 ? 5 : 3;
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

  void toggleUseCurrentPosition(bool val) {
    _prefs.setBool('play_useCurrentPosition', val);
    state = state.copyWith(useCurrentPosition: val);
  }

  Future<void> startGame(AppLocalizations loc) async {
    bool isIt = loc.localeName == 'it';
    state = state.copyWith(
      isPlaying: true,
      logMessage: isIt ? "Avvio motore in corso..." : "Starting engine...",
      whiteTime: state.tcType == 0
          ? state.baseTime * 60 * 1000
          : state.baseTime * 1000,
      blackTime: state.tcType == 0
          ? state.baseTime * 60 * 1000
          : state.baseTime * 1000,
    );

    final boardCtrl = ref.read(playBoardProvider);
    if (!state.useCurrentPosition) {
      boardCtrl.resetBoard();
    }

    await _engineManager.initEngine(state.selectedEngine, [
      'nn-c288c895ea92.nnue',
      'nn-37f18f62d772.nnue',
    ]);

    if (state.selectedEngine == 'alexander') {
      if (state.limitStrength) {
        _engineManager.sendCommand(
          'setoption name UCI_LimitStrength value true',
        );
        _engineManager.sendCommand(
          'setoption name UCI_Elo value ${state.eloValue.toInt()}',
        );
        _engineManager.sendCommand(
          'setoption name Simulate human blunders value true',
        );
      } else {
        _engineManager.sendCommand(
          'setoption name UCI_LimitStrength value false',
        );
        _engineManager.sendCommand(
          'setoption name Simulate human blunders value false',
        );
      }
    }

    _engineManager.sendCommand('isready');
    await Future.delayed(const Duration(milliseconds: 100));

    _orchestrator = PlayOrchestrator(
      engineManager: _engineManager,
      boardController: boardCtrl,
      engineName: state.selectedEngine,
      onLog: (msg) => state = state.copyWith(logMessage: msg),
      onGameOver: (msg) => state = state.copyWith(
        isPlaying: false,
        logMessage: msg ?? (isIt ? "Partita Terminata!" : "Game Over!"),
      ),
      onClockUpdate: (w, b) =>
          state = state.copyWith(whiteTime: w, blackTime: b),
      loc: loc,
      useLivebook: state.useLivebook,
      tcType: state.tcType,
      baseTimeMs: state.tcType == 0
          ? (state.baseTime * 60 * 1000)
          : (state.baseTime * 1000),
      incMs: state.increment * 1000,
    );

    _orchestrator!.startGame();

    final fen = boardCtrl.getFen();
    final isWhiteTurn = fen.split(' ')[1] == 'w';
    final isEngineTurn =
        (state.userColor == PlayerColor.white && !isWhiteTurn) ||
        (state.userColor == PlayerColor.black && isWhiteTurn);

    if (isEngineTurn) {
      _orchestrator!.playCycle();
    }
  }

  void onUserMove() {
    if (state.isPlaying) _orchestrator?.registerUserMove();
  }

  // --- ABBANDONA LA PARTITA ---
  void resignGame(AppLocalizations loc) {
    if (!state.isPlaying) return;
    _orchestrator?.stop();
    _engineManager.sendCommand('stop');
    bool isWhiteUser = state.userColor == PlayerColor.white;
    bool isIt = loc.localeName == 'it';
    String winner = isWhiteUser
        ? (isIt
              ? "0-1 (Vince il computer per Abbandono)"
              : "0-1 (Computer wins by Resignation)")
        : (isIt
              ? "1-0 (Vince il computer per Abbandono)"
              : "1-0 (Computer wins by Resignation)");

    state = state.copyWith(isPlaying: false, logMessage: winner);
  }

  // --- OFFRI PATTA (CON LOGICA DECISIONALE DEL MOTORE) ---
  void offerDraw(AppLocalizations loc) {
    if (!state.isPlaying) return;

    bool isIt = loc.localeName == 'it';
    final fen = ref.read(playBoardProvider).getFen();

    // 1. Calcolo rapido del bilancio materiale dalla FEN
    int materialScore = 0;
    final pieces = fen.split(' ')[0];
    for (int i = 0; i < pieces.length; i++) {
      switch (pieces[i]) {
        case 'Q':
          materialScore += 9;
          break;
        case 'R':
          materialScore += 5;
          break;
        case 'B':
          materialScore += 3;
          break;
        case 'N':
          materialScore += 3;
          break;
        case 'P':
          materialScore += 1;
          break;
        case 'q':
          materialScore -= 9;
          break;
        case 'r':
          materialScore -= 5;
          break;
        case 'b':
          materialScore -= 3;
          break;
        case 'n':
          materialScore -= 3;
          break;
        case 'p':
          materialScore -= 1;
          break;
      }
    }

    // Se l'utente è bianco, il vantaggio del motore si calcola invertendo il segno
    bool isUserWhite = state.userColor == PlayerColor.white;
    int engineAdvantage = isUserWhite ? -materialScore : materialScore;

    // 2. Il motore prende la sua decisione
    bool acceptDraw = false;

    if (engineAdvantage > 0) {
      // Il motore sta vincendo: RIFIUTA SEMPRE
      acceptDraw = false;
    } else if (engineAdvantage < 0) {
      // Il motore sta perdendo: ACCETTA SEMPRE
      acceptDraw = true;
    } else {
      // Parità materiale perfetta: Accetta al 50%
      acceptDraw = DateTime.now().millisecond % 2 == 0;
    }

    // 3. Risoluzione della proposta
    if (acceptDraw) {
      _orchestrator?.stop();
      _engineManager.sendCommand('stop');
      state = state.copyWith(
        isPlaying: false,
        logMessage: isIt
            ? "1/2-1/2 (Patta concordata)"
            : "1/2-1/2 (Draw agreed)",
      );
    } else {
      // Il motore rifiuta e te lo dice in faccia
      state = state.copyWith(
        logMessage: isIt
            ? "❌ Proposta rifiutata. Il motore continua!"
            : "❌ Draw declined. Engine plays on!",
      );

      // Dopo 2.5 secondi, il messaggio di rifiuto svanisce
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && state.isPlaying) {
          state = state.copyWith(
            logMessage: isIt ? "Tocca a te..." : "Your turn...",
          );
        }
      });
    }
  }

  void stopGame() {
    _orchestrator?.stop();
    _engineManager.sendCommand('stop');
    bool isIt = appLocale.value.languageCode == 'it';
    state = state.copyWith(
      isPlaying: false,
      logMessage: isIt ? "Partita interrotta." : "Game interrupted.",
    );
  }

  @override
  void dispose() {
    _orchestrator?.dispose();
    _engineManager.dispose();
    super.dispose();
  }
}
