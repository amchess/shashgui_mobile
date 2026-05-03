import 'dart:async';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../engine/engine_manager.dart';

// I tre stati della nostra partita
enum PlayState { idle, userTurn, engineThinking }

class PlayOrchestrator {
  final EngineManager engineManager;
  final ChessBoardController boardController;

  PlayState currentState = PlayState.idle;
  StreamSubscription<String>? _outputSubscription;

  // Callback per aggiornare i testi nella UI
  final Function(String) onLog;
  final Function(PlayState) onStateChanged;

  PlayOrchestrator({
    required this.engineManager,
    required this.boardController,
    required this.onLog,
    required this.onStateChanged,
  }) {
    // Ci sintonizziamo sulla "Radio Pubblica" del motore
    _outputSubscription = engineManager.engineOutput?.listen(
      _handleEngineOutput,
    );
  }

  void _handleEngineOutput(String line) {
    // Se è il turno del motore e sentiamo la parola magica "bestmove"...
    if (currentState == PlayState.engineThinking &&
        line.startsWith("bestmove")) {
      final match = RegExp(r"bestmove (\w+)").firstMatch(line);
      if (match != null) {
        String move = match.group(1)!;
        _executeEngineMove(move);
      }
    }
  }

  /// Inizia una nuova partita (Noi siamo il Bianco, il motore il Nero)
  void startGame() {
    if (currentState != PlayState.idle) {
      engineManager.sendCommand('stop');
    }

    boardController.resetBoard(); // Resetta la scacchiera visiva
    onLog("===========================================");
    onLog("⚔️ Partita Iniziata! Tu hai il Bianco.");

    _waitForUser();
  }

  /// Viene chiamato dalla UI ogni volta che l'utente muove un pezzo
  void onUserMoved() {
    if (currentState == PlayState.userTurn) {
      // È il turno del Nero!
      _triggerEngine();
    }
  }

  /// Sveglia il motore e gli fa calcolare la mossa
  void _triggerEngine() {
    currentState = PlayState.engineThinking;
    onStateChanged(currentState);
    onLog("🤖 Il motore sta pensando...");

    // Legge la scacchiera e la invia al motore
    String fen = boardController.getFen();
    engineManager.sendCommand('position fen $fen');

    // Per questa demo, diamo al motore 1.5 secondi netti per pensare
    engineManager.sendCommand('go movetime 1500');
  }

  /// Applica fisicamente la mossa del motore sulla scacchiera grafica
  void _executeEngineMove(String uciMove) {
    onLog("♟️ Mossa del motore: $uciMove");

    // Convertiamo la mossa UCI (es. "e7e5") in coordinate per la UI
    String from = uciMove.substring(0, 2);
    String to = uciMove.substring(2, 4);

    // Muoviamo il pezzo sulla scacchiera in modo visivo
    boardController.makeMove(from: from, to: to);

    // Ripassa il turno all'umano
    _waitForUser();
  }

  /// Aspetta la mossa dell'utente umano
  void _waitForUser() {
    currentState = PlayState.userTurn;
    onStateChanged(currentState);
    onLog("👤 Tocca a te! Fai la tua mossa.");
  }

  /// Ferma la partita
  void stop() {
    engineManager.sendCommand('stop');
    currentState = PlayState.idle;
    onStateChanged(currentState);
    onLog("🛑 Partita interrotta.");
  }

  void dispose() {
    _outputSubscription?.cancel();
  }
}
