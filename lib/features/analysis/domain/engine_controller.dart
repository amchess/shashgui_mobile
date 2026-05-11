import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../core/engine/engine_manager.dart';
import '../../../core/logic/shashin_logic.dart';
import '../../../core/orchestrators/shashin_fsm.dart';
import 'engine_state.dart';

final engineControllerProvider =
    StateNotifierProvider<EngineController, EngineState>((ref) {
      return EngineController();
    });

class EngineController extends StateNotifier<EngineState> {
  EngineManager _engineManager = EngineManager();
  ShashinFsm? _fsm;

  EngineController()
    : super(
        EngineState(
          zone: ShashinZone("In attesa...", "-", Colors.grey, 50.0, [
            "assets/images/capablanca.png",
          ]),
        ),
      );

  Future<void> startEngine(
    String fen, {
    int baseTimeMs = 1500,
    String engineName = 'shashchess',
  }) async {
    state = state.copyWith(isRunning: true, selectedEngine: engineName);

    try {
      // Se l'utente ha scelto un motore diverso, puliamo quello vecchio
      if (_engineManager.engineOutput != null &&
          engineName != state.selectedEngine) {
        _engineManager.dispose();
        _engineManager = EngineManager();
      }

      // Se il motore non è acceso, lo inizializziamo
      if (_engineManager.engineOutput == null) {
        await _engineManager.initEngine(engineName, [
          'nn-c288c895ea92.nnue',
          'nn-37f18f62d772.nnue',
        ]);

        // ⚠️ IL FIX MAGICO: Creiamo la FSM *SOLO DOPO* che l'engine è inizializzato!
        // Così si aggancerà al flusso dati corretto e non a un "null".
        _fsm?.dispose();
        _fsm = ShashinFsm(
          engineManager: _engineManager,
          onLog: (log) =>
              state = state.copyWith(outputLines: [...state.outputLines, log]),
          onZoneChanged: (zone) => state = state.copyWith(zone: zone),
          onStateChanged: (fsmState) {},
          onPvUpdate: (pv) {},
          onStatsUpdate: (stats) => state = state.copyWith(stats: stats),
          onOptionFound: (opt) {},
        );
      }

      _fsm!.startAnalysis(fen, baseTimeMs: baseTimeMs);
    } catch (e) {
      state = state.copyWith(isRunning: false);
    }
  }

  void analyzeCurrentPosition(String fen, {int baseTimeMs = 1500}) {
    if (state.isRunning && _fsm != null) {
      _fsm!.startAnalysis(fen, baseTimeMs: baseTimeMs);
    }
  }

  void stopEngine() {
    _fsm?.stop();
    _engineManager.sendCommand('stop');
    state = state.copyWith(
      isRunning: false,
      zone: ShashinZone("Analisi Fermata", "-", Colors.grey, 50.0, [
        "assets/images/capablanca.png",
      ]),
    );
  }

  @override
  void dispose() {
    _fsm?.dispose();
    _engineManager.dispose();
    super.dispose();
  }
}
