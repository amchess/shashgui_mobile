import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart'
    hide
        Color; // ⚠️ FIX: Nasconde il colore degli scacchi per usare quello di Flutter!
import '../../domain/engine_controller.dart';
import '../../domain/board_provider.dart';
import '../../domain/notation_controller.dart';
import 'package:shashgui_mobile/features/play/presentation/custom_chess_board.dart';

class BoardSection extends ConsumerStatefulWidget {
  const BoardSection({super.key});

  @override
  ConsumerState<BoardSection> createState() => _BoardSectionState();
}

class _BoardSectionState extends ConsumerState<BoardSection> {
  bool _isWhiteBottom =
      true; // Sostituisce PlayerColor.white per la nuova scacchiera
  ChessBoardController? _boardControllerListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boardControllerListener = ref.read(boardControllerProvider);
      _boardControllerListener?.addListener(_syncBoard);
      _syncBoard();
    });
  }

  void _syncBoard() {
    if (_boardControllerListener != null) {
      ref
          .read(customBoardProvider.notifier)
          .updateFen(_boardControllerListener!.getFen());
    }
  }

  @override
  void dispose() {
    _boardControllerListener?.removeListener(_syncBoard);
    super.dispose();
  }

  void _flipBoard() {
    setState(() {
      _isWhiteBottom = !_isWhiteBottom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final engineState = ref.watch(engineControllerProvider);
    final boardController = ref.watch(boardControllerProvider);

    // 1. Mossa principale del motore
    String engineBestMoveUci = "";
    if (engineState.isRunning && engineState.stats.pvs.isNotEmpty) {
      engineBestMoveUci = engineState.stats.pvs.first.split(' ').first;
    }

    // 2. Mossa minaccia (se il radar è attivo)
    String threatMoveUci = engineState.threatMoveUci;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight - 70;
        final boardSize = constraints.maxWidth < availableHeight
            ? constraints.maxWidth
            : availableHeight;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ==========================================
            // LA NUOVA SCACCHIERA CON FRECCIA ENGINE
            // ==========================================
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: Stack(
                children: [
                  CustomChessBoard(
                    isWhiteBottom: _isWhiteBottom,
                    onUserMove: (uciMove) {
                      final fromSq = uciMove.substring(0, 2);
                      final toSq = uciMove.substring(2, 4);

                      boardController.makeMove(from: fromSq, to: toSq);
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
                      ref
                          .read(notationControllerProvider.notifier)
                          .handleNewMove(
                            boardController.getFen(),
                            moveSan,
                            context,
                          );
                      if (engineState.isRunning) {
                        ref
                            .read(engineControllerProvider.notifier)
                            .analyzeCurrentPosition(boardController.getFen());
                      }
                    },
                  ),

                  // Disegna PRIMA la minaccia (Rossa Opaca), ALTRIMENTI l'analisi normale
                  if (threatMoveUci.length >= 4)
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(boardSize, boardSize),
                        painter: EngineArrowPainter(
                          threatMoveUci,
                          _isWhiteBottom,
                          Colors.red.withValues(alpha: 0.95), // ROSSO INTENSO!
                        ),
                      ),
                    )
                  else if (engineBestMoveUci.length >= 4)
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(boardSize, boardSize),
                        painter: EngineArrowPainter(
                          engineBestMoveUci,
                          _isWhiteBottom,
                          Colors.redAccent.withValues(
                            alpha: 0.5,
                          ), // TRASPARENTE
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
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

// ============================================================================
// PAINTER: IL DISEGNATORE DELLE FRECCE
// ============================================================================
class EngineArrowPainter extends CustomPainter {
  final String moveUci;
  final bool isWhiteBottom;
  final Color arrowColor;

  EngineArrowPainter(this.moveUci, this.isWhiteBottom, this.arrowColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (moveUci.length < 4) return;
    final sqSize = size.width / 8;

    int fromFile = moveUci.codeUnitAt(0) - 97;
    int fromRank = int.parse(moveUci[1]) - 1;
    int toFile = moveUci.codeUnitAt(2) - 97;
    int toRank = int.parse(moveUci[3]) - 1;

    if (!isWhiteBottom) {
      fromFile = 7 - fromFile;
      fromRank = 7 - fromRank;
      toFile = 7 - toFile;
      toRank = 7 - toRank;
    }

    final start = Offset(
      (fromFile + 0.5) * sqSize,
      (7 - fromRank + 0.5) * sqSize,
    );
    final end = Offset((toFile + 0.5) * sqSize, (7 - toRank + 0.5) * sqSize);

    final paint = Paint()
      ..color = arrowColor
      ..strokeWidth = sqSize * 0.15
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, paint);
    canvas.drawCircle(end, sqSize * 0.25, paint);
  }

  @override
  bool shouldRepaint(covariant EngineArrowPainter oldDelegate) {
    return oldDelegate.moveUci != moveUci ||
        oldDelegate.isWhiteBottom != isWhiteBottom ||
        oldDelegate.arrowColor != arrowColor;
  }
}
