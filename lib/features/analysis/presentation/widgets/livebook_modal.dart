import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logic/livebook_scanner.dart';
import '../../domain/board_provider.dart';
import '../../domain/engine_controller.dart';

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

    // Esegue le due chiamate in parallelo per dimezzare i tempi d'attesa!
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

  Widget _buildList(LiveBookResult? result) {
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
              return ListTile(
                leading: const Icon(
                  Icons.arrow_right_alt,
                  color: Colors.white54,
                ),
                title: Text(
                  move.move.toUpperCase(),
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
                onTap: () {
                  if (move.move != "-" && !move.move.contains(".")) {
                    final boardCtrl = ref.read(boardControllerProvider);
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
                    if (ref.read(engineControllerProvider).isRunning) {
                      ref
                          .read(engineControllerProvider.notifier)
                          .analyzeCurrentPosition(boardCtrl.getFen());
                    }
                    Navigator.pop(context);
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
      height:
          MediaQuery.of(context).size.height *
          0.6, // Leggermente più alto per far spazio ai tab
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
                const Text(
                  "📖 Esploratore Cloud",
                  style: TextStyle(
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
                  _buildList(_chessDbResult),
                  _buildList(_lichessResult),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
