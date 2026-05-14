import 'livebook_oracle.dart';
import 'dart:convert';
import 'dart:math'; // ⚠️ FIX: SPOSTATO QUI IN CIMA!
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:chess/chess.dart'
    as chess_lib; // ⚠️ Aggiunto per calcolare il SAN nel background

class LiveBookMove {
  final String move; // La mossa UCI (es. e2e4)
  final String san; // La mossa SAN (es. e4) - ⚠️ NUOVA VARIABILE
  final String description;

  LiveBookMove({
    required this.move,
    required this.san,
    required this.description,
  });
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

          // Ordiniamo le mosse per winrate decrescente
          moves.sort(
            (a, b) => parseSafeDouble(
              b['winrate'],
            ).compareTo(parseSafeDouble(a['winrate'])),
          );

          // =========================================================================
          // ⚠️ IL FIX ANTI-FREEZE: LIMITIAMO A 15 MOSSE!
          // ChessDB restituisce centinaia di mosse. Processarle tutte uccide la CPU.
          // =========================================================================
          final topMoves = moves.take(15).toList();

          // Inizializziamo una scacchiera temporanea per calcolare i SAN
          final tempChess = chess_lib.Chess.fromFEN(fen);

          for (int i = 0; i < topMoves.length; i++) {
            String uci = topMoves[i]['uci'];
            double winrate = parseSafeDouble(topMoves[i]['winrate']);

            // ⚠️ CALCOLO SAN VELOCE IN BACKGROUND (SOLO SULLE 15 MIGLIORI)
            String san = uci;
            try {
              var m = tempChess.move(uci);
              if (m != false) {
                san = (m as dynamic).san ?? uci;
                tempChess
                    .undo(); // Torniamo subito indietro per la prossima mossa
              }
            } catch (_) {}

            if (i == 0) {
              bestWp = winrate;
              bestSan = san;
            }

            results.add(
              LiveBookMove(
                move: uci,
                san: san,
                description: "${winrate.toStringAsFixed(2)}%",
              ),
            );
          }
        }
      }

      // Scraping Ottimizzato (Niente regex pesanti, solo string indexOf per evitare blocchi!)
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
          int start = webResp.body.indexOf('var suggest_note="');
          if (start == -1) start = webResp.body.indexOf("var suggest_note='");

          if (start != -1) {
            int end = webResp.body.indexOf(";", start);
            if (end != -1) {
              String raw = webResp.body.substring(start + 18, end - 1);
              aiComment = _stripHtml(
                raw,
              ).replaceAll(r"\'", "'").replaceAll(r'\"', '"');
            }
          }
        }
      } catch (e) {
        debugPrint("Scrape ChessDB failed: $e");
      }

      // Se non c'è il commento AI online, generiamo quello discorsivo in Inglese
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
          LiveBookMove(move: "-", san: "-", description: "Nessuna Teoria NNUE"),
        );
      }

      return LiveBookResult(
        moves: results,
        engineComment: aiComment,
        openingName: "ChessDB Analysis",
      );
    } catch (e) {
      return LiveBookResult(
        moves: [LiveBookMove(move: "-", san: "-", description: "Errore")],
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
          moves: [
            LiveBookMove(move: "...", san: "...", description: "Token Scaduto"),
          ],
        );
      }
      if (response.statusCode == 429) {
        return LiveBookResult(
          moves: [
            LiveBookMove(move: "...", san: "...", description: "Lichess Busy"),
          ],
        );
      }
      if (response.statusCode == 404) {
        return LiveBookResult(
          moves: [
            LiveBookMove(move: "-", san: "-", description: "Nessuna Teoria"),
          ],
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

        // ⚠️ ANTI-FREEZE WIKIBOOKS: La teoria non supera quasi mai la 12a mossa.
        if (moveHistory.isNotEmpty) {
          final maxPlies = moveHistory.length > 24 ? 24 : moveHistory.length;

          List<String> pathsToTry = [];
          String currentPath = "Chess_Opening_Theory";

          for (int i = 0; i < maxPlies; i++) {
            int turn = (i ~/ 2) + 1;
            String cleanMove = moveHistory[i].replaceAll(RegExp(r'[+#?!]'), '');
            if (i % 2 == 0) {
              currentPath += "/$turn._$cleanMove";
            } else {
              currentPath += "/$turn...$cleanMove";
            }
            pathsToTry.add(currentPath);
          }

          // Controlliamo SOLO le ultime 6 diramazioni per non intasare le chiamate HTTP
          final pathsToCheck = pathsToTry.reversed.take(6).toList();

          for (String path in pathsToCheck) {
            final wbUrl =
                "https://en.wikibooks.org/w/api.php?action=query&prop=extracts&format=json&titles=${Uri.encodeComponent(path)}";
            try {
              final wbResp = await http
                  .get(Uri.parse(wbUrl))
                  .timeout(const Duration(seconds: 2));

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
                    break; // Trovato, usciamo dal ciclo!
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

            // ⚠️ FIX: Usiamo la formula matematica pura e centralizzata dell'Oracolo!
            double pEff = LiveBookOracle.calculateEffectiveWinProbability(
              w,
              d,
              b,
              globalTot,
              isWhiteTurn,
            );

            // Il filtro anti-rumore dell'Oracolo restituisce -1.0 se la mossa è irrilevante
            if (pEff < 0) continue;

            processedMoves.add({
              'uci': move['uci'],
              'san': move['san'] ?? move['uci'],
              'pEff': pEff,
            });
          }

          // Ordiniamo e limitiamo anche Lichess per estrema sicurezza (massimo 15 mosse logiche)
          processedMoves.sort(
            (a, b) => (b['pEff'] as double).compareTo(a['pEff'] as double),
          );

          final topLichessMoves = processedMoves.take(15).toList();

          for (var pm in topLichessMoves) {
            results.add(
              LiveBookMove(
                move: pm['uci'] as String,
                san: pm['san'] as String,
                description: "${(pm['pEff'] as double).toStringAsFixed(1)}%",
              ),
            );
          }

          if (results.isEmpty) {
            results.add(
              LiveBookMove(
                move: "-",
                san: "-",
                description: "Nessuna Teoria Lichess",
              ),
            );
          }

          return LiveBookResult(
            moves: results,
            openingName: openingTitle,
            engineComment: wikiExtract,
          );
        } else {
          return LiveBookResult(
            moves: [
              LiveBookMove(move: "-", san: "-", description: "Nessuna Teoria"),
            ],
            openingName: openingTitle,
            engineComment: wikiExtract,
          );
        }
      }
      return LiveBookResult(
        moves: [LiveBookMove(move: "-", san: "-", description: "Errore API")],
      );
    } catch (e) {
      return LiveBookResult(
        moves: [
          LiveBookMove(move: "-", san: "-", description: "Nessuna connessione"),
        ],
      );
    }
  }
}

