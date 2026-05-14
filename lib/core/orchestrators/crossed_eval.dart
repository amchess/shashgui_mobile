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

  // --- VARIABILI ANALISI STATICA (EVAL) ---
  int? spaceWhite;
  int? spaceBlack;
  String? worstPieceWhite;
  String? worstPieceBlack;
  String? worstPieceNnue;

  // ⚠️ NUOVE VARIABILI PER ARRICCHIRE IL COACH
  String? centerType;
  double? deltaK; // Packing density difference
  double? deltaExpansion; // Center of Gravity difference
  bool hasBishopPairWhite = false;
  bool hasBishopPairBlack = false;

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

    // Reset di tutte le variabili statiche
    spaceWhite = null;
    spaceBlack = null;
    worstPieceWhite = null;
    worstPieceBlack = null;
    worstPieceNnue = null;
    centerType = null;
    deltaK = null;
    deltaExpansion = null;
    hasBishopPairWhite = false;
    hasBishopPairBlack = false;

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
            worstPieceNnue = '${loc.pieceKnight} in $sq';
            break;
          case 'B':
            worstPieceNnue = "${loc.pieceBishop} in $sq";
            break;
          case 'R':
            worstPieceNnue = '${loc.pieceRook} in $sq';
            break;
          case 'Q':
            worstPieceNnue = '${loc.pieceQueen} in $sq';
            break;
          case 'K':
            worstPieceNnue = '${loc.pieceKing} in $sq';
            break;
          default:
            worstPieceNnue = '${loc.piecePawn} in $sq';
        }
      }

      // ⚠️ FIX: Il marker finale infallibile per ShashChess!
      if (line.startsWith(
            "*** Note: Static activity analysis based on current piece placement ***",
          ) ||
          line.contains("Final Static Activity Evaluation")) {
        currentState = CrossedState.masterThinking;
        engineManager.sendCommand('go movetime $baseTimeMs');
      }
      return;
    }

    // --- LETTURA TRACCIA STATICA (ALEXANDER EVAL) ---
    if (currentState == CrossedState.staticEval) {
      // 1. Spazio
      final spaceMatch = RegExp(
        r"Total Space: White (\d+) - Black (\d+)",
      ).firstMatch(line);
      if (spaceMatch != null) {
        spaceWhite = int.tryParse(spaceMatch.group(1)!);
        spaceBlack = int.tryParse(spaceMatch.group(2)!);
      }

      // 2. Tipo di Centro
      final centerMatch = RegExp(r"Center Type:\s*(.+)").firstMatch(line);
      if (centerMatch != null) centerType = centerMatch.group(1)!.trim();

      // 3. Densità e Coordinazione (Knights/Deltak)
      final deltaKMatch = RegExp(
        r"deltak \(White - Black\):\s*(-?\d+\.\d+)",
      ).firstMatch(line);
      if (deltaKMatch != null) deltaK = double.tryParse(deltaKMatch.group(1)!);

      // 4. Baricentro/Espansione
      final expMatch = RegExp(
        r"Delta Expansion \(White-Black\):\s*(-?\d+\.\d+)",
      ).firstMatch(line);
      if (expMatch != null) {
        deltaExpansion = double.tryParse(expMatch.group(1)!);
      }

      // 5. Coppia Alfieri
      if (line.contains("White bishops: 2")) hasBishopPairWhite = true;
      if (line.contains("Black bishops: 2")) hasBishopPairBlack = true;

      // 6. Pezzo peggiore (Makogonov)
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

      // ⚠️ FIX: Il marker finale infallibile per Alexander!
      if (line.startsWith("Best move:")) {
        currentState = CrossedState.baseEval;
        onLog(loc.logCalcThermodynamicZone);
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
      await engineManager.initEngine('shashchess', [
        'nn-c288c895ea92.nnue',
        'nn-37f18f62d772.nnue',
      ]);
      _outputSubscription?.cancel();
      _outputSubscription = engineManager.engineOutput?.listen(
        _handleEngineOutput,
      );
      onLog(loc.logShashReady);

      currentState = CrossedState.masterStaticEval;
      engineManager.sendCommand('position fen $currentFen');
      engineManager.sendCommand('eval');
      return;
    } else {
      engineManager.sendCommand('setoption name UCI_LimitStrength value true');
      engineManager.sendCommand('setoption name UCI_Elo value $masterElo');
      currentState = CrossedState.masterThinking;
      engineManager.sendCommand('position fen $currentFen');
      engineManager.sendCommand('go movetime $baseTimeMs');
    }
  }

  // ⚠️ IL NUOVO MOTORE NLP (Natural Language Processing) COMPLETAMENTE BILINGUE
  String _generateStaticAnalysisText() {
    StringBuffer txt = StringBuffer();
    bool isIt = loc.localeName == 'it'; // Rileva la lingua corrente

    // 1. TIPO DI CENTRO
    if (centerType != null && centerType!.isNotEmpty) {
      txt.write(
        isIt
            ? "La struttura centrale determina il piano di gioco: abbiamo un **$centerType**. "
            : "The central structure dictates the plan: we have a **$centerType**. ",
      );
    }

    // 2. EQUILIBRI E SQUILIBRI DI SPAZIO
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

    // 3. BARICENTRO ED ESPANSIONE
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

    // 4. DENSITÀ E COORDINAZIONE
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

    // 5. VANTAGGI MATERIALI STATICI
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

    // 6. PRINCIPIO DI MAKOGONOV
    String? worst = isWhiteToMove ? worstPieceWhite : worstPieceBlack;
    if (worst != null) {
      txt.write("\n${loc.evalMakogonovWorst} **$worst**.");
    }

    return txt.isNotEmpty ? txt.toString().trim() : loc.evalComplex;
  }

  void _finishAndReport() {
    currentState = CrossedState.idle;
    StringBuffer report = StringBuffer();

    // 1. CLOUD
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

    // 2. ANALISI PRE-MOSSA
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

    if (worstPieceNnue != null) {
      report.writeln("🔍 ${loc.reportNnueWorstPiece}: $worstPieceNnue");
    }
    report.writeln("");

    // 5. VERDETTO E NAG
    report.writeln(loc.reportTitleVerdict);
    if (studentMove == masterMove) {
      report.writeln(loc.nagExcellentTitle);
      report.writeln(loc.nagExcellentDesc);
    } else {
      double sWp = studentZone?.wp ?? 50.0;
      double mWp = masterZone?.wp ?? 50.0;

      // ⚠️ FIX: Usiamo la funzione importata anziché la copia locale!
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

    // 6. VISIONE AVANZATA
    if (masterElo >= 3500 &&
        worstPieceNnue != null &&
        studentMove != masterMove) {
      String worstBase = isWhiteToMove
          ? (worstPieceWhite ?? "")
          : (worstPieceBlack ?? "");

      if (worstBase.isNotEmpty) {
        report.writeln("");
        report.writeln(loc.reportTitleAdvVision);

        if (worstBase != worstPieceNnue) {
          report.writeln(
            "${loc.advVisionFixed1} $worstBase ${loc.advVisionFixed2} $worstPieceNnue.",
          );
        } else {
          report.writeln(
            "${loc.advVisionIgnored1} $worstBase, ${loc.advVisionIgnored2} $masterMove ${loc.advVisionIgnored3}",
          );
        }
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
