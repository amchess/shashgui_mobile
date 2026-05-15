import 'package:flutter/material.dart';

class ShashinZone {
  final String name;
  final String symbol;
  final Color color;
  final double wp;
  final List<String> avatars;
  final String shashinMode;
  final double avatarScale; // ⚠️ NUOVO: Gestisce la grandezza della faccina!

  ShashinZone(
    this.name,
    this.symbol,
    this.color,
    this.wp,
    this.avatars, {
    this.shashinMode = "Normal",
    this.avatarScale = 1.0, // 1.0 è la dimensione normale di default
  });
}

/// Converte i millesimi WDL in una Zona Shashin rispettando la Tabella Ufficiale
ShashinZone analyzeShashinZone(int w, int d, int l) {
  int total = w + d + l;
  if (total == 0) {
    return ShashinZone("Calcolo...", "...", Colors.grey, 50.0, [
      "assets/images/capablanca.png",
    ]);
  }

  // Calcolo WP
  double wpDouble = ((w + (d / 2.0)) / total) * 100.0;
  int wpInt = wpDouble.round();

  // 1. Assegnazione Avatar
  List<String> getAvatars(int wp) {
    // Total Chaos
    if ((w - 333).abs() <= 5 && (d - 333).abs() <= 5 && (l - 333).abs() <= 5) {
      return [
        "assets/images/capablanca.png",
        "assets/images/petrosian.png",
        "assets/images/tal.png",
      ];
    }
    // Le Pepite a 25 e 75 esatti!
    if (wp == 25 || wp == 75) return ["assets/images/nugget.png"];

    // Zone Caos
    if (wp >= 25 && wp <= 49) {
      return ["assets/images/capablanca.png", "assets/images/petrosian.png"];
    }
    if (wp >= 51 && wp <= 75) {
      return ["assets/images/capablanca.png", "assets/images/tal.png"];
    }

    // Dominio netto
    if (wp > 50) return ["assets/images/tal.png"];
    if (wp < 50) return ["assets/images/petrosian.png"];
    return ["assets/images/capablanca.png"];
  }

  List<String> avatars = getAvatars(wpInt);

  // ==========================================
  // TABELLA SHASHIN UFFICIALE (MAPPING ESATTO)
  // ==========================================

  // Total Chaos: perfetto equilibrio WDL
  if ((w - 333).abs() <= 5 && (d - 333).abs() <= 5 && (l - 333).abs() <= 5) {
    return ShashinZone(
      "Chaos: Capablanca-Petrosian-Tal",
      "∞",
      Colors.purple,
      wpDouble,
      avatars,
      shashinMode: "Normal",
      avatarScale: 1.0,
    );
  }

  // ZONE PETROSIAN [0 - 49]
  if (wpInt >= 0 && wpInt <= 5) {
    return ShashinZone(
      "High Petrosian",
      "-+",
      Colors.red,
      wpDouble,
      avatars,
      shashinMode: "Petrosian",
      avatarScale: 1.3,
    ); // Grandissimo
  }
  if (wpInt >= 6 && wpInt <= 10) {
    return ShashinZone(
      "High-Middle Petrosian",
      r"-+ \ -/+",
      Colors.deepOrange,
      wpDouble,
      avatars,
      shashinMode: "Petrosian",
      avatarScale: 1.15,
    );
  }
  if (wpInt >= 11 && wpInt <= 15) {
    return ShashinZone(
      "Middle Petrosian",
      "-/+",
      Colors.orange,
      wpDouble,
      avatars,
      shashinMode: "Petrosian",
      avatarScale: 1.0,
    ); // Normale
  }
  if (wpInt >= 16 && wpInt <= 20) {
    return ShashinZone(
      "Middle-Low Petrosian",
      r"-/+ \ =/+",
      Colors.orangeAccent,
      wpDouble,
      avatars,
      shashinMode: "Petrosian",
      avatarScale: 0.85,
    );
  }
  if (wpInt >= 21 && wpInt <= 24) {
    return ShashinZone(
      "Low Petrosian",
      "=/+",
      Colors.amber,
      wpDouble,
      avatars,
      shashinMode: "Petrosian",
      avatarScale: 0.7,
    ); // Molto piccolo
  }
  if (wpInt >= 25 && wpInt <= 49) {
    String name = wpInt == 25
        ? "Petrosian Nugget"
        : "Chaos: Capablanca-Petrosian";
    return ShashinZone(
      name,
      "↓",
      Colors.purpleAccent,
      wpDouble,
      avatars,
      shashinMode: "Normal",
      avatarScale: 1.0,
    );
  }

  // ZONA CAPABLANCA [50]
  if (wpInt == 50) {
    return ShashinZone(
      "Capablanca",
      "=",
      Colors.blue,
      wpDouble,
      avatars,
      shashinMode: "Capablanca",
      avatarScale: 1.0,
    );
  }

  // ZONE TAL [51 - 100]
  if (wpInt >= 51 && wpInt <= 75) {
    String name = wpInt == 75 ? "Tal Nugget" : "Chaos: Capablanca-Tal";
    return ShashinZone(
      name,
      "↑",
      Colors.teal,
      wpDouble,
      avatars,
      shashinMode: "Normal",
      avatarScale: 1.0,
    );
  }
  if (wpInt >= 76 && wpInt <= 79) {
    return ShashinZone(
      "Low Tal",
      "+/=",
      Colors.lightGreen,
      wpDouble,
      avatars,
      shashinMode: "Tal",
      avatarScale: 0.7,
    ); // Molto piccolo
  }
  if (wpInt >= 80 && wpInt <= 84) {
    return ShashinZone(
      "Middle-Low Tal",
      r"+/= \ +/-",
      Colors.green,
      wpDouble,
      avatars,
      shashinMode: "Tal",
      avatarScale: 0.85,
    );
  }
  if (wpInt >= 85 && wpInt <= 89) {
    return ShashinZone(
      "Middle Tal",
      "+/-",
      Colors.green.shade700,
      wpDouble,
      avatars,
      shashinMode: "Tal",
      avatarScale: 1.0,
    ); // Normale
  }
  if (wpInt >= 90 && wpInt <= 94) {
    return ShashinZone(
      "High-Middle Tal",
      r"+/- \ +-",
      Colors.green.shade800,
      wpDouble,
      avatars,
      shashinMode: "Tal",
      avatarScale: 1.15,
    );
  }
  if (wpInt >= 95 && wpInt <= 100) {
    return ShashinZone(
      "High Tal",
      "+-",
      Colors.green.shade900,
      wpDouble,
      avatars,
      shashinMode: "Tal",
      avatarScale: 1.3,
    ); // Grandissimo
  }

  return ShashinZone("Unknown", "?", Colors.grey, wpDouble, avatars);
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
