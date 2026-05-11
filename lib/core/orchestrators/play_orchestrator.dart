import 'dart:async';
import 'dart:math';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../engine/engine_manager.dart';
import '../logic/livebook_scanner.dart';

class PlayOrchestrator {
  final EngineManager engineManager;
  final ChessBoardController boardController;
  final Function(String) onLog;
  final Function(String?) onGameOver;
  final bool useLivebook;

  final int tcType;
  final int baseTimeMs;
  final int incMs;

  int _wtime = 0;
  int _btime = 0;
  DateTime? _lastEngineStart;

  StreamSubscription<String>? _outputSubscription;
  bool _isEngineThinking = false;
  bool _outOfBook = false;
  final Map<String, int> _positionCount = {};

  PlayOrchestrator({
    required this.engineManager,
    required this.boardController,
    required this.onLog,
    required this.onGameOver,
    this.useLivebook = true,
    this.tcType = 1,
    this.baseTimeMs = 3000,
    this.incMs = 0,
  }) {
    if (tcType == 0) {
      _wtime = baseTimeMs;
      _btime = baseTimeMs;
    }
  }

  String _getPosKey(String fen) => fen.split(' ').take(4).join(' ');

  void startGame() {
    onLog("🎮 Partita iniziata! Buona fortuna.");
    _outOfBook = !useLivebook;
    _positionCount.clear();
    _positionCount[_getPosKey(boardController.getFen())] = 1;
    _listenToEngine();
  }

  void playCycle() async {
    if (_isEngineThinking) {
      return;
    }
    if (_checkStatus()) {
      stop();
      return;
    }

    _isEngineThinking = true;
    onLog("🤖 Il computer sta pensando...");

    if (!_outOfBook) {
      bool isShash = engineManager.engineOutput == null;
      try {
        var result = await LiveBookScanner.scan(
          boardController.getFen(),
          [],
          isShash,
        );
        String? chosenUci = _applyOracleRoulette(result.moves);

        if (chosenUci != null) {
          onLog("📖 Mossa pescata dal LiveBook Cloud!");
          _executeMoveOnBoard(chosenUci, fromBook: true);
          return;
        } else {
          onLog("📉 Livebook esaurito. Il motore pensa da solo.");
          _outOfBook = true;
        }
      } catch (e) {
        onLog("⚠️ Errore LiveBook ($e). Il motore pensa da solo.");
        _outOfBook = true;
      }
    }

    engineManager.sendCommand('position fen ${boardController.getFen()}');
    if (tcType == 1) {
      engineManager.sendCommand('go movetime $baseTimeMs');
    } else {
      _lastEngineStart = DateTime.now();
      engineManager.sendCommand(
        'go wtime $_wtime btime $_btime winc $incMs binc $incMs',
      );
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
      parsedMoves.add({
        'uci': m.move,
        'wp': double.tryParse(m.description.replaceAll('%', '')) ?? 0.0,
      });
    }

    if (parsedMoves.isEmpty) {
      return null;
    }

    double topScore = parsedMoves.first['wp'];
    if (topScore < 40.0) {
      return parsedMoves.first['uci'];
    }

    List<Map<String, dynamic>> eliteMoves = parsedMoves
        .take(3)
        .where((m) => m['wp'] >= 45.0)
        .toList();

    if (eliteMoves.isEmpty) {
      return parsedMoves.first['uci'];
    }

    List<double> weights = [];
    double totalWeight = 0.0;
    for (int i = 0; i < eliteMoves.length; i++) {
      double weight = pow(3.0, (eliteMoves.length - i - 1)).toDouble();
      weights.add(weight);
      totalWeight += weight;
    }

    double randomVal = Random().nextDouble() * totalWeight;
    double current = 0.0;
    for (int i = 0; i < eliteMoves.length; i++) {
      current += weights[i];
      if (randomVal <= current) {
        return eliteMoves[i]['uci'];
      }
    }
    return eliteMoves.first['uci'];
  }

  void _listenToEngine() {
    _outputSubscription = engineManager.engineOutput?.listen((line) {
      if (!_isEngineThinking) {
        return;
      }

      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        if (parts.length > 1) {
          String best = parts[1].toLowerCase();

          if (best == '(none)' || best == '0000' || best == 'resign') {
            bool isWhiteTurn = boardController.getFen().split(' ')[1] == 'w';
            String winner = isWhiteTurn
                ? "0-1 (Vince il Nero)"
                : "1-0 (Vince il Bianco)";
            String reason = (best == 'resign')
                ? "per Abbandono"
                : "per Fine Partita";

            if (!_checkStatus()) {
              onGameOver("$winner $reason");
            }
            stop();
          } else {
            _executeMoveOnBoard(best, fromBook: false);
          }
        }
      }
    });
  }

  void _executeMoveOnBoard(String uciMove, {bool fromBook = false}) {
    try {
      if (uciMove.length >= 4) {
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
      }
    } catch (_) {}

    String newKey = _getPosKey(boardController.getFen());
    _positionCount[newKey] = (_positionCount[newKey] ?? 0) + 1;

    _isEngineThinking = false;

    if (tcType == 0 && _lastEngineStart != null) {
      int elapsed = DateTime.now().difference(_lastEngineStart!).inMilliseconds;
      if (boardController.getFen().contains(" b ")) {
        _wtime -= elapsed;
        if (_wtime <= 0) {
          onGameOver("0-1 (Vince il Nero per il Tempo)");
          stop();
          return;
        }
        _wtime += incMs;
      } else {
        _btime -= elapsed;
        if (_btime <= 0) {
          onGameOver("1-0 (Vince il Bianco per il Tempo)");
          stop();
          return;
        }
        _btime += incMs;
      }
    }

    if (_checkStatus()) {
      stop();
    }
  }

  bool _checkStatus() {
    var legalMoves = boardController.game.generate_moves();

    if (boardController.game.in_checkmate || legalMoves.isEmpty) {
      if (boardController.game.in_check) {
        bool isWhiteTurn = boardController.getFen().split(' ')[1] == 'w';
        onGameOver(
          isWhiteTurn ? "0-1 (Vince il Nero)" : "1-0 (Vince il Bianco)",
        );
      } else {
        onGameOver("1/2-1/2 (Stallo)");
      }
      return true;
    }

    String currentKey = _getPosKey(boardController.getFen());
    if ((_positionCount[currentKey] ?? 0) >= 3) {
      onGameOver("1/2-1/2 (Patta per Ripetizione)");
      return true;
    }

    List<String> fenParts = boardController.getFen().split(' ');
    int halfMoves = fenParts.length > 4 ? (int.tryParse(fenParts[4]) ?? 0) : 0;
    if (halfMoves >= 100) {
      onGameOver("1/2-1/2 (Regola delle 50 Mosse)");
      return true;
    }

    if (boardController.game.in_draw ||
        boardController.game.in_stalemate ||
        boardController.game.insufficient_material) {
      onGameOver("1/2-1/2 (Patta)");
      return true;
    }

    return false;
  }

  void stop() {
    _outputSubscription?.cancel();
  }

  void dispose() {
    _outputSubscription?.cancel();
  }
}
