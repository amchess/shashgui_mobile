import 'dart:async';
import '../engine/engine_manager.dart';
import '../logic/shashin_logic.dart';
import '../logic/livebook_scanner.dart';

enum CrossedState {
  idle,
  staticEval,
  baseEval,
  studentThinking,
  masterStaticEval, // <--- NUOVO STATO
  masterThinking,
}

class CrossedEvalOrchestrator {
  final EngineManager engineManager;
  CrossedState currentState = CrossedState.idle;
  StreamSubscription<String>? _outputSubscription;

  String currentFen = "";
  bool isWhiteToMove = true;

  int baseTimeMs = 2000; // <--- NUOVO

  int studentElo = 1500;
  int masterElo = 2000;
  String studentSchool = "";
  String masterSchool = "";

  LiveBookResult? cloudLichess;
  LiveBookResult? cloudChessDb;

  ShashinZone? baseZone;
  String? studentMove;
  ShashinZone? studentZone;
  String? masterMove;
  ShashinZone? masterZone;

  // Variabili per l'analisi Statica (comando 'eval')
  int? spaceWhite;
  int? spaceBlack;
  String? worstPieceWhite;
  String? worstPieceBlack;

  String? worstPieceNnue;

  // Callback per la UI
  final Function(String) onLog;
  final Function(String) onReportReady;

  CrossedEvalOrchestrator({
    required this.engineManager,
    required this.onLog,
    required this.onReportReady,
  }) {
    _outputSubscription = engineManager.engineOutput?.listen(
      _handleEngineOutput,
    );
  }

  void _determineSchools(int elo) {
    studentElo = elo;
    if (elo < 2000) {
      studentSchool = "Principianti";
      masterElo = 2199;
      masterSchool = "Intermedia";
    } else if (elo < 2200) {
      studentSchool = "Intermedia";
      masterElo = 2399;
      masterSchool = "Avanzata";
    } else if (elo < 2500) {
      // <--- Soglia portata a 2500
      studentSchool = "Avanzata";
      masterElo = 3190;
      masterSchool = "Esperta (Max HCE)";
    } else {
      studentSchool = "Esperta";
      masterElo = 3500; // Flag per ShashChess
      masterSchool = "Super-Umana (NNUE)";
    }
  }

  void startCrossedEval(String fen, int playerElo, int timeMs) async {
    // <--- Aggiunto int timeMs
    if (currentState != CrossedState.idle) engineManager.sendCommand('stop');

    currentFen = fen;
    baseTimeMs = timeMs; // <--- Salva il tempo
    isWhiteToMove = fen.split(' ')[1] == 'w';
    _determineSchools(playerElo);

    // Reset variabili statiche
    spaceWhite = null;
    spaceBlack = null;
    worstPieceWhite = null;
    worstPieceBlack = null;

    onLog("===========================================");
    onLog("🌐 [Coach] Interrogazione Oracoli Cloud (Lichess/ChessDB)...");

    try {
      cloudLichess = await LiveBookScanner.scan(fen, [], false);
      cloudChessDb = await LiveBookScanner.scan(fen, [], true);
    } catch (e) {
      onLog("⚠️ Errore Cloud: $e");
    }

    // FASE 1: Estrazione parametri semantici (comando eval)
    currentState = CrossedState.staticEval;
    onLog(
      "📍 [Coach] Scansione semantica della posizione (Makogonov/Spazio)...",
    );
    engineManager.sendCommand('position fen $fen');
    engineManager.sendCommand('eval');
  }

