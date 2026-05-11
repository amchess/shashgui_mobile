import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

// Esponiamo una SINGOLA istanza della scacchiera a tutta l'app
final boardControllerProvider = Provider<ChessBoardController>((ref) {
  return ChessBoardController();
});
