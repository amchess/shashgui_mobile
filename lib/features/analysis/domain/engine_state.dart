import '../../../core/orchestrators/shashin_fsm.dart';
import '../../../core/logic/shashin_logic.dart';

// Questa classe rappresenta l'istantanea esatta del tuo motore in un dato momento.
class EngineState {
  final bool isRunning;
  final String selectedEngine;
  final EngineStats stats;
  final ShashinZone zone;
  final List<String> outputLines;
  final String threatMoveUci; // ⚠️ NUOVO: Memorizza la mossa della minaccia

  EngineState({
    this.isRunning = false,
    this.selectedEngine = 'shashchess',
    this.stats = const EngineStats(),
    required this.zone,
    this.outputLines = const [],
    this.threatMoveUci = "", // ⚠️ Default vuoto per la minaccia
  });

  // Il copyWith è fondamentale in Riverpod per aggiornare solo un pezzo dello stato
  EngineState copyWith({
    bool? isRunning,
    String? selectedEngine,
    EngineStats? stats,
    ShashinZone? zone,
    List<String>? outputLines,
    String? threatMoveUci, // ⚠️ Aggiunto al copyWith
  }) {
    return EngineState(
      isRunning: isRunning ?? this.isRunning,
      selectedEngine: selectedEngine ?? this.selectedEngine,
      stats: stats ?? this.stats,
      zone: zone ?? this.zone,
      outputLines: outputLines ?? this.outputLines,
      threatMoveUci: threatMoveUci ?? this.threatMoveUci, // ⚠️ Assegnazione
    );
  }
}
