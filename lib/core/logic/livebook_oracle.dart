import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LiveBookOracle {
  static const String _lichessUrl = "https://explorer.lichess.ovh/masters?fen=";
  static const String _chessDbUrl =
      "https://www.chessdb.cn/cdb.php?action=queryall&json=1&board=";

  // Cache in RAM per non interrogare le API due volte per la stessa posizione
  static final Map<String, String?> _cache = {};

  /// Restituisce la mossa migliore in formato UCI (es. "e2e4") o null se non c'è teoria.
  static Future<String?> getBestCloudMove(String fen, bool isNeural) async {
    String cacheKey = "${fen}_$isNeural";

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      if (isNeural) {
        return await _getChessDbMove(fen, cacheKey);
      } else {
        return await _getLichessMove(fen, cacheKey);
      }
    } catch (e) {
      debugPrint("Errore LiveBook: $e");
      return null;
    }
  }

  // --- LICHESS MASTERS (Per Alexander - HCE) ---
  static Future<String?> _getLichessMove(String fen, String cacheKey) async {
    final uri = Uri.parse("$_lichessUrl${Uri.encodeComponent(fen)}");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final moves = data['moves'] as List<dynamic>?;

      if (moves != null && moves.isNotEmpty) {
        double bestScore = -1.0;
        String? bestUci;
        bool isWhiteTurn = fen.split(' ')[1] == 'w';

        for (var move in moves) {
          int w = move['white'];
          int d = move['draws'];
          int b = move['black'];
          int total = w + d + b;

          // Filtro anti-rumore: ignoriamo mosse giocate in meno di 5 partite Master
          if (total < 5) continue;

          // Calcolo Win Probability (WP = (Vittorie + Patte/2) / Totale)
          double wp = isWhiteTurn
              ? ((w + d / 2) / total)
              : ((b + d / 2) / total);

          if (wp > bestScore) {
            bestScore = wp;
            bestUci = move['uci'];
          }
        }

        if (bestUci != null) {
          _cache[cacheKey] = bestUci;
          return bestUci;
        }
      }
    }
    _cache[cacheKey] = null;
    return null;
  }

  // --- CHESSDB (Per ShashChess - NNUE) ---
  static Future<String?> _getChessDbMove(String fen, String cacheKey) async {
    final uri = Uri.parse("$_chessDbUrl${Uri.encodeComponent(fen)}");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final moves = data['moves'] as List<dynamic>?;

      if (moves != null && moves.isNotEmpty) {
        // ChessDB restituisce già le mosse ordinate per score/rank dalla migliore alla peggiore.
        // Prendiamo la prima mossa valida proposta dai supercomputer cinesi.
        String bestUci = moves[0]['uci'];
        _cache[cacheKey] = bestUci;
        return bestUci;
      }
    }
    _cache[cacheKey] = null;
    return null;
  }
}