  void _handleEngineOutput(String line) {
    // --- LETTURA TRACCIA NEURALE (SHASHCHESS EVAL) ---
    if (currentState == CrossedState.masterStaticEval) {
      String targetColor = isWhiteToMove ? "White" : "Black";
      final match = RegExp(
        "($targetColor) pieces \\(worst to best static activity\\):\\s*([A-Z]?)([a-h][1-8])\\((-?\\d+)\\)\\s*<-- Worst unit",
      ).firstMatch(line);

      if (match != null) {
        String pieceChar = match.group(2)!;
        String sq = match.group(3)!;

        switch (pieceChar) {
          case 'N':
            worstPieceNnue = 'il Cavallo in $sq';
            break;
          case 'B':
            worstPieceNnue = "l'Alfiere in $sq";
            break;
          case 'R':
            worstPieceNnue = 'la Torre in $sq';
            break;
          case 'Q':
            worstPieceNnue = 'la Donna in $sq';
            break;
          case 'K':
            worstPieceNnue = 'il Re in $sq';
            break;
          default:
            worstPieceNnue = 'il Pedone in $sq';
        }
      }

      if (line.startsWith("*** Note: Static activity")) {
        // Fine lettura neurale, avvia il pensiero del Maestro!
        currentState = CrossedState.masterThinking;
        engineManager.sendCommand('go movetime $baseTimeMs');
      }
      return;
    }
    // --- LETTURA TRACCIA STATICA (EVAL) ---
    if (currentState == CrossedState.staticEval) {
      // Cattura Spazio (Alexander)
      final spaceMatch = RegExp(
        r"Total Space: White (\d+) - Black (\d+)",
      ).firstMatch(line);
      if (spaceMatch != null) {
        spaceWhite = int.tryParse(spaceMatch.group(1)!);
        spaceBlack = int.tryParse(spaceMatch.group(2)!);
      }

      // Helper interno per tradurre i pezzi
      String translatePiece(String engPiece) {
        switch (engPiece.trim().toLowerCase()) {
          case 'pawn':
            return 'il Pedone';
          case 'knight':
            return 'il Cavallo';
          case 'bishop':
            return "l'Alfiere";
          case 'rook':
            return 'la Torre';
          case 'queen':
            return 'la Donna';
          case 'king':
            return 'il Re';
          default:
            return 'il pezzo';
        }
      }

      // Cattura Pezzi Peggiori (Makogonov per Alexander) - ORA PRENDE ANCHE LA CASA!
      final makWhiteMatch = RegExp(
        r"Makogonov White: Improve (.+?) on ([a-h][1-8])",
      ).firstMatch(line);
      if (makWhiteMatch != null) {
        worstPieceWhite =
            "${translatePiece(makWhiteMatch.group(1)!)} in ${makWhiteMatch.group(2)!}";
      }

      final makBlackMatch = RegExp(
        r"Makogonov Black: Improve (.+?) on ([a-h][1-8])",
      ).firstMatch(line);
      if (makBlackMatch != null) {
        worstPieceBlack =
            "${translatePiece(makBlackMatch.group(1)!)} in ${makBlackMatch.group(2)!}";
      }

      // Fine della traccia 'eval'
      if (line.startsWith("Best move:") ||
          line.contains("Final static evaluation") ||
          line.startsWith("*** Note:")) {
        currentState = CrossedState.baseEval;
        onLog("📍 [Coach] Calcolo Zona Termodinamica in corso...");

        // Usa esattamente il tempo scelto dall'utente!
        engineManager.sendCommand('go movetime $baseTimeMs');
      }
      return;
    }

    // --- LETTURA DINAMICA (WDL E MOSSE) ---
    final wdlMatch = RegExp(r"wdl (\d+) (\d+) (\d+)").firstMatch(line);
    if (wdlMatch != null) {
      int w = int.parse(wdlMatch.group(1)!);
      int d = int.parse(wdlMatch.group(2)!);
      int l = int.parse(wdlMatch.group(3)!);
      ShashinZone currentZ = analyzeShashinZone(w, d, l);

      if (currentState == CrossedState.baseEval) {
        baseZone = currentZ;
      } else if (currentState == CrossedState.studentThinking)
        studentZone = currentZ;
      else if (currentState == CrossedState.masterThinking)
        masterZone = currentZ;
    }
    if (line.startsWith("bestmove")) {
      final moveMatch = RegExp(r"bestmove (\w+)").firstMatch(line);
      if (moveMatch != null) {
        String move = moveMatch.group(1)!;

        if (currentState == CrossedState.baseEval) {
          currentState = CrossedState.studentThinking;
          onLog(
            "🧑‍🎓 L'Allievo (Scuola $studentSchool - Elo $studentElo) elabora il piano...",
          );
          // --- INIZIO PARTE MANCANTE ---
          engineManager.sendCommand('position fen $currentFen');
          engineManager.sendCommand(
            'setoption name UCI_LimitStrength value true',
          );
          engineManager.sendCommand('setoption name UCI_Elo value $studentElo');
          engineManager.sendCommand('go movetime $baseTimeMs');
        } else if (currentState == CrossedState.studentThinking) {
          studentMove = move;
          _startMasterPhase();
        } else if (currentState == CrossedState.masterThinking) {
          masterMove = move;
          _finishAndReport();
        }
      }
    }
  } // <-- Queste sono le parentesi graffe che chiudevano _handleEngineOutput
  // --- FINE PARTE MANCANTE ---

