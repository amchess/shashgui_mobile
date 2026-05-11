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
  final String pv;

  const EngineStats({
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
  DateTime _lastStatsTime = DateTime.now();
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
      // ⚠️ FIX ANTI 0/0
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
          int.tryParse(
            RegExp(r"nps (\d+)").firstMatch(line)?.group(1) ?? "0",
          ) ??
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

      if (fullPv != null && fullPv.isNotEmpty) {
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

    String targetMode = "Normal";
    if (currentZone.name.contains("Tal")) targetMode = "Tal";
    if (currentZone.name.contains("Petrosian")) targetMode = "Petrosian";
    if (currentZone.name.contains("Capablanca")) targetMode = "Capablanca";

    engineManager.sendCommand('setoption name ShashinMode value $targetMode');

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
