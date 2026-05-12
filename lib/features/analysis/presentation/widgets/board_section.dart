import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart'; // Lo teniamo come "motore logico" invisibile
import '../../domain/engine_controller.dart';
import '../../domain/board_provider.dart';
import '../../domain/notation_controller.dart';
import 'package:shashgui_mobile/features/play/presentation/custom_chess_board.dart'; // ⚠️ Assicurati che il percorso sia corretto se l'hai salvato altrove!

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
    // ⚠️ LA MAGIA: Colleghiamo il vecchio controller alla nuova scacchiera!
    // Se l'engine muove o se premi "Indietro", la nuova scacchiera si aggiorna da sola.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boardControllerListener = ref.read(boardControllerProvider);
      _boardControllerListener?.addListener(_syncBoard);
      _syncBoard(); // Sincronizzazione iniziale
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

    // 1. Recuperiamo la mossa suggerita dal motore (se acceso)
    String engineBestMoveUci = "";
    if (engineState.isRunning && engineState.stats.pvs.isNotEmpty) {
      engineBestMoveUci = engineState.stats.pvs.first.split(' ').first;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Margine per la pulsantiera
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
                  // Il nostro nuovo Widget col Tap-to-Move
                  CustomChessBoard(
                    isWhiteBottom: _isWhiteBottom,
                    onUserMove: (uciMove) {
                      // 1. Estraiamo la casa di partenza e arrivo (es. "e2" -> "e4")
                      final fromSq = uciMove.substring(0, 2);
                      final toSq = uciMove.substring(2, 4);

                      // 2. Passiamo la mossa al VECCHIO controller logico (senza "promotion")
                      boardController.makeMove(from: fromSq, to: toSq);

                      // 3. Estraiamo il SAN (es. "Nf3") per la notazione esatta come prima
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

                      // 4. Aggiorniamo la barra della notazione
                      ref
                          .read(notationControllerProvider.notifier)
                          .handleNewMove(
                            boardController.getFen(),
                            moveSan,
                            context,
                          );

                      // 5. Riavvia l'analisi del motore se era acceso
                      if (engineState.isRunning) {
                        ref
                            .read(engineControllerProvider.notifier)
                            .analyzeCurrentPosition(boardController.getFen());
                      }
                    },
                  ),

                  // La Freccia dell'Euristica (disegnata dinamicamente sopra la scacchiera)
                  if (engineBestMoveUci.length >= 4)
                    IgnorePointer(
                      // Per far passare i tocchi alla scacchiera sotto
                      child: CustomPaint(
                        size: Size(boardSize, boardSize),
                        painter: EngineArrowPainter(
                          engineBestMoveUci,
                          _isWhiteBottom,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ==========================================
            // BARRA NAVIGAZIONE
            // ==========================================
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
                    // Ora non serve forzare la grafica, ci pensa l'addListener in alto!
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

  EngineArrowPainter(this.moveUci, this.isWhiteBottom);

  @override
  void paint(Canvas canvas, Size size) {
    if (moveUci.length < 4) return;

    final sqSize = size.width / 8;

    // Decodifica la mossa UCI (da "e2" a coordinate matematiche X,Y)
    int fromFile = moveUci.codeUnitAt(0) - 97; // 'a' = 0
    int fromRank = int.parse(moveUci[1]) - 1; // '1' = 0
    int toFile = moveUci.codeUnitAt(2) - 97;
    int toRank = int.parse(moveUci[3]) - 1;

    // Ribalta matematicamente se giochiamo coi neri
    if (!isWhiteBottom) {
      fromFile = 7 - fromFile;
      fromRank = 7 - fromRank;
      toFile = 7 - toFile;
      toRank = 7 - toRank;
    }

    // Calcola il centro esatto delle case di partenza e arrivo
    final start = Offset(
      (fromFile + 0.5) * sqSize,
      (7 - fromRank + 0.5) * sqSize,
    );
    final end = Offset((toFile + 0.5) * sqSize, (7 - toRank + 0.5) * sqSize);

    // Stile della freccia (Rossa semitrasparente stile ChessBase)
    final paint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.6)
      ..strokeWidth = sqSize * 0.15
      ..strokeCap = StrokeCap.round;

    // Disegna la linea
    canvas.drawLine(start, end, paint);
    // Disegna un elegante cerchio ("pallino") sulla casa di destinazione per indicare la direzione
    canvas.drawCircle(end, sqSize * 0.25, paint);
  }

  @override
  bool shouldRepaint(covariant EngineArrowPainter oldDelegate) {
    return oldDelegate.moveUci != moveUci ||
        oldDelegate.isWhiteBottom != isWhiteBottom;
  }
}
