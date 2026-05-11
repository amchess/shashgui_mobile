import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../../domain/engine_controller.dart';
import '../../domain/board_provider.dart';

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

  void _undoMove() {
    final controller = ref.read(boardControllerProvider);
    if (controller.game.history.isEmpty) return;

    controller.undoMove();
    setState(() {});
    _triggerAnalysis();
  }

  void _resetBoard() {
    ref.read(boardControllerProvider).resetBoard();
    setState(() {});
    _triggerAnalysis();
  }

  void _triggerAnalysis() {
    if (ref.read(engineControllerProvider).isRunning) {
      ref
          .read(engineControllerProvider.notifier)
          .analyzeCurrentPosition(ref.read(boardControllerProvider).getFen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final engineState = ref.watch(engineControllerProvider);
    final boardController = ref.watch(boardControllerProvider);

    List<BoardArrow> arrows = [];
    if (engineState.isRunning && engineState.stats.pv.isNotEmpty) {
      String bestMove = engineState.stats.pv.split(' ').first;
      if (bestMove.length >= 4) {
        arrows.add(
          BoardArrow(
            from: bestMove.substring(0, 2),
            to: bestMove.substring(2, 4),
            color: Colors.redAccent.withOpacity(0.7),
          ),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Aumentato il margine di sicurezza a 70 pixel per evitare l'overflow verticale
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
              // ⚠️ IL FIX: FittedBox scalerà i pulsanti se la scacchiera è stretta!
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page),
                      color: Colors.white70,
                      onPressed: _resetBoard,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      color: Colors.white,
                      onPressed: _undoMove,
                    ),
                    IconButton(
                      icon: const Icon(Icons.sync),
                      color: Colors.blueAccent,
                      onPressed: _flipBoard,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      color: Colors.white30,
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      color: Colors.white30,
                      onPressed: () {},
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
