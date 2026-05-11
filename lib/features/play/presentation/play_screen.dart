// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import '../../../../l10n/app_localizations.dart';
import '../domain/play_controller.dart';

class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playControllerProvider);
    final boardController = ref.watch(playBoardProvider);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.giocaControIlMotore),
        backgroundColor: const Color(0xFF1e1e1e),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. MESSAGGI DI STATO E LOG
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

          // 2. LA SCACCHIERA DI GIOCO
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 10),
                    ],
                  ),
                  child: ChessBoard(
                    controller: boardController,
                    boardColor: BoardColor.brown,
                    boardOrientation: state.userColor,
                    enableUserMoves: state.isPlaying,
                    onMove: () =>
                        ref.read(playControllerProvider.notifier).onUserMove(),
                  ),
                ),
              ),
            ),
          ),

          // 3. PANNELLO IMPOSTAZIONI E CONTROLLI
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
                  // --- SELETTORE COLORE E MOTORE ---
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
                        onChanged: state.isPlaying
                            ? null
                            : (c) => ref
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
                        onChanged: state.isPlaying
                            ? null
                            : (e) => ref
                                  .read(playControllerProvider.notifier)
                                  .setEngine(e!),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),

                  // --- OPZIONI LIVEBOOK E TRATTI ---
                  SwitchListTile(
                    title: Text(
                      loc.usaLivebookCloud,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    subtitle: Text(
                      loc.ilMotorePescherLeApertureDalWe,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    value: state.useLivebook,
                    activeColor: Colors.greenAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: state.isPlaying
                        ? null
                        : (v) => ref
                              .read(playControllerProvider.notifier)
                              .toggleLivebook(v),
                  ),
                  ListTile(
                    title: Text(
                      loc.filtriTrattiPosizionali,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    subtitle: Text(
                      loc.aggiungeBiasStrategicoAlleMoss,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: const Icon(
                      Icons.lock,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc.funzioneTrattiPosizionaliBlocc),
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 24),

                  // --- OPZIONI ELO (SOLO PER ALEXANDER) ---
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
                      onChanged: state.isPlaying
                          ? null
                          : (v) => ref
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
                        onChanged: state.isPlaying
                            ? null
                            : (v) => ref
                                  .read(playControllerProvider.notifier)
                                  .setEloValue(v),
                      ),
                    ],
                    const Divider(color: Colors.white24, height: 24),
                  ],

                  // --- CONTROLLO TEMPO ---
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
                          onChanged: state.isPlaying
                              ? null
                              : (v) => ref
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
                          onChanged: state.isPlaying
                              ? null
                              : (v) => ref
                                    .read(playControllerProvider.notifier)
                                    .setTcType(v!),
                        ),
                      ),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            state.tcType == 0 ? loc.minuti : loc.secondi,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          DropdownButton<int>(
                            value: state.baseTime,
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
                            onChanged: state.isPlaying
                                ? null
                                : (v) => ref
                                      .read(playControllerProvider.notifier)
                                      .setBaseTime(v!),
                          ),
                        ],
                      ),
                      if (state.tcType == 0)
                        Column(
                          children: [
                            Text(
                              loc.incrementoS,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            DropdownButton<int>(
                              value: state.increment,
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
                              onChanged: state.isPlaying
                                  ? null
                                  : (v) => ref
                                        .read(playControllerProvider.notifier)
                                        .setIncrement(v!),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- BOTTONE PRINCIPALE START / STOP ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (state.isPlaying) {
                          ref.read(playControllerProvider.notifier).stopGame();
                        } else {
                          ref.read(playControllerProvider.notifier).startGame();
                        }
                      },
                      icon: Icon(
                        state.isPlaying ? Icons.stop : Icons.play_arrow,
                      ),
                      label: Text(
                        state.isPlaying ? loc.annulla : loc.gioca,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.isPlaying
                            ? Colors.red[700]
                            : Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
