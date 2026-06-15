import 'dart:async';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../../l10n/app_localizations.dart';
import '../engine/engine_manager.dart';
import '../logic/livebook_scanner.dart';

class PlayOrchestrator {
  final EngineManager engineManager;
  final ChessBoardController boardController;
  final String engineName;
  final Function(String) onLog;
  final Function(String?) onGameOver;
  final Function(int wTimeMs, int bTimeMs) onClockUpdate;
  final AppLocalizations loc;
  final bool useLivebook;

  final int tcType;
  // ⚠️ TEMPI E INCREMENTI SEPARATI PER BIANCO E NERO
  final int whiteBaseTimeMs;
  final int whiteIncMs;
  final int blackBaseTimeMs;
  final int blackIncMs;

  int _wtime = 0;
  int _btime = 0;

  Timer? _clockTimer;
  DateTime _lastTimeUpdate = DateTime.now();

  StreamSubscription<String>? _outputSubscription;
  bool _isEngineThinking = false;
  bool _outOfBook = false;
  final Map<String, int> _positionCount = {};

  PlayOrchestrator({
    required this.engineManager,
    required this.boardController,
    required this.engineName,
    required this.onLog,
    required this.onGameOver,
    required this.onClockUpdate,
    required this.loc,
    required this.whiteBaseTimeMs,
    required this.whiteIncMs,
    required this.blackBaseTimeMs,
    required this.blackIncMs,
    this.useLivebook = true,
    this.tcType = 1,
  }) {
    _wtime = whiteBaseTimeMs;
    _btime = blackBaseTimeMs;
  }

  String _getPosKey(String fen) => fen.split(' ').take(4).join(' ');

  void startGame() {
    bool isIt = loc.localeName == 'it';
    onLog(
      isIt
          ? "🎮 Partita iniziata! Buona fortuna."
          : "🎮 Game started! Good luck.",
    );

    _outOfBook = !useLivebook;
    _positionCount.clear();
    _positionCount[_getPosKey(boardController.getFen())] = 1;

    _lastTimeUpdate = DateTime.now();
    _clockTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _updateClock(),
    );
    onClockUpdate(_wtime, _btime);

