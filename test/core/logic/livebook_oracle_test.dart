import 'package:flutter_test/flutter_test.dart';
import 'package:shashgui_mobile/core/logic/livebook_oracle.dart';

void main() {
  group('LiveBookOracle - calculateEffectiveWinProbability (pEff)', () {
    test(
      '1. Scarta la mossa (ritorna -1.0) se la popolarità è inferiore allo 0.5%',
      () {
        // 1000 partite totali, questa mossa è stata giocata solo 4 volte (0.4%)
        final pEff = LiveBookOracle.calculateEffectiveWinProbability(
          2,
          0,
          2,
          1000,
          true,
        );

        // Deve essere scartata dal filtro anti-rumore
        expect(pEff, -1.0);
      },
    );

    test('2. Calcola correttamente il punteggio per il BIANCO', () {
      // 100 partite totali nell'apertura. Questa mossa giocata 50 volte (50% popolarità).
      // Di queste 50: 40 vinte dal bianco, 10 patte, 0 vinte dal nero.
      //
      // Matematica attesa:
      // WP Pura = (40 + 5) / 50 * 100 = 90.0%
      // Punteggio Popolarità = 50 / 100 * 100 = 50.0%
      // pEff = (90.0 * 0.70) + (50.0 * 0.30) = 63.0 + 15.0 = 78.0

      final pEff = LiveBookOracle.calculateEffectiveWinProbability(
        40,
        10,
        0,
        100,
        true,
      );
      expect(pEff, 78.0);
    });

    test('3. Calcola correttamente il punteggio per il NERO', () {
      // Come sopra, ma è il turno del nero e il nero domina.
      // 0 vinte dal bianco, 10 patte, 40 vinte dal nero.

      final pEff = LiveBookOracle.calculateEffectiveWinProbability(
        0,
        10,
        40,
        100,
        false,
      );
      expect(pEff, 78.0);
    });

    test('4. Penalizza mosse con 100% di WinRate ma rarissime (Anti-Trappola)', () {
      // Abbiamo una mossa pazzesca che vince il 100% delle volte, ma è stata giocata
      // solo 1 volta su 100 totali (1% popolarità).
      //
      // WP Pura = 100.0%
      // pEff = (100 * 0.70) + (1 * 0.30) = 70 + 0.3 = 70.3
      final pEffTrap = LiveBookOracle.calculateEffectiveWinProbability(
        1,
        0,
        0,
        100,
        true,
      );

      // Una mossa "standard" con il 50% di WinRate, ma giocata 80 volte (80% popolarità)
      // WP Pura = 50.0%
      // pEff = (50 * 0.70) + (80 * 0.30) = 35 + 24 = 59.0
      final pEffStandard = LiveBookOracle.calculateEffectiveWinProbability(
        40,
        0,
        40,
        100,
        true,
      );

      // Verifica che la matematica funzioni e scarti le percentuali assolute!
      expect(pEffTrap, 70.3);
      expect(pEffStandard, 59.0);
    });
  });
}
