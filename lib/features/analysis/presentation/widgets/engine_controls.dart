import 'package:flutter/foundation.dart'; // Aggiunto per 'compute'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/engine_controller.dart';
import '../../domain/board_provider.dart';
import '../../domain/notation_controller.dart';
import '../../../../core/widgets/setup_position_dialog.dart';
import 'autoplay_modal.dart';
import 'livebook_modal.dart';
import 'coach_modal.dart';
import '../../domain/autoplay_controller.dart';
import 'analysis_setup_modal.dart';
import '../../../../core/services/import_export_service.dart';
import 'package:chess/chess.dart' as chess_lib;

// ============================================================================
// ⚠️ CLASSI E FUNZIONI PER IL MULTI-THREADING (ISOLATE)
// ============================================================================

// Questa classe serve a impacchettare i dati per farli viaggiare tra i thread
class ParsedMoveData {
  final String san;
  final String fen;
  final String? comment;
  ParsedMoveData(this.san, this.fen, this.comment);
}

// ⚠️ QUESTA FUNZIONE GIRA NEL BACKGROUND THREAD (ISOLATE)
// Non può accedere alla UI né a Riverpod. Riceve un testo, restituisce dati puri.
List<ParsedMoveData> _parsePgnInBackground(String text) {
  List<ParsedMoveData> resultList = [];
  String startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  // 1. Estrazione FEN di partenza se presente
  final fenMatch = RegExp(r'\[FEN\s+"([^"]+)"\]').firstMatch(text);
  if (fenMatch != null) {
    startFen = fenMatch.group(1)!;
  }

  // 2. Pulizia PGN e rimozione Header/Varianti
  String movesText = text
      .replaceAll(RegExp(r'^\[.*\]\s*', multiLine: true), '')
      .trim();
  movesText = movesText.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  movesText = movesText.replaceAll(
    RegExp(r'\}\s*\{'),
    ' | ',
  ); // Uniamo commenti adiacenti
  movesText = movesText.replaceAll(RegExp(r'\d+\s*\.+\s*'), ' ').trim();
  movesText = movesText
      .replaceAll(RegExp(r'(1-0|0-1|1/2-1/2|\*)\s*$'), ' ')
      .trim();

  // 3. Estrazione Mossa + Commento
  final moveRegex = RegExp(r'([a-zA-Z0-9O\-+#=?!$]+)(?:\s*\{([^}]*)\})?');
  final matches = moveRegex.allMatches(movesText);

  // 4. Simulazione e validazione virtuale
  final tempChess = chess_lib.Chess.fromFEN(startFen);

  for (var match in matches) {
    String san = match.group(1)!;
    String cleanSan = san
        .replaceAll(RegExp(r'[?!]'), '')
        .replaceAll(RegExp(r'\$\d+'), '');
    String? comment = match.group(2)?.trim();

    final success = tempChess.move(cleanSan);
    if (success != false) {
      resultList.add(ParsedMoveData(san, tempChess.fen, comment));
    }
  }

  return resultList;
}

// ============================================================================
// FINE BLOCCO ISOLATE
// ============================================================================

class EngineControls extends ConsumerWidget {
  const EngineControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineState = ref.watch(engineControllerProvider);
    final autoplayState = ref.watch(autoplayControllerProvider);
    final boardController = ref.watch(boardControllerProvider);
    final loc = AppLocalizations.of(context)!;

    void loadImportedText(String text) async {
      try {
        if (text.contains('[Event') || text.contains('1.')) {
          // 1. Diamo un feedback visivo immediato all'utente
          if (!context.mounted) return; // ⚠️ FIX LINTER
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Elaborazione PGN in background in corso..."),
              duration: Duration(seconds: 1),
            ),
          );

          // 2. AVVIAMO IL PARSING IN UN THREAD SEPARATO TRAMITE 'compute'
          final parsedMoves = await compute(_parsePgnInBackground, text);

          if (!context.mounted) return; // ⚠️ FIX LINTER: Controllo post-await

          if (parsedMoves.isEmpty) {
            throw Exception("Nessuna mossa valida trovata nel testo.");
          }

          // 3. Torniamo sul Thread Principale per applicare i risultati alla UI in 1 istante!
          String startFen =
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
          final fenMatch = RegExp(r'\[FEN\s+"([^"]+)"\]').firstMatch(text);
          if (fenMatch != null) startFen = fenMatch.group(1)!;

          boardController.loadFen(startFen);
          ref.read(notationControllerProvider.notifier).reset();

          // Aggiunge tutto all'albero velocemente
          for (var move in parsedMoves) {
            ref
                .read(notationControllerProvider.notifier)
                .addMove(move.san, move.fen, 'main', comment: move.comment);
          }

          boardController.loadFen(parsedMoves.last.fen);
          ref.read(notationControllerProvider.notifier).goToEnd();
        } else {
          // Caricamento FEN singola (Istantaneo, non serve Isolate)
          boardController.loadFen(text);
          ref.read(notationControllerProvider.notifier).reset();
        }

        if (engineState.isRunning) {
          ref
              .read(engineControllerProvider.notifier)
              .analyzeCurrentPosition(boardController.getFen());
        }

