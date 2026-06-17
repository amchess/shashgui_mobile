import 'package:flutter/foundation.dart';
import 'dart:async';
import '../engine/engine_manager.dart';
import '../logic/shashin_logic.dart';
import '../logic/livebook_scanner.dart';
import '../../l10n/app_localizations.dart';

enum CrossedState {
  idle,
  staticEval,
  baseEval,
  studentThinking,
  masterStaticEval,
  masterThinking,
}

class CrossedEvalOrchestrator {
  final EngineManager engineManager;
  final AppLocalizations loc;
  CrossedState currentState = CrossedState.idle;
  StreamSubscription<String>? _outputSubscription;

  String currentFen = "";
  bool isWhiteToMove = true;
  int baseTimeMs = 2000;

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

  // --- VARIABILI ANALISI STATICA (HCE CLASSICA) ---
  int? spaceWhite;
  int? spaceBlack;
  String? worstPieceWhite;
  String? worstPieceBlack;
  String? centerType;
  double? deltaK;
  double? deltaExpansion;
  bool hasBishopPairWhite = false;
  bool hasBishopPairBlack = false;

  // --- NUOVE VARIABILI XAI (SHASHCHESS COMPACT TRACE) ---
  int? nnueWp;
  String? nnueZone;
  String? nnueWorstWhite;
  String? nnueWorstBlack;
  String? nnueBestOutpost;
  String? nnueBlindspotW;
  String? nnueBlindspotB;
  int? nnueDelta;

  final Function(String) onLog;
  final Function(String) onReportReady;

  CrossedEvalOrchestrator({
    required this.engineManager,
    required this.onLog,
    required this.onReportReady,
    required this.loc,
  }) {
    _outputSubscription = engineManager.engineOutput?.listen(
      _handleEngineOutput,
    );
  }

  void _determineSchools(int elo) {
    studentElo = elo;
    if (elo < 2000) {
      studentSchool = loc.schoolBeginner;
      masterElo = 2199;
      masterSchool = loc.schoolIntermediate;
    } else if (elo < 2200) {
      studentSchool = loc.schoolIntermediate;
      masterElo = 2399;
      masterSchool = loc.schoolAdvanced;
    } else if (elo < 2500) {
      studentSchool = loc.schoolAdvanced;
      masterElo = 3190;
      masterSchool = loc.schoolExpertHCE;
    } else {
      studentSchool = loc.schoolExpert;
      masterElo = 3500;
      masterSchool = loc.schoolSuperhumanNNUE;
    }
  }

  void startCrossedEval(String fen, int playerElo, int timeMs) async {
    if (currentState != CrossedState.idle) {
      engineManager.sendCommand('stop');
    }

    currentFen = fen;
    baseTimeMs = timeMs;
    isWhiteToMove = fen.split(' ')[1] == 'w';
    _determineSchools(playerElo);

    // Reset Variabili Statiche e XAI
    spaceWhite = null;
    spaceBlack = null;
    worstPieceWhite = null;
    worstPieceBlack = null;
    centerType = null;
    deltaK = null;
    deltaExpansion = null;
    hasBishopPairWhite = false;
    hasBishopPairBlack = false;

    nnueWp = null;
    nnueZone = null;
    nnueWorstWhite = null;
    nnueWorstBlack = null;
    nnueBestOutpost = null;
    nnueBlindspotW = null;
    nnueBlindspotB = null;
    nnueDelta = null;

    onLog("===========================================");
    onLog(loc.logQueryingOracles);

    try {
      cloudLichess = await LiveBookScanner.scan(fen, [], false);
      cloudChessDb = await LiveBookScanner.scan(fen, [], true);
    } catch (e) {
      onLog("${loc.logCloudError} $e");
    }

    currentState = CrossedState.staticEval;
    onLog(loc.logSemanticScan);
    engineManager.sendCommand('position fen $fen');
    engineManager.sendCommand('eval');
  }

