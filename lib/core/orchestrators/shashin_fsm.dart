import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/engine_manager.dart';
import '../logic/shashin_logic.dart';

enum FsmState { idle, phase1, phase2 }

class EngineStats {
  final int depth;
  final int selDepth;
  final int nodes;
  final int nps;
  final List<String> pvs;
  final String score; // ⚠️ NUOVO: Il valore in CP o Mate

  const EngineStats({
    this.depth = 0,
    this.selDepth = 0,
    this.nodes = 0,
    this.nps = 0,
    this.pvs = const [],
    this.score = "", // ⚠️ Valore di default
  });
}

class ShashinFsm {
  final EngineManager engineManager;
  FsmState currentState = FsmState.idle;
  StreamSubscription<String>? _outputSubscription;

  ShashinZone currentZone = ShashinZone(
    "In attesa...",
    "-",
    Colors.grey,
    50.0,
    ["assets/images/capablanca.png"],
  );

  final Function(String) onLog;
  final Function(ShashinZone) onZoneChanged;
  final Function(FsmState) onStateChanged;
  final Function(String) onPvUpdate;
  final Function(EngineStats) onStatsUpdate;
  final Function(String) onOptionFound;

  bool _isSearchingPhase1 = false;
  bool _isSearchingPhase2 = false;
  int _baseTimeMs = 1500;
  int _iteration = 1;
  String currentFen = "";

  final Map<int, String> _multiPvMap = {};

  // ⚠️ NUOVE VARIABILI DI STATO PER IL DEBOUNCE GRAFICO
  int _currentDepth = 0;
  int _currentSelDepth = 0;
  int _currentNodes = 0;
  int _currentNps = 0;
  String _currentScore = "";
  bool _statsUpdatePending = false;

  ShashinFsm({
    required this.engineManager,
    required this.onLog,
    required this.onZoneChanged,
    required this.onStateChanged,
    required this.onPvUpdate,
    required this.onStatsUpdate,
    required this.onOptionFound,
  }) {
    _outputSubscription = engineManager.engineOutput?.listen(
      _handleEngineOutput,
    );
  }

