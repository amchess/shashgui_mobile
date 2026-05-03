import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/engine_manager.dart';
import '../logic/shashin_logic.dart';

enum CrossedState { idle, studentThinking, masterThinking }

class CrossedEvalOrchestrator {
  final EngineManager engineManager;

  CrossedState currentState = CrossedState.idle;
  StreamSubscription<String>? _outputSubscription;

  // Memoria del calcolo
  String? studentMove;
  ShashinZone? studentZone;
  String? masterMove;
  ShashinZone? masterZone;

  // Callback per la UI
  final Function(String) onLog;
  final Function(String, ShashinZone, String, ShashinZone) onReportReady;

  CrossedEvalOrchestrator({
    required this.engineManager,
    required this.onLog,
    required this.onReportReady,
  }) {
    _outputSubscription = engineManager.engineOutput?.listen(
      _handleEngineOutput,
    );
  }

  void _handleEngineOutput(String line) {
    // Aggiorniamo la zona in base a chi sta pensando
    final wdlMatch = RegExp(r"wdl (\d+) (\d+) (\d+)").firstMatch(line);
    if (wdlMatch != null) {
      int w = int.parse(wdlMatch.group(1)!);
      int d = int.parse(wdlMatch.group(2)!);
      int l = int.parse(wdlMatch.group(3)!);

      if (currentState == CrossedState.studentThinking) {
        studentZone = analyzeShashinZone(w, d, l);
      } else if (currentState == CrossedState.masterThinking) {
        masterZone = analyzeShashinZone(w, d, l);
      }
    }

    // Quando scade il tempo, catturiamo la bestmove e passiamo alla fase successiva
    if (line.startsWith("bestmove")) {
      final moveMatch = RegExp(r"bestmove (\w+)").firstMatch(line);
      if (moveMatch != null) {
        String move = moveMatch.group(1)!;

        if (currentState == CrossedState.studentThinking) {
          studentMove = move;
          _startMasterAnalysis(); // Tocca al Maestro!
        } else if (currentState == CrossedState.masterThinking) {
          masterMove = move;
          _finishAndReport(); // Analisi conclusa, generiamo il verdetto!
        }
      }
    }
  }

  /// Avvia la valutazione incrociata partendo dall'Allievo
  void startCrossedEval(String fen, int playerElo) {
    if (currentState != CrossedState.idle) engineManager.sendCommand('stop');

    currentState = CrossedState.studentThinking;
    onLog("===========================================");
    onLog("🧑‍🎓 L'Allievo (Elo $playerElo) sta cercando un piano...");

    engineManager.sendCommand('position fen $fen');

    // Per l'MVP simuliamo l'Elo basso limitando fortemente la profondità di ricerca
    // (Nella versione completa useremo i comandi UCI_LimitStrength e UCI_Elo)
    int studentDepth = (playerElo < 1500) ? 3 : 6;
    engineManager.sendCommand('go depth $studentDepth');
  }

  /// Il Maestro analizza la stessa posizione al massimo della forza
  void _startMasterAnalysis() {
    currentState = CrossedState.masterThinking;
    onLog("🧙‍♂️ Il Maestro sta valutando la posizione profonda...");

    // Il maestro pensa molto più a fondo
    engineManager.sendCommand('go depth 12');
  }

  /// Genera il risultato finale
  void _finishAndReport() {
    currentState = CrossedState.idle;

    if (studentMove != null &&
        studentZone != null &&
        masterMove != null &&
        masterZone != null) {
      onLog("✅ Valutazione incrociata completata.");
      onReportReady(studentMove!, studentZone!, masterMove!, masterZone!);
    } else {
      onLog("❌ Errore durante l'estrazione delle mosse.");
    }
  }

  void stop() {
    engineManager.sendCommand('stop');
    currentState = CrossedState.idle;
  }

  void dispose() {
    _outputSubscription?.cancel();
  }
}
