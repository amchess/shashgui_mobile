import 'shash_trace_models.dart';

class ShashTraceParser {
  /// Analizza l'intero blocco di testo generato da "eval" di ShashChess
  static AdvancedShashTrace parse(String rawTrace) {
    final trace = AdvancedShashTrace();
    final lines = rawTrace.split('\n');

    bool inCriticalFeatures = false;
    bool inPairwiseAblation = false;
    bool inMultiPieceProbe = false;

    for (var line in lines) {
      line = line.trim();

      // 1. Estrazione della Probabilità di Vittoria Base
      if (line.contains("Base Win Probability (White):")) {
        final match = RegExp(r'(\d+)%').firstMatch(line);
        if (match != null) {
          trace.baseWinProbability =
              double.tryParse(match.group(1) ?? '50') ?? 50.0;
        }
        continue;
      }

      // 2. Lettura dell'Impatto dei Singoli Pezzi (SHAP-Proxy)
      if (line.contains("White's Most Influential Pieces:") ||
          line.contains("Black's Most Influential Pieces:")) {
        inCriticalFeatures = true;
        inPairwiseAblation = false;
        inMultiPieceProbe = false;
        continue;
      }

      if (inCriticalFeatures) {
        // Cerca pattern come: "- Ra1 : +72% WP impact" oppure "- ra8 : +28% WP"
        final match = RegExp(
          r'-\s+([a-zA-Z]+)(\d)\s*:\s*\+?(-?\d+)%',
        ).firstMatch(line);
        if (match != null) {
          String pieceAndCol = match.group(1) ?? '';
          String row = match.group(2) ?? '';
          double impact = double.tryParse(match.group(3) ?? '0') ?? 0.0;

          if (pieceAndCol.isNotEmpty && row.isNotEmpty) {
            // Estraiamo la casa logica (es: "a1" o "a8") prendendo l'ultima lettera del pezzo + la riga
            String square =
                "${pieceAndCol.substring(pieceAndCol.length - 1).toLowerCase()}$row";
            trace.squareImpacts[square] = impact;
          }
          continue;
        }
        // Se incontriamo una nuova sezione numerata, usciamo dalle Critical Features
        if (RegExp(r'^\d+\.').hasMatch(line) || line.isEmpty) {
          inCriticalFeatures = false;
        }
      }

      // 3. Lettura delle Sinergie di Coppia (Pairwise Ablation)
      if (line.contains("6. PAIRWISE ABLATION")) {
        inPairwiseAblation = true;
        inCriticalFeatures = false;
        inMultiPieceProbe = false;
        continue;
      }

      if (inPairwiseAblation) {
        // Cerca pattern come: "- Pf2 + Pd4 : +21% WP synergy" o "- Pa2 + Pb2 : -15% WP synergy"
        final match = RegExp(
          r'-\s+[a-zA-Z]([a-h][1-8])\s*\+\s*[a-zA-Z]([a-h][1-8])\s*:\s*\+?(-?\d+)%',
        ).firstMatch(line);
        if (match != null) {
          String sq1 = match.group(1) ?? '';
          String sq2 = match.group(2) ?? '';
          double weight = double.tryParse(match.group(3) ?? '0') ?? 0.0;

          trace.synergies.add(
            ShashPieceSynergy(square1: sq1, square2: sq2, weight: weight),
          );
          continue;
        }
        if (RegExp(r'^\d+\.').hasMatch(line) || line.isEmpty) {
          inPairwiseAblation = false;
        }
      }

      // 4. Lettura del Canale dei Filtri degli Avamposti (Multi-Piece Filter Probe)
      if (line.contains("7. MULTI-PIECE FILTER PROBE")) {
        inMultiPieceProbe = true;
        inCriticalFeatures = false;
        inPairwiseAblation = false;
        continue;
      }

      if (inMultiPieceProbe) {
        // Cerca linee come: "h1      +28%    +28%   +28%  => N (mobility/outpost filter)"
        final match = RegExp(
          r'^([a-h][1-8])\s+\+?(-?\d+)%[^\n]+=>\s*([NBRQ])',
        ).firstMatch(line);
        if (match != null) {
          String sq = match.group(1) ?? '';
          double wp = double.tryParse(match.group(2) ?? '0') ?? 0.0;
          String piece = match.group(3) ?? 'N';

          trace.outposts.add(
            LatentOutpost(square: sq, wpImpact: wp, idealPiece: piece),
          );
          continue;
        }
        if (line.contains("===") || line.isEmpty) {
          inMultiPieceProbe = false;
        }
      }

      // 5. Composizione Astratta dell'Algoritmo (Materiale vs Pattern)
      if (line.contains("Material perception (PSQT)")) {
        final match = RegExp(r'(\d+)%').firstMatch(line);
        if (match != null) {
          trace.materialPsqtWp =
              double.tryParse(match.group(1) ?? '50') ?? 50.0;
        }
      }
      if (line.contains("Structural abstraction")) {
        final match = RegExp(r'([-+]\d+)%').firstMatch(line);
        if (match != null) {
          trace.structuralDeltaWp =
              double.tryParse(match.group(1) ?? '0') ?? 0.0;
        }
      }
    }

    return trace;
  }
}