    _listenToEngine();
  }

  void _updateClock() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastTimeUpdate).inMilliseconds;
    _lastTimeUpdate = now;
    bool isIt = loc.localeName == 'it';

    bool isWhiteTurn = boardController.getFen().split(' ')[1] == 'w';
    if (isWhiteTurn) {
      _wtime -= elapsed;
      if (_wtime <= 0) {
        _wtime = 0;
        onClockUpdate(_wtime, _btime); // ⚠️ FORZA L'UI A ZERO ESATTO
        _clockTimer?.cancel();
        if (!_checkStatus()) {
          onGameOver(
            isIt
                ? "0-1 (Vince il Nero per il Tempo)"
                : "0-1 (Black wins on Time)",
          );
        }
        stop();
        return;
      }
    } else {
      _btime -= elapsed;
      if (_btime <= 0) {
        _btime = 0;
        onClockUpdate(_wtime, _btime); // ⚠️ FORZA L'UI A ZERO ESATTO
        _clockTimer?.cancel();
        if (!_checkStatus()) {
          onGameOver(
            isIt
                ? "1-0 (Vince il Bianco per il Tempo)"
                : "1-0 (White wins on Time)",
          );
        }
        stop();
        return;
      }
    }
    onClockUpdate(_wtime, _btime);
  }

  void registerUserMove() {
    _updateClock();
    bool wasWhite = boardController.getFen().split(' ')[1] == 'b';
    if (tcType == 0) {
      // ⚠️ Applica l'incremento corretto in base al colore
      if (wasWhite) {
        _wtime += whiteIncMs;
      } else {
        _btime += blackIncMs;
      }
    } else {
      // ⚠️ Ricarica i tempi base asimmetrici
      _wtime = whiteBaseTimeMs;
      _btime = blackBaseTimeMs;
    }

    onClockUpdate(_wtime, _btime);
    playCycle();
  }

  void playCycle() async {
    if (_isEngineThinking) return;
    if (_checkStatus()) {
      stop();
      return;
    }

    _isEngineThinking = true;
    bool isIt = loc.localeName == 'it';
    onLog(
      isIt
          ? "🤖 Il computer sta pensando..."
          : "🤖 The computer is thinking...",
    );

    if (!_outOfBook) {
      bool isShash = engineName == 'shashchess';
      try {
        var result = await LiveBookScanner.scan(
          boardController.getFen(),
          [],
          isShash,
        );
        String? chosenUci = OracleRoulette.spin(result.moves);

        if (chosenUci != null) {
          onLog(
            isIt
                ? "📖 Mossa pescata dal LiveBook Cloud!"
                : "📖 Move fetched from LiveBook Cloud!",
          );
          _executeMoveOnBoard(chosenUci, fromBook: true);
          return;
        } else {
          onLog(
            isIt
                ? "📉 Livebook esaurito. Il motore pensa da solo."
                : "📉 Livebook exhausted. Engine thinks on its own.",
          );
          _outOfBook = true;
        }
      } catch (e) {
        onLog(
          isIt
              ? "⚠️ Errore LiveBook. Il motore pensa da solo."
              : "⚠️ LiveBook Error. Engine thinks on its own.",
        );
        _outOfBook = true;
      }
    }

    engineManager.sendCommand('position fen ${boardController.getFen()}');

    if (tcType == 1) {
      // ⚠️ TEMPO FISSO ASIMMETRICO: Invia il tempo specifico di chi tocca muovere
      bool isWhiteTurn = boardController.getFen().split(' ')[1] == 'w';
      int currentMoveTime = isWhiteTurn ? whiteBaseTimeMs : blackBaseTimeMs;
      engineManager.sendCommand('go movetime $currentMoveTime');
    } else {
      // ⚠️ TEMPO GLOBALE ASIMMETRICO
      engineManager.sendCommand(
        'go wtime $_wtime btime $_btime winc $whiteIncMs binc $blackIncMs',
      );
    }
  }

  void _listenToEngine() {
    _outputSubscription = engineManager.engineOutput?.listen((line) {
      if (!_isEngineThinking) return;

      bool isIt = loc.localeName == 'it';

      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        if (parts.length > 1) {
          String best = parts[1].toLowerCase();

          if (best == '(none)' || best == '0000' || best == 'resign') {
            bool isWhiteTurn = boardController.getFen().split(' ')[1] == 'w';
            String winner = isWhiteTurn
                ? (isIt ? "0-1 (Vince il Nero)" : "0-1 (Black Wins)")
                : (isIt ? "1-0 (Vince il Bianco)" : "1-0 (White Wins)");
            String reason = (best == 'resign')
                ? (isIt ? "per Abbandono" : "by Resignation")
                : (isIt ? "per Fine Partita" : "by Game Over");

            if (!_checkStatus()) onGameOver("$winner $reason");
            stop();
          } else {
            _executeMoveOnBoard(best, fromBook: false);
          }
        }
      }
    });
  }

  void _executeMoveOnBoard(String uciMove, {bool fromBook = false}) {
    bool wasWhite = boardController.getFen().split(' ')[1] == 'w';

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

    _updateClock();
    if (tcType == 0) {
      // ⚠️ Applica l'incremento
      if (wasWhite) {
        _wtime += whiteIncMs;
      } else {
        _btime += blackIncMs;
      }
    } else {
      // ⚠️ Ripristina il tempo base
      _wtime = whiteBaseTimeMs;
      _btime = blackBaseTimeMs;
    }
    onClockUpdate(_wtime, _btime);

    if (_checkStatus()) stop();
  }

  bool _checkStatus() {
    var legalMoves = boardController.game.generate_moves();
    bool isIt = loc.localeName == 'it';

    if (boardController.game.in_checkmate || legalMoves.isEmpty) {
      if (boardController.game.in_check) {
        bool isWhiteTurn = boardController.getFen().split(' ')[1] == 'w';
        onGameOver(
          isWhiteTurn
              ? (isIt ? "0-1 (Vince il Nero)" : "0-1 (Black Wins)")
              : (isIt ? "1-0 (Vince il Bianco)" : "1-0 (White Wins)"),
        );
      } else {
        onGameOver(isIt ? "1/2-1/2 (Stallo)" : "1/2-1/2 (Stalemate)");
      }
      return true;
    }

    String currentKey = _getPosKey(boardController.getFen());
    if ((_positionCount[currentKey] ?? 0) >= 3) {
      onGameOver(
        isIt
            ? "1/2-1/2 (Patta per Ripetizione)"
            : "1/2-1/2 (Draw by Repetition)",
      );
      return true;
    }

    List<String> fenParts = boardController.getFen().split(' ');
    int halfMoves = fenParts.length > 4 ? (int.tryParse(fenParts[4]) ?? 0) : 0;
    if (halfMoves >= 100) {
      onGameOver(
        isIt ? "1/2-1/2 (Regola delle 50 Mosse)" : "1/2-1/2 (50-Move Rule)",
      );
      return true;
    }

    if (boardController.game.in_draw ||
        boardController.game.in_stalemate ||
        boardController.game.insufficient_material) {
      onGameOver(isIt ? "1/2-1/2 (Patta)" : "1/2-1/2 (Draw)");
      return true;
    }

    return false;
  }

  void stop() {
    _clockTimer?.cancel();
    _outputSubscription?.cancel();
    engineManager.sendCommand('stop'); // ⚠️ ORA IL MOTORE SI SPEGNE DAVVERO!
  }

  void dispose() {
    _clockTimer?.cancel();
    _outputSubscription?.cancel();
    engineManager.sendCommand('stop');
  }
}
