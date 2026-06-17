import 'package:flutter/material.dart';
import '../../../../core/logic/shash_trace_models.dart';

class ShashBoardOverlayPainter extends CustomPainter {
  final AdvancedShashTrace trace;
  final bool isWhitePerspective; // true se il Bianco è in basso

  ShashBoardOverlayPainter({
    required this.trace,
    required this.isWhitePerspective,
  });

  /// Traduce una coordinata scacchistica (es: "e4") nei punti geometrici X e Y dello schermo
  Offset _getSquareCenter(String square, Size size) {
    int file = square.codeUnitAt(0) - 'a'.codeUnitAt(0); // 0 a 7 (colonne a-h)
    int rank = int.parse(square[1]) - 1; // 0 a 7 (righe 1-8)

    // Se la prospettiva è del Bianco, la riga 8 (rank=7) è in alto, la riga 1 (rank=0) è in basso.
    // Se la prospettiva è del Nero, le coordinate si invertono.
    if (isWhitePerspective) {
      rank = 7 - rank;
    } else {
      file = 7 - file;
    }

    double squareSize = size.width / 8;
    double x = (file * squareSize) + (squareSize / 2);
    double y = (rank * squareSize) + (squareSize / 2);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    double squareSize = size.width / 8;

    // ==========================================
    // 1. DISEGNO DELLA HEATMAP (Importanza SHAP)
    // ==========================================
    // Per lo scacchista: colora intensamente la base dei pezzi vitali per il piano corrente.
    trace.squareImpacts.forEach((square, impact) {
      if (impact.abs() < 15) {
        return; // Ignoriamo gli impatti minimi per non confondere l'occhio
      }

      Offset center = _getSquareCenter(square, size);

      // Calcoliamo l'intensità del colore in base all'impatto percentuale
      // Pezzi Keystone (>50%): colore molto marcato
      double intensity = (impact.abs() / 72.0).clamp(0.1, 0.6);

      Color glowColor = impact > 0
          // ignore: deprecated_member_use
          ? Colors.blue.withOpacity(
              intensity,
            ) // Pezzi positivi che sostengono la posizione
          // ignore: deprecated_member_use
          : Colors.red.withOpacity(
              intensity,
            ); // Pezzi che rappresentano un punto debole/cieco

      final paintGlow = Paint()
        ..shader =
            RadialGradient(
              // ignore: deprecated_member_use
              colors: [glowColor, glowColor.withOpacity(0.0)],
            ).createShader(
              Rect.fromCircle(center: center, radius: squareSize * 0.8),
            );

      canvas.drawCircle(center, squareSize * 0.8, paintGlow);
    });

    // ==========================================
    // 2. DISEGNO DELLE SINERGIE (Pairwise Ablation)
    // ==========================================
    // Per lo scacchista: linee verdi uniscono i pezzi che cooperano (es. difese interconnesse),
    // linee arancioni mostrano le ridondanze (pezzi che si bloccano l'un l'altro).
    for (var synergy in trace.synergies) {
      if (synergy.weight.abs() < 10) continue; // Filtriamo le relazioni deboli

      Offset p1 = _getSquareCenter(synergy.square1, size);
      Offset p2 = _getSquareCenter(synergy.square2, size);

      final paintLine = Paint()
        ..color = synergy.isCoordinated
            // ignore: deprecated_member_use
            ? Colors.green.withOpacity(0.6)
            // ignore: deprecated_member_use
            : Colors.orange.withOpacity(0.6)
        ..strokeWidth = (synergy.weight.abs() / 5.0).clamp(2.0, 6.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Disegniamo una linea tratteggiata o continua tra i due pezzi coordinati
      canvas.drawLine(p1, p2, paintLine);

      // Piccolo nodulo centrale per dare un feedback organico sulla forza della connessione
      final paintNode = Paint()
        ..color = synergy.isCoordinated ? Colors.green : Colors.orange;
      canvas.drawCircle(
        Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2),
        4,
        paintNode,
      );
    }

    // ==========================================
    // 3. EVIDENZIARE GLI AVAMPOSTI LATENTI
    // ==========================================
    // Per lo scacchista: mostra un cerchio geometrico dorato e futuristico sulle case
    // dove i filtri neurali implorano di posizionare un pezzo.
    for (var outpost in trace.outposts) {
      Offset center = _getSquareCenter(outpost.square, size);

      // Disegniamo un mirino geometrico elegante sulla casa libera
      final paintOutpostRing = Paint()
        // ignore: deprecated_member_use
        ..color = Colors.amber.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, squareSize * 0.35, paintOutpostRing);

      // Testo interno per indicare la lettera del pezzo ideale (es: N o B)
      final textPainter = TextPainter(
        text: TextSpan(
          text: outpost.idealPiece,
          style: TextStyle(
            color: Colors.amber.shade200,
            fontSize: squareSize * 0.3,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ShashBoardOverlayPainter oldDelegate) {
    return oldDelegate.trace != trace ||
        oldDelegate.isWhitePerspective != isWhitePerspective;
  }
}
