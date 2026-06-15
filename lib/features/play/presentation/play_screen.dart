// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/import_export_service.dart';
import '../domain/play_controller.dart';
import 'custom_chess_board.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  ChessBoardController? _boardControllerListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boardControllerListener = ref.read(playBoardProvider);
      _boardControllerListener?.addListener(_syncBoard);
      _syncBoard();
    });
  }

  void _syncBoard() {
    if (_boardControllerListener != null) {
      ref
          .read(customBoardProvider.notifier)
          .updateFen(_boardControllerListener!.getFen());
    }
  }

  @override
  void dispose() {
    _boardControllerListener?.removeListener(_syncBoard);
    super.dispose();
  }

  Widget _buildPlayerBadge(
    String name,
    int timeMs,
    bool isWhite,
    int tcType,
    int baseTime,
  ) {
    String timeStr = "";
    int secs = (timeMs / 1000).ceil();

    if (tcType == 1) {
      timeStr = "${secs}s";
    } else {
      timeStr =
          "${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isWhite
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isWhite ? Colors.white : Colors.grey[700]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            name == 'UMANO'
                ? Icons.person
                : (name == 'shashchess' ? Icons.memory : Icons.shield),
            color: isWhite ? Colors.black87 : Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            name.toUpperCase(),
            style: TextStyle(
              color: isWhite ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              timeStr,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playControllerProvider);
    final boardController = ref.watch(playBoardProvider);
    final loc = AppLocalizations.of(context)!;

    bool isWhiteBottom = state.userColor == PlayerColor.white;

    // --- IL POP-UP DI FINE PARTITA CON TASTO ESPORTA ---
    ref.listen<PlayState>(playControllerProvider, (previous, next) {
      if (previous != null &&
          previous.isPlaying == true &&
          next.isPlaying == false) {
        if (next.logMessage != "Partita interrotta." &&
            next.logMessage != "Game interrupted.") {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF2b2b2b),
              title: Text(
                loc.finePartita,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              content: Text(
                next.logMessage,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    ImportExportService.copyPgnToClipboard(
                      context,
                      boardController.game.pgn(),
                    );
                  },
                  icon: const Icon(Icons.copy, color: Colors.greenAccent),
                  label: Text(
                    loc.localeName == 'it' ? "COPIA PGN" : "COPY PGN",
                    style: const TextStyle(color: Colors.greenAccent),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: Text(
                    loc.chiudi1,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.giocaControIlMotore),
        backgroundColor: const Color(0xFF1e1e1e),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            color: Colors.black26,
            child: Text(
              state.logMessage == "Imposta la partita e premi Gioca"
                  ? loc.impostaEGioca
                  : state.logMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (state.isPlaying)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPlayerBadge(
                    state.userColor == PlayerColor.white
                        ? 'UMANO'
                        : state.selectedEngine,
                    state.whiteTime,
                    true,
                    state.tcType,
                    state.userColor == PlayerColor.white
                        ? state.playerBaseTime
                        : state.engineBaseTime,
                  ),
                  _buildPlayerBadge(
                    state.userColor == PlayerColor.black
                        ? 'UMANO'
                        : state.selectedEngine,
                    state.blackTime,
                    false,
                    state.tcType,
                    state.userColor == PlayerColor.black
                        ? state.playerBaseTime
                        : state.engineBaseTime,
                  ),
                ],
              ),
            ),

          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: CustomChessBoard(
                    isWhiteBottom: isWhiteBottom,
                    onUserMove: (uciMove) {
                      if (!state.isPlaying) return;

                      final fen = boardController.getFen();
                      final isWhiteTurn = fen.split(' ')[1] == 'w';
                      final isUserTurn =
                          (state.userColor == PlayerColor.white &&
                              isWhiteTurn) ||
                          (state.userColor == PlayerColor.black &&
                              !isWhiteTurn);

                      if (!isUserTurn) {
                        ref
                            .read(customBoardProvider.notifier)
                            .updateFen(boardController.getFen());
                        return;
                      }

                      final fromSq = uciMove.substring(0, 2);
                      final toSq = uciMove.substring(2, 4);

                      if (uciMove.length == 5) {
                        boardController.makeMoveWithPromotion(
                          from: fromSq,
                          to: toSq,
                          pieceToPromoteTo: uciMove[4],
                        );
                      } else {
                        boardController.makeMove(from: fromSq, to: toSq);
                      }

                      ref.read(playControllerProvider.notifier).onUserMove();
                    },
                  ),
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1a1a1a),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!state.isPlaying) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        DropdownButton<PlayerColor>(
                          value: state.userColor,
                          dropdownColor: const Color(0xFF2b2b2b),
                          style: const TextStyle(color: Colors.white),
                          items: [
                            DropdownMenuItem(
                              value: PlayerColor.white,
                              child: Text(loc.bianco),
                            ),
                            DropdownMenuItem(
                              value: PlayerColor.black,
                              child: Text(loc.nero),
                            ),
                          ],
                          onChanged: (c) => ref
                              .read(playControllerProvider.notifier)
                              .setUserColor(c!),
                        ),
                        DropdownButton<String>(
                          value: state.selectedEngine,
                          dropdownColor: const Color(0xFF2b2b2b),
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'alexander',
                              child: Text("Alexander (HCE)"),
                            ),
                            DropdownMenuItem(
                              value: 'shashchess',
                              child: Text("ShashChess (NNUE)"),
                            ),
                          ],
                          onChanged: (e) => ref
                              .read(playControllerProvider.notifier)
                              .setEngine(e!),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 24),

                    SwitchListTile(
                      title: Text(
                        loc.localeName == 'it'
                            ? "Usa posizione corrente"
                            : "Use current position",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        loc.localeName == 'it'
                            ? "Inizia la partita dalla posizione visibile sulla scacchiera."
                            : "Start the game from the current position visible on the board.",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      value: state.useCurrentPosition,
                      activeColor: Colors.blueAccent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => ref
                          .read(playControllerProvider.notifier)
                          .toggleUseCurrentPosition(v),
                    ),
                    SwitchListTile(
                      title: Text(
                        loc.usaLivebookCloud,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        loc.ilMotorePescherLeApertureDalWe,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      value: state.useLivebook,
                      activeColor: Colors.greenAccent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => ref
                          .read(playControllerProvider.notifier)
                          .toggleLivebook(v),
                    ),

                    const Divider(color: Colors.white24, height: 24),

                    if (state.selectedEngine == 'alexander') ...[
                      SwitchListTile(
                        title: Text(
                          loc.limitaForza,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        value: state.limitStrength,
                        activeColor: Colors.blueAccent,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => ref
                            .read(playControllerProvider.notifier)
                            .toggleLimitStrength(v),
                      ),
                      if (state.limitStrength) ...[
                        Text(
                          "Livello ELO: ${state.eloValue.toInt()}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Slider(
                          value: state.eloValue,
                          min: 1000,
                          max: 2850,
                          divisions: 37,
                          label: state.eloValue.toInt().toString(),
                          activeColor: Colors.blueAccent,
                          onChanged: (v) => ref
                              .read(playControllerProvider.notifier)
                              .setEloValue(v),
                        ),
                      ],
                      const Divider(color: Colors.white24, height: 24),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<int>(
                            title: Text(
                              loc.tempoGlobaleFischer,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            value: 0,
                            groupValue: state.tcType,
                            activeColor: Colors.orangeAccent,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (v) => ref
                                .read(playControllerProvider.notifier)
                                .setTcType(v!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<int>(
                            title: Text(
                              loc.tempoFissoPerMossa,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            value: 1,
                            groupValue: state.tcType,
                            activeColor: Colors.orangeAccent,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (v) => ref
                                .read(playControllerProvider.notifier)
                                .setTcType(v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ⚠️ SEZIONE TEMPI ASIMMETRICI SDOPPIATA IN UI
                    Text(
                      loc.localeName == 'it'
                          ? "⏱️ TEMPO GIOCATORE (UMANO)"
                          : "⏱️ PLAYER TIME (HUMAN)",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              state.tcType == 0 ? loc.minuti : loc.secondi,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            DropdownButton<int>(
                              value: state.playerBaseTime,
                              dropdownColor: const Color(0xFF2b2b2b),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              items:
                                  (state.tcType == 0
                                          ? [1, 2, 3, 5, 10, 15, 30]
                                          : [1, 2, 3, 5, 10, 15])
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text("$e"),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) => ref
                                  .read(playControllerProvider.notifier)
                                  .setPlayerBaseTime(v!),
                            ),
                          ],
                        ),
                        if (state.tcType == 0)
                          Column(
                            children: [
                              Text(
                                loc.incrementoS,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                              DropdownButton<int>(
                                value: state.playerIncrement,
                                dropdownColor: const Color(0xFF2b2b2b),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                items: [0, 1, 2, 3, 5, 10, 15]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text("$e"),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => ref
                                    .read(playControllerProvider.notifier)
                                    .setPlayerIncrement(v!),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loc.localeName == 'it'
                          ? "🤖 TEMPO MOTORE"
                          : "🤖 ENGINE TIME",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              state.tcType == 0 ? loc.minuti : loc.secondi,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            DropdownButton<int>(
                              value: state.engineBaseTime,
                              dropdownColor: const Color(0xFF2b2b2b),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              items:
                                  (state.tcType == 0
                                          ? [1, 2, 3, 5, 10, 15, 30]
                                          : [1, 2, 3, 5, 10, 15])
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text("$e"),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) => ref
                                  .read(playControllerProvider.notifier)
                                  .setEngineBaseTime(v!),
                            ),
                          ],
                        ),
                        if (state.tcType == 0)
                          Column(
                            children: [
                              Text(
                                loc.incrementoS,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                              DropdownButton<int>(
                                value: state.engineIncrement,
                                dropdownColor: const Color(0xFF2b2b2b),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                items: [0, 1, 2, 3, 5, 10, 15]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text("$e"),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => ref
                                    .read(playControllerProvider.notifier)
                                    .setEngineIncrement(v!),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (state.isPlaying) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => ref
                                .read(playControllerProvider.notifier)
                                .resignGame(loc),
                            icon: const Icon(Icons.flag),
                            label: Text(
                              loc.localeName == 'it' ? "ABBANDONA" : "RESIGN",
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => ref
                                .read(playControllerProvider.notifier)
                                .offerDraw(loc),
                            icon: const Icon(Icons.handshake),
                            label: Text(
                              loc.localeName == 'it' ? "PATTA" : "DRAW",
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => ref
                            .read(playControllerProvider.notifier)
                            .stopGame(),
                        icon: const Icon(Icons.stop),
                        label: Text(
                          loc.localeName == 'it' ? "INTERROMPI" : "ABORT",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => ref
                            .read(playControllerProvider.notifier)
                            .startGame(loc),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          loc.localeName == 'it' ? "GIOCA" : "PLAY",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    if (boardController.game.history.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ImportExportService.copyPgnToClipboard(
                              context,
                              boardController.game.pgn(),
                            );
                          },
                          icon: const Icon(Icons.file_copy),
                          label: Text(
                            loc.localeName == 'it'
                                ? "COPIA PGN PER IL LABORATORIO"
                                : "COPY PGN FOR LAB",
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.cyanAccent,
                            side: const BorderSide(color: Colors.cyanAccent),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
