import 'package:flutter/material.dart';

class ShashinZone {
  final String name;
  final String symbol;
  final Color color;
  final double wp; // La percentuale esatta (0.0 - 100.0)
  final List<String> avatars; // Quale faccina mostrare (ora supporta array)

  ShashinZone(this.name, this.symbol, this.color, this.wp, this.avatars);
}

/// Converte i millesimi WDL in una Zona Shashin con WP e Avatar
ShashinZone analyzeShashinZone(int w, int d, int l) {
  int total = w + d + l;
  if (total == 0) {
    return ShashinZone("Calcolo...", "...", Colors.grey, 50.0, [
      "assets/images/capablanca.png",
    ]);
  }

  // Calcolo esatto Win Probability (WP)
  double wpDouble = ((w + (d / 2.0)) / total) * 100.0;
  int wpInt = wpDouble.round();

  // Assegnazione Avatar (Percorsi alle immagini locali)
  List<String> getAvatars(int wp) {
    // 0. Total Chaos
    if ((w - 333).abs() <= 5 && (d - 333).abs() <= 5 && (l - 333).abs() <= 5) {
      return [
        "assets/images/capablanca.png",
        "assets/images/petrosian.png",
        "assets/images/tal.png",
      ];
    }

    // 1. Prima controlliamo se è una Pepita (Nugget)
    if (wp == 25 || wp == 75) return ["assets/images/nugget.png"];

    // 2. Zone miste (Caos)
    if (wp >= 25 && wp <= 49) {
      return ["assets/images/capablanca.png", "assets/images/petrosian.png"];
    }
    if (wp >= 51 && wp <= 75) {
      return ["assets/images/capablanca.png", "assets/images/tal.png"];
    }

    // 3. Altrimenti, assegniamo il giocatore standard
    if (wp > 50) return ["assets/images/tal.png"];
    if (wp < 50) return ["assets/images/petrosian.png"];

    // 4. Perfetto equilibrio
    return ["assets/images/capablanca.png"];
  }

  List<String> avatars = getAvatars(wpInt);

  // Total Chaos: perfetto equilibrio
  if ((w - 333).abs() <= 5 && (d - 333).abs() <= 5 && (l - 333).abs() <= 5) {
    return ShashinZone(
      "Chaos: Capa-Petrosian-Tal",
      "∞",
      Colors.purple,
      wpDouble,
      avatars,
    );
  }

  // Pepite
  if (wpInt == 25) {
    return ShashinZone(
      "Petrosian Nugget",
      "⚱️",
      Colors.orangeAccent,
      wpDouble,
      avatars,
    );
  }
  if (wpInt == 75) {
    return ShashinZone(
      "Tal Nugget",
      "⚱️",
      Colors.tealAccent,
      wpDouble,
      avatars,
    );
  }

  // Zone PETROSIAN (Rosso/Arancio)
  if (wpInt >= 0 && wpInt <= 5) {
    return ShashinZone("High Petrosian", "-+", Colors.red, wpDouble, avatars);
  }
  if (wpInt >= 6 && wpInt <= 10) {
    return ShashinZone(
      "High-Middle Petrosian",
      r"-+ \ -/+",
      Colors.deepOrange,
      wpDouble,
      avatars,
    );
  }
  if (wpInt >= 11 && wpInt <= 15) {
    return ShashinZone(
      "Middle Petrosian",
      "-/+",
      Colors.orange,
      wpDouble,
      avatars,
    );
  }
  if (wpInt >= 16 && wpInt <= 20) {
    return ShashinZone(
      "Middle-Low Petrosian",
      r"-/+ \ =/+",
      Colors.orangeAccent,
      wpDouble,
      avatars,
    );
  }
  if (wpInt >= 21 && wpInt <= 24) {
    return ShashinZone("Low Petrosian", "=/+", Colors.amber, wpDouble, avatars);
  }
  if (wpInt >= 25 && wpInt <= 49) {
    return ShashinZone(
      "Chaos: Capablanca-Petrosian",
      "↓",
      Colors.purpleAccent,
      wpDouble,
      avatars,
    );
  }

  // Zona CAPABLANCA (Blu)
  if (wpInt == 50) {
    return ShashinZone("Capablanca", "=", Colors.blue, wpDouble, avatars);
  }

  // Zone TAL (Verde)
  if (wpInt >= 51 && wpInt <= 75) {
    return ShashinZone(
      "Chaos: Capablanca-Tal",
      "↑",
      Colors.teal,
      wpDouble,
      avatars,
    );
  }
  if (wpInt >= 76 && wpInt <= 79) {
    return ShashinZone("Low Tal", "+/=", Colors.lightGreen, wpDouble, avatars);
  }
  if (wpInt >= 80 && wpInt <= 84) {
    return ShashinZone(
      "Middle-Low Tal",
      r"+/= \ +/-",
      Colors.green,
      wpDouble,
      avatars,
    );
  }
  if (wpInt >= 85 && wpInt <= 89) {
    return ShashinZone(
      "Middle Tal",
      "+/-",
      Colors.green[700]!,
      wpDouble,
      avatars,
    );
  }
  if (wpInt >= 90 && wpInt <= 94) {
    return ShashinZone(
      "High-Middle Tal",
      r"+/- \ +-",
      Colors.green[800]!,
      wpDouble,
      avatars,
    );
  }

  return ShashinZone("High Tal", "+-", Colors.green[900]!, wpDouble, avatars);
}

// =========================================================================
// ⚠️ HELPER PUBBLICI PER L'ASSEGNAZIONE DEI NAG (Testabili in isolamento)
// =========================================================================

/// Converte la Win Probability (0-100) nell'indice della scala termodinamica (0-12)
int getZoneIndex(double wp) {
  if (wp <= 5) return 0;
  if (wp <= 10) return 1;
  if (wp <= 15) return 2;
  if (wp <= 20) return 3;
  if (wp <= 24) return 4;
  if (wp <= 49) return 5;
  if (wp <= 50) return 6;
  if (wp <= 75) return 7;
  if (wp <= 79) return 8;
  if (wp <= 84) return 9;
  if (wp <= 89) return 10;
  if (wp <= 94) return 11;
  return 12;
}

/// Calcola di quante zone termodinamiche scende la mossa dell'Allievo rispetto al Maestro
int calculateZoneDrop(double studentWp, double masterWp) {
  return getZoneIndex(masterWp) - getZoneIndex(studentWp);
}
