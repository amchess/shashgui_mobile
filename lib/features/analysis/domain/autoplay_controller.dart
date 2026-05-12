import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/engine/engine_manager.dart';
import '../../../core/orchestrators/autoplay_orchestrator.dart';
import '../../../core/orchestrators/shashin_fsm.dart';
import '../../../core/logic/shashin_logic.dart';
import 'board_provider.dart';
import 'engine_controller.dart';
import 'notation_controller.dart';

class AutoplayState {
  final bool isPlaying;
  final String whiteEngine;
  final String blackEngine;
  final bool whiteLivebook;
  final bool blackLivebook;
  final int tcType;
  final int baseTime;
  final int increment;

  final int totalGames;
  final int currentGame;
  final double scoreWhite;
  final double scoreBlack;
  final int draws;

  final bool useCurrentPosition;
  final bool reverseColors;
  final String savedStartingFen;

  final ShashinZone zone;
  final EngineStats stats;
  final String currentLog;
  final int whiteTime;
  final int blackTime;

  AutoplayState({
    this.isPlaying = false,
    this.whiteEngine = 'shashchess',
    this.blackEngine = 'alexander',
    this.whiteLivebook = true,
    this.blackLivebook = true,
    this.tcType = 1,
    this.baseTime = 2,
    this.increment = 1,
    this.totalGames = 1,
    this.currentGame = 1,
    this.scoreWhite = 0.0,
    this.scoreBlack = 0.0,
    this.draws = 0,
    this.useCurrentPosition = false,
    this.reverseColors = true,
    this.savedStartingFen =
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    ShashinZone? zone,
    this.stats = const EngineStats(),
    this.currentLog = "",
    this.whiteTime = 0,
    this.blackTime = 0,
  }) : zone =
           zone ??
           ShashinZone("In attesa...", "⚔️", Colors.purple, 50.0, [
             "assets/images/capablanca.png",
           ]);

  AutoplayState copyWith({
    bool? isPlaying,
    String? whiteEngine,
    String? blackEngine,
    bool? whiteLivebook,
    bool? blackLivebook,
    int? tcType,
    int? baseTime,
    int? increment,
    int? totalGames,
    int? currentGame,
    double? scoreWhite,
    double? scoreBlack,
    int? draws,
    bool? useCurrentPosition,
    bool? reverseColors,
    String? savedStartingFen,
    ShashinZone? zone,
    EngineStats? stats,
    String? currentLog,
    int? whiteTime,
    int? blackTime,
  }) {
    return AutoplayState(
      isPlaying: isPlaying ?? this.isPlaying,
      whiteEngine: whiteEngine ?? this.whiteEngine,
      blackEngine: blackEngine ?? this.blackEngine,
      whiteLivebook: whiteLivebook ?? this.whiteLivebook,
      blackLivebook: blackLivebook ?? this.blackLivebook,
      tcType: tcType ?? this.tcType,
      baseTime: baseTime ?? this.baseTime,
      increment: increment ?? this.increment,
      totalGames: totalGames ?? this.totalGames,
      currentGame: currentGame ?? this.currentGame,
      scoreWhite: scoreWhite ?? this.scoreWhite,
      scoreBlack: scoreBlack ?? this.scoreBlack,
      draws: draws ?? this.draws,
      useCurrentPosition: useCurrentPosition ?? this.useCurrentPosition,
      reverseColors: reverseColors ?? this.reverseColors,
      savedStartingFen: savedStartingFen ?? this.savedStartingFen,
      zone: zone ?? this.zone,
      stats: stats ?? this.stats,
      currentLog: currentLog ?? this.currentLog,
      whiteTime: whiteTime ?? this.whiteTime,
      blackTime: blackTime ?? this.blackTime,
    );
  }
}

final autoplayControllerProvider =
    StateNotifierProvider<AutoplayController, AutoplayState>(
      (ref) => AutoplayController(ref),
    );

class AutoplayController extends StateNotifier<AutoplayState> {
  final Ref ref;
  EngineManager? _whiteManager;
  EngineManager? _blackManager;
  AutoplayOrchestrator? _orchestrator;

  AutoplayController(this.ref) : super(AutoplayState());

  void setWhiteEngine(String e) => state = state.copyWith(whiteEngine: e);
  void setBlackEngine(String e) => state = state.copyWith(blackEngine: e);
  void setWhiteLivebook(bool v) => state = state.copyWith(whiteLivebook: v);
  void setBlackLivebook(bool v) => state = state.copyWith(blackLivebook: v);
  void setTotalGames(int n) => state = state.copyWith(totalGames: n);
  void setTcType(int t) =>
      state = state.copyWith(tcType: t, baseTime: t == 0 ? 3 : 2);
  void setBaseTime(int t) => state = state.copyWith(baseTime: t);
  void setIncrement(int i) => state = state.copyWith(increment: i);

  void setUseCurrentPosition(bool v) =>
      state = state.copyWith(useCurrentPosition: v);
  void setReverseColors(bool v) => state = state.copyWith(reverseColors: v);