// =========================================================================
// ⚠️ HELPER PUBBLICO PER L'ORACOLO (Testabile in isolamento con injection)
// =========================================================================
class OracleRoulette {
  // ⚠️ FIX LINTER: Rimossa l'annotazione @visibleForTesting che bloccava gli orchestratori!
  static String? spin(List<LiveBookMove> moves, {double? testRandomVal}) {
    if (moves.isEmpty ||
        moves.first.move == "-" ||
        moves.first.move.contains(".")) {
      return null;
    }

    List<Map<String, dynamic>> parsedMoves = [];
    for (var m in moves) {
      parsedMoves.add({
        'uci': m.move,
        'wp': double.tryParse(m.description.replaceAll('%', '')) ?? 0.0,
      });
    }

    if (parsedMoves.isEmpty) return null;

    double topScore = parsedMoves.first['wp'];

    // Se la posizione è disperata (<40%), giochiamo sempre e solo la migliore
    if (topScore < 40.0) return parsedMoves.first['uci'];

    // Prendiamo solo l'elite (Top 3 mosse con almeno 45% di WP)
    List<Map<String, dynamic>> eliteMoves = parsedMoves
        .take(3)
        .where((m) => m['wp'] >= 45.0)
        .toList();

    if (eliteMoves.isEmpty) return parsedMoves.first['uci'];

    // Assegnazione pesi esponenziali (es. 9, 3, 1)
    List<double> weights = [];
    double totalWeight = 0.0;
    for (int i = 0; i < eliteMoves.length; i++) {
      double weight = pow(3.0, (eliteMoves.length - i - 1)).toDouble();
      weights.add(weight);
      totalWeight += weight;
    }

    // ⚠️ INJECTION: Se siamo nei test usiamo il valore fisso, altrimenti Random!
    double randomFraction = testRandomVal ?? Random().nextDouble();
    double randomVal = randomFraction * totalWeight;

    double current = 0.0;
    for (int i = 0; i < eliteMoves.length; i++) {
      current += weights[i];
      if (randomVal <= current) return eliteMoves[i]['uci'];
    }
    return eliteMoves.first['uci'];
  }
}
