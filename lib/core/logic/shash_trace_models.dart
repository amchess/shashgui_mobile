/// Rappresenta una sinergia o una ridondanza tra due pezzi.
/// Per lo scacchista: Spiega se due pezzi si aiutano a vicenda (es. Batteria Alfiere+Donna)
/// o se si intralciano/fanno lo stesso lavoro (Ridondanza).
class ShashPieceSynergy {
  final String square1; // Es: "f2"
  final String square2; // Es: "d4"
  final double
  weight; // Impatto percentuale (positivo = coordinazione, negativo = intralcio)

  ShashPieceSynergy({
    required this.square1,
    required this.square2,
    required this.weight,
  });

  bool get isCoordinated => weight > 0;
}

/// Rappresenta un avamposto latente rilevato dai filtri della rete neurale.
/// Per lo scacchista: Indica una casa vuota dove l'inserimento di un pezzo specifico
/// cambierebbe drasticamente il corso della partita.
class LatentOutpost {
  final String square; // Es: "c7"
  final double wpImpact; // Incremento della probabilità di vittoria (es: +28%)
  final String
  idealPiece; // Il pezzo ideale suggerito dai filtri NNUE (es: "N" per Cavallo)

  LatentOutpost({
    required this.square,
    required this.wpImpact,
    required this.idealPiece,
  });
}

/// Il contenitore globale di tutte le informazioni estratte dalla traccia.
class AdvancedShashTrace {
  double baseWinProbability = 50.0;

  // Impatto di ogni casa/pezzo sulla probabilità di vittoria (SHAP-Proxy)
  Map<String, double> squareImpacts = {};

  // Lista delle sinergie attive sulla scacchiera
  List<ShashPieceSynergy> synergies = [];

  // Lista degli avamposti latenti ideali
  List<LatentOutpost> outposts = [];

  // Scomposizione del giudizio della rete neurale
  double materialPsqtWp = 50.0; // Valutazione del puro materiale statico
  double structuralDeltaWp =
      0.0; // Il "Neural Delta": quanto la struttura altera il materiale
  int activeBucket = 0; // Fase di gioco interna rilevata dalla rete
}
