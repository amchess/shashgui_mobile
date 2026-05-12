import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/engine_controller.dart';
import '../../domain/board_provider.dart';
import 'uci_options_modal.dart';

class AnalysisSetupModal extends ConsumerStatefulWidget {
  const AnalysisSetupModal({super.key});

  @override
  ConsumerState<AnalysisSetupModal> createState() => _AnalysisSetupModalState();
}

class _AnalysisSetupModalState extends ConsumerState<AnalysisSetupModal> {
  String _selectedEngine = 'shashchess';
  double _t1 = 2.0;

  @override
  Widget build(BuildContext context) {
    // Inizializziamo il file delle lingue
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: const Color(0xFF2b2b2b),
      title: Text(
        loc.impostazioniAnalisi,
        style: const TextStyle(color: Colors.orangeAccent),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedEngine,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF2b2b2b),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: [
                    DropdownMenuItem(
                      value: 'shashchess',
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/shashchess.bmp',
                            width: 20,
                            height: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text("ShashChess (NNUE)"),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'alexander',
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/alexander.bmp',
                            width: 20,
                            height: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text("Alexander (HCE)"),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedEngine = v!),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.blueAccent),
                tooltip: loc.configuraParametri,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) =>
                        UciOptionsModal(engineName: _selectedEngine),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            "${loc.tempoInizialeT1PerMossa} ${_t1.toInt()} s",
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Slider(
            value: _t1,
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: Colors.cyanAccent,
            onChanged: (v) => setState(() => _t1 = v),
          ),

          Text(
            loc.ilTempoRaddoppierAutomaticamen,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            loc.annulla.toUpperCase(),
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            ref
                .read(engineControllerProvider.notifier)
                .startEngine(
                  ref.read(boardControllerProvider).getFen(),
                  baseTimeMs: (_t1 * 1000).toInt(),
                  engineName: _selectedEngine,
                );
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
          child: Text(
            loc.avviaAnalisi.toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
