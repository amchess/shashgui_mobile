import 'package:flutter_test/flutter_test.dart';
import 'package:shashgui_mobile/core/logic/livebook_scanner.dart';

void main() {
  group('Oracle Roulette - Distribuzione Statistica', () {
    // Creiamo una finta lista di mosse "Elite" dal Cloud
    final eliteMoves = [
      LiveBookMove(move: "e2e4", san: "e4", description: "55.0%"), // Top
      LiveBookMove(move: "d2d4", san: "d4", description: "52.0%"), // Seconda
      LiveBookMove(move: "c2c4", san: "c4", description: "50.0%"), // Terza
    ];

    test('1. testRandomVal: 0.0 sceglie SEMPRE la prima mossa', () {
      // Simuliamo un Random() che estrae il valore minimo assoluto
      final move = OracleRoulette.spin(eliteMoves, testRandomVal: 0.0);
      expect(move, "e2e4");
    });

    test('2. testRandomVal: 0.99 sceglie SEMPRE l\'ultima mossa', () {
      // Simuliamo un Random() che estrae il valore massimo sfiorando l'1.0
      final move = OracleRoulette.spin(eliteMoves, testRandomVal: 0.99);
      expect(move, "c2c4");
    });

    test(
      '3. Fallback di sicurezza: posizioni disperate giocano sempre la migliore',
      () {
        // Se il winrate è bassissimo (<40%), la roulette viene ignorata per non rischiare
        final desperateMoves = [
          LiveBookMove(move: "g1f3", san: "Nf3", description: "35.0%"),
          LiveBookMove(move: "a2a3", san: "a3", description: "30.0%"),
        ];
        // Passiamo 0.99 che normalmente pescherebbe l'ultima mossa, ma qui DEVE pescare la prima
        final move = OracleRoulette.spin(desperateMoves, testRandomVal: 0.99);
        expect(move, "g1f3");
      },
    );
  });
}
