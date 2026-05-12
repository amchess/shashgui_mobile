import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess_lib;
// ⚠️ IMPORTIAMO I PEZZI IN STILE LICHESS
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';

class CustomBoardState {
  final chess_lib.Chess chess;
  final String? selectedSquare;
  final List<String> validDestinations;

  CustomBoardState({
    required this.chess,
    this.selectedSquare,
    this.validDestinations = const [],
  });

  CustomBoardState copyWith({
    chess_lib.Chess? chess,
    String? selectedSquare,
    List<String>? validDestinations,
    bool clearSelection = false,
  }) {
    return CustomBoardState(
      chess: chess ?? this.chess,
      selectedSquare: clearSelection
          ? null
          : (selectedSquare ?? this.selectedSquare),
      validDestinations: clearSelection
          ? []
          : (validDestinations ?? this.validDestinations),
    );
  }
}

final customBoardProvider =
    StateNotifierProvider<CustomBoardController, CustomBoardState>((ref) {
      return CustomBoardController();
    });

class CustomBoardController extends StateNotifier<CustomBoardState> {
  CustomBoardController() : super(CustomBoardState(chess: chess_lib.Chess()));

  void updateFen(String fen) {
    final newChess = chess_lib.Chess.fromFEN(fen);
    state = CustomBoardState(chess: newChess);
  }

  // Mossa con Tocco
  String? onSquareTapped(String square) {
    if (state.selectedSquare == null) {
      final piece = state.chess.get(square);
      if (piece != null && piece.color == state.chess.turn) {
        final moves = state.chess.generate_moves({'square': square});
        state = state.copyWith(
          selectedSquare: square,
          validDestinations: moves.map((m) => m.toAlgebraic).toList(),
        );
      }
      return null;
    } else {
      if (state.validDestinations.contains(square)) {
        final from = state.selectedSquare!;
        final isPawn = state.chess.get(from)?.type == chess_lib.PieceType.PAWN;
        final isPromotionRank = (square[1] == '8' || square[1] == '1');

        String moveUci = "$from$square";
        state = state.copyWith(clearSelection: true);

        if (isPawn && isPromotionRank) {
          return "$moveUci?";
        } else {
          state.chess.move(moveUci);
          return moveUci;
        }
      } else {
        state = state.copyWith(clearSelection: true);
        return null;
      }
    }
  }

  // Mossa con Trascinamento
  String? onDragMove(String from, String to) {
    if (from == to) return null;

    final piece = state.chess.get(from);
    if (piece != null && piece.color == state.chess.turn) {
      final moves = state.chess.generate_moves({'square': from});
      final validDestinations = moves.map((m) => m.toAlgebraic).toList();

      if (validDestinations.contains(to)) {
        final isPawn = piece.type == chess_lib.PieceType.PAWN;
        final isPromotionRank = (to[1] == '8' || to[1] == '1');
        String moveUci = "$from$to";

        state = state.copyWith(clearSelection: true);

        if (isPawn && isPromotionRank) {
          return "$moveUci?";
        } else {
          state.chess.move(moveUci);
          return moveUci;
        }
      }
    }
    return null;
  }
}

// ============================================================================
// WIDGET GRAFICO (LA GRIGLIA)
// ============================================================================
class CustomChessBoard extends ConsumerWidget {
  final bool isWhiteBottom;
  final Function(String) onUserMove;

  const CustomChessBoard({
    super.key,
    this.isWhiteBottom = true,
    required this.onUserMove,
  });