        if (!context.mounted) {
          return; // ⚠️ FIX LINTER: Controllo finale prima del messaggio di successo
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.partitaCaricataConSuccesso)));
      } catch (e) {
        debugPrint("ERRORE IMPORTAZIONE: $e");
        if (!context.mounted) {
          return; // ⚠️ FIX LINTER: Controllo anche nel blocco catch
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Errore: $e")));
      }
    }

    void showPasteDialog() {
      final textController = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2b2b2b),
          title: Text(
            loc.importaLinkLichessIncollaPgn,
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: textController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: loc.incollaUnLinkLichessUnFenOUnPg,
              hintStyle: const TextStyle(color: Colors.grey),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                loc.annulla,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  if (text.contains('lichess.org')) {
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Download da Lichess...")),
                      );
                      final pgn = await ImportExportService().fetchLichessGame(
                        text,
                      );
                      if (!context.mounted) return;
                      loadImportedText(pgn);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Errore Lichess: $e")),
                      );
                    }
                  } else {
                    loadImportedText(text);
                  }
                }
              },
              child: Text(loc.importa),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 4,
      ), // Padding laterale ridotto
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a1a),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: SafeArea(
        // ⚠️ FITTEDBOX: Il trucco per far entrare 6 bottoni su schermi stretti senza causare errori!
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: engineState.isRunning
                    ? Icons.stop_circle
                    : Icons.power_settings_new,
                color: engineState.isRunning
                    ? Colors.redAccent
                    : Colors.greenAccent,
                label: engineState.isRunning ? "Stop" : loc.accendi,
                onPressed: () {
                  if (engineState.isRunning) {
                    ref.read(engineControllerProvider.notifier).stopEngine();
                  } else {
                    showDialog(
                      context: context,
                      builder: (context) => const AnalysisSetupModal(),
                    );
                  }
                },
              ),

              _buildControlButton(
                icon: Icons.folder_open,
                color: Colors.white70,
                label:
                    "PGN/FEN", // Ridotto il testo da "PGN / FEN" per recuperare spazio
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF1a1a1a),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ListTile(
                            leading: const Icon(
                              Icons.grid_on,
                              color: Colors.orangeAccent,
                            ),
                            title: Text(
                              loc.editorVisivoFen,
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final newFen = await showDialog<String>(
                                context: context,
                                builder: (context) => SetupPositionDialog(
                                  initialFen: boardController.getFen(),
                                ),
                              );
                              if (!context.mounted) return; // ⚠️ FIX LINTER
                              if (newFen != null) loadImportedText(newFen);
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.file_open,
                              color: Colors.blueAccent,
                            ),
                            title: Text(
                              loc.apriFilePgnfen,
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              try {
                                final content = await ImportExportService()
                                    .pickAndReadFile();
                                if (!context.mounted) return;
                                if (content != null) loadImportedText(content);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Errore: $e")),
                                );
                              }
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.link,
                              color: Colors.greenAccent,
                            ),
                            title: Text(
                              loc.importaLinkLichessIncollaPgn,
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              showPasteDialog();
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),

              _buildControlButton(
                icon: Icons.menu_book,
                color: Colors.blueAccent,
                label: loc.livebook,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const LivebookModal(),
                  );
                },
              ),

              // ⚠️ IL PULSANTE DELLE MINACCE RIPRISTINATO
              _buildControlButton(
                icon: Icons.crisis_alert,
                color: Colors.redAccent,
                label: loc.rilevaMinacce,
                onPressed: () {
                  if (!engineState.isRunning) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Accendi il motore per usare questa funzione.",
                        ),
                      ),
                    );
                    return;
                  }

                  if (boardController.game.in_check) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc.impossibileAnalizzareLeMinacce),
                      ),
                    );
                    return;
                  }
                  if (boardController.getFen().contains(
                    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w",
                  )) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc.nessunaMinacciaAllaMossaInizia),
                      ),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Scansione minacce in corso..."),
                      duration: Duration(seconds: 1),
                    ),
                  );

                  ref
                      .read(engineControllerProvider.notifier)
                      .scanThreats(boardController.getFen());
                },
              ),

              _buildControlButton(
                icon: Icons.psychology,
                color: Colors.orangeAccent,
                label: "Coach",
                onPressed: () {
                  if (engineState.isRunning) {
                    ref.read(engineControllerProvider.notifier).stopEngine();
                  }
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CoachModal(),
                  );
                },
              ),

              _buildControlButton(
                icon: autoplayState.isPlaying
                    ? Icons.stop_circle
                    : Icons.smart_toy,
                color: autoplayState.isPlaying
                    ? Colors.redAccent
                    : Colors.purpleAccent,
                label: autoplayState.isPlaying ? "Ferma" : "Torneo",
                onPressed: () {
                  if (autoplayState.isPlaying) {
                    ref.read(autoplayControllerProvider.notifier).stopMatch();
                  } else {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const AutoplayModal(),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 10.0,
        ), // Margini orizzontali ridotti da 12 a 10
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ), // ⚠️ Font ridotto per accomodare 6 bottoni
            ),
          ],
        ),
      ),
    );
  }
}
