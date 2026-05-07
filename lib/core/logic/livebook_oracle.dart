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

        int globalTot = 0;
        for (var move in moves) {
          globalTot +=
              ((move['white'] ?? 0) +
                      (move['draws'] ?? 0) +
                      (move['black'] ?? 0))
                  as int;
        }
        if (globalTot == 0) globalTot = 1;

        for (var move in moves) {
          int w = move['white'];
          int d = move['draws'];
          int b = move['black'];
          int total = w + d + b;

          double popularity = total / globalTot;

          // Filtro anti-rumore (< 0.5% popolarità)
          if (total < 1 || popularity < 0.005) continue;

          double wpPura = isWhiteTurn
              ? ((w + d / 2.0) / total) * 100.0
              : ((b + d / 2.0) / total) * 100.0;

          // LA VERA WIN PROBABILITY: 70% WP + 30% Frequenza
          double pEff = (wpPura * 0.70) + (popularity * 100.0 * 0.30);

          if (pEff > bestScore) {
            bestScore = pEff;
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
