import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/engine_manager.dart';
import '../logic/shashin_logic.dart';

// I tre stati in cui può trovarsi il nostro orchestratore
enum FsmState { idle, phase1, phase2 }

class ShashinFsm {
  final EngineManager engineManager;

  FsmState currentState = FsmState.idle;
  StreamSubscription<String>? _outputSubscription;
  ShashinZone currentZone = ShashinZone("In attesa...", "-", Colors.grey);

  // Callback per comunicare con l'interfaccia grafica (UI)
  final Function(String) onLog;
  final Function(ShashinZone) onZoneChanged;
  final Function(FsmState) onStateChanged;

  ShashinFsm({
    required this.engineManager,
    required this.onLog,
    required this.onZoneChanged,
    required this.onStateChanged,
  }) {
    // Ci mettiamo in ascolto dei sussurri del motore
    _outputSubscription = engineManager.engineOutput?.listen(
      _handleEngineOutput,
    );
  }

  void _handleEngineOutput(String line) {
    // 1. Cacciatore di WDL (Aggiorna il termometro)
    final wdlMatch = RegExp(r"wdl (\d+) (\d+) (\d+)").firstMatch(line);
    if (wdlMatch != null) {
      int w = int.parse(wdlMatch.group(1)!);
      int d = int.parse(wdlMatch.group(2)!);
      int l = int.parse(wdlMatch.group(3)!);

      currentZone = analyzeShashinZone(w, d, l);
      onZoneChanged(currentZone); // Avvisa la UI che la zona è cambiata
    }

    // 2. IL TRUCCO DELLO SWITCH:
    // Quando la Fase 1 finisce (il tempo scade), Stockfish sputa sempre "bestmove".
    // Noi intercettiamo quel "bestmove" per innescare la Fase 2!
    if (currentState == FsmState.phase1 && line.startsWith("bestmove")) {
      _startPhase2();
    }
  }

  /// Avvia l'analisi della posizione (FASE 1)
  void startAnalysis(String fen) {
    if (currentState != FsmState.idle) {
      engineManager.sendCommand('stop');
    }

    currentState = FsmState.phase1;
    onStateChanged(currentState);

    onLog("===========================================");
    onLog("⏱️ FASE 1: Lettura Termodinamica rapida...");

    engineManager.sendCommand('position fen $fen');

    // Diciamo al motore di pensare SOLO per 1.5 secondi (1500 millisecondi)
    engineManager.sendCommand('go movetime 1500');
  }

  /// Avvia l'analisi profonda (FASE 2)
  void _startPhase2() {
    currentState = FsmState.phase2;
    onStateChanged(currentState);

    onLog(
      "🎯 FASE 2: Analisi profonda in modalità [ ${currentZone.name.toUpperCase()} ]",
    );

    // Qui prepariamo il motore alla modalità specifica.
    // N.B. In futuro qui invieremo le UCI options specifiche di ShashChess
    // es: engineManager.sendCommand('setoption name TargetZone value ${currentZone.name}');

    // Facciamo ripartire il motore per un calcolo più profondo e mirato
    engineManager.sendCommand('go depth 12');
  }

  /// Ferma tutto
  void stop() {
    engineManager.sendCommand('stop');
    currentState = FsmState.idle;
    onStateChanged(currentState);
    onLog("🛑 Analisi fermata.");
  }

  void dispose() {
    _outputSubscription?.cancel();
  }
}
