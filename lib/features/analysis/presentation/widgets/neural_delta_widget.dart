import 'package:flutter/material.dart';
import '../../../../core/logic/shash_trace_models.dart';

class NeuralDeltaWidget extends StatelessWidget {
  final AdvancedShashTrace trace;

  const NeuralDeltaWidget({super.key, required this.trace});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Comprensione Globale Rete:",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${trace.baseWinProbability.toStringAsFixed(0)}% Win Prob.",
                style: TextStyle(
                  color: Colors.blue.shade300,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra a segmenti speculari
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  // Segmento Percezione Materiale Pura (PSQT)
                  Expanded(
                    flex: trace.materialPsqtWp.round(),
                    child: Container(
                      color: Colors.grey.shade400,
                      child: const Center(
                        child: Text(
                          "Materiale",
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Segmento Delta Astratto / Posizionale
                  if (trace.structuralDeltaWp != 0)
                    Expanded(
                      flex: trace.structuralDeltaWp.abs().round(),
                      child: Container(
                        color: trace.structuralDeltaWp > 0
                            ? Colors.blue
                            : Colors.red,
                        child: Center(
                          child: Text(
                            trace.structuralDeltaWp > 0
                                ? "+Pattern"
                                : "-Pattern",
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Spazio rimanente per arrivare al 100% di probabilità complessiva
                  Expanded(
                    flex:
                        (100 - (trace.materialPsqtWp + trace.structuralDeltaWp))
                            .round()
                            .clamp(0, 100),
                    child: Container(color: Colors.black26),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Nota: La rete calcola un incremento strutturale del ${trace.structuralDeltaWp.toStringAsFixed(0)}% "
            "dovuto a geometrie di pattern e coordinazione non spiegabili dal solo conteggio dei pezzi.",
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
