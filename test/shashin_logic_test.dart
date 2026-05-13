import 'package:flutter_test/flutter_test.dart';
import 'package:shashgui_mobile/core/logic/shashin_logic.dart';

void main() {
  group('Shashin Logic - analyzeShashinZone', () {
    test('1. Equilibrio perfetto (Capablanca) restituisce 50%', () {
      // 300 vittorie, 400 patte, 300 sconfitte.
      // wp = (300 + 400/2) / 1000 * 100 = 50%
      final zone = analyzeShashinZone(300, 400, 300);

      expect(zone.name, "Capablanca");
      expect(zone.wp, 50.0);
    });

    test('2. Total Chaos (333, 334, 333) restituisce la zona mista e 50%', () {
      // 333 + 334 + 333 = 1000
      // wp = (333 + 334/2) / 1000 * 100 = 50.0%
      final zone = analyzeShashinZone(333, 334, 333);

      expect(zone.name, "Chaos: Capa-Petrosian-Tal");
      expect(zone.wp, 50.0);
    });

    test('3. Dominio Bianco (High Tal) con wp >= 95%', () {
      // 900 vittorie, 100 patte, 0 sconfitte.
      // wp = (900 + 50) / 1000 * 100 = 95%
      final zone = analyzeShashinZone(900, 100, 0);

      expect(zone.name, "High Tal");
      expect(zone.wp, 95.0);
    });

    test('4. Dominio Nero (High Petrosian) con wp <= 5%', () {
      // 0 vittorie, 100 patte, 900 sconfitte.
      // wp = (0 + 50) / 1000 * 100 = 5%
      final zone = analyzeShashinZone(0, 100, 900);

      expect(zone.name, "High Petrosian");
      expect(zone.wp, 5.0);
    });

    test('5. Nugget check (25% Win Probability esatta)', () {
      // 0 vittorie, 500 patte, 500 sconfitte.
      // wp = (0 + 250) / 1000 * 100 = 25%
      final zone = analyzeShashinZone(0, 500, 500);

      expect(zone.name, "Petrosian Nugget");
      expect(zone.wp, 25.0);
    });

    test('6. Gestione sicura della divisione per zero (0 partite totali)', () {
      // Simuliamo il momento prima che il motore inizi a calcolare
      final zone = analyzeShashinZone(0, 0, 0);

      expect(zone.name, "Calcolo...");
      expect(zone.wp, 50.0);
    });
  });
}