  // ⚠️ LA MAGIA: Restituiamo un'immagine vettoriale (SVG) perfetta per ogni pezzo!
  Widget _getPieceWidget(chess_lib.Piece piece, double size) {
    final isWhite = piece.color == chess_lib.Color.WHITE;
    switch (piece.type) {
      case chess_lib.PieceType.PAWN:
        return isWhite ? WhitePawn(size: size) : BlackPawn(size: size);
      case chess_lib.PieceType.KNIGHT:
        return isWhite ? WhiteKnight(size: size) : BlackKnight(size: size);
      case chess_lib.PieceType.BISHOP:
        return isWhite ? WhiteBishop(size: size) : BlackBishop(size: size);
      case chess_lib.PieceType.ROOK:
        return isWhite ? WhiteRook(size: size) : BlackRook(size: size);
      case chess_lib.PieceType.QUEEN:
        return isWhite ? WhiteQueen(size: size) : BlackQueen(size: size);
      case chess_lib.PieceType.KING:
        return isWhite ? WhiteKing(size: size) : BlackKing(size: size);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<String?> _showPromotionDialog(
    BuildContext context,
    chess_lib.Color color,
  ) async {
    final isWhite = color == chess_lib.Color.WHITE;
    final size = 50.0;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2b2b2b),
        title: const Text("Promozione", style: TextStyle(color: Colors.white)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _promoOption(
              ctx,
              isWhite ? WhiteQueen(size: size) : BlackQueen(size: size),
              'q',
            ),
            _promoOption(
              ctx,
              isWhite ? WhiteRook(size: size) : BlackRook(size: size),
              'r',
            ),
            _promoOption(
              ctx,
              isWhite ? WhiteBishop(size: size) : BlackBishop(size: size),
              'b',
            ),
            _promoOption(
              ctx,
              isWhite ? WhiteKnight(size: size) : BlackKnight(size: size),
              'n',
            ),
          ],
        ),
      ),
    );
  }

  Widget _promoOption(BuildContext context, Widget pieceWidget, String code) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, code),
      child: pieceWidget,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardState = ref.watch(customBoardProvider);

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black87, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final file = isWhiteBottom ? (index % 8) : 7 - (index % 8);
            final rank = isWhiteBottom ? 7 - (index ~/ 8) : (index ~/ 8);
            final squareName = '${String.fromCharCode(97 + file)}${rank + 1}';

            final isLightSquare = (file + rank) % 2 != 0;
            final baseColor = isLightSquare
                ? const Color(0xFFF0D9B5)
                : const Color(0xFFB58863);

            final isSelected = boardState.selectedSquare == squareName;
            final isDestination = boardState.validDestinations.contains(
              squareName,
            );
            final piece = boardState.chess.get(squareName);

            return DragTarget<String>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) async {
                final fromSq = details.data;
                final toSq = squareName;

                final moveResult = ref
                    .read(customBoardProvider.notifier)
                    .onDragMove(fromSq, toSq);
                if (moveResult != null) {
                  if (moveResult.endsWith('?')) {
                    final pieceCode = await _showPromotionDialog(
                      context,
                      boardState.chess.turn,
                    );
                    if (pieceCode != null) {
                      final fullMove = moveResult.replaceAll('?', pieceCode);
                      ref.read(customBoardProvider).chess.move(fullMove);
                      onUserMove(fullMove);
                    }
                  } else {
                    onUserMove(moveResult);
                  }
                }
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: () async {
                    final moveResult = ref
                        .read(customBoardProvider.notifier)
                        .onSquareTapped(squareName);
                    if (moveResult != null) {
                      if (moveResult.endsWith('?')) {
                        final pieceCode = await _showPromotionDialog(
                          context,
                          boardState.chess.turn,
                        );
                        if (pieceCode != null) {
                          final fullMove = moveResult.replaceAll(
                            '?',
                            pieceCode,
                          );
                          ref.read(customBoardProvider).chess.move(fullMove);
                          onUserMove(fullMove);
                        }
                      } else {
                        onUserMove(moveResult);
                      }
                    }
                  },
                  child: Container(
                    color: isSelected
                        ? Colors.yellow.withValues(alpha: 0.5)
                        : baseColor,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (piece != null)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Diamo al pezzo l'85% della grandezza della casa (Perfetto stile Lichess)
                              final pieceSize = constraints.maxWidth * 0.85;
                              final pieceWidget = _getPieceWidget(
                                piece,
                                pieceSize,
                              );

                              if (piece.color == boardState.chess.turn) {
                                return Draggable<String>(
                                  data: squareName,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      child: Center(child: pieceWidget),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: pieceWidget,
                                  ),
                                  child: pieceWidget,
                                );
                              }
                              return pieceWidget;
                            },
                          ),

                        if (isDestination)
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
