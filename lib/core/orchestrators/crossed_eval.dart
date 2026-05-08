import 'dart:async';
import '../engine/engine_manager.dart';
import '../logic/shashin_logic.dart';
import '../logic/livebook_scanner.dart';
import '../../l10n/app_localizations.dart'; // <--- IMPORT CRITICO AGGIUNTO QUI!

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
  final AppLocalizations loc; // <--- VARIABILE LINGUA AGGIUNTA
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
    required this.loc, // <--- RICHIESTO NEL COSTRUTTORE
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
      // <--- Soglia portata a 2500
      studentSchool = loc.schoolAdvanced;
      masterElo = 3190;
      masterSchool = loc.schoolExpertHCE;
    } else {
      studentSchool = loc.schoolExpert;
      masterElo = 3500; // Flag per ShashChess
      masterSchool = loc.schoolSuperhumanNNUE;
    }
  }

  void startCrossedEval(String fen, int playerElo, int timeMs) async {
    // <--- Aggiunto int timeMs
    if (currentState != CrossedState.idle) {
      engineManager.sendCommand('stop');
    }

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
    onLog(loc.logQueryingOracles);

    try {
      cloudLichess = await LiveBookScanner.scan(fen, [], false);
      cloudChessDb = await LiveBookScanner.scan(fen, [], true);
    } catch (e) {
      onLog("${loc.logCloudError} $e");
    }

    // FASE 1: Estrazione parametri semantici (comando eval)
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
        onLog(loc.logCalcThermodynamicZone);

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
  }

  // --- NUOVO METODO PER LO SWAP DEL MOTORE ---
  Future<void> _startMasterPhase() async {
    currentState = CrossedState.masterThinking;
    onLog("${loc.logPrepMaster1} $masterSchool ${loc.logPrepMaster2}");

    if (masterElo >= 3500) {
      onLog(loc.logEngineSwap);

      // 1. Uccidiamo il vecchio processo Alexander
      engineManager.dispose();

      // 2. Inizializziamo ShashChess (con le sue reti neurali)
      await engineManager.initEngine('shashchess', [
        'nn-c288c895ea92.nnue',
        'nn-37f18f62d772.nnue',
      ]);

      // 3. CRITICO: Ri-agganciamo l'ascoltatore!
      _outputSubscription?.cancel();
      _outputSubscription = engineManager.engineOutput?.listen(
        _handleEngineOutput,
      );

      onLog(loc.logShashReady);

      // Chiediamo a ShashChess di valutare i suoi pezzi peggiori
      currentState = CrossedState.masterStaticEval;
      engineManager.sendCommand('position fen $currentFen');
      engineManager.sendCommand('eval');
      return;
    } else {
      // Se il maestro è ancora Alexander, impostiamo solo l'handicap UCI
      engineManager.sendCommand('setoption name UCI_LimitStrength value true');
      engineManager.sendCommand('setoption name UCI_Elo value $masterElo');

      currentState = CrossedState.masterThinking;
      engineManager.sendCommand('position fen $currentFen');
      engineManager.sendCommand('go movetime $baseTimeMs');
    }
  }

  // NLP: Genera l'analisi testuale della posizione iniziale
  String _generateStaticAnalysisText() {
    String txt = "";

    if (spaceWhite != null && spaceBlack != null) {
      int diff = spaceWhite! - spaceBlack!;
      if (diff >= 4) {
        txt += loc.evalWhiteDominate;
      } else if (diff >= 1 && diff <= 3) {
        txt += loc.evalWhiteSlightEdge;
      } else if (diff <= -4) {
        txt += loc.evalBlackDominate;
      } else if (diff >= -3 && diff <= -1) {
        txt += loc.evalBlackSlightEdge;
      } else {
        txt += loc.evalSpaceBalanced;
      }
    }

    String? worst = isWhiteToMove ? worstPieceWhite : worstPieceBlack;
    if (worst != null) {
      txt += "${loc.evalMakogonovWorst} $worst.";
    }

    return txt.isNotEmpty ? txt.trim() : loc.evalComplex;
  }

  // Helper interno per assegnare l'indice di Zona Shashin (0-12)
  int _getZoneIndex(double wp) {
    if (wp <= 5) {
      return 0;
    }
    if (wp <= 10) {
      return 1;
    }
    if (wp <= 15) {
      return 2;
    }
    if (wp <= 20) {
      return 3;
    }
    if (wp <= 24) {
      return 4;
    }
    if (wp <= 49) {
      return 5;
    }
    if (wp <= 50) {
      return 6;
    }
    if (wp <= 75) {
      return 7;
    }
    if (wp <= 79) {
      return 8;
    }
    if (wp <= 84) {
      return 9;
    }
    if (wp <= 89) {
      return 10;
    }
    if (wp <= 94) {
      return 11;
    }
    return 12;
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

    // NUOVO: Integrazione Makogonov ShashChess sempre visibile
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
      int sIndex = _getZoneIndex(sWp);
      int mIndex = _getZoneIndex(mWp);
      int zoneDrop = mIndex - sIndex;

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

    // 6. VISIONE AVANZATA (Solo ShashChess e se le mosse differiscono)
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