  void _handleEngineOutput(String line) {
    final wdlMatch = RegExp(r"wdl (\d+) (\d+) (\d+)").firstMatch(line);
    if (wdlMatch != null) {
      int w = int.parse(wdlMatch.group(1)!);
      int d = int.parse(wdlMatch.group(2)!);
      int l = int.parse(wdlMatch.group(3)!);
      currentZone = analyzeShashinZone(w, d, l);
      onZoneChanged(currentZone);
    }

    if (line.startsWith("info")) {
      if (!line.contains("depth") &&
          !line.contains("nodes") &&
          !line.contains("pv")) {
        return;
      }

      // 1. Aggiorniamo silenziosamente i dati in RAM appena arrivano
      final dMatch = RegExp(r"depth (\d+)").firstMatch(line);
      if (dMatch != null) _currentDepth = int.parse(dMatch.group(1)!);

      final sdMatch = RegExp(r"seldepth (\d+)").firstMatch(line);
      if (sdMatch != null) _currentSelDepth = int.parse(sdMatch.group(1)!);

      final nMatch = RegExp(r"nodes (\d+)").firstMatch(line);
      if (nMatch != null) _currentNodes = int.parse(nMatch.group(1)!);

      final npsMatch = RegExp(r"nps (\d+)").firstMatch(line);
      if (npsMatch != null) _currentNps = int.parse(npsMatch.group(1)!);

      // ⚠️ LA MAGIA PER I CENTIPEDONI E IL MATE
      final cpMatch = RegExp(r"score cp (-?\d+)").firstMatch(line);
      if (cpMatch != null) {
        int cpVal = int.parse(cpMatch.group(1)!);
        _currentScore = (cpVal / 100.0).toStringAsFixed(2);
        if (cpVal > 0)
          _currentScore = "+$_currentScore"; // Aggiunge il + ai positivi
      } else {
        final mateMatch = RegExp(r"score mate (-?\d+)").firstMatch(line);
        if (mateMatch != null) {
          _currentScore = "M${mateMatch.group(1)}";
        }
      }

      int multipv =
          int.tryParse(
            RegExp(r"multipv (\d+)").firstMatch(line)?.group(1) ?? "1",
          ) ??
          1;
      String? fullPv = RegExp(r" pv (.*)$").firstMatch(line)?.group(1);

      if (fullPv != null && fullPv.isNotEmpty) {
        _multiPvMap[multipv] = fullPv;
      }

      // 2. ⚠️ IL NUOVO THROTTLE INTELLIGENTE
      // Invece di bloccare le righe, imposta un timer. Se arrivano 5 righe nello stesso istante,
      // il timer scatta una volta sola dopo 200ms e spedisce tutta la mappa aggiornata alla UI!
      if (!_statsUpdatePending && (_currentDepth > 0 || _currentNodes > 0)) {
        _statsUpdatePending = true;
        Future.delayed(const Duration(milliseconds: 200), () {
          _statsUpdatePending = false;

          final sortedKeys = _multiPvMap.keys.toList()..sort();
          final currentPvs = sortedKeys.map((k) => _multiPvMap[k]!).toList();

          onStatsUpdate(
            EngineStats(
              depth: _currentDepth,
              selDepth: _currentSelDepth,
              nodes: _currentNodes,
              nps: _currentNps,
              pvs: currentPvs,
              score: _currentScore,
            ),
          );
        });
      }

      // La freccia rossa reagisce solo alla linea principale (multipv = 1)
      if (multipv == 1 && fullPv != null && fullPv.isNotEmpty) {
        String firstMove = fullPv.trim().split(' ').first;
        onPvUpdate(firstMove);
      }
    }

    if (line.startsWith("option name")) {
      onOptionFound(line);
    }

    if (line.startsWith("bestmove")) {
      if (currentState == FsmState.phase1 && _isSearchingPhase1) {
        _isSearchingPhase1 = false;
        _startPhase2();
      } else if (currentState == FsmState.phase2 && _isSearchingPhase2) {
        _isSearchingPhase2 = false;
        _loopBackToPhase1();
      }
    }
  }

  void startAnalysis(String fen, {int baseTimeMs = 1500}) {
    engineManager.sendCommand('stop');
    currentFen = fen;
    _baseTimeMs = baseTimeMs;
    _iteration = 1;

    // Reset di tutta la RAM per il nuovo calcolo
    _multiPvMap.clear();
    _currentDepth = 0;
    _currentSelDepth = 0;
    _currentNodes = 0;
    _currentNps = 0;

    onLog("===========================================");
    _runPhase1();
  }

  void _runPhase1() {
    currentState = FsmState.phase1;
    _isSearchingPhase1 = false;
    _isSearchingPhase2 = false;
    onStateChanged(currentState);

    int t1 = min(_baseTimeMs * _iteration, 30000);
    onLog("⏱️ CICLO $_iteration | FASE 1: Lettura Termodinamica (${t1}ms)...");

    Future.delayed(const Duration(milliseconds: 200), () {
      if (currentState == FsmState.phase1) {
        engineManager.sendCommand('position fen $currentFen');
        engineManager.sendCommand('go movetime $t1');
        _isSearchingPhase1 = true;
      }
    });
  }

  void _startPhase2() {
    currentState = FsmState.phase2;
    onStateChanged(currentState);

    int t2 = (_baseTimeMs * _iteration) * 2;
    onLog(
      "🎯 CICLO $_iteration | FASE 2: Calcolo [ ${currentZone.name.toUpperCase()} ] (${t2}ms)...",
    );

    // ⚠️ FIX P4: Usa la variabile shashinMode nativa della zona, senza string matching!
    engineManager.sendCommand(
      'setoption name ShashinMode value ${currentZone.shashinMode}',
    );

    Future.delayed(const Duration(milliseconds: 50), () {
      if (currentState == FsmState.phase2) {
        engineManager.sendCommand('go movetime $t2');
        _isSearchingPhase2 = true;
      }
    });
  }

  void _loopBackToPhase1() {
    _iteration++;
    onLog("🔄 Preparazione Ciclo $_iteration con tempi lineari...");
    _runPhase1();
  }

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
