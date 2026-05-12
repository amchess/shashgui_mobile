import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/engine_controller.dart';
import '../../domain/autoplay_controller.dart';

class AnalysisPanel extends ConsumerWidget {
  const AnalysisPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineState = ref.watch(engineControllerProvider);
    final autoplayState = ref.watch(autoplayControllerProvider);

    final isAutoplay = autoplayState.isPlaying;
    final stats = isAutoplay ? autoplayState.stats : engineState.stats;
    final zone = isAutoplay ? autoplayState.zone : engineState.zone;

    final statusMsg = isAutoplay
        ? autoplayState.currentLog
        : (engineState.isRunning
              ? "⚙️ Analisi in corso..."
              : "Motore in standby");

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. IL CRONISTA
          Center(
            child: Text(
              statusMsg,
              style: TextStyle(
                color: isAutoplay ? Colors.greenAccent : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. TABELLONE MOTORI E LOGHI
          if (isAutoplay) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlayerBadge(
                  autoplayState.whiteEngine,
                  autoplayState.whiteTime,
                  true,
                  autoplayState.tcType,
                  autoplayState.baseTime,
                ),
                const Text(
                  "VS",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildPlayerBadge(
                  autoplayState.blackEngine,
                  autoplayState.blackTime,
                  false,
                  autoplayState.tcType,
                  autoplayState.baseTime,
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),
          ] else if (engineState.isRunning) ...[
            Center(
              child: _buildPlayerBadge(
                engineState.selectedEngine,
                0,
                true,
                1,
                0,
                hideTime: true,
              ),
            ),
            const Divider(color: Colors.white12, height: 20),
          ],

          // 3. HEADER ZONA TERMODINAMICA E AVATAR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name.toUpperCase(),
                    style: TextStyle(
                      color: zone.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Simbolo: ${zone.symbol} | WP: ${zone.wp.toStringAsFixed(1)}%",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: zone.color.withValues(alpha: 0.2),
                backgroundImage: AssetImage(zone.avatars.first),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4. TERMOMETRO SHASHIN
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: zone.wp / 100,
              minHeight: 12,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(zone.color),
            ),
          ),
          const SizedBox(height: 12),

          // 5. DATI TECNICI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Depth", "${stats.depth}/${stats.selDepth}"),
              _buildStatItem("Nodes", _formatNodes(stats.nodes)),
              _buildStatItem("NPS", _formatNodes(stats.nps)),
            ],
          ),

          // 6. PRINCIPAL VARIATION (PV) - SCROLLABILE!
          if (stats.pvs.isNotEmpty) ...[
            const Divider(color: Colors.white12, height: 16),
            ConstrainedBox(
              // ⚠️ Imposta un'altezza massima fissa. Se le linee la superano, appare lo scroll.
              constraints: const BoxConstraints(maxHeight: 85),
              child: SingleChildScrollView(
                physics:
                    const BouncingScrollPhysics(), // Effetto rimbalzo morbido
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: stats.pvs.asMap().entries.map((entry) {
                    int index = entry.key + 1;
                    String pvLine = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text(
                        stats.pvs.length > 1
                            ? "PV$index: $pvLine"
                            : "PV: $pvLine",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerBadge(
    String name,
    int timeMs,
    bool isWhite,
    int tcType,
    int baseTime, {
    bool hideTime = false,
  }) {
    String timeStr = "";
    if (!hideTime) {
      if (tcType == 1) {
        timeStr = "${baseTime}s";
      } else {
        int secs = timeMs ~/ 1000;
        timeStr =
            "${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}";
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isWhite ? Colors.black26 : Colors.white24,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Image.asset(
              'assets/images/$name.bmp',
              width: 16,
              height: 16,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                name == 'shashchess' ? Icons.memory : Icons.shield,
                color: isWhite ? Colors.black87 : Colors.white,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name.toUpperCase(),
            style: TextStyle(
              color: isWhite ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          if (!hideTime) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  String _formatNodes(int n) {
    if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}k";
    return n.toString();
  }
}
