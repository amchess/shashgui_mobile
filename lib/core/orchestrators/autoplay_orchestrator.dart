// lib/core/orchestrators/autoplay_orchestrator.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart'; // ⚠️ FIX 1: Risolve l'errore "Colors"
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../engine/engine_manager.dart';
import '../logic/livebook_scanner.dart';
import '../logic/shashin_logic.dart';
import 'shashin_fsm.dart';

class AutoplayOrchestrator {
  final EngineManager whiteEngine;
  final EngineManager blackEngine;
  final String whiteEngineName;
  final String blackEngineName;
  final ChessBoardController boardController;

  final Function(String) onLog;
  final Function(String?) onGameOver;
  final Function(ShashinZone) onZoneChanged;
  final Function(EngineStats) onStatsUpdate;
  final Function(int wTimeMs, int bTimeMs) onClockUpdate;

  final bool whiteUseLivebook;
  final bool blackUseLivebook;
  final int tcType;
  final int baseTimeMs;
  final int incMs;

  int _wtime = 0;
  int _btime = 0;
  DateTime? _lastEngineStart;
  DateTime _lastStatsTime = DateTime.now();
  Timer? _watchdogTimer; // 🔔 TIMER DI SICUREZZA
  ShashinZone _lastZone = ShashinZone(
    "In attesa...",
    "...",
    Colors.grey,
    50.0,
    [],
  ); // 🧠 ULTIMA ZONA

  StreamSubscription<String>? _whiteSub;
  StreamSubscription<String>? _blackSub;

  bool _isEngineThinking = false;
  bool _whiteOutOfBook = false;
  bool _blackOutOfBook = false;
  bool _isRunning = false;
  bool _isGameOver = false; // 🛑 IMPEDISCE DOPPIE CHIAMATE

  final Map<String, int> _positionCount = {};