  void _handleEngineOutput(String line) {
    // -----------------------------------------------------------
    // LETTURA TRACCIA NEURALE (SHASHCHESS EVAL)
    // -----------------------------------------------------------
    if (currentState == CrossedState.masterStaticEval) {
      // Parse del nuovo formato SHASHHERMES COMPACT TRACE
      if (line.contains("WP_White=")) {
        // 🔍 STAMPA TRACCIA GREZZA: Monitoriamo esattamente cosa invia il motore in tempo reale
        debugPrint("🔍 MOTORE INVIA TRACCIA: $line");

        final parts = line.split('|').map((e) => e.trim()).toList();
        for (var part in parts) {
          if (part.startsWith('WP_White=')) {
            nnueWp = int.tryParse(part.split('=')[1].replaceAll('%', ''));
          }
          if (part.startsWith('Zone=')) {
            nnueZone = part.split('=')[1];
          }
          if (part.startsWith('WorstWhite=')) {
            nnueWorstWhite = part.split('=')[1];
          }
          if (part.startsWith('WorstBlack=')) {
            nnueWorstBlack = part.split('=')[1];
          }
          if (part.startsWith('BestOutpost=')) {
            nnueBestOutpost = part.split('=')[1];
            debugPrint(
              "🤖 PARSER OUTPOST: Estratto valore -> $nnueBestOutpost",
            );
          }
          if (part.startsWith('BLINDSPOT_W=')) {
            nnueBlindspotW = part.split('=')[1];
          }
          if (part.startsWith('BLINDSPOT_B=')) {
            nnueBlindspotB = part.split('=')[1];
          }
          if (part.startsWith('NeuralDelta=')) {
            nnueDelta = int.tryParse(part.split('=')[1].replaceAll('%', ''));
          }
        }
      }

      // Marker di fine output del comando eval per ShashChess
      if (line.startsWith(
            "*** Note: Static activity analysis based on current piece placement ***",
          ) ||
          line.contains("Final Static Activity Evaluation")) {
        currentState = CrossedState.masterThinking;
        engineManager.sendCommand('go movetime $baseTimeMs');
      }
      return;
    }

    // -----------------------------------------------------------
    // LETTURA TRACCIA STATICA (ALEXANDER EVAL)
    // -----------------------------------------------------------
    if (currentState == CrossedState.staticEval) {
      final spaceMatch = RegExp(
        r"Total Space: White (\d+) - Black (\d+)",
      ).firstMatch(line);
      if (spaceMatch != null) {
        spaceWhite = int.tryParse(spaceMatch.group(1)!);
        spaceBlack = int.tryParse(spaceMatch.group(2)!);
      }

      final centerMatch = RegExp(r"Center Type:\s*(.+)").firstMatch(line);
      if (centerMatch != null) {
        centerType = centerMatch.group(1)!.trim();
      }

      final deltaKMatch = RegExp(
        r"deltak \(White - Black\):\s*(-?\d+\.\d+)",
      ).firstMatch(line);
      if (deltaKMatch != null) {
        deltaK = double.tryParse(deltaKMatch.group(1)!);
      }

      final expMatch = RegExp(
        r"Delta Expansion \(White-Black\):\s*(-?\d+\.\d+)",
      ).firstMatch(line);
      if (expMatch != null) {
        deltaExpansion = double.tryParse(expMatch.group(1)!);
      }

      if (line.contains("White bishops: 2")) {
        hasBishopPairWhite = true;
      }
      if (line.contains("Black bishops: 2")) {
        hasBishopPairBlack = true;
      }

      String translatePiece(String engPiece) {
        switch (engPiece.trim().toLowerCase()) {
          case 'pawn':
            return loc.piecePawn;
          case 'knight':
            return loc.pieceKnight;
          case 'bishop':
            return loc.pieceBishop;
          case 'rook':
            return loc.pieceRook;
          case 'queen':
            return loc.pieceQueen;
          case 'king':
            return loc.pieceKing;
          default:
            return loc.pieceGeneric;
        }
      }

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

      if (line.startsWith("Best move:")) {
        currentState = CrossedState.baseEval;
        onLog(loc.logCalcThermodynamicZone);
        engineManager.sendCommand('go movetime $baseTimeMs');
      }
      return;
    }

    // -----------------------------------------------------------
    // GESTIONE DINAMICA WDL E CALCOLO MOSSE
    // -----------------------------------------------------------
    final wdlMatch = RegExp(r"wdl (\d+) (\d+) (\d+)").firstMatch(line);
    if (wdlMatch != null) {
      int w = int.parse(wdlMatch.group(1)!);
      int d = int.parse(wdlMatch.group(2)!);
      int l = int.parse(wdlMatch.group(3)!);
      ShashinZone currentZ = analyzeShashinZone(w, d, l);

      if (currentState == CrossedState.baseEval) {
        baseZone = currentZ;
      } else if (currentState == CrossedState.studentThinking) {
        studentZone = currentZ;
      } else if (currentState == CrossedState.masterThinking) {
        masterZone = currentZ;
      }
    }

    if (line.startsWith("bestmove")) {
      final moveMatch = RegExp(r"bestmove (\w+)").firstMatch(line);
      if (moveMatch != null) {
        String move = moveMatch.group(1)!;

        if (currentState == CrossedState.baseEval) {
          currentState = CrossedState.studentThinking;
          onLog(
            "${loc.logStudentThinking1} $studentSchool ${loc.logStudentThinking2} $studentElo ${loc.logStudentThinking3}",
          );
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
  }

  Future<void> _startMasterPhase() async {
    currentState = CrossedState.masterThinking;
    onLog("${loc.logPrepMaster1} $masterSchool ${loc.logPrepMaster2}");

    if (masterElo >= 3500) {
      onLog(loc.logEngineSwap);
      engineManager.dispose();
      await Future.delayed(const Duration(milliseconds: 500));

      await engineManager.initEngine('shashchess', [
        'nn-c288c895ea92.nnue',
        'nn-37f18f62d772.nnue',
      ]);

      _outputSubscription?.cancel();
      _outputSubscription = engineManager.engineOutput?.listen(
        _handleEngineOutput,
      );
      onLog(loc.logShashReady);

      engineManager.sendCommand('ucinewgame');
      await Future.delayed(const Duration(milliseconds: 100));

      currentState = CrossedState.masterStaticEval;
      engineManager.sendCommand('position fen $currentFen');
      await Future.delayed(const Duration(milliseconds: 50));
      engineManager.sendCommand('eval');
      return;
    } else {
      engineManager.sendCommand('setoption name UCI_LimitStrength value true');
      engineManager.sendCommand('setoption name UCI_Elo value $masterElo');
      currentState = CrossedState.masterThinking;
      engineManager.sendCommand('ucinewgame');
      await Future.delayed(const Duration(milliseconds: 100));
      engineManager.sendCommand('position fen $currentFen');
      engineManager.sendCommand('go movetime $baseTimeMs');
    }
  }

  String _generateStaticAnalysisText() {
    StringBuffer txt = StringBuffer();
    bool isIt = loc.localeName == 'it';

    if (centerType != null && centerType!.isNotEmpty) {
      txt.write(
        isIt
            ? "La struttura centrale determina il piano di gioco: abbiamo un **$centerType**. "
            : "The central structure dictates the plan: we have a **$centerType**. ",
      );
    }

    if (spaceWhite != null && spaceBlack != null) {
      int diff = spaceWhite! - spaceBlack!;
      if (diff == 0) {
        txt.write("${loc.evalSpaceBalanced} ($spaceWhite - $spaceBlack). ");
      } else if (diff >= 4) {
        txt.write("${loc.evalWhiteDominate} ");
      } else if (diff >= 1) {
        txt.write("${loc.evalWhiteSlightEdge} ");
      } else if (diff <= -4) {
        txt.write("${loc.evalBlackDominate} ");
      } else {
        txt.write("${loc.evalBlackSlightEdge} ");
      }
    }

    if (deltaExpansion != null) {
      if (deltaExpansion!.abs() < 0.2) {
        txt.write(
          isIt
              ? "Il baricentro dei due schieramenti è simmetrico. "
              : "The center of gravity is symmetrical. ",
        );
      } else if (deltaExpansion! > 0.5) {
        txt.write(
          isIt
              ? "Il Bianco è molto più espanso, tenendo i pezzi avanzati. "
              : "White is much more expanded. ",
        );
      } else if (deltaExpansion! < -0.5) {
        txt.write(
          isIt
              ? "Il Nero ha un fattore di espansione superiore. "
              : "Black has a higher expansion factor. ",
        );
      }
    }

    if (deltaK != null) {
      if (deltaK!.abs() <= 0.02) {
        txt.write(
          isIt
              ? "La densità di imballaggio (coordinazione a corto raggio) è bilanciata. "
              : "The packing density is perfectly balanced. ",
        );
      } else if (deltaK! > 0.05) {
        txt.write(
          isIt
              ? "Il Bianco ha pezzi a corto raggio meglio raggruppati. "
              : "White has better grouped short-range pieces. ",
        );
      } else if (deltaK! < -0.05) {
        txt.write(
          isIt
              ? "Il Nero ha una struttura più densa e compatta. "
              : "Black has a more compact structure. ",
        );
      }
    }

    if (hasBishopPairWhite && !hasBishopPairBlack) {
      txt.write(
        isIt
            ? "\nIl Bianco possiede il vantaggio della **coppia degli alfieri**. "
            : "\nWhite holds the long-term advantage of the **bishop pair**. ",
      );
    } else if (hasBishopPairBlack && !hasBishopPairWhite) {
      txt.write(
        isIt
            ? "\nIl Nero detiene la **coppia degli alfieri**. "
            : "\nBlack holds the **bishop pair**, a key factor in open games. ",
      );
    }

    String? worst = isWhiteToMove ? worstPieceWhite : worstPieceBlack;
    if (worst != null) txt.write("\n${loc.evalMakogonovWorst} **$worst**.");

    return txt.isNotEmpty ? txt.toString().trim() : loc.evalComplex;
  }

  // Helper per tradurre nomi notazione PGN in umano ("Nf3" -> "Cavallo f3")
  String _translatePieceNotation(String p, bool isIt) {
    if (p.isEmpty) return "";
    if (!isIt) return p;

    if (p.startsWith('N')) return 'Cavallo ${p.substring(1)}';
    if (p.startsWith('B')) return 'Alfiere ${p.substring(1)}';
    if (p.startsWith('R')) return 'Torre ${p.substring(1)}';
    if (p.startsWith('Q')) return 'Regina ${p.substring(1)}';
    if (p.startsWith('K')) return 'Re ${p.substring(1)}';

    if (RegExp(r'^[a-h][1-8]').hasMatch(p)) return 'Pedone $p';
    return p;
  }

  /// Genera il testo geometrico corretto isolando la casa tramite Regex
  /// e verificando se si tratta di un vero avamposto, di uno snodo o di un rinforzo retroguardia.
  String _buildGeometryText(String rawString, bool isIt) {
    // 🔍 FIX BLINDATO: Usiamo una Regex per trovare la casa (es. "e1", "d5") ovunque sia
    final match = RegExp(r'([a-h])([1-8])').firstMatch(rawString);
    if (match == null) return "";

    final file = match.group(1)!;
    final rankStr = match.group(2)!;
    final int rank = int.parse(rankStr);
    final square = "$file$rank";

    // Estraiamo la porzione dell'impatto percentuale es. "(+28%)"
    String impact = "";
    if (rawString.contains('(')) {
      impact = rawString.substring(rawString.indexOf('('));
    }

    // ⚠️ FILTRO DI SICUREZZA PER LE TRAVERSE 1 E 8 (Retroguardia/Bordi della scacchiera)
    // Non possono scacchisticamente essere definiti avamposti o nodi di manovra dinamica avanzata.
    if (rank == 1 || rank == 8) {
      return isIt
          ? "🛡️ RINFORZO DIFENSIVO: La casa $square $impact è una base nevralgica per blindare le retrovie."
          : "🛡️ DEFENSIVE REINFORCEMENT: Square $square $impact is a key node to secure the back ranks.";
    }

    bool isTrueOutpost = false;
    if (isWhiteToMove) {
      // Per il Bianco, un vero avamposto si trova nelle linee avanzate (4^, 5^, 6^, 7^ traversa)
      isTrueOutpost = (rank >= 4 && rank <= 7);
    } else {
      // Per il Nero, si trova nelle sue linee avanzate (2^, 3^, 4^, 5^ traversa)
      isTrueOutpost = (rank >= 2 && rank <= 5);
    }

    if (isTrueOutpost) {
      return isIt
          ? "📍 GEOMETRIA: Eccellente avamposto latente individuato nella casa $square $impact (ideale per manovrare un Cavallo)."
          : "📍 GEOMETRY: Excellent latent outpost found on $square $impact (perfect for a Knight).";
    } else {
      return isIt
          ? "📍 GEOMETRIA: Cruciale snodo di manovra e coordinazione individuato in $square $impact."
          : "📍 GEOMETRY: Crucial maneuver/coordination node found on $square $impact.";
    }
  }

  void _finishAndReport() {
    currentState = CrossedState.idle;
    StringBuffer report = StringBuffer();
    bool isIt = loc.localeName == 'it';

    // 1. CLOUD LICHESS/DB
    report.writeln(loc.reportTitleCloud);
    if (cloudLichess != null &&
        cloudLichess!.moves.isNotEmpty &&
        cloudLichess!.moves.first.move != "-") {
      report.writeln(
        "• ${loc.reportLichessHumans}: ${cloudLichess!.moves.first.move} (${cloudLichess!.moves.first.description})",
      );
    } else {
      report.writeln("• ${loc.reportLichessHumans}: ${loc.reportNoMoves}");
    }
    if (cloudChessDb != null &&
        cloudChessDb!.moves.isNotEmpty &&
        cloudChessDb!.moves.first.move != "-") {
      report.writeln(
        "• ${loc.reportChessDbNeural}: ${cloudChessDb!.moves.first.move} (${cloudChessDb!.moves.first.description})",
      );
    }
    report.writeln("");

    // 2. ANALISI POSIZIONALE (HCE)
    report.writeln(loc.reportTitleStatic);
    report.writeln(
      "• ${loc.reportZone}: ${baseZone?.name ?? '-'} (${baseZone?.symbol ?? ''})",
    );
    report.writeln("ℹ️ ${_generateStaticAnalysisText()}");
    report.writeln("");

    // 3. ALLIEVO
    report.writeln(
      "${loc.reportTitleStudent1} $studentSchool ${loc.reportTitleStudent2}",
    );
    report.writeln("• ${loc.reportChosenMove}: $studentMove");
    report.writeln(
      "• ${loc.reportExpectation}: ${studentZone?.name ?? '-'} (${studentZone?.wp.toStringAsFixed(1)}%)",
    );
    report.writeln("");

    // 4. MAESTRO
    report.writeln(
      "${loc.reportTitleMaster1} $masterSchool ${loc.reportTitleMaster2}",
    );
    report.writeln("• ${loc.reportChosenMove}: $masterMove");
    report.writeln(
      "• ${loc.reportExpectation}: ${masterZone?.name ?? '-'} (${masterZone?.wp.toStringAsFixed(1)}%)",
    );
    report.writeln("");

    // 5. VERDETTO E NAG
    report.writeln(loc.reportTitleVerdict);
    if (studentMove == masterMove) {
      report.writeln(loc.nagExcellentTitle);
      report.writeln(loc.nagExcellentDesc);
    } else {
      double sWp = studentZone?.wp ?? 50.0;
      double mWp = masterZone?.wp ?? 50.0;
      int zoneDrop = calculateZoneDrop(sWp, mWp);

      if (zoneDrop >= 3) {
        report.writeln(loc.nagBlunderTitle);
        report.writeln(
          "${loc.nagBlunderDesc1} $zoneDrop ${loc.nagBlunderDesc2}",
        );
      } else if (zoneDrop == 2) {
        report.writeln(loc.nagMistakeTitle);
        report.writeln(
          "${loc.nagMistakeDesc1} $zoneDrop ${loc.nagMistakeDesc2}",
        );
      } else if (zoneDrop == 1) {
        report.writeln(loc.nagInaccuracyTitle);
        report.writeln(loc.nagInaccuracyDesc);
      } else {
        report.writeln(loc.nagInterestingTitle);
        if (mWp - sWp > 8.0) {
          report.writeln(
            "${loc.nagInterestingDescDiff1} ($masterMove) ${loc.nagInterestingDescDiff2} (${studentZone?.name}). ${loc.nagInterestingDescDiff3}",
          );
        } else {
          report.writeln(loc.nagInterestingDescClose);
        }
      }
    }

    // -----------------------------------------------------------
    // 6. VISIONE PROFONDA (XAI Termodinamica & NNUE Abstractions)
    // -----------------------------------------------------------
    if (masterElo >= 3500 && studentMove != masterMove) {
      report.writeln("");
      report.writeln("=========================================");
      report.writeln(
        isIt
            ? "🔬 VISIONE PROFONDA (Rete Neurale NNUE)"
            : "🔬 DEEP VISION (NNUE Network)",
      );
      report.writeln("=========================================");

      // A. Intuizione Astratta (Neural Delta)
      if (nnueDelta != null && nnueDelta != 0) {
        if (nnueDelta! > 5) {
          report.writeln(
            isIt
                ? "🧠 INTUIZIONE ASTRATTA: La rete vede un forte compenso dinamico (+$nnueDelta% probabilità di vittoria) che va oltre il nudo valore dei pezzi."
                : "🧠 ABSTRACT INTUITION: The network sees strong dynamic compensation (+$nnueDelta% WP) beyond raw material.",
          );
        } else if (nnueDelta! < -5) {
          report.writeln(
            isIt
                ? "🧠 INTUIZIONE ASTRATTA: La pessima struttura o l'inattività penalizzano severamente la tua posizione ($nnueDelta% probabilità di vittoria) rispetto al valore nominale dei pezzi."
                : "🧠 ABSTRACT INTUITION: Poor structure severely penalizes your pieces ($nnueDelta% WP) compared to raw material.",
          );
        }
      }

      // B. Avamposto Spaziale / Snodo Coordinazione (Filtro geometrico applicato)
      if (nnueBestOutpost != null && nnueBestOutpost!.isNotEmpty) {
        report.writeln(_buildGeometryText(nnueBestOutpost!, isIt));
      }

      // C. Pezzo Peggiore (Ablazione Spaziale)
      String? myWorst = isWhiteToMove ? nnueWorstWhite : nnueWorstBlack;
      if (myWorst != null && myWorst.isNotEmpty) {
        String tPiece = _translatePieceNotation(myWorst, isIt);
        report.writeln(
          isIt
              ? "📉 PEZZO CRITICO: Il $tPiece è attualmente il pezzo che contribuisce di meno. Cerca di migliorarne la posizione o scambialo."
              : "📉 CRITICAL PIECE: $tPiece contributes the least. Try to improve its position or trade it.",
        );
      }

      // D. Punto Cieco (Blindspot Difensivo)
      String? myBlindspot = isWhiteToMove ? nnueBlindspotW : nnueBlindspotB;
      if (myBlindspot != null && myBlindspot.isNotEmpty) {
        String tBlind = _translatePieceNotation(myBlindspot, isIt);
        report.writeln(
          isIt
              ? "⚠️ PUNTO CIECO DIFENSIVO: Paradossalmente, sacrificare o smettere di difendere il $tBlind migliorerebbe le probabilità di vittoria. Non fossilizzarti su di esso!"
              : "⚠️ DEFENSIVE BLINDSPOT: Paradoxically, sacrificing or ignoring the defense of $tBlind improves win probability. Don't fixate on it!",
        );
      }
    }

    onReportReady(report.toString());
    onLog(loc.logEvalComplete);
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
