import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ⚠️ FIX: Abbiamo aggiunto un "../" in più per risalire correttamente alla cartella "domain"!
import '../../domain/engine_controller.dart';
import '../../domain/board_provider.dart';

class AnalysisSetupModal extends ConsumerStatefulWidget {
  const AnalysisSetupModal({super.key});
  @override
  ConsumerState<AnalysisSetupModal> createState() => _AnalysisSetupModalState();
}

class _AnalysisSetupModalState extends ConsumerState<AnalysisSetupModal> {
  String _selectedEngine = 'shashchess';
  double _t1 = 2.0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2b2b2b),
      title: const Text(
        "Configura Analisi",
        style: TextStyle(color: Colors.orangeAccent),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<String>(
            value: _selectedEngine,
            isExpanded: true,
            dropdownColor: const Color(0xFF2b2b2b),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            items: [
              DropdownMenuItem(
                value: 'shashchess',
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/shashchess.bmp',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text("ShashChess (NNUE)"),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'alexander',
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/alexander.bmp',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text("Alexander (HCE)"),
                  ],
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedEngine = v!),
          ),
          const SizedBox(height: 20),
          Text(
            "Tempo base T1: ${_t1.toInt()} secondi",
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          Slider(
            value: _t1,
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: Colors.cyanAccent,
            onChanged: (v) => setState(() => _t1 = v),
          ),
          const Text(
            "Il tempo raddoppierà in Fase 2.",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ANNULLA", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Avvia il motore passando sia il FEN che il tempo T1 in millisecondi!
            ref
                .read(engineControllerProvider.notifier)
                .startEngine(
                  ref.read(boardControllerProvider).getFen(),
                  baseTimeMs: (_t1 * 1000).toInt(),
                  engineName: _selectedEngine,
                );
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
          child: const Text("AVVIA", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