  AutoplayOrchestrator({
    required this.whiteEngine,
    required this.blackEngine,
    required this.whiteEngineName,
    required this.blackEngineName,
    required this.boardController,
    required this.onLog,
    required this.onGameOver,
    required this.onZoneChanged,
    required this.onStatsUpdate,
    required this.onClockUpdate,
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

  String _getPosKey(String fen) => fen.split(' ').take(4).join(' ');

  void startMatch() {
    if (_isRunning) return;
    _isRunning = true;
    _isGameOver = false;
    _whiteOutOfBook = !whiteUseLivebook;
    _blackOutOfBook = !blackUseLivebook;

    _positionCount.clear();
    _positionCount[_getPosKey(boardController.getFen())] = 1;

    onLog("⚔️ AUTOPLAY INIZIATO!");
    onClockUpdate(_wtime, _btime);

    _whiteSub = whiteEngine.engineOutput?.listen(
      (line) => _handleEngineOutput(line, PlayerColor.white),
    );
    _blackSub = blackEngine.engineOutput?.listen(
      (line) => _handleEngineOutput(line, PlayerColor.black),
    );

    playNextTurn();
  }

  void playNextTurn() async {
    if (!_isRunning || _isGameOver) return;
    if (_isEngineThinking) return;

    if (_checkStatus()) {
      _forceGameOver(null);
      return;
    }

    _isEngineThinking = true;
    bool isWhiteTurn = boardController.getFen().split(' ')[1] == 'w';
    EngineManager activeEngine = isWhiteTurn ? whiteEngine : blackEngine;
    bool outOfBook = isWhiteTurn ? _whiteOutOfBook : _blackOutOfBook;
    String colorName = isWhiteTurn ? "Bianco" : "Nero";

    if (!outOfBook) {
      try {
        bool isNeural = isWhiteTurn
            ? whiteEngineName == 'shashchess'
            : blackEngineName == 'shashchess';
        var result = await LiveBookScanner.scan(
          boardController.getFen(),
          [],
          isNeural,
        );
        String? chosenUci = _applyOracleRoulette(result.moves);
        if (chosenUci != null) {
          onLog("📖 Il $colorName gioca dal LiveBook!");
          _executeMoveOnBoard(chosenUci, fromBook: true);
          return;
        } else {
          onLog("📉 Livebook esaurito per il $colorName.");
          if (isWhiteTurn)
            _whiteOutOfBook = true;
          else
            _blackOutOfBook = true;
        }
      } catch (e) {
        if (isWhiteTurn)
          _whiteOutOfBook = true;
        else
          _blackOutOfBook = true;
      }
    }

    onLog("🤖 Il $colorName sta calcolando...");
    activeEngine.sendCommand('position fen ${boardController.getFen()}');

    // 🕒 AVVIA WATCHDOG (10 secondi)
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 10), () {
      if (_isRunning && _isEngineThinking && !_isGameOver) {
        onLog("⛔ WATCHDOG: nessuna risposta dal motore, forzo la decisione");
        bool isWhiteTurnNow = boardController.getFen().split(' ')[1] == 'w';
        String result;
        if (_lastZone.wp >= 90.0) {
          result = isWhiteTurnNow
              ? "1-0 (Vince il Bianco per timeout - posizione dominante)"
              : "0-1 (Vince il Nero per timeout - posizione dominante)";
        } else if (_lastZone.wp <= 10.0) {
          result = isWhiteTurnNow
              ? "0-1 (Vince il Nero per timeout - posizione disperata)"
              : "1-0 (Vince il Bianco per timeout - posizione disperata)";
        } else {
          result = "1/2-1/2 (Patta per timeout - posizione bilanciata)";
        }
        _forceGameOver(result);
      }
    });

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
    if (!_isRunning || _isGameOver) return;

    PlayerColor currentTurn = boardController.getFen().split(' ')[1] == 'w'
        ? PlayerColor.white
        : PlayerColor.black;
    if (currentTurn != engineColor) return;

    final wdlMatch = RegExp(r"wdl (\d+) (\d+) (\d+)").firstMatch(line);
    if (wdlMatch != null) {
      int w = int.parse(wdlMatch.group(1)!);
      int d = int.parse(wdlMatch.group(2)!);
      int l = int.parse(wdlMatch.group(3)!);
      _lastZone = analyzeShashinZone(w, d, l);
      onZoneChanged(_lastZone);
    }

    if (line.startsWith("info")) {
      _parseInfoLine(line);
    }

    if (line.startsWith('bestmove')) {
      _watchdogTimer?.cancel();
      _watchdogTimer = null;

      if (!_isEngineThinking) return;

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
              : "per Scaccomatto";
          _forceGameOver("$winner $reason");
        } else {
          _executeMoveOnBoard(best, fromBook: false);
        }
      }
    }
  }

  void _parseInfoLine(String line) {
    if (!line.contains("depth") &&
        !line.contains("nodes") &&
        !line.contains("pv"))
      return;
    int depth =
        int.tryParse(
          RegExp(r"depth (\d+)").firstMatch(line)?.group(1) ?? "0",
        ) ??
        0;
    int selDepth =
        int.tryParse(
          RegExp(r"seldepth (\d+)").firstMatch(line)?.group(1) ?? "0",
        ) ??
        0;
    int nodes =
        int.tryParse(
          RegExp(r"nodes (\d+)").firstMatch(line)?.group(1) ?? "0",
        ) ??
        0;
    int nps =
        int.tryParse(RegExp(r"nps (\d+)").firstMatch(line)?.group(1) ?? "0") ??
        0;
    String? fullPv = RegExp(r" pv (.*)$").firstMatch(line)?.group(1);
    if (depth == 0 && nodes == 0) return;
    final now = DateTime.now();
    if (now.difference(_lastStatsTime).inMilliseconds > 200) {
      _lastStatsTime = now;
      onStatsUpdate(
        EngineStats(
          depth: depth,
          selDepth: selDepth,
          nodes: nodes,
          nps: nps,
          pv: fullPv ?? "",
        ),
      );
    }
  }

  void _executeMoveOnBoard(String uciMove, {bool fromBook = false}) {
    if (!_isRunning || _isGameOver) return;

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
    } catch (e) {
      onLog("Errore nell'esecuzione della mossa $uciMove");
    }

    String newKey = _getPosKey(boardController.getFen());
    _positionCount[newKey] = (_positionCount[newKey] ?? 0) + 1;
    _isEngineThinking = false;

    if (tcType == 0 && _lastEngineStart != null) {
      int elapsed = DateTime.now().difference(_lastEngineStart!).inMilliseconds;
      if (boardController.getFen().contains(" b ")) {
        _wtime -= elapsed;
        if (_wtime <= 0) {
          _forceGameOver("0-1 (Vince il Nero per il Tempo)");
          return;
        }
        _wtime += incMs;
      } else {
        _btime -= elapsed;
        if (_btime <= 0) {
          _forceGameOver("1-0 (Vince il Bianco per il Tempo)");
          return;
        }
        _btime += incMs;
      }
      onClockUpdate(_wtime, _btime);
    }

    if (_checkStatus()) {
      _forceGameOver(null);
    } else {
      Future.delayed(const Duration(milliseconds: 50), playNextTurn);
    }
  }

  bool _checkStatus() {
    if (_isGameOver) return true;

    bool isCheckmate = boardController.game.in_checkmate;
    bool isStalemate = boardController.game.in_stalemate;
    bool insufficient = boardController.game.insufficient_material;
    bool noMoves = boardController.game.generate_moves().isEmpty;

    // 2. Controllo manuale sicuro leggendo la FEN (⚠️ FIX 2: Previene crash sui pezzi C++)
    if (!insufficient) {
      insufficient = _isInsufficientMaterial();
    }

    if (isCheckmate || noMoves) {
      if (isCheckmate || (noMoves && boardController.game.in_check)) {
        bool isWhiteTurn = boardController.getFen().split(' ')[1] == 'w';
        onGameOver(
          isWhiteTurn ? "0-1 (Vince il Nero)" : "1-0 (Vince il Bianco)",
        );
      } else {
        onGameOver("1/2-1/2 (Stallo)");
      }
      return true;
    }

    if (isStalemate || insufficient) {
      onGameOver("1/2-1/2 (Patta per materiale insufficiente)");
      return true;
    }

    String currentKey = _getPosKey(boardController.getFen());
    if ((_positionCount[currentKey] ?? 0) >= 3) {
      onGameOver("1/2-1/2 (Patta per ripetizione)");
      return true;
    }

    List<String> fenParts = boardController.getFen().split(' ');
    int halfMoves = fenParts.length > 4 ? (int.tryParse(fenParts[4]) ?? 0) : 0;
    if (halfMoves >= 100) {
      onGameOver("1/2-1/2 (Regola delle 50 mosse)");
      return true;
    }

    return false;
  }

  // ⚠️ FIX: Il metodo a prova di bomba per contare i pezzi leggendo la FEN
  bool _isInsufficientMaterial() {
    String piecesOnly = boardController.getFen().split(' ')[0];

    int whitePieces = 0, blackPieces = 0;
    bool whiteHasMinor = false, blackHasMinor = false;
    bool hasMajorOrPawn = false;

    for (int i = 0; i < piecesOnly.length; i++) {
      String p = piecesOnly[i];
      if (p == '/' || int.tryParse(p) != null) continue;

      if (p == 'K')
        whitePieces++;
      else if (p == 'k')
        blackPieces++;
      else if (p == 'N' || p == 'B') {
        whitePieces++;
        whiteHasMinor = true;
      } else if (p == 'n' || p == 'b') {
        blackPieces++;
        blackHasMinor = true;
      } else {
        hasMajorOrPawn = true; // Se ci sono Donne, Torri o Pedoni, si continua!
      }
    }

    if (hasMajorOrPawn) return false;

    // Solo Re (1 vs 1)
    if (whitePieces == 1 && blackPieces == 1) return true;
    // Re + Alfiere/Cavallo vs Re
    if (whitePieces == 2 && whiteHasMinor && blackPieces == 1) return true;
    if (blackPieces == 2 && blackHasMinor && whitePieces == 1) return true;

    return false;
  }

  void _forceGameOver(String? customMessage) {
    if (_isGameOver) return;
    _isGameOver = true;
    _isRunning = false;
    _isEngineThinking = false;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    if (customMessage != null) {
      onGameOver(customMessage);
    }

    whiteEngine.sendCommand('stop');
    blackEngine.sendCommand('stop');
    _whiteSub?.cancel();
    _blackSub?.cancel();
    _whiteSub = null;
    _blackSub = null;
  }

  void stop() {
    _forceGameOver("Match interrotto dall'utente");
  }

  void dispose() {
    stop();
  }

  String? _applyOracleRoulette(List<LiveBookMove> moves) {
    if (moves.isEmpty ||
        moves.first.move == "-" ||
        moves.first.move.contains("."))
      return null;

    List<Map<String, dynamic>> parsedMoves = [];
    for (var m in moves) {
      parsedMoves.add({
        'uci': m.move,
        'wp': double.tryParse(m.description.replaceAll('%', '')) ?? 0.0,
      });
    }

    if (parsedMoves.isEmpty) return null;

    double topScore = parsedMoves.first['wp'];
    if (topScore < 40.0) return parsedMoves.first['uci'];

    List<Map<String, dynamic>> eliteMoves = parsedMoves
        .take(3)
        .where((m) => m['wp'] >= 45.0)
        .toList();
    if (eliteMoves.isEmpty) return parsedMoves.first['uci'];

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
      if (randomVal <= current) return eliteMoves[i]['uci'];
    }
    return eliteMoves.first['uci'];
  }
}
