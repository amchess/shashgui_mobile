import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ⚠️ FIX: i percorsi corretti per risalire di due cartelle (../../)
import '../../domain/notation_controller.dart';
import '../../domain/engine_controller.dart';

class NotationPanel extends ConsumerWidget {
  const NotationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notationControllerProvider);
    List<Widget> widgets = [];

    void buildList(MoveNode node, int moveCount) {
      if (node.children.isEmpty) return;
      var mainMove = node.children.first;
      bool isCurrent = (mainMove == state.currentNode);
      String prefix = (moveCount % 2 != 0)
          ? "${(moveCount / 2).floor() + 1}. "
          : "";

      widgets.add(
        GestureDetector(
          onTap: () {
            ref
                .read(notationControllerProvider.notifier)
                .setCurrentNode(mainMove);
            if (ref.read(engineControllerProvider).isRunning) {
              ref
                  .read(engineControllerProvider.notifier)
                  .analyzeCurrentPosition(mainMove.fen);
            }
          },
          child: Text(
            "$prefix${mainMove.san} ",
            style: TextStyle(
              color: isCurrent ? Colors.orangeAccent : Colors.white,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
      );

      // =========================================================
      // ⚠️ MOSTRA IL COMMENTO SE ESISTE (Es. Valutazioni o Livebook)
      // =========================================================
      if (mainMove.comment != null && mainMove.comment!.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Text(
              "{ ${mainMove.comment} } ",
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      }

      if (node.children.length > 1) {
        for (int i = 1; i < node.children.length; i++) {
          var variant = node.children[i];
          widgets.add(
            GestureDetector(
              onTap: () {
                ref
                    .read(notationControllerProvider.notifier)
                    .setCurrentNode(variant);
                if (ref.read(engineControllerProvider).isRunning) {
                  ref
                      .read(engineControllerProvider.notifier)
                      .analyzeCurrentPosition(variant.fen);
                }
              },
              child: Text(
                "(${variant.san}) ",
                style: const TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }
      }
      buildList(mainMove, moveCount + 1);
    }

    buildList(state.root, 1);

    return Container(
      width: double.infinity,
      height: 100,
      padding: const EdgeInsets.all(12), // Uniformato all'AnalysisPanel
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: 0.3,
        ), // Stessa trasparenza dell'analisi
        borderRadius: BorderRadius.circular(12), // Stesso raggio di curvatura
        border: Border.all(color: Colors.white12),
      ),
      child: SingleChildScrollView(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4, // Piccolo spazio tra le mosse
          children: widgets.isEmpty
              ? [
                  const Text(
                    "Inizia a muovere...",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ]
              : widgets,
        ),
      ),
    );
  }
}