  // --- NUOVO METODO PER LO SWAP DEL MOTORE ---
  Future<void> _startMasterPhase() async {
    currentState = CrossedState.masterThinking;
    onLog("🧙‍♂️ Preparazione Maestro (Scuola $masterSchool)...");

    if (masterElo >= 3500) {
      onLog(
        "🚀 Cambio motore in corso: Spegnimento Alexander -> Avvio ShashChess...",
      );

      // 1. Uccidiamo il vecchio processo Alexander
      engineManager.dispose();

      // 2. Inizializziamo ShashChess (con le sue reti neurali)
      await engineManager.initEngine('shashchess', [
        'nn-c288c895ea92.nnue',
        'nn-37f18f62d772.nnue',
      ]);

      // 3. CRITICO: Ri-agganciamo l'ascoltatore!
      // Poiché initEngine ha creato un nuovo stream di comunicazione, dobbiamo rimetterci in ascolto.
      _outputSubscription?.cancel();
      _outputSubscription = engineManager.engineOutput?.listen(
        _handleEngineOutput,
      );

      onLog("✅ ShashChess pronto alla massima forza.");

      // Chiediamo a ShashChess di valutare i suoi pezzi peggiori
      currentState = CrossedState.masterStaticEval;
      engineManager.sendCommand('position fen $currentFen');
      engineManager.sendCommand('eval');
      return; // Usciamo, il 'go movetime' verrà lanciato dal listener di sopra!
    } else {
      // Se il maestro è ancora Alexander, impostiamo solo l'handicap UCI
      engineManager.sendCommand('setoption name UCI_LimitStrength value true');
      engineManager.sendCommand('setoption name UCI_Elo value $masterElo');

      currentState = CrossedState.masterThinking;
      engineManager.sendCommand('position fen $currentFen');
      engineManager.sendCommand('go movetime $baseTimeMs');
    }
  }

  // NLP: Genera l'analisi testuale della posizione iniziale (Senza HTML!)
  String _generateStaticAnalysisText() {
    String txt = "";

    if (spaceWhite != null && spaceBlack != null) {
      int diff = spaceWhite! - spaceBlack!;
      if (diff >= 4) {
        txt +=
            "Il Bianco gode di un netto dominio territoriale, che gli garantisce grande libertà di manovra.\n";
      } else if (diff >= 1 && diff <= 3)
        txt += "Il Bianco possiede un lieve vantaggio di spazio.\n";
      else if (diff <= -4)
        txt +=
            "Il Nero ha conquistato un forte vantaggio di spazio, asfissiando i pezzi bianchi.\n";
      else if (diff >= -3 && diff <= -1)
        txt += "Il Nero detiene un leggero controllo territoriale superiore.\n";
      else
        txt +=
            "La gestione dello spazio sulla scacchiera è in perfetto equilibrio.\n";
    }

    String? worst = isWhiteToMove ? worstPieceWhite : worstPieceBlack;
    if (worst != null) {
      txt +=
          "Secondo il principio di Makogonov, il pezzo che richiede più urgenza di essere riattivato è $worst.";
    }

    return txt.isNotEmpty ? txt.trim() : "Valutazione posizionale complessa.";
  }

