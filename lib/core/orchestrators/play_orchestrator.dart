import 'dart:async';
import 'dart:math';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../engine/engine_manager.dart';
import '../logic/livebook_scanner.dart'; // Messo per usare l'Oracolo

class PlayOrchestrator {
  final EngineManager engineManager;
  final ChessBoardController boardController;
  final Function(String) onLog;
  final Function(String?) onGameOver;
  final bool useLivebook;
  final int thinkTimeMs;

  StreamSubscription<String>? _outputSubscription;
  bool _isEngineThinking = false;
  bool _outOfBook = false;

  PlayOrchestrator({
    required this.engineManager,
    required this.boardController,
    required this.onLog,
    required this.onGameOver,
    this.useLivebook = true,
    this.thinkTimeMs = 1500,
  });

  void startGame() {
    onLog("🎮 Partita iniziata! Buona fortuna.");
    _outOfBook = !useLivebook;
    _listenToEngine();
  }

  void playCycle() async {
    if (_isEngineThinking) return;
    if (_checkStatus()) return;

    _isEngineThinking = true;
    onLog("🤖 Il computer sta pensando...");

    // --- LOGICA ORACOLO LIVEBOOK (Roulette Stocastica) ---
    if (!_outOfBook) {
      // Mock logica per capire che motore stiamo usando (da affinare se serve)
      bool isShash = engineManager.engineOutput == null;

      try {
        // Chiamiamo il Cloud! Passiamo [] come history perché qui ci servono solo i WinRate
        var result = await LiveBookScanner.scan(
          boardController.getFen(),
          [],
          isShash,
        );
        String? chosenUci = _applyOracleRoulette(result.moves);

        if (chosenUci != null) {
          onLog("📖 Mossa pescata dal LiveBook Cloud!");
          _executeMoveOnBoard(chosenUci);
          return;
        } else {
          onLog(
            "📉 Livebook esaurito o mosse deboli. Il motore pensa da solo.",
          );
          _outOfBook = true;
        }
      } catch (e) {
        onLog("⚠️ Errore LiveBook ($e). Il motore pensa da solo.");
        _outOfBook = true;
      }
    }

    // --- ANALISI MOTORE NORMALE ---
    engineManager.sendCommand('position fen ${boardController.getFen()}');
    engineManager.sendCommand('go movetime $thinkTimeMs');
  }

  // --- TRADUZIONE ESATTA DALLA TUA VERSIONE PYTHON ---
  String? _applyOracleRoulette(List<LiveBookMove> moves) {
    if (moves.isEmpty ||
        moves.first.move == "-" ||
        moves.first.move.contains("."))
      return null;

    List<Map<String, dynamic>> parsedMoves = [];
    for (var m in moves) {
      double wp = double.tryParse(m.description.replaceAll('%', '')) ?? 0.0;
      parsedMoves.add({'uci': m.move, 'wp': wp});
    }

    // Ordinamento
    parsedMoves.sort(
      (a, b) => (b['wp'] as double).compareTo(a['wp'] as double),
    );
    double topScore = parsedMoves.first['wp'];

    // Se la mossa migliore fa schifo, usciamo dal libro (Bailout)
    if (topScore < 40.0) return null;

    // Selezioniamo l'Élite (almeno 48% di vittoria e a non più di 2 punti dalla migliore)
    List<Map<String, dynamic>> eliteMoves = parsedMoves.where((m) {
      double wp = m['wp'];
      return wp >= 48.0 && (topScore - wp) <= 2.0;
    }).toList();

    if (eliteMoves.isEmpty) return parsedMoves.first['uci'];

    // Assegnazione Biglietti Lotteria (Esponenziale)
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
      if (randomVal <= current) {
        return eliteMoves[i]['uci'];
      }
    }

    return eliteMoves.last['uci'];
  }

  void _listenToEngine() {
    _outputSubscription = engineManager.engineOutput?.listen((line) {
      if (!_isEngineThinking) return;

      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        if (parts.length > 1 && parts[1] != '(none)') {
          _executeMoveOnBoard(parts[1]);
        }
      }
    });
  }

  void _executeMoveOnBoard(String uciMove) {
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

    onLog("🤖 Computer gioca: $uciMove");
    _isEngineThinking = false;
    _checkStatus();
  }

  bool _checkStatus() {
    if (boardController.game.in_checkmate) {
      onGameOver("SCACCOMATTO! La partita è finita.");
      return true;
    } else if (boardController.game.in_draw) {
      onGameOver("PATTA! La partita è finita in pareggio.");
      return true;
    } else if (boardController.game.in_stalemate) {
      onGameOver("STALLO! Pareggio.");
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
