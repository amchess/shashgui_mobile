import 'dart:async';
import 'dart:math';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../engine/engine_manager.dart';
import '../logic/livebook_scanner.dart';

class AutoplayOrchestrator {
  final EngineManager whiteEngine;
  final EngineManager blackEngine;
  final ChessBoardController boardController;
  final Function(String) onLog;
  final Function(String?) onGameOver;

  final bool whiteUseLivebook;
  final bool blackUseLivebook;

  final int tcType; // 0 = Fischer, 1 = Fisso
  final int baseTimeMs;
  final int incMs;

  int _wtime = 0;
  int _btime = 0;
  DateTime? _lastEngineStart;

  StreamSubscription<String>? _whiteSub;
  StreamSubscription<String>? _blackSub;

  bool _isEngineThinking = false;
  bool _whiteOutOfBook = false;
  bool _blackOutOfBook = false;
  bool _isRunning = false;

  AutoplayOrchestrator({
    required this.whiteEngine,
    required this.blackEngine,
    required this.boardController,
    required this.onLog,
    required this.onGameOver,
    required this.whiteUseLivebook,
    required this.blackUseLivebook,
    this.tcType = 1,
    this.baseTimeMs = 3000,
    this.incMs = 0,
  }) {
    if (tcType == 0) {
      _wtime = baseTimeMs;
      _btime = baseTimeMs;
    }
  }

  void startMatch() {
    _isRunning = true;
    _whiteOutOfBook = !whiteUseLivebook;
    _blackOutOfBook = !blackUseLivebook;
    onLog("⚔️ AUTOPLAY INIZIATO! Buona visione.");

    // Mettiamoci in ascolto di entrambi i motori
    _whiteSub = whiteEngine.engineOutput?.listen(
      (line) => _handleEngineOutput(line, PlayerColor.white),
    );
    _blackSub = blackEngine.engineOutput?.listen(
      (line) => _handleEngineOutput(line, PlayerColor.black),
    );

    playNextTurn();
  }

  void playNextTurn() async {
    if (!_isRunning || _isEngineThinking) return;
    if (_checkStatus()) return;

    _isEngineThinking = true;
    bool isWhiteTurn = boardController.getFen().split(' ')[1] == 'w';
    EngineManager activeEngine = isWhiteTurn ? whiteEngine : blackEngine;
    bool outOfBook = isWhiteTurn ? _whiteOutOfBook : _blackOutOfBook;

    String colorName = isWhiteTurn ? "Bianco" : "Nero";

    // --- ORACOLO LIVEBOOK ---
    if (!outOfBook) {
      try {
        bool isNeural =
            true; // In mobile usiamo il parametro per capire se interrogare ChessDB o Lichess
        var result = await LiveBookScanner.scan(
          boardController.getFen(),
          [],
          isNeural,
        );
        String? chosenUci = _applyOracleRoulette(result.moves);

        if (chosenUci != null) {
          onLog("📖 Il $colorName gioca dal LiveBook!");
          _executeMoveOnBoard(chosenUci);
          return;
        } else {
          onLog("📉 Livebook esaurito per il $colorName.");
          if (isWhiteTurn) {
            _whiteOutOfBook = true;
          } else {
            _blackOutOfBook = true;
          }
        }
      } catch (e) {
        if (isWhiteTurn) {
          _whiteOutOfBook = true;
        } else {
          _blackOutOfBook = true;
        }
      }
    }

    // --- RICERCA MOTORE ---
    onLog("🤖 Il $colorName sta pensando...");
    activeEngine.sendCommand('position fen ${boardController.getFen()}');

    if (tcType == 1) {
      activeEngine.sendCommand('go movetime $baseTimeMs');
    } else {
      _lastEngineStart = DateTime.now();
      activeEngine.sendCommand(
        'go wtime $_wtime btime $_btime winc $incMs binc $incMs',
      );
    }
  }

  void _handleEngineOutput(String line, PlayerColor engineColor) {
    if (!_isRunning || !_isEngineThinking) return;

    PlayerColor currentTurn = boardController.getFen().split(' ')[1] == 'w'
        ? PlayerColor.white
        : PlayerColor.black;
    if (currentTurn != engineColor) {
      return; // Ignora se parla il motore sbagliato
    }

    if (line.startsWith('bestmove')) {
      final parts = line.split(' ');
      if (parts.length > 1 && parts[1] != '(none)') {
        _executeMoveOnBoard(parts[1]);
      }
    }
  }

  void _executeMoveOnBoard(String uciMove) {
    if (!_isRunning) return;

    String fromSq = uciMove.substring(0, 2);
    String toSq = uciMove.substring(2, 4);

    if (uciMove.length == 5) {
      boardController.makeMoveWithPromotion(
        from: fromSq,
        to: toSq,
        pieceToPromoteTo: uciMove[4],
      );
    } else {
      boardController.makeMove(from: fromSq, to: toSq);
    }

    _isEngineThinking = false;

    // Aggiornamento Orologio
    if (tcType == 0 && _lastEngineStart != null) {
      int elapsed = DateTime.now().difference(_lastEngineStart!).inMilliseconds;
      if (boardController.getFen().contains(" b ")) {
        _wtime = (_wtime - elapsed + incMs).clamp(1000, 9999999);
      } else {
        _btime = (_btime - elapsed + incMs).clamp(1000, 9999999);
      }
    }

    if (!_checkStatus()) {
      Future.delayed(const Duration(milliseconds: 100), playNextTurn);
    }
  }

  String? _applyOracleRoulette(List<LiveBookMove> moves) {
    if (moves.isEmpty ||
        moves.first.move == "-" ||
        moves.first.move.contains(".")) {
      return null;
    }
    List<Map<String, dynamic>> parsedMoves = [];
    for (var m in moves) {
      double wp = double.tryParse(m.description.replaceAll('%', '')) ?? 0.0;
      parsedMoves.add({'uci': m.move, 'wp': wp});
    }
    parsedMoves.sort(
      (a, b) => (b['wp'] as double).compareTo(a['wp'] as double),
    );
    double topScore = parsedMoves.first['wp'];
    if (topScore < 40.0) return null;

    List<Map<String, dynamic>> eliteMoves = parsedMoves
        .where((m) => m['wp'] >= 48.0 && (topScore - m['wp']) <= 2.0)
        .toList();
    if (eliteMoves.isEmpty) return parsedMoves.first['uci'];

    List<double> weights = [];
    double totalWeight = 0.0;
    for (var m in eliteMoves) {
      double weight = pow(2.5, m['wp'] - 48.0).toDouble();
      weights.add(weight);
      totalWeight += weight;
    }

    double randomVal = Random().nextDouble() * totalWeight;
    double current = 0.0;
    for (int i = 0; i < eliteMoves.length; i++) {
      current += weights[i];
      if (randomVal <= current) return eliteMoves[i]['uci'];
    }
    return eliteMoves.last['uci'];
  }

  bool _checkStatus() {
    if (boardController.game.in_checkmate) {
      onGameOver("SCACCOMATTO!");
      return true;
    } else if (boardController.game.in_draw ||
        boardController.game.in_stalemate) {
      onGameOver("PATTA!");
      return true;
    }
    return false;
  }

  void stop() {
    _isRunning = false;
    whiteEngine.sendCommand('stop');
    blackEngine.sendCommand('stop');
    _whiteSub?.cancel();
    _blackSub?.cancel();
  }

  void dispose() {
    stop();
  }
}
