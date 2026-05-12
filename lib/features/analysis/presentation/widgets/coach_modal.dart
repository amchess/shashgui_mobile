import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/engine/engine_manager.dart';
import '../../../../core/orchestrators/crossed_eval.dart';
import '../../domain/board_provider.dart';

class CoachModal extends ConsumerStatefulWidget {
  const CoachModal({super.key});

  @override
  ConsumerState<CoachModal> createState() => _CoachModalState();
}

class _CoachModalState extends ConsumerState<CoachModal> {
  double _elo = 1500;
  double _timeSec = 2; // ⚠️ Modificato in secondi!

  bool _isRunning = false;
  bool _isFinished = false;

  final List<String> _logs = [];
  String _report = "";

  late EngineManager _coachEngine;
  CrossedEvalOrchestrator? _orchestrator;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _reportScrollController =
      ScrollController(); // ⚠️ Controller dedicato al testo finale

  @override
  void initState() {
    super.initState();
    _coachEngine = EngineManager();
  }

  @override
  void dispose() {
    _orchestrator?.dispose();
    _coachEngine.dispose();
    _scrollController.dispose();
    _reportScrollController.dispose();
    super.dispose();
  }

  Future<void> _startCoach() async {
    setState(() {
      _isRunning = true;
      _logs.add("Avvio motore base (Alexander)...");
    });

    await _coachEngine.initEngine('alexander', []);

    if (!mounted) return;

    _orchestrator = CrossedEvalOrchestrator(
      engineManager: _coachEngine,
      loc: AppLocalizations.of(context)!,
      onLog: (log) {
        if (!mounted) return;
        setState(() => _logs.add(log));
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      },
      onReportReady: (report) {
        if (!mounted) return;
        setState(() {
          _report = report;
          _isRunning = false;
          _isFinished = true;
        });
      },
    );

    final fen = ref.read(boardControllerProvider).getFen();
    // ⚠️ Moltiplichiamo i secondi per 1000 per passare i millisecondi corretti all'orchestratore
    _orchestrator!.startCrossedEval(
      fen,
      _elo.toInt(),
      (_timeSec * 1000).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      // Aumentato leggermente l'altezza per dare più respiro al testo
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a1a),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.coachAnalisiIncrociata,
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const Divider(color: Colors.white24, height: 30),

          // FASE 1: IMPOSTAZIONI
          if (!_isRunning && !_isFinished) ...[
            Text(
              "Elo dell'Allievo: ${_elo.toInt()}",
              style: const TextStyle(color: Colors.white),
            ),
            Slider(
              value: _elo,
              min: 800,
              max: 3190, // ⚠️ Limite aggiornato a 3190
              divisions: 239, // Scatti da 10 Elo
              label: _elo.toInt().toString(),
              activeColor: Colors.blueAccent,
              onChanged: (val) => setState(() => _elo = val),
            ),
            Text(
              loc.da2500EloInPoiIlMaestroSarLaRe,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 20),

            Text(
              "Tempo di riflessione: ${_timeSec.toInt()} s", // ⚠️ UI in secondi
              style: const TextStyle(color: Colors.white),
            ),
            Slider(
              value: _timeSec,
              min: 1,
              max: 30, // Massimo 30 secondi
              divisions: 29,
              label: "${_timeSec.toInt()} s",
              activeColor: Colors.greenAccent,
              onChanged: (val) => setState(() => _timeSec = val),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _startCoach,
              icon: const Icon(Icons.psychology),
              label: Text(loc.avviaCoach),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],

          // FASE 2: LOG IN TEMPO REALE
          if (_isRunning) ...[
            const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _logs[i],
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // FASE 3: VERDETTO FINALE
          if (_isFinished) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: Scrollbar(
                  // ⚠️ Aggiunta barra di scorrimento visibile
                  controller: _reportScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _reportScrollController,
                    child: SelectableText(
                      // ⚠️ Testo ora selezionabile per il copia/incolla!
                      _report,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
              ),
              child: Text(loc.chiudi),
            ),
          ],
        ],
      ),
    );
  }
}
