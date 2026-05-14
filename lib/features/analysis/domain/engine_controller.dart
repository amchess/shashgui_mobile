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
    state = state.copyWith(isRunning: true, selectedEngine: engineName);
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

  Future<void> scanThreats(String currentFen) async {
    if (!state.isRunning) return;

    // 1. Ferma l'analisi attuale
    _fsm?.stop();
    _engineManager.sendCommand('stop');

    // 2. Manipola la FEN per cedere il turno (Null Move)
    List<String> fenParts = currentFen.split(' ');
    fenParts[1] = (fenParts[1] == 'w') ? 'b' : 'w'; // Inverte turno
    fenParts[3] = '-'; // Rimuove catture en-passant
    String nullMoveFen = fenParts.join(' ');

    // 3. Aspetta un istante per far pulire il buffer
    await Future.delayed(const Duration(milliseconds: 100));
    _engineManager.sendCommand('position fen $nullMoveFen');
    _engineManager.sendCommand('go movetime 1500');

    int? calcoloThreatDrop; // Variabile temporanea per immagazzinare il calo

    StreamSubscription<String>? threatSub;
    threatSub = _engineManager.engineOutput?.listen((line) {
      // NUOVO: Ascoltiamo la valutazione della posizione durante la mossa nulla
      final wdlMatch = RegExp(r"wdl (\d+) (\d+) (\d+)").firstMatch(line);
      if (wdlMatch != null) {
        int w = int.parse(wdlMatch.group(1)!);
        int d = int.parse(wdlMatch.group(2)!);
        int l = int.parse(wdlMatch.group(3)!);

        // Questa è la valutazione dal punto di vista dell'avversario
        ShashinZone opponentZone = analyzeShashinZone(w, d, l);

        // La nostra WP aggiornata è speculare a quella dell'avversario
        double ourNewWp = 100.0 - opponentZone.wp;

        // Calcoliamo di quante zone cadiamo rispetto a state.zone.wp attuale
        calcoloThreatDrop = calculateZoneDrop(ourNewWp, state.zone.wp);
      }

      // QUANDO IL MOTORE SPUTA LA MINACCIA
      if (line.startsWith('bestmove')) {
        threatSub?.cancel();
        final parts = line.split(' ');

        if (parts.length > 1 && parts[1] != '(none)' && parts[1] != '0000') {
          // Ha trovato una minaccia! Aggiorna lo stato globale con la mossa e il calo
          state = state.copyWith(
            threatMoveUci: parts[1],
            threatDrop: calcoloThreatDrop ?? 0, // <-- SALVIAMO IL CALO QUI!
          );

          // Lascia la freccia visibile per 3 secondi, poi ripristina la normalità
          Future.delayed(const Duration(seconds: 3), () {
            if (state.isRunning) {
              state = state.copyWith(threatMoveUci: "", threatDrop: 0);
              analyzeCurrentPosition(currentFen);
            }
          });
        } else {
          // Nessuna minaccia trovata
          analyzeCurrentPosition(currentFen);
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
