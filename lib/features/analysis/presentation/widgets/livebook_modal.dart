import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart'
    hide Color; // ⚠️ Aggiunto per il traduttore SAN
import '../../../../core/logic/livebook_scanner.dart';
import '../../../../l10n/app_localizations.dart'; // ⚠️ Aggiunto per le lingue
import '../../domain/board_provider.dart';
import '../../domain/engine_controller.dart';
import '../../domain/notation_controller.dart'; // ⚠️ Aggiunto per l'albero delle mosse

class LivebookModal extends ConsumerStatefulWidget {
  const LivebookModal({super.key});

  @override
  ConsumerState<LivebookModal> createState() => _LivebookModalState();
}

class _LivebookModalState extends ConsumerState<LivebookModal> {
  LiveBookResult? _chessDbResult;
  LiveBookResult? _lichessResult;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCloudData();
  }

  Future<void> _fetchCloudData() async {
    final fen = ref.read(boardControllerProvider).getFen();
    // Esegue le due chiamate in parallelo per dimezzare i tempi d'attesa
    final results = await Future.wait([
      LiveBookScanner.scan(fen, [], true), // true = ChessDB
      LiveBookScanner.scan(fen, [], false), // false = Lichess
    ]);

    if (mounted) {
      setState(() {
        _chessDbResult = results[0];
        _lichessResult = results[1];
        _isLoading = false;
      });
    }
  }

  // --- IL TRADUTTORE UCI -> SAN ---
  // Usa una scacchiera fantasma in RAM per calcolare il nome esatto della mossa
  String _getSan(String fen, String uci) {
    if (uci == "-" || uci.contains(".")) return uci;
    try {
      final tempChess = Chess.fromFEN(fen);
      String fromSq = uci.substring(0, 2);
      String toSq = uci.substring(2, 4);
      String? prom = uci.length == 5 ? uci[4] : null;

      var moveRes = tempChess.move({
        'from': fromSq,
        'to': toSq,
        'promotion': prom,
      });
      if (moveRes != false) {
        String pgn = tempChess.pgn();
        pgn = pgn.replaceAll(RegExp(r'\s*(1-0|0-1|1/2-1/2|\*)\s*$'), '');
        List<String> parts = pgn.split(RegExp(r'\s+'));
        return parts.lastWhere(
          (s) => !s.contains('.'),
          orElse: () => uci.toUpperCase(),
        );
      }
    } catch (_) {}
    return uci.toUpperCase(); // Fallback in caso di mossa illegale
  }

  Widget _buildList(LiveBookResult? result, String currentFen) {
    if (result == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (result.openingName.isNotEmpty) ...[
          Text(
            result.openingName,
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (result.engineComment.isNotEmpty) ...[
          Text(
            result.engineComment,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Divider(color: Colors.white24),
        Expanded(
          child: ListView.builder(
            itemCount: result.moves.length,
            itemBuilder: (context, index) {
              final move = result.moves[index];
              // Convertiamo il brutto UCI (es. d4d5) nel bellissimo SAN (es. d5)
              final sanMove = _getSan(currentFen, move.move);

              return ListTile(
                leading: const Icon(
                  Icons.arrow_right_alt,
                  color: Colors.white54,
                ),
                title: Text(
                  sanMove,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                trailing: Text(
                  move.description,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                onTap: () async {
                  // ⚠️ Aggiunto 'async' qui!
                  if (move.move != "-" && !move.move.contains(".")) {
                    final boardCtrl = ref.read(boardControllerProvider);

                    // 1. Applica mossa sulla scacchiera fisica
                    if (move.move.length == 5) {
                      boardCtrl.makeMoveWithPromotion(
                        from: move.move.substring(0, 2),
                        to: move.move.substring(2, 4),
                        pieceToPromoteTo: move.move[4],
                      );
                    } else {
                      boardCtrl.makeMove(
                        from: move.move.substring(0, 2),
                        to: move.move.substring(2, 4),
                      );
                    }

                    // 2. AGGIORNA L'ALBERO DELLA NOTAZIONE E LE VARIANTI!
                    ref
                        .read(notationControllerProvider.notifier)
                        .handleNewMove(
                          boardCtrl.getFen(),
                          sanMove,
                          context,
                          comment: move.description, // ⚠️ BONUS INIETTATO!
                        );

                    // 3. Riavvia l'analisi del motore se era acceso
                    if (ref.read(engineControllerProvider).isRunning) {
                      ref
                          .read(engineControllerProvider.notifier)
                          .analyzeCurrentPosition(boardCtrl.getFen());
                    }

                    // 4. ⚠️ INVECE DI CHIUDERE IL PANNELLO, LO RICARICHIAMO!
                    // Togliamo Navigator.pop(context); e mettiamo questo:
                    setState(() {
                      _isLoading = true; // Mostra la rotellina di caricamento
                    });
                    await _fetchCloudData(); // Scarica le mosse della nuova posizione
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final fen = ref.read(boardControllerProvider).getFen();

    if (_isLoading) {
      return const SizedBox(
        height: 350,
        child: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a1a),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER CON TITOLO E PULSANTE CHIUSURA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "📖 ${loc.livebook} Cloud", // ⚠️ Usa il file di lingua!
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            // TAB BAR (Selettore tra Database Neurale e Umano)
            const TabBar(
              indicatorColor: Colors.orangeAccent,
              labelColor: Colors.orangeAccent,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: "ChessDB (Neural)"),
                Tab(text: "Lichess (Masters)"),
              ],
            ),
            // CONTENUTO TAB
            Expanded(
              child: TabBarView(
                children: [
                  _buildList(_chessDbResult, fen),
                  _buildList(_lichessResult, fen),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
