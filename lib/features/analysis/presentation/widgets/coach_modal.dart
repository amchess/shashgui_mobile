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
  double _timeMs = 2000;

  bool _isRunning = false;
  bool _isFinished = false;

  final List<String> _logs = [];
  String _report = "";

  late EngineManager _coachEngine;
  CrossedEvalOrchestrator? _orchestrator;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _coachEngine = EngineManager(); // Motore isolato dal resto dell'app!
  }

  @override
  void dispose() {
    _orchestrator?.dispose();
    _coachEngine.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startCoach() async {
    setState(() {
      _isRunning = true;
      _logs.add("Avvio motore base (Alexander)...");
    });

    // Inizializziamo il motore HCE di base
    await _coachEngine.initEngine('alexander', []);

    if (!mounted) return;

    // Assembliamo il cervello del Coach
    _orchestrator = CrossedEvalOrchestrator(
      engineManager: _coachEngine,
      loc: AppLocalizations.of(context)!,
      onLog: (log) {
        if (!mounted) return;
        setState(() => _logs.add(log));
        // Auto-scroll verso il basso
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

    // Lanciamo la valutazione sulla FEN attuale
    final fen = ref.read(boardControllerProvider).getFen();
    _orchestrator!.startCrossedEval(fen, _elo.toInt(), _timeMs.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
              max: 3000,
              divisions: 22,
              activeColor: Colors.blueAccent,
              onChanged: (val) => setState(() => _elo = val),
            ),
            Text(
              loc.da2500EloInPoiIlMaestroSarLaRe,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 20),

            Text(
              "Tempo di riflessione: ${_timeMs.toInt()} ms",
              style: const TextStyle(color: Colors.white),
            ),
            Slider(
              value: _timeMs,
              min: 500,
              max: 10000,
              divisions: 19,
              activeColor: Colors.greenAccent,
              onChanged: (val) => setState(() => _timeMs = val),
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
                    color: Colors.orangeAccent.withOpacity(0.5),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
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
