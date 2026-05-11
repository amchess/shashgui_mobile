import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1a1a1a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, color: Colors.amberAccent, size: 28),
                  SizedBox(width: 10),
                  Text(
                    "RISULTATO TORNEO",
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "${next.whiteEngine.toUpperCase()}: ${next.scoreWhite}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "vs",
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  Text(
                    "${next.blackEngine.toUpperCase()}: ${next.scoreBlack}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (next.draws > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      "Patte: ${next.draws}",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const Divider(color: Colors.white24, height: 30),
                  const Text(
                    "Tutte le partite sono state salvate nel file locale\n'gauntlet_results.pgn'",
                    style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final directory =
                          await getApplicationDocumentsDirectory();
                      final path = '${directory.path}/gauntlet_results.pgn';
                      final file = File(path);

                      if (await file.exists()) {
                        await Share.shareXFiles(
                          [XFile(path)],
                          text:
                              'Ecco i risultati del torneo Gauntlet su ShashGui Mobile!',
                        );
                      } else {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text("File PGN non trovato."),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      debugPrint("Errore durante la condivisione: $e");
                    }
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text(
                    "CONDIVIDI PGN",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    "CHIUDI",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
      body: const Column(
        children: [
          Expanded(flex: 6, child: Center(child: BoardSection())),

          // ⚠️ ECCO LA FINESTRA DELLA NOTAZIONE E DELL'ALBERO VARIANTI!
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: NotationPanel(),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: AnalysisPanel(),
          ),
          Spacer(),
          EngineControls(),
        ],
      ),
    );
  }
}
