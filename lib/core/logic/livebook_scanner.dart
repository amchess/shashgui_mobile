import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LiveBookMove {
  final String move;
  final String description;
  LiveBookMove({required this.move, required this.description});
}

class LiveBookResult {
  final List<LiveBookMove> moves;
  final String openingName;
  final String engineComment;
  LiveBookResult({
    required this.moves,
    this.openingName = "",
    this.engineComment = "",
  });
}

class LiveBookScanner {
  static Future<LiveBookResult> scan(
    String fen,
    List<String> moveHistory,
    bool isShashChess,
  ) async {
    if (isShashChess) {
      return await _scanChessDb(fen);
    } else {
      return await _scanLichess(fen, moveHistory);
    }
  }

  static String _stripHtml(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').replaceAll('&nbsp;', ' ').trim();
  }

  static Future<LiveBookResult> _scanChessDb(String fen) async {
    try {
      final url =
          "https://www.chessdb.cn/cdb.php?action=queryall&json=1&board=${Uri.encodeComponent(fen)}";
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 8));

      String aiComment = "";
      List<LiveBookMove> results = [];
      double bestWp = 0.0;
      String bestSan = "";

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final moves = data['moves'] as List<dynamic>?;

        if (moves != null && moves.isNotEmpty) {
          double parseSafeDouble(dynamic val) {
            if (val is num) return val.toDouble();
            if (val is String) return double.tryParse(val) ?? 0.0;
            return 0.0;
          }

          for (int i = 0; i < moves.length; i++) {
            String uci = moves[i]['uci'];
            double winrate = parseSafeDouble(moves[i]['winrate']);
            if (i == 0) {
              bestWp = winrate;
              bestSan = uci;
            }
            results.add(
              LiveBookMove(
                move: uci,
                description: "${winrate.toStringAsFixed(2)}%",
              ),
            );
          }
        }
      }

      try {
        final webUrl =
            "https://www.chessdb.cn/queryc_en/?${fen.replaceAll(' ', '_')}";
        final webResp = await http
            .get(
              Uri.parse(webUrl),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
              },
            )
            .timeout(const Duration(seconds: 4));
        if (webResp.statusCode == 200) {
          final match = RegExp(
            r"""var\s+suggest_note\s*=\s*(["'])(.*?)(?<!\\)\1\s*;""",
            dotAll: true,
          ).firstMatch(webResp.body);
          if (match != null) {
            aiComment = _stripHtml(match.group(2) ?? "");
            aiComment = aiComment.replaceAll(r"\'", "'").replaceAll(r'\"', '"');
          }
        }
      } catch (e) {
        debugPrint("Scrape ChessDB failed: $e");
      }

      if (aiComment.isEmpty && results.isNotEmpty) {
        bool isWhiteTurn = fen.split(' ')[1] == 'w';
        String side = isWhiteTurn ? "White's" : "Black's";
        String oppSide = isWhiteTurn ? "Black" : "White";
        aiComment = "From $side view the position is ";
        if (bestWp >= 60.0) {
          aiComment +=
              "clearly dominant, offering excellent winning chances.\n";
        } else if (bestWp >= 53.0) {
          aiComment +=
              "slightly better, with a solid edge and a promising initiative.\n";
        } else if (bestWp <= 40.0) {
          aiComment += "critical: $oppSide has seized control of the game.\n";
        } else if (bestWp <= 47.0) {
          aiComment += "under uncomfortable pressure from $oppSide.\n";
        } else {
          aiComment +=
              "perfectly balanced, with no clear advantage either side;\nany of the usual opening moves maintain equality and simply set the stage for the ensuing struggle.\n";
        }
        aiComment +=
            "The strongest continuation is $bestSan (${bestWp.toStringAsFixed(1)}%).";
      }

      if (results.isEmpty) {
        results.add(
          LiveBookMove(move: "-", description: "Nessuna Teoria NNUE"),
        );
      }

      return LiveBookResult(
        moves: results,
        engineComment: aiComment,
        openingName: "ChessDB Analysis",
      );
    } catch (e) {
      return LiveBookResult(
        moves: [LiveBookMove(move: "-", description: "Errore")],
        engineComment: "Errore connessione: $e",
      );
    }
  }

  static Future<LiveBookResult> _scanLichess(
    String fen,
    List<String> moveHistory,
  ) async {
    try {
      final url =
          "https://explorer.lichess.ovh/masters?fen=${Uri.encodeComponent(fen)}";
      Map<String, String> requestHeaders = {
        'Accept': 'application/json',
        'User-Agent': 'ShashGuiMobileApp/1.0',
      };

      final String p1 = 'lip_a8aj0hJH';
      final String p2 = 'FE43DEwGnFKc';
      requestHeaders['Authorization'] = 'Bearer $p1$p2';

      final response = await http
          .get(Uri.parse(url), headers: requestHeaders)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 401) {
        return LiveBookResult(
          moves: [LiveBookMove(move: "...", description: "Token Scaduto")],
        );
      }
      if (response.statusCode == 429) {
        return LiveBookResult(
          moves: [LiveBookMove(move: "...", description: "Lichess Busy")],
        );
      }
      if (response.statusCode == 404) {
        return LiveBookResult(
          moves: [LiveBookMove(move: "-", description: "Nessuna Teoria")],
        );
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final moves = data['moves'] as List<dynamic>?;
        String openingTitle = "";

        if (data['opening'] != null) {
          String eco = data['opening']['eco'] ?? "";
          String name = data['opening']['name'] ?? "";
          openingTitle = "[$eco] $name";
        }

        String wikiExtract = "";
        if (moveHistory.isNotEmpty) {
          List<String> pathsToTry = [];
          String currentPath = "Chess_Opening_Theory";
          for (int i = 0; i < moveHistory.length; i++) {
            int turn = (i ~/ 2) + 1;
            String cleanMove = moveHistory[i].replaceAll(RegExp(r'[+#?!]'), '');
            if (i % 2 == 0) {
              currentPath += "/$turn._$cleanMove";
            } else {
              currentPath += "/$turn...$cleanMove";
            }
            pathsToTry.add(currentPath);
          }
          for (String path in pathsToTry.reversed) {
            final wbUrl =
                "https://en.wikibooks.org/w/api.php?action=query&prop=extracts&format=json&titles=${Uri.encodeComponent(path)}";
            try {
              final wbResp = await http
                  .get(Uri.parse(wbUrl))
                  .timeout(const Duration(seconds: 3));
              if (wbResp.statusCode == 200) {
                final wbData = json.decode(wbResp.body);
                final pages =
                    wbData['query']?['pages'] as Map<String, dynamic>?;
                if (pages != null && pages.isNotEmpty) {
                  final page = pages.values.first;
                  if (page['missing'] == null &&
                      page['extract'] != null &&
                      page['extract'].toString().isNotEmpty) {
                    wikiExtract = _stripHtml(page['extract']);
                    openingTitle += " (Fonte: Wikibooks - $path)";
                    break;
                  }
                }
              }
            } catch (e) {
              debugPrint("Scrape Wikibooks failed: $e");
            }
          }
        }

        List<LiveBookMove> results = [];
        if (moves != null && moves.isNotEmpty) {
          bool isWhiteTurn = fen.split(' ')[1] == 'w';
          List<Map<String, dynamic>> processedMoves = [];
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
            int w = move['white'] ?? 0;
            int d = move['draws'] ?? 0;
            int b = move['black'] ?? 0;
            int total = w + d + b;
            double freqPct = (total / globalTot) * 100.0;

            if (total < 1 || (total / globalTot) < 0.005) continue;

            double wpPura = isWhiteTurn
                ? ((w + d / 2.0) / total) * 100.0
                : ((b + d / 2.0) / total) * 100.0;
            double pEff = (wpPura * 0.70) + (freqPct * 0.30);
            processedMoves.add({'uci': move['uci'], 'pEff': pEff});
          }

          processedMoves.sort(
            (a, b) => (b['pEff'] as double).compareTo(a['pEff'] as double),
          );

          for (var pm in processedMoves) {
            results.add(
              LiveBookMove(
                move: pm['uci'] as String,
                description: "${(pm['pEff'] as double).toStringAsFixed(1)}%",
              ),
            );
          }

          if (results.isEmpty) {
            results.add(
              LiveBookMove(move: "-", description: "Nessuna Teoria Lichess"),
            );
          }

          return LiveBookResult(
            moves: results,
            openingName: openingTitle,
            engineComment: wikiExtract,
          );
        } else {
          return LiveBookResult(
            moves: [LiveBookMove(move: "-", description: "Nessuna Teoria")],
            openingName: openingTitle,
            engineComment: wikiExtract,
          );
        }
      }
      return LiveBookResult(
        moves: [LiveBookMove(move: "-", description: "Errore API")],
      );
    } catch (e) {
      return LiveBookResult(
        moves: [LiveBookMove(move: "-", description: "Nessuna connessione")],
      );
    }
  }
}
