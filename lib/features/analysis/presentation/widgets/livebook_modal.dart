import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logic/livebook_scanner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/board_provider.dart';
import '../../domain/engine_controller.dart';
import '../../domain/notation_controller.dart';

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

    List<String> history = [];
    var tempNode = ref.read(notationControllerProvider).currentNode;

    // ⚠️ FIX Loop Sicuro: Usiamo add e un contatore per non impallare mai la RAM
    int safeCounter = 0;
    while (tempNode.parent != null && safeCounter < 200) {
      history.add(tempNode.san);
      tempNode = tempNode.parent!;
      safeCounter++;
    }
    history = history.reversed.toList();

    // Esegue le due chiamate in parallelo passando la cronologia corretta
    final results = await Future.wait([
      LiveBookScanner.scan(fen, history, true), // true = ChessDB
      LiveBookScanner.scan(fen, history, false), // false = Lichess
    ]);

    if (mounted) {
      setState(() {
        _chessDbResult = results[0];
        _lichessResult = results[1];
        _isLoading = false;
      });
    }
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
          // ⚠️ FIX DEFINITIVO: Rimosso lo "Scrollbar" e i suoi parametri che causavano il loop e l'overflow!
          // Usiamo un semplice Expanded -> SingleChildScrollView
          Expanded(
            flex: 1, // Occupa 1 porzione di spazio, blindando il testo
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                result.engineComment,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Divider(color: Colors.white24),
        Expanded(
          flex: 2, // La lista mosse occupa 2 porzioni di spazio
          child: ListView.builder(
            itemCount: result.moves.length,
            itemBuilder: (context, index) {
              final move = result.moves[index];
              return ListTile(
                leading: const Icon(
                  Icons.arrow_right_alt,
                  color: Colors.white54,
                ),
                title: Text(
                  move.san, // Accesso diretto e immediato alla stringa pre-calcolata
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

                    // 2. AGGIORNA L'ALBERO DELLA NOTAZIONE
                    ref
                        .read(notationControllerProvider.notifier)
                        .handleNewMove(
                          boardCtrl.getFen(),
                          move.san,
                          context,
                          comment: move.description,
                        );

                    // 3. Riavvia l'analisi del motore se era acceso
                    if (ref.read(engineControllerProvider).isRunning) {
                      ref
                          .read(engineControllerProvider.notifier)
                          .analyzeCurrentPosition(boardCtrl.getFen());
                    }

                    // 4. RICARICHIAMO I DATI DELLA NUOVA POSIZIONE
                    setState(() {
                      _isLoading = true;
                    });
                    await _fetchCloudData();
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
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFF1a1a1a),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(
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
                  "📖 ${loc.livebook} Cloud",
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
