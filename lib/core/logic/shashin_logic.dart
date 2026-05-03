import 'package:flutter/material.dart';

class ShashinZone {
  final String name;
  final String symbol;
  final Color color;
  final double wp; // La percentuale esatta (0.0 - 100.0)
  final String avatar; // Quale faccina mostrare

  ShashinZone(this.name, this.symbol, this.color, this.wp, this.avatar);
}

/// Converte i millesimi WDL in una Zona Shashin con WP e Avatar
ShashinZone analyzeShashinZone(int w, int d, int l) {
  int total = w + d + l;
  if (total == 0)
    return ShashinZone("Calcolo...", "...", Colors.grey, 50.0, "⚖️");

  // Calcolo esatto Win Probability (WP)
  double wpDouble = ((w + (d / 2.0)) / 10.0);
  int wpInt = wpDouble.round();

  // Assegnazione Avatar (Percorsi alle immagini locali)
  String getAvatar(int wp) {
    // 1. Prima controlliamo se è una Pepita (Nugget)
    if (wp == 25 || wp == 75) return "assets/images/nugget.png";

    // 2. Altrimenti, assegniamo il giocatore standard
    if (wp > 50) return "assets/images/tal.png";
    if (wp < 50) return "assets/images/petrosian.png";

    // 3. Perfetto equilibrio
    return "assets/images/capablanca.png";
  }

  String avatar = getAvatar(wpInt);

  // Total Chaos: perfetto equilibrio
  if ((w - 333).abs() <= 5 && (d - 333).abs() <= 5 && (l - 333).abs() <= 5) {
    return ShashinZone(
      "Chaos: Capa-Petrosian-Tal",
      "∞",
      Colors.purple,
      wpDouble,
      "🌪️",
    );
  }

  // Pepite
  if (wpInt == 25)
    return ShashinZone(
      "Petrosian Nugget",
      "⚱️",
      Colors.orangeAccent,
      wpDouble,
      avatar,
    );
  if (wpInt == 75)
    return ShashinZone("Tal Nugget", "⚱️", Colors.tealAccent, wpDouble, avatar);

  // Zone PETROSIAN (Rosso/Arancio)
  if (wpInt <= 5)
    return ShashinZone("High Petrosian", "-+", Colors.red, wpDouble, avatar);
  if (wpInt <= 10)
    return ShashinZone(
      "High-Middle Petrosian",
      "-+ / -/+",
      Colors.deepOrange,
      wpDouble,
      avatar,
    );
  if (wpInt <= 15)
    return ShashinZone(
      "Middle Petrosian",
      "-/+",
      Colors.orange,
      wpDouble,
      avatar,
    );
  if (wpInt <= 20)
    return ShashinZone(
      "Middle-Low Petrosian",
      "-/+ / =/+",
      Colors.orangeAccent,
      wpDouble,
      avatar,
    );
  if (wpInt <= 24)
    return ShashinZone("Low Petrosian", "=/+", Colors.amber, wpDouble, avatar);
  if (wpInt <= 49)
    return ShashinZone(
      "Chaos: Capablanca-Petrosian",
      "↓",
      Colors.purpleAccent,
      wpDouble,
      avatar,
    );

  // Zona CAPABLANCA (Blu)
  if (wpInt == 50)
    return ShashinZone("Capablanca", "=", Colors.blue, wpDouble, avatar);

  // Zone TAL (Verde)
  if (wpInt <= 74)
    return ShashinZone(
      "Chaos: Capablanca-Tal",
      "↑",
      Colors.teal,
      wpDouble,
      avatar,
    );
  if (wpInt <= 79)
    return ShashinZone("Low Tal", "+/=", Colors.lightGreen, wpDouble, avatar);
  if (wpInt <= 84)
    return ShashinZone(
      "Middle-Low Tal",
      "+/= / +/-",
      Colors.green,
      wpDouble,
      avatar,
    );
  if (wpInt <= 89)
    return ShashinZone(
      "Middle Tal",
      "+/-",
      Colors.green[700]!,
      wpDouble,
      avatar,
    );
  if (wpInt <= 94)
    return ShashinZone(
      "High-Middle Tal",
      "+/- / +-",
      Colors.green[800]!,
      wpDouble,
      avatar,
    );

  return ShashinZone("High Tal", "+-", Colors.green[900]!, wpDouble, avatar);
}
