import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'board_provider.dart';

class MoveNode {
  final String fen;
  final String san;
  MoveNode? parent;
  List<MoveNode> children = [];
  MoveNode({required this.fen, required this.san, this.parent});
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

  void addMove(String san, String fen, String choice) {
    // Se la mossa esiste già tra i figli, ci spostiamo lì
    for (var child in state.currentNode.children) {
      if (child.fen == fen) {
        state = state.copyWith(currentNode: child);
        return;
      }
    }

    final newNode = MoveNode(fen: fen, san: san, parent: state.currentNode);

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
}
