// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/autoplay_controller.dart';

class AutoplayModal extends ConsumerWidget {
  const AutoplayModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final state = ref.watch(autoplayControllerProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a1a),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.impostazioniAutoplay,
              style: const TextStyle(
                color: Colors.purpleAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const Divider(color: Colors.white24, height: 30),

            // COLONNE MOTORI
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          loc.motoreBianco,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        DropdownButton<String>(
                          value: state.whiteEngine,
                          dropdownColor: const Color(0xFF2b2b2b),
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 13,
                          ),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'shashchess',
                              child: Row(
                                children: [
                                  Image.asset(
                                    'assets/images/shashchess.bmp',
                                    width: 18,
                                    height: 18,
                                    errorBuilder: (ctx, err, st) => const Icon(
                                      Icons.memory,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("ShashChess"),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'alexander',
                              child: Row(
                                children: [
                                  Image.asset(
                                    'assets/images/alexander.bmp',
                                    width: 18,
                                    height: 18,
                                    errorBuilder: (ctx, err, st) => const Icon(
                                      Icons.shield,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("Alexander"),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (v) => ref
                              .read(autoplayControllerProvider.notifier)
                              .setWhiteEngine(v!),
                        ),
                        SwitchListTile(
                          title: Text(
                            loc.livebook,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          value: state.whiteLivebook,
                          activeThumbColor: Colors.greenAccent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => ref
                              .read(autoplayControllerProvider.notifier)
                              .setWhiteLivebook(v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          loc.motoreNero,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        DropdownButton<String>(
                          value: state.blackEngine,
                          dropdownColor: const Color(0xFF2b2b2b),
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 13,
                          ),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'shashchess',
                              child: Row(
                                children: [
                                  Image.asset(
                                    'assets/images/shashchess.bmp',
                                    width: 18,
                                    height: 18,
                                    errorBuilder: (ctx, err, st) => const Icon(
                                      Icons.memory,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("ShashChess"),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'alexander',
                              child: Row(
                                children: [
                                  Image.asset(
                                    'assets/images/alexander.bmp',
                                    width: 18,
                                    height: 18,
                                    errorBuilder: (ctx, err, st) => const Icon(
                                      Icons.shield,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("Alexander"),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (v) => ref
                              .read(autoplayControllerProvider.notifier)
                              .setBlackEngine(v!),
                        ),
                        SwitchListTile(
                          title: Text(
                            loc.livebook,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          value: state.blackLivebook,
                          activeThumbColor: Colors.greenAccent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => ref
                              .read(autoplayControllerProvider.notifier)
                              .setBlackLivebook(v),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CADENZA E OROLOGI CON RADIO GROUP
            Row(
              children: [
                Expanded(
                  child: RadioListTile<int>(
                    title: Text(
                      loc.tempoGlobaleFischer,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                    value: 0,
                    groupValue: state.tcType,
                    activeColor: Colors.purpleAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => ref
                        .read(autoplayControllerProvider.notifier)
                        .setTcType(v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    title: Text(
                      loc.tempoFissoPerMossa,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                    value: 1,
                    groupValue: state.tcType,
                    activeColor: Colors.purpleAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => ref
                        .read(autoplayControllerProvider.notifier)
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
                                  ? [1, 2, 3, 5, 10]
                                  : [1, 2, 3, 5, 10])
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text("$e"),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => ref
                          .read(autoplayControllerProvider.notifier)
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
                        items: [0, 1, 2, 3, 5]
                            .map(
                              (e) =>
                                  DropdownMenuItem(value: e, child: Text("$e")),
                            )
                            .toList(),
                        onChanged: (v) => ref
                            .read(autoplayControllerProvider.notifier)
                            .setIncrement(v!),
                      ),
                    ],
                  ),
              ],
            ),

            // POSIZIONE E COLORI
            const Divider(color: Colors.white24, height: 32),
            Text(
              "POSIZIONE INIZIALE E COLORI",
              style: TextStyle(
                color: Colors.blueAccent[100],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            SwitchListTile(
              title: const Text(
                "Usa la posizione corrente",
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
              subtitle: const Text(
                "Inizia dalla scacchiera visibile dietro al menu.",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              value: state.useCurrentPosition,
              activeThumbColor: Colors.blueAccent,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => ref
                  .read(autoplayControllerProvider.notifier)
                  .setUseCurrentPosition(v),
            ),
            SwitchListTile(
              title: const Text(
                "Andata e Ritorno",
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
              subtitle: const Text(
                "Inverti i motori ad ogni nuovo round.",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              value: state.reverseColors,
              activeThumbColor: Colors.blueAccent,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => ref
                  .read(autoplayControllerProvider.notifier)
                  .setReverseColors(v),
            ),

            const Divider(color: Colors.white24, height: 32),
            Text(
              "NUMERO DI PARTITE (GAUNTLET)",
              style: TextStyle(
                color: Colors.purpleAccent[100],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            Slider(
              value: state.totalGames.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: "${state.totalGames}",
              activeColor: Colors.purpleAccent,
              onChanged: (v) => ref
                  .read(autoplayControllerProvider.notifier)
                  .setTotalGames(v.toInt()),
            ),
            const SizedBox(height: 12),

            // START BUTTON
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref
                    .read(autoplayControllerProvider.notifier)
                    .startMatch(context);
              },
              icon: const Icon(Icons.smart_toy),
              label: Text(loc.avviaMatch),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
