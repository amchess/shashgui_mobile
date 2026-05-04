import 'dart:async';
import '../engine/engine_manager.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

class PlayOrchestrator {
  final EngineManager engineManager;
  final ChessBoardController boardController;
  final Function(String) onLog;
  final Function(String?) onGameOver; // Callback per la fine partita

  StreamSubscription<String>? _outputSubscription;
  bool _isEngineThinking = false;

  PlayOrchestrator({
    required this.engineManager,
    required this.boardController,
    required this.onLog,
    required this.onGameOver,
  });

  void startGame() {
    onLog("🎮 Partita iniziata. Muovi il Bianco per cominciare!");
    _listenToEngine();
  }

  // Il cuore del gioco: viene chiamato ogni volta che tu muovi
  void playCycle() {
    if (_isEngineThinking) return;

    // 1. Controlla se hai vinto tu con la tua mossa
    if (_checkStatus()) return;

    // 2. Tocca al Nero (Computer)
    _makeComputerMove();
  }

  void _makeComputerMove() {
    _isEngineThinking = true;
    onLog("🤖 Il computer sta pensando...");

    // Invia la posizione attuale e chiedi una mossa rapida (1.5 secondi)
    engineManager.sendCommand('position fen ${boardController.getFen()}');
    engineManager.sendCommand('go movetime 1500');
  }

  void _listenToEngine() {
    _outputSubscription = engineManager.engineOutput?.listen((line) {
      if (line.startsWith('bestmove')) {
        // 1. FIX FANTASMA: Ignora le vecchie risposte se il computer non stava "pensando" al turno attuale
        if (!_isEngineThinking) return;

        final parts = line.split(' ');
        if (parts.length > 1) {
          String move = parts[1]; // Es. riceve "e7e5" o "e7e8q"

          // 2. FIX SCACCHIERA: Traduciamo l'UCI in case di partenza e arrivo
          String fromSquare = move.substring(0, 2);
          String toSquare = move.substring(2, 4);

          // Eseguiamo la mossa puntando esattamente le caselle fisiche
          boardController.makeMove(from: fromSquare, to: toSquare);

          onLog("🤖 Computer muove: $move");
          _isEngineThinking = false;

          // 3. Controlla se ha vinto il computer o è patta
          _checkStatus();
        }
      }
    });
  }

  bool _checkStatus() {
    // Usiamo l'oggetto 'game' interno al controller per leggere le regole
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
    onLog("🎮 Sessione di gioco terminata.");
  }

  // Aggiunto per evitare l'errore "The method 'dispose' isn't defined"
  void dispose() {
    _outputSubscription?.cancel();
  }
}
