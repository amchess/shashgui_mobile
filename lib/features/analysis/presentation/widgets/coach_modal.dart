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
  double _timeSec = 2; // Valore in secondi
  bool _isRunning = false;
  bool _isFinished = false;

  // ⚠️ LA NUOVA VARIABILE PER LA MINIMIZZAZIONE
  bool _isMinimized = false;

  final List<String> _logs = [];
  String _report = "";

  late EngineManager _coachEngine;
  CrossedEvalOrchestrator? _orchestrator;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _reportScrollController = ScrollController();

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
      _logs.add(
        AppLocalizations.of(context)!.localeName == 'it'
            ? "Avvio motore base (Alexander)..."
            : "Starting base engine (Alexander)...",
      );
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
          // ⚠️ ESPANSIONE AUTOMATICA QUANDO HA FINITO!
          _isMinimized = false;
        });
      },
    );

    final fen = ref.read(boardControllerProvider).getFen();
    _orchestrator!.startCrossedEval(
      fen,
      _elo.toInt(),
      (_timeSec * 1000).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // ==========================================
    // ⚠️ LAYOUT MINIMIZZATO (PICCOLO BANNER)
    // ==========================================
    if (_isMinimized) {
      return GestureDetector(
        onTap: () =>
            setState(() => _isMinimized = false), // Cliccando si espande
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a1a),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_isRunning)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.orangeAccent,
                    strokeWidth: 2.5,
                  ),
                )
              else
                const Icon(Icons.psychology, color: Colors.orangeAccent),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _isRunning
                      ? "Coach in elaborazione..."
                      : "Coach in attesa...",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.expand_less, color: Colors.white),
                onPressed: () => setState(() => _isMinimized = false),
              ),
            ],
          ),
        ),
      );
    }

    // ==========================================
    // ⚠️ LAYOUT NORMALE (ESPANSO)
    // ==========================================
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a1a),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER CON TITOLO E PULSANTI (Minimizza e Chiudi)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40), // Bilanciamento per centrare il testo
              Expanded(
                child: Text(
                  loc.coachAnalisiIncrociata,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.expand_more, color: Colors.white54),
                    onPressed: () => setState(() => _isMinimized = true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),

          // FASE 1: IMPOSTAZIONI
          if (!_isRunning && !_isFinished) ...[
            Text(
              "Elo dell'Allievo: ${_elo.toInt()}",
              style: const TextStyle(color: Colors.white),
            ),
            Slider(
              value: _elo,
              min: 800,
              max: 3190,
              divisions: 239,
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
              "Tempo di riflessione: ${_timeSec.toInt()} s",
              style: const TextStyle(color: Colors.white),
            ),
            Slider(
              value: _timeSec,
              min: 1,
              max: 30,
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
                foregroundColor: Colors.white,
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
            const SizedBox(height: 16),
            // Bottone per minimizzare comodamente durante l'attesa
            ElevatedButton.icon(
              onPressed: () => setState(() => _isMinimized = true),
              icon: const Icon(Icons.expand_more),
              label: const Text("Minimizza e Gioca"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[800],
                foregroundColor: Colors.white,
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
                  controller: _reportScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _reportScrollController,
                    child: SelectableText(
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
                foregroundColor: Colors.white,
              ),
              child: Text(loc.chiudi),
            ),
          ],
        ],
      ),
    );
  }
}
