import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LiveBookOracle {
  static const String _lichessUrl = "https://explorer.lichess.ovh/masters?fen=";
  static const String _chessDbUrl =
      "https://www.chessdb.cn/cdb.php?action=queryall&json=1&board=";

  // ⚠️ FIX: Cache in RAM limitata per non consumare la RAM in sessioni lunghe
  static final Map<String, String?> _cache = {};
  static const int _maxCacheSize = 200;

  static void _addToCache(String key, String? value) {
    if (value == null) return;
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first); // Elimina la voce più vecchia
    }
    _cache[key] = value;
  }

  // =========================================================================
  // ⚠️ LA NOSTRA FORMULA ESTRATTA (Ora testabile in totale isolamento!)
  // =========================================================================
  static double calculateEffectiveWinProbability(
    int w,
    int d,
    int b,
    int globalTot,
    bool isWhiteTurn,
  ) {
    int total = w + d + b;
    double popularity = total / globalTot;

    // Filtro anti-rumore (< 0.5% popolarità o zero partite).
    // Restituiamo -1.0 per farla scartare in automatico.
    if (total < 1 || popularity < 0.005) return -1.0;

    // Calcolo della Win Probability Pura
    double wpPura = isWhiteTurn
        ? ((w + d / 2.0) / total) * 100.0
        : ((b + d / 2.0) / total) * 100.0;

    // LA VERA WIN PROBABILITY: 70% WP + 30% Frequenza
    return (wpPura * 0.70) + (popularity * 100.0 * 0.30);
  }

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

          // ⚠️ Richiamiamo la nostra formula matematica pura
          double pEff = calculateEffectiveWinProbability(
            w,
            d,
            b,
            globalTot,
            isWhiteTurn,
          );

          if (pEff > bestScore) {
            bestScore = pEff;
            bestUci = move['uci'];
          }
        }

        if (bestUci != null) {
          _addToCache(cacheKey, bestUci);
          return bestUci;
        }
      }
    }
    _addToCache(cacheKey, null);
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
        _addToCache(cacheKey, bestUci);
        return bestUci;
      }
    }
    _addToCache(cacheKey, null);
    return null;
  }
}
