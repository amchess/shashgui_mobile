import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/engine_controller.dart';
import '../../domain/board_provider.dart';
import '../../../../core/widgets/setup_position_dialog.dart';
import 'autoplay_modal.dart';
import 'livebook_modal.dart';
import 'coach_modal.dart';
import '../../domain/autoplay_controller.dart';
// Importiamo il file separato correttamente!
import 'analysis_setup_modal.dart';

class EngineControls extends ConsumerWidget {
  const EngineControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineState = ref.watch(engineControllerProvider);
    final autoplayState = ref.watch(autoplayControllerProvider);
    final boardController = ref.watch(boardControllerProvider);
    final loc = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a1a),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: engineState.isRunning
                  ? Icons.stop_circle
                  : Icons.power_settings_new,
              color: engineState.isRunning
                  ? Colors.redAccent
                  : Colors.greenAccent,
              label: engineState.isRunning ? "Stop" : loc.accendi,
              onPressed: () {
                if (engineState.isRunning) {
                  ref.read(engineControllerProvider.notifier).stopEngine();
                } else {
                  showDialog(
                    context: context,
                    builder: (context) => const AnalysisSetupModal(),
                  );
                }
              },
            ),
            _buildControlButton(
              icon: Icons.folder_open,
              color: Colors.white70,
              label: "PGN / FEN",
              onPressed: () async {
                final newFen = await showDialog<String>(
                  context: context,
                  builder: (context) =>
                      SetupPositionDialog(initialFen: boardController.getFen()),
                );
                if (newFen != null) {
                  boardController.loadFen(newFen);
                  if (engineState.isRunning) {
                    ref
                        .read(engineControllerProvider.notifier)
                        .analyzeCurrentPosition(newFen);
                  }
                }
              },
            ),
            _buildControlButton(
              icon: Icons.menu_book,
              color: Colors.blueAccent,
              label: loc.livebook,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const LivebookModal(),
                );
              },
            ),
            _buildControlButton(
              icon: Icons.psychology,
              color: Colors.orangeAccent,
              label: "Coach",
              onPressed: () {
                if (engineState.isRunning) {
                  ref.read(engineControllerProvider.notifier).stopEngine();
                }
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const CoachModal(),
                );
              },
            ),
            _buildControlButton(
              icon: autoplayState.isPlaying
                  ? Icons.stop_circle
                  : Icons.smart_toy,
              color: autoplayState.isPlaying
                  ? Colors.redAccent
                  : Colors.purpleAccent,
              label: autoplayState.isPlaying ? "Stop" : "Autoplay",
              onPressed: () {
                if (autoplayState.isPlaying) {
                  ref.read(autoplayControllerProvider.notifier).stopMatch();
                } else {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AutoplayModal(),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
