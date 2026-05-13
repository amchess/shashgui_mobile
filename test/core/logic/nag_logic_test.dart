import 'package:flutter_test/flutter_test.dart';
import 'package:shashgui_mobile/core/logic/shashin_logic.dart';

void main() {
  group('NAG Logic - Assegnazione Zone e Cadute Termodinamiche', () {
    test('1. Verifica l\'indice delle Zone di confine', () {
      expect(getZoneIndex(4.9), 0); // High Petrosian
      expect(getZoneIndex(24.0), 4); // Low Petrosian
      expect(getZoneIndex(50.0), 6); // Capablanca Perfetto
      expect(getZoneIndex(76.0), 8); // Low Tal
      expect(getZoneIndex(95.0), 12); // High Tal estremo
    });

    test('2. Nessuna caduta (0 drop) = Mossa Eccellente/Interessante', () {
      // Allievo trova una mossa che tiene la partita in Capablanca (50%)
      // Maestro trova una mossa leggermente migliore ma sempre in Capablanca (50%)
      int drop = calculateZoneDrop(50.0, 50.0);
      expect(drop, 0); // Nessun NAG negativo
    });

    test('3. Imprecisione (?! = 1 drop)', () {
      // Allievo gioca da "Capablanca" (50.0)
      // Maestro trova una linea da "Chaos Tal" (51.0)
      int drop = calculateZoneDrop(50.0, 51.0);
      expect(drop, 1);
    });

    test('4. Errore (? = 2 drop)', () {
      // Allievo cade in "Low Petrosian" (24.0)
      // Il potenziale del Maestro era "Capablanca" (50.0)
      int drop = calculateZoneDrop(24.0, 50.0);
      expect(drop, 2);
    });

    test('5. Blunder Assoluto (?? >= 3 drop)', () {
      // Allievo regala la donna: "Middle Petrosian" (15.0)
      // Maestro sa come vincere: "Middle Tal" (85.0)
      int drop = calculateZoneDrop(15.0, 85.0);
      expect(
        drop,
        8,
      ); // 10 - 2 = 8 (Molto maggiore di 3, è un Blunder catastrofico!)
    });
  });
}
