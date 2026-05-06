import 'dart:async';
import 'dart:math'; // Serve per il calcolo del limite (min)
import 'package:flutter/material.dart';
import '../engine/engine_manager.dart';
import '../logic/shashin_logic.dart';

// I tre stati in cui può trovarsi il nostro orchestratore
enum FsmState { idle, phase1, phase2 }

// NUOVO DTO: Trasporta i dati tecnici del motore alla UI
class EngineStats {
  final int depth;
  final int selDepth;
  final int nodes;
  final int nps;
  final String pv;

  EngineStats({
    this.depth = 0,
    this.selDepth = 0,
    this.nodes = 0,
    this.nps = 0,
    this.pv = "",
  });
}

class ShashinFsm {
  final EngineManager engineManager;

  FsmState currentState = FsmState.idle;

  // NUOVO: Cronometro per limitare la velocità degli aggiornamenti UI
  DateTime _lastStatsTime = DateTime.now();

  StreamSubscription<String>? _outputSubscription;
  ShashinZone currentZone = ShashinZone(
    "In attesa...",
    "-",
    Colors.grey,
    50.0,
    ["assets/images/capablanca.png"], // <-- Messo tra parentesi quadre
  );

  // Callback per comunicare con l'interfaccia grafica (UI)
  final Function(String) onLog;
  final Function(ShashinZone) onZoneChanged;
  final Function(FsmState) onStateChanged;
  final Function(String) onPvUpdate;
  final Function(EngineStats) onStatsUpdate; // <-- NUOVO: Invio statistiche
  final Function(String) onOptionFound; // <-- NUOVO: Intercetta le opzioni UCI

  // Sicure contro i bestmove "fantasma"
  bool _isSearchingPhase1 = false;
  bool _isSearchingPhase2 = false;

  // Variabili per il ciclo temporale Lineare (T1, 2T1, 3T1...)
  int _baseTimeMs = 1500;
  int _iteration = 1;
  String currentFen = "";

  ShashinFsm({
    required this.engineManager,
    required this.onLog,
    required this.onZoneChanged,
    required this.onStateChanged,
    required this.onPvUpdate,
    required this.onStatsUpdate,
    required this.onOptionFound, // <-- NUOVO
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

    // 2. Lettura Dati Tecnici e Frecce (Profondità, Nodi, PV)
    if (line.startsWith("info")) {
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
          int.tryParse(
            RegExp(r"nps (\d+)").firstMatch(line)?.group(1) ?? "0",
          ) ??
          0;

      // Estraiamo l'intera stringa della PV (tutte le mosse)!
      String? fullPv = RegExp(r" pv (.*)$").firstMatch(line)?.group(1);

      // --- AGGIUNTA FILTRO VELOCITÀ (THROTTLE) ---
      final now = DateTime.now();
      // Invia i dati alla UI solo se sono passati più di 200 millisecondi
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

      // La freccia sulla scacchiera la lasciamo fuori dal filtro temporale
      // perché è un'operazione grafica leggera e vogliamo che sia istantanea
      if (fullPv != null && fullPv.isNotEmpty) {
        String firstMove = fullPv.trim().split(' ').first;
        onPvUpdate(firstMove);
      }
    }

    // <-- NUOVO: Cacciatore di Opzioni UCI -->
    if (line.startsWith("option name")) {
      onOptionFound(line);
    }

    // 3. IL TRUCCO DELLO SWITCH CICLICO:
    if (line.startsWith("bestmove")) {
      // Se finisce la Fase 1, avvia la Fase 2
      if (currentState == FsmState.phase1 && _isSearchingPhase1) {
        _isSearchingPhase1 = false;
        _startPhase2();
      }
      // Se finisce la Fase 2, passa alla iterazione successiva e riavvia la Fase 1
      else if (currentState == FsmState.phase2 && _isSearchingPhase2) {
        _isSearchingPhase2 = false;
        _loopBackToPhase1();
      }
    }
  }

  /// Avvia l'analisi della posizione con tempo configurabile
  void startAnalysis(String fen, {int baseTimeMs = 1500}) {
    // Fermiamo brutalmente il motore per zittire vecchie analisi
    engineManager.sendCommand('stop');

    currentFen = fen;
    _baseTimeMs = baseTimeMs;
    _iteration = 1; // Resettiamo le iterazioni a 1

    onLog("===========================================");
    _runPhase1();
  }

  /// Esegue la Fase 1
  void _runPhase1() {
    currentState = FsmState.phase1;
    _isSearchingPhase1 = false;
    _isSearchingPhase2 = false;
    onStateChanged(currentState);

    // Calcolo Lineare: T1 * iterazione (1T1, 2T1, 3T1...), con tetto a 30s
    int t1 = min(_baseTimeMs * _iteration, 30000);

    onLog("⏱️ CICLO $_iteration | FASE 1: Lettura Termodinamica (${t1}ms)...");

    // FIX: La Frizione. Aspettiamo 200ms che il motore sputi i vecchi output e si resetti.
    Future.delayed(const Duration(milliseconds: 200), () {
      // Assicuriamoci che l'utente non abbia premuto stop in questi 200ms
      if (currentState == FsmState.phase1) {
        engineManager.sendCommand('position fen $currentFen');
        engineManager.sendCommand('go movetime $t1');
        _isSearchingPhase1 = true; // Togliamo la sicura!
      }
    });
  }

  /// Avvia l'analisi profonda (FASE 2) con settaggio dinamico Shashin
  void _startPhase2() {
    currentState = FsmState.phase2;
    onStateChanged(currentState);

    int t2 = (_baseTimeMs * _iteration) * 2;
    onLog(
      "🎯 CICLO $_iteration | FASE 2: Calcolo [ ${currentZone.name.toUpperCase()} ] (${t2}ms)...",
    );

    // --- IL CUORE DELLA TEORIA DI SHASHIN ---
    // Comunichiamo al motore in che zona "mentale" deve calcolare
    String targetMode = "Normal";
    if (currentZone.name.contains("Tal")) targetMode = "Tal";
    if (currentZone.name.contains("Petrosian")) targetMode = "Petrosian";
    if (currentZone.name.contains("Capablanca")) targetMode = "Capablanca";

    // Invia il comando UCI specifico per ShashChess o Alexander
    engineManager.sendCommand('setoption name ShashinMode value $targetMode');

    Future.delayed(const Duration(milliseconds: 50), () {
      if (currentState == FsmState.phase2) {
        engineManager.sendCommand('go movetime $t2');
        _isSearchingPhase2 = true;
      }
    });
  }

  /// Passa all'iterazione successiva e riavvia
  void _loopBackToPhase1() {
    _iteration++; // Incremento lineare (1, 2, 3, 4...)
    onLog("🔄 Preparazione Ciclo $_iteration con tempi lineari...");
    _runPhase1();
  }

  /// Ferma tutto
  void stop() {
    engineManager.sendCommand('stop');
    currentState = FsmState.idle;
    _isSearchingPhase1 = false;
    _isSearchingPhase2 = false;
    onStateChanged(currentState);
    onLog("🛑 Analisi fermata.");
  }

  void dispose() {
    _outputSubscription?.cancel();
  }
}
