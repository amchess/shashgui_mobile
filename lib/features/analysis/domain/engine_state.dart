import 'package:flutter/material.dart'; // ⚠️ Aggiunto per poter usare i Color
import '../../../core/orchestrators/shashin_fsm.dart';
import '../../../core/logic/shashin_logic.dart';

// Questa classe rappresenta l'istantanea esatta del tuo motore in un dato momento.
class EngineState {
  final bool isRunning;
  final String selectedEngine;
  final EngineStats stats;
  final ShashinZone zone;
  final List<String> outputLines;
  final String threatMoveUci;

  // ⚠️ CAMPI PER LE MINACCE RAFFINATE XAI
  final int? threatDrop;
  final Color? threatColor;
  final int
  currentBaseTimeMs; // ⚠️ NUOVO CAMPO: Tempo base per la coerenza del radar

  EngineState({
    this.isRunning = false,
    this.selectedEngine = 'shashchess',
    this.stats = const EngineStats(),
    required this.zone,
    this.outputLines = const [],
    this.threatMoveUci = "",
    this.threatDrop,
    this.threatColor,
    this.currentBaseTimeMs = 1500, // ⚠️ Valore di default
  });

  // Il copyWith è fondamentale in Riverpod per aggiornare solo un pezzo dello stato
  EngineState copyWith({
    bool? isRunning,
    String? selectedEngine,
    EngineStats? stats,
    ShashinZone? zone,
    List<String>? outputLines,
    String? threatMoveUci,
    int? threatDrop,
    Color? threatColor,
    int? currentBaseTimeMs, // ⚠️ AGGIUNTO
  }) {
    return EngineState(
      isRunning: isRunning ?? this.isRunning,
      selectedEngine: selectedEngine ?? this.selectedEngine,
      stats: stats ?? this.stats,
      zone: zone ?? this.zone,
      outputLines: outputLines ?? this.outputLines,
      threatMoveUci: threatMoveUci ?? this.threatMoveUci,
      threatDrop: threatDrop ?? this.threatDrop,
      threatColor: threatColor ?? this.threatColor,
      currentBaseTimeMs:
          currentBaseTimeMs ?? this.currentBaseTimeMs, // ⚠️ AGGIUNTO
    );
  }
}
