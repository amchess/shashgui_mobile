import 'package:flutter/material.dart';

class ShashinZone {
  final String name;
  final String symbol;
  final Color color;

  ShashinZone(this.name, this.symbol, this.color);
}

/// Converte i millesimi WDL del motore in una Zona Shashin
ShashinZone analyzeShashinZone(int w, int d, int l) {
  int total = w + d + l;
  if (total == 0) return ShashinZone("Calcolo in corso...", "...", Colors.grey);

  // Total Chaos: perfetto equilibrio
  if ((w - 333).abs() <= 5 && (d - 333).abs() <= 5 && (l - 333).abs() <= 5) {
    return ShashinZone("Chaos: Capablanca-Petrosian-Tal", "∞", Colors.purple);
  }

  // Calcolo Win Probability (WP) 0-100
  int wpInt = ((w + (d / 2.0)) / 10.0).round();

  // Pepite d'oro
  if (wpInt == 25)
    return ShashinZone("Petrosian Nugget", "⚱️", Colors.orangeAccent);
  if (wpInt == 75) return ShashinZone("Tal Nugget", "⚱️", Colors.tealAccent);

  // Zone PETROSIAN
  if (wpInt <= 5) return ShashinZone("High Petrosian", "-+", Colors.red);
  if (wpInt <= 10)
    return ShashinZone("High-Middle Petrosian", "-+ / -/+", Colors.deepOrange);
  if (wpInt <= 15) return ShashinZone("Middle Petrosian", "-/+", Colors.orange);
  if (wpInt <= 20)
    return ShashinZone(
      "Middle-Low Petrosian",
      "-/+ / =/+",
      Colors.orangeAccent,
    );
  if (wpInt <= 24) return ShashinZone("Low Petrosian", "=/+", Colors.amber);
  if (wpInt <= 49)
    return ShashinZone("Chaos: Capablanca-Petrosian", "↓", Colors.purpleAccent);

  // Zona CAPABLANCA
  if (wpInt == 50) return ShashinZone("Capablanca", "=", Colors.blue);

  // Zone TAL
  if (wpInt <= 74)
    return ShashinZone("Chaos: Capablanca-Tal", "↑", Colors.teal);
  if (wpInt <= 79) return ShashinZone("Low Tal", "+/=", Colors.lightGreen);
  if (wpInt <= 84)
    return ShashinZone("Middle-Low Tal", "+/= / +/-", Colors.green);
  if (wpInt <= 89) return ShashinZone("Middle Tal", "+/-", Colors.green[700]!);
  if (wpInt <= 94)
    return ShashinZone("High-Middle Tal", "+/- / +-", Colors.green[800]!);

  return ShashinZone("High Tal", "+-", Colors.green[900]!);
}
