import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../../domain/engine_controller.dart';
import '../../domain/board_provider.dart';
import '../../domain/notation_controller.dart'; // ⚠️ Import aggiunto per la notazione

class BoardSection extends ConsumerStatefulWidget {
  const BoardSection({super.key});

  @override
  ConsumerState<BoardSection> createState() => _BoardSectionState();
}

class _BoardSectionState extends ConsumerState<BoardSection> {
  PlayerColor _boardOrientation = PlayerColor.white;

  void _flipBoard() {
    setState(() {
      _boardOrientation = _boardOrientation == PlayerColor.white
          ? PlayerColor.black
          : PlayerColor.white;
    });
  }

  @override
  Widget build(BuildContext context) {
    final engineState = ref.watch(engineControllerProvider);
    final boardController = ref.watch(boardControllerProvider);

    List<BoardArrow> arrows = [];
    // Cambia stats.pv con stats.pvs
    if (engineState.isRunning && engineState.stats.pvs.isNotEmpty) {
      // Estrai la PV dalla primissima riga!
      String bestMove = engineState.stats.pvs.first.split(' ').first;
      if (bestMove.length >= 4) {
        arrows.add(
          BoardArrow(
            from: bestMove.substring(0, 2),
            to: bestMove.substring(2, 4),
            color: Colors.redAccent.withValues(alpha: 0.7),
          ),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Margine di sicurezza per evitare l'overflow verticale
        final availableHeight = constraints.maxHeight - 70;

        final boardSize = constraints.maxWidth < availableHeight
            ? constraints.maxWidth
            : availableHeight;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // SCACCHIERA
            Container(
              width: boardSize,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ChessBoard(
                size: boardSize - 4, // Sottraiamo i bordi
                controller: boardController,
                boardColor: BoardColor.brown,
                boardOrientation: _boardOrientation,
                arrows: arrows,
                enableUserMoves: true,
                onMove: () {
                  // 1. RECUPERA IL SAN (nome mossa) dal PGN del gioco interno
                  String pgn = boardController.game.pgn();
                  pgn = pgn.replaceAll(
                    RegExp(r'\s*(1-0|0-1|1/2-1/2|\*)\s*$'),
                    '',
                  );
                  List<String> pgnParts = pgn.split(RegExp(r'\s+'));
                  String moveSan = pgnParts.lastWhere(
                    (s) => !s.contains('.'),
                    orElse: () => "Mossa",
                  );

                  // 2. AGGIORNA LA NOTAZIONE (tramite il NotationController)
                  ref
                      .read(notationControllerProvider.notifier)
                      .handleNewMove(
                        boardController.getFen(),
                        moveSan,
                        context,
                      );

                  // 3. AVVIA L'ANALISI DEL MOTORE (se acceso)
                  if (engineState.isRunning) {
                    ref
                        .read(engineControllerProvider.notifier)
                        .analyzeCurrentPosition(boardController.getFen());
                  }
                },
              ),
            ),

            const SizedBox(height: 8),

            // BARRA NAVIGAZIONE
            Container(
              width: boardSize,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // I tasti ora comunicano con il NotationController invece che fare "undo" brutale!
                    IconButton(
                      icon: const Icon(Icons.first_page),
                      color: Colors.white70,
                      onPressed: () => ref
                          .read(notationControllerProvider.notifier)
                          .goToStart(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      color: Colors.white,
                      onPressed: () => ref
                          .read(notationControllerProvider.notifier)
                          .goBack(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sync),
                      color: Colors.blueAccent,
                      onPressed: _flipBoard,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      color: Colors.white30,
                      onPressed: () => ref
                          .read(notationControllerProvider.notifier)
                          .goForward(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      color: Colors.white30,
                      onPressed: () => ref
                          .read(notationControllerProvider.notifier)
                          .goToEnd(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
