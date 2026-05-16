import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../domain/autoplay_controller.dart';
import 'widgets/board_section.dart';
import 'widgets/analysis_panel.dart';
import 'widgets/engine_controls.dart';
import 'widgets/notation_panel.dart'; // ⚠️ IMPORTIAMO IL PANNELLO DELLE MOSSE!
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../../core/services/import_export_service.dart'; // ⚠️ AGGIUNTO L'IMPORT MANCANTE!

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
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF2b2b2b),
              title: const Text(
                "🏆 Torneo Concluso!",
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${next.whiteEngine.toUpperCase()} vs ${next.blackEngine.toUpperCase()}",
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 16,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Text(
                    "Vittorie Bianco: ${next.scoreWhite}",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    "Vittorie Nero: ${next.scoreBlack}",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    "Patte: ${next.draws}",
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
              actions: [
                // NUOVO BOTTONE PER CONDIVIDERE IL FILE PGN DEL TORNEO!
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx); // Chiude il popup
                    try {
                      final directory =
                          await getApplicationDocumentsDirectory();
                      // ⚠️ CORRETTO: rimosso "java.io."
                      final file = File(
                        '${directory.path}/gauntlet_results.pgn',
                      );
                      if (await file.exists()) {
                        final contents = await file.readAsString();
                        // Usiamo il tuo servizio per aprire il menu di condivisione di Android
                        ImportExportService.exportPgn(contents);
                      }
                    } catch (e) {
                      debugPrint("Errore esportazione: $e");
                    }
                  },
                  child: const Text(
                    "CONDIVIDI PGN",
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: const Text(
                    "CHIUDI",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
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