  // Helper interno per assegnare l'indice di Zona Shashin (0-12)
  int _getZoneIndex(double wp) {
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

  void _finishAndReport() {
    currentState = CrossedState.idle;
    StringBuffer report = StringBuffer();

    // 1. CLOUD
    report.writeln("🌐 VALUTAZIONI CLOUD:");
    if (cloudLichess != null &&
        cloudLichess!.moves.isNotEmpty &&
        cloudLichess!.moves.first.move != "-") {
      report.writeln(
        "• Lichess (Umani): ${cloudLichess!.moves.first.move} (${cloudLichess!.moves.first.description})",
      );
    } else {
      report.writeln("• Lichess (Umani): Nessuna giocata predominante");
    }
    if (cloudChessDb != null &&
        cloudChessDb!.moves.isNotEmpty &&
        cloudChessDb!.moves.first.move != "-") {
      report.writeln(
        "• ChessDB (Neurali): ${cloudChessDb!.moves.first.move} (${cloudChessDb!.moves.first.description})",
      );
    }
    report.writeln("");

    // 2. ANALISI PRE-MOSSA
    report.writeln("📍 SCENOGRAFIA STATICA (Pre-Mossa):");
    report.writeln(
      "• Zona: ${baseZone?.name ?? '-'} (${baseZone?.symbol ?? ''})",
    );
    report.writeln("ℹ️ ${_generateStaticAnalysisText()}");
    report.writeln("");

    // 3. ALLIEVO
    report.writeln("🧑‍🎓 LA TUA IDEA (Scuola $studentSchool):");
    report.writeln("• Mossa scelta: $studentMove");
    report.writeln(
      "• Aspettativa: ${studentZone?.name ?? '-'} (${studentZone?.wp.toStringAsFixed(1)}%)",
    );
    report.writeln("");

    // 4. MAESTRO
    report.writeln("🧙‍♂️ L'IDEA DEL MAESTRO (Scuola $masterSchool):");
    report.writeln("• Mossa scelta: $masterMove");
    report.writeln(
      "• Aspettativa: ${masterZone?.name ?? '-'} (${masterZone?.wp.toStringAsFixed(1)}%)",
    );

    // NUOVO: Integrazione Makogonov ShashChess sempre visibile
    if (worstPieceNnue != null) {
      report.writeln("🔍 Pezzo peggiore per la Rete Neurale: $worstPieceNnue");
    }
    report.writeln("");

    // 5. VERDETTO E NAG
    report.writeln("💡 VERDETTO DEL COACH:");
    if (studentMove == masterMove) {
      report.writeln("🌟 ECCELLENTE!");
      report.writeln(
        "Hai trovato la stessa mossa del Maestro. Stai giocando a un livello superiore alla tua categoria, rispettando i canoni posizionali estratti nell'analisi statica.",
      );
    } else {
      double sWp = studentZone?.wp ?? 50.0;
      double mWp = masterZone?.wp ?? 50.0;
      int sIndex = _getZoneIndex(sWp);
      int mIndex = _getZoneIndex(mWp);
      int zoneDrop = mIndex - sIndex;

      if (zoneDrop >= 3) {
        report.writeln("❌ NAG: ?? (Grave Errore)");
        report.writeln(
          "La tua idea cede un vantaggio letale facendo crollare la posizione di $zoneDrop Zone. Il Maestro suggerisce una via diversa per salvare la posizione.",
        );
      } else if (zoneDrop == 2) {
        report.writeln("⚠️ NAG: ? (Errore)");
        report.writeln(
          "Una svista posizionale o tattica. La posizione scende di $zoneDrop Zone rispetto al potenziale massimizzato dal Maestro.",
        );
      } else if (zoneDrop == 1) {
        report.writeln("🤔 NAG: ?! (Imprecisione)");
        report.writeln(
          "La tua idea è giocabile, ma perdi una Zona Termodinamica rispetto alla mossa del Maestro.",
        );
      } else {
        report.writeln("👌 NAG: !? (Interessante)");
        if (mWp - sWp > 8.0) {
          report.writeln(
            "La mossa del Maestro ($masterMove) spreme più vantaggio, ma la tua idea mantiene la stessa Zona (${studentZone?.name}). È saggio giocare il piano che comprendi meglio.",
          );
        } else {
          report.writeln(
            "Idea validissima! Sei vicino alla valutazione del Maestro e mantieni intatta la Zona Termodinamica.",
          );
        }
      }
    }

    // 6. VISIONE AVANZATA (Solo ShashChess e se le mosse differiscono)
    if (masterElo >= 3500 &&
        worstPieceNnue != null &&
        studentMove != masterMove) {
      String worstBase = isWhiteToMove
          ? (worstPieceWhite ?? "")
          : (worstPieceBlack ?? "");
      if (worstBase.isNotEmpty) {
        report.writeln("");
        report.writeln("👁️ VISIONE AVANZATA DEL MAESTRO:");
        if (worstBase != worstPieceNnue) {
          report.writeln(
            "Il Maestro ha identificato il problema su $worstBase e lo ha risolto. Ora il punto debole è diventato $worstPieceNnue.",
          );
        } else {
          report.writeln(
            "Il Maestro ignora la passività di $worstBase, indicando un attacco tattico o un sacrificio dinamico (la mossa $masterMove garantisce il picco di attività).",
          );
        }
      }
    }

    onReportReady(report.toString());
    onLog("✅ Valutazione incrociata completata.");
    engineManager.sendCommand('setoption name UCI_LimitStrength value false');
  }

  void stop() {
    engineManager.sendCommand('stop');
    engineManager.sendCommand('setoption name UCI_LimitStrength value false');
    currentState = CrossedState.idle;
  }

  void dispose() {
    _outputSubscription?.cancel();
  }
}