  Future<void> startMatch(
    BuildContext context, {
    bool isRestart = false,
  }) async {
    final boardCtrl = ref.read(boardControllerProvider);

    if (!isRestart) {
      // ⚠️ FIX: Aggiunte le graffe
      if (ref.read(engineControllerProvider).isRunning) {
        ref.read(engineControllerProvider.notifier).stopEngine();
      }

      String fenToUse = state.useCurrentPosition
          ? boardCtrl.getFen()
          : "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

      state = state.copyWith(
        currentGame: 1,
        scoreWhite: 0,
        scoreBlack: 0,
        draws: 0,
        isPlaying: true,
        savedStartingFen: fenToUse,
      );
    }

    state = state.copyWith(
      currentLog:
          "Round ${state.currentGame}/${state.totalGames}: Avvio motori...",
      whiteTime: state.tcType == 0
          ? state.baseTime * 60 * 1000
          : state.baseTime * 1000,
      blackTime: state.tcType == 0
          ? state.baseTime * 60 * 1000
          : state.baseTime * 1000,
    );

    boardCtrl.loadFen(state.savedStartingFen);

    // ⚠️ Azzera la notazione se iniziamo una nuova partita dalla posizione base
    if (state.savedStartingFen ==
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") {
      ref.read(notationControllerProvider.notifier).goToStart();
    }

    _whiteManager?.dispose();
    _blackManager?.dispose();
    _whiteManager = EngineManager();
    _blackManager = EngineManager();

    await _whiteManager!.initEngine(state.whiteEngine, [
      'nn-c288c895ea92.nnue',
      'nn-37f18f62d772.nnue',
    ]);
    await _blackManager!.initEngine(state.blackEngine, [
      'nn-c288c895ea92.nnue',
      'nn-37f18f62d772.nnue',
    ]);

    _orchestrator = AutoplayOrchestrator(
      whiteEngine: _whiteManager!,
      blackEngine: _blackManager!,
      whiteEngineName: state.whiteEngine,
      blackEngineName: state.blackEngine,
      boardController: boardCtrl,
      whiteUseLivebook: state.whiteLivebook,
      blackUseLivebook: state.blackLivebook,
      tcType: state.tcType,
      baseTimeMs: state.tcType == 0
          ? (state.baseTime * 60 * 1000)
          : (state.baseTime * 1000),
      incMs: state.increment * 1000,
      onLog: (log) =>
          state = state.copyWith(currentLog: "R${state.currentGame}: $log"),
      onZoneChanged: (nz) => state = state.copyWith(zone: nz),
      onStatsUpdate: (ns) => state = state.copyWith(stats: ns),
      onClockUpdate: (w, b) =>
          state = state.copyWith(whiteTime: w, blackTime: b),

      // ⚠️ RICEVIAMO LA MOSSA E LA STAMPIAMO SULLA UI!
      onMovePlayed: (san, fen) {
        ref.read(notationControllerProvider.notifier).addMove(san, fen, 'main');
      },

      onGameOver: (res) => _handleEndOfGame(context, res),
    );

    _orchestrator!.startMatch();
  }

  void _handleEndOfGame(BuildContext context, String? result) async {
    // Salvataggio Database (operazione asincrona che richiede tempo)
    await _saveMatchToDatabase(result);

    // ⚠️ FIX: Controllo di sicurezza "mounted" dopo l'await!
    // Assicura che la schermata non sia stata chiusa mentre salvavamo il file.
    if (!context.mounted) {
      return;
    }

    // ⚠️ FIX: Aggiunte le graffe a tutta la catena if/else if/else
    if (result!.contains("1-0")) {
      state = state.copyWith(scoreWhite: state.scoreWhite + 1);
    } else if (result.contains("0-1")) {
      state = state.copyWith(scoreBlack: state.scoreBlack + 1);
    } else {
      state = state.copyWith(
        draws: state.draws + 1,
        scoreWhite: state.scoreWhite + 0.5,
        scoreBlack: state.scoreBlack + 0.5,
      );
    }

    if (state.currentGame < state.totalGames) {
      if (state.reverseColors) {
        state = state.copyWith(
          currentGame: state.currentGame + 1,
          whiteEngine: state.blackEngine,
          blackEngine: state.whiteEngine,
          whiteLivebook: state.blackLivebook,
          blackLivebook: state.whiteLivebook,
        );
      } else {
        state = state.copyWith(currentGame: state.currentGame + 1);
      }

      onLog("🔄 Preparazione Round ${state.currentGame}...");

      // ⚠️ FIX: Aggiunto un ulteriore controllo context.mounted prima di riavviare
      Future.delayed(const Duration(seconds: 3), () {
        if (context.mounted) {
          startMatch(context, isRestart: true);
        }
      });
    } else {
      state = state.copyWith(
        isPlaying: false,
        currentLog: "🏆 Torneo Concluso!",
      );
      _whiteManager?.dispose();
      _blackManager?.dispose();
    }
  }

  Future<void> _saveMatchToDatabase(String? result) async {
    try {
      final pgn = ref.read(boardControllerProvider).game.pgn();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/gauntlet_results.pgn');

      String header = '[Event "Gauntlet Mobile Round ${state.currentGame}"]\n';
      header +=
          '[White "${state.whiteEngine}"]\n[Black "${state.blackEngine}"]\n';

      if (state.savedStartingFen !=
          "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") {
        header += '[FEN "${state.savedStartingFen}"]\n[SetUp "1"]\n';
      }
      header += '[Result "$result"]\n\n';

      await file.writeAsString(
        "$header$pgn\n\n",
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint("Errore salvataggio database: $e");
    }
  }

  void stopMatch() {
    _orchestrator?.stop();
    _whiteManager?.dispose();
    _blackManager?.dispose();
    _whiteManager = null;
    _blackManager = null;
    state = state.copyWith(isPlaying: false, currentLog: "Match interrotto.");
  }

  void onLog(String msg) => state = state.copyWith(currentLog: msg);

  @override
  void dispose() {
    _orchestrator?.dispose();
    _whiteManager?.dispose();
    _blackManager?.dispose();
    super.dispose();
  }
}
