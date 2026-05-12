import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../domain/autoplay_controller.dart';
import 'widgets/board_section.dart';
import 'widgets/analysis_panel.dart';
import 'widgets/engine_controls.dart';
import 'widgets/notation_panel.dart'; // ⚠️ IMPORTIAMO IL PANNELLO DELLE MOSSE!

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;

    // Ascoltiamo i cambiamenti dell'Autoplay per mostrare il pop-up finale
    ref.listen<AutoplayState>(autoplayControllerProvider, (previous, next) {
      if (previous != null &&
          previous.isPlaying == true &&
          next.isPlaying == false) {
        if (next.currentLog == "🏆 Torneo Concluso!") {
          // ... (Il codice del popup rimane identico, non lo riscrivo per brevità)
          // Lascia pure il tuo blocco ref.listen invariato!
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.shashguiLaboratorio),
        backgroundColor: const Color(0xFF1e1e1e),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ⚠️ 1. LA MAGIA: Scacchiera bloccata alla grandezza massima del telefono!
          SizedBox(
            width: MediaQuery.of(context).size.width,
            // Aggiungiamo 70px per lasciare spazio alla pulsantiera (avanti/indietro)
            height: MediaQuery.of(context).size.width + 70,
            child: const BoardSection(),
          ),

          // ⚠️ 2. Tutto il resto diventa scrollabile, così non schiaccerà MAI la scacchiera!
          const Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: NotationPanel(),
                  ),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: AnalysisPanel(),
                  ),
                  SizedBox(height: 8),
                  EngineControls(),
                  SizedBox(height: 24), // Un po' di respiro a fondo pagina
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
