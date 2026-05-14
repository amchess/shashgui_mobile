import 'dart:async'; // ⚠️ Necessario per StreamSubscription
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    // ⚠️ Salva il tempo scelto dall'utente nello stato per usi futuri (es. Radar)
    state = state.copyWith(
      isRunning: true,
      selectedEngine: engineName,
      currentBaseTimeMs: baseTimeMs,
    );

    try {
      // 1. Inizializza il motore se non esiste o se è cambiato
      if (_engineManager.engineOutput == null ||
          engineName != state.selectedEngine) {
        _engineManager.dispose();
        _engineManager = EngineManager();

        await _engineManager.initEngine(engineName, [
          'nn-c288c895ea92.nnue',
          'nn-37f18f62d772.nnue',
        ]);

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

      // 2. ⚠️ APPLICA LE OPZIONI: Carica le preferenze e inviale al motore
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('${engineName}_'));
      for (var key in keys) {
        final optionName = key.replaceFirst('${engineName}_', '');
        final value = prefs.getString(key);
        if (value != null && value.isNotEmpty) {
          _engineManager.sendCommand('setoption name $optionName value $value');
        }
      }

      // 3. ⚠️ BARRIERA DI SINCRONIZZAZIONE (Il Fix Magico)
      // Costringe il motore a digerire le opzioni (es. MultiPV=2) prima di ricevere il comando 'go'
      _engineManager.sendCommand('isready');
      await Future.delayed(const Duration(milliseconds: 50));

      _fsm!.startAnalysis(fen, baseTimeMs: baseTimeMs);
    } catch (e) {
      state = state.copyWith(isRunning: false);
    }
  }

  // ⚠️ NUOVO METODO: Invia opzioni al motore attivo in tempo reale
  void setUciOption(String optionName, String value) {
    if (_engineManager.engineOutput != null) {
      _engineManager.sendCommand('setoption name $optionName value $value');
    }
  }

  void analyzeCurrentPosition(String fen, {int baseTimeMs = 1500}) {
    if (state.isRunning && _fsm != null) {
      _fsm!.startAnalysis(fen, baseTimeMs: baseTimeMs);
    }
  }

  // ⚠️ NUOVO METODO: Per resettare il radar manualmente tramite il pulsante Toggle
  void clearThreat() {
    state = state.copyWith(threatMoveUci: "", threatDrop: 0);
  }

  Future<void> scanThreats(String currentFen) async {
    if (!state.isRunning) return;

    _fsm?.stop();
    _engineManager.sendCommand('stop');

    // ====================================================================
    // ⚠️ IL FIX DEFINITIVO: CONGELIAMO LA WP DELLA NOSTRA POSIZIONE!
    // Siccome l'FSM continua ad ascoltare in background e a sporcare
    // lo state.zone con i calcoli della mossa nulla, salviamo il dato qui.
    // ====================================================================
    final double frozenOurWp = state.zone.wp;

    List<String> fenParts = currentFen.split(' ');
    fenParts[1] = (fenParts[1] == 'w') ? 'b' : 'w';
    fenParts[3] = '-';
    String nullMoveFen = fenParts.join(' ');

    _engineManager.sendCommand('setoption name ShashinMode value Normal');
    _engineManager.sendCommand('setoption name UCI_LimitStrength value false');

    await Future.delayed(const Duration(milliseconds: 100));
    _engineManager.sendCommand('position fen $nullMoveFen');

    // ⚠️ COERENZA TEMPORALE: Usiamo il tempo dell'analisi salvato nello stato
    _engineManager.sendCommand('go movetime ${state.currentBaseTimeMs}');

    int? calcoloThreatDrop;

    StreamSubscription<String>? threatSub;
    threatSub = _engineManager.engineOutput?.listen((line) {
      if (line.contains("wdl") && line.contains("multipv 1")) {
        final wdlMatch = RegExp(r"wdl (\d+) (\d+) (\d+)").firstMatch(line);

        if (wdlMatch != null) {
          int w = int.parse(wdlMatch.group(1)!);
          int d = int.parse(wdlMatch.group(2)!);
          int l = int.parse(wdlMatch.group(3)!);

          ShashinZone opponentNewZone = analyzeShashinZone(w, d, l);

          // ⚠️ USIAMO LA VARIABILE CONGELATA, IGNORIAMO LO STATO GLOBALE!
          double opponentCurrentWp = 100.0 - frozenOurWp;

          int currentZoneIndex = getZoneIndex(opponentCurrentWp);
          int newZoneIndex = getZoneIndex(opponentNewZone.wp);

          int jump = newZoneIndex - currentZoneIndex;

          // NOTA: Se preferisci che i micro-scatti di 1 singola zona in apertura
          // siano sempre considerati "Semplici Idee", cambia `jump > 0` con `jump > 1`.
          calcoloThreatDrop = jump > 0 ? jump : 0;
        }
      }

      if (line.startsWith('bestmove')) {
        threatSub?.cancel();
        final parts = line.split(' ');

        if (parts.length > 1 && parts[1] != '(none)' && parts[1] != '0000') {
          state = state.copyWith(
            threatMoveUci: parts[1],
            threatDrop: calcoloThreatDrop ?? 0,
          );
          // ⚠️ Rimosso il Future.delayed automatico!
          // La freccia rossa e il banner rimarranno visibili finché non si clicca
          // di nuovo il pulsante "Analisi" per fare lo switch back.
        } else {
          // ⚠️ Se non c'è minaccia, riprende l'analisi normale usando il tempo corretto
          analyzeCurrentPosition(
            currentFen,
            baseTimeMs: state.currentBaseTimeMs,
          );
        }
      }
    });
  }

  void stopEngine() {
    _fsm?.stop();
    _engineManager.sendCommand('stop');
    state = state.copyWith(
      isRunning: false,
      threatMoveUci: "", // ⚠️ Pulisce eventuali minacce rimaste a schermo
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
