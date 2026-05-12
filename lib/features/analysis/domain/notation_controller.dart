import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'board_provider.dart';
import 'package:flutter/material.dart';

class MoveNode {
  final String fen;
  final String san;
  final String? comment;
  MoveNode? parent;
  List<MoveNode> children = [];
  MoveNode({required this.fen, required this.san, this.comment, this.parent});
}

class NotationState {
  final MoveNode root;
  final MoveNode currentNode;
  NotationState({required this.root, required this.currentNode});

  NotationState copyWith({MoveNode? root, MoveNode? currentNode}) {
    return NotationState(
      root: root ?? this.root,
      currentNode: currentNode ?? this.currentNode,
    );
  }
}

final notationControllerProvider =
    StateNotifierProvider<NotationController, NotationState>((ref) {
      return NotationController(ref);
    });

class NotationController extends StateNotifier<NotationState> {
  final Ref ref;
  NotationController(this.ref) : super(_initialState());

  static NotationState _initialState() {
    final root = MoveNode(
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      san: 'Inizio',
    );
    return NotationState(root: root, currentNode: root);
  }

  void addMove(String san, String fen, String choice, {String? comment}) {
    // Se la mossa esiste già tra i figli, ci spostiamo lì
    for (var child in state.currentNode.children) {
      if (child.fen == fen) {
        state = state.copyWith(currentNode: child);
        return;
      }
    }

    final newNode = MoveNode(
      fen: fen,
      san: san,
      comment: comment,
      parent: state.currentNode,
    );

    if (state.currentNode.children.isEmpty || choice == 'overwrite') {
      if (choice == 'overwrite') state.currentNode.children.clear();
      state.currentNode.children.add(newNode);
    } else if (choice == 'main') {
      state.currentNode.children.insert(0, newNode);
    } else {
      state.currentNode.children.add(newNode);
    }
    state = state.copyWith(currentNode: newNode);
  }

  void setCurrentNode(MoveNode node) {
    state = state.copyWith(currentNode: node);
    ref.read(boardControllerProvider).loadFen(node.fen);
  }

  void goBack() {
    if (state.currentNode.parent != null) {
      setCurrentNode(state.currentNode.parent!);
    }
  }

  void goForward() {
    if (state.currentNode.children.isNotEmpty) {
      setCurrentNode(state.currentNode.children.first);
    }
  }

  void goToStart() {
    setCurrentNode(state.root);
  }

  void goToEnd() {
    MoveNode temp = state.currentNode;
    while (temp.children.isNotEmpty) {
      temp = temp.children.first;
    }
    setCurrentNode(temp);
  }

  void reset() {
    state = _initialState();
  }

  Future<void> handleNewMove(
    String newFen,
    String san,
    BuildContext context, {
    String? comment,
  }) async {
    // 1. Controlla se esiste già
    for (var child in state.currentNode.children) {
      if (child.fen == newFen) {
        state = state.copyWith(currentNode: child);
        return;
      }
    }

    // 2. Chiedi se creare variante
    String choice = 'main';
    if (state.currentNode.children.isNotEmpty) {
      choice = await _showBranchingDialog(context) ?? 'cancel';
    }

    if (choice == 'cancel') {
      ref.read(boardControllerProvider).loadFen(state.currentNode.fen);
      return;
    }

    final newNode = MoveNode(
      fen: newFen,
      san: san,
      comment: comment,
      parent: state.currentNode,
    );
    if (choice == 'overwrite') state.currentNode.children.clear();

    if (choice == 'main' && state.currentNode.children.isNotEmpty) {
      state.currentNode.children.insert(0, newNode);
    } else {
      state.currentNode.children.add(newNode);
    }

    state = state.copyWith(currentNode: newNode);
  }

  Future<String?> _showBranchingDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2b2b2b),
        title: const Text(
          "Variante Rilevata",
          style: TextStyle(color: Colors.orangeAccent),
        ),
        content: const Text(
          "Esiste già una mossa in questo punto. Cosa vuoi fare?",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'main'),
                child: const Text("NUOVA LINEA PRINCIPALE"),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'variant'),
                child: const Text("AGGIUNGI VARIANTE"),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'overwrite'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                ),
                child: const Text("SOVRASCRIVI"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text(
                  "ANNULLA",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
