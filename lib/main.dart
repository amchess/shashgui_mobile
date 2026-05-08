import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io'; // <-- AGGIUNTO PER GESTIRE I FILE
import 'package:path_provider/path_provider.dart'; // <-- AGGIUNTO PER TROVARE LA CARTELLA DELLO SMARTPHONE

import 'core/logic/shashin_logic.dart';
import 'core/orchestrators/shashin_fsm.dart';
import 'core/orchestrators/crossed_eval.dart';
import 'core/orchestrators/play_orchestrator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'core/engine/engine_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'core/logic/livebook_scanner.dart'; // <-- AGGIUNTO PER IL LIVEBOOK
import 'dart:async';
import 'core/orchestrators/autoplay_orchestrator.dart';
import 'core/widgets/setup_position_dialog.dart';

void main() {
  runApp(const ShashGuiApp());
}

class ShashGuiApp extends StatelessWidget {
  const ShashGuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShashGui MVP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2b2b2b),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationWrapper(),
    );
  }
}

// --- IL WRAPPER DELLA NAVIGAZIONE ---
class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0;

  // Le due pagine principali
  final List<Widget> _pages = [
    const EngineTestScreen(), // Indice 0: Il Laboratorio (Locale)
    const PremiumShowcaseScreen(), // Indice 1: La Vetrina (Cloud/Mockup)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.orangeAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1e1e1e),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.science),
            label: 'Laboratorio',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Premium'),
        ],
      ),
    );
  }
}

// --- L'ENGINE TEST SCREEN (COMPLETO ED ESTESO) ---
class EngineTestScreen extends StatefulWidget {
  const EngineTestScreen({super.key});

  @override
  State<EngineTestScreen> createState() => _EngineTestScreenState();
}

class _EngineTestScreenState extends State<EngineTestScreen> {
  final EngineManager _engineManager =
      EngineManager(); // Motore Bianco/Principale
  final EngineManager _engineManagerBlack = EngineManager(); // Motore Nero

  ShashinFsm? _fsm;
  CrossedEvalOrchestrator? _crossedFsm;
  PlayOrchestrator? _playFsm;
  AutoplayOrchestrator? _autoplayFsm;

  final List<String> _outputLines = [];
  final ChessBoardController _boardController = ChessBoardController();
  final ScrollController _scrollController = () {
    final sc = ScrollController();
    return sc;
  }();

  bool _isEngineRunning = false;
  bool _isPlayingMode = false;
  bool _isDragging = false;
  bool _isScanningThreat = false;

  // --- NUOVE VARIABILI PER NAVIGAZIONE E ORIENTAMENTO ---
  PlayerColor _boardOrientation = PlayerColor.white; // Bianco o Nero in basso
  late MoveNode _rootNode;
  late MoveNode _currentNode;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- NOTIFIER PER LE FRECCE ---
  final ValueNotifier<List<BoardArrow>> _arrowsNotifier = ValueNotifier([]);

  // --- VARIABILI LIVEBOOK ---
  LiveBookResult? _liveBookResult;
  final bool _showLiveBook = true;

  // Memoria del tempo iniziale T1 per il loop infinito
  double _baseTimeSec = 2.0; // Cambiato in double per lo slider

  // Variabili per l'handicap (Modalità Gioco)
  final double _playTimeSec =
      2.0; // <-- 1. NUOVA VARIABILE PER IL TEMPO DI GIOCO
  bool _limitStrength = false;
  double _eloValue = 1500;
  final bool _simulateBlunders = false;

  // --- VARIABILI REINSERITE ---
  SharedPreferences? _prefs;
  String _selectedEngine = 'shashchess';
  bool _isLoadingOptions = false;
  final List<Map<String, String>> _engineOptionsMetadata = [];
  final Map<String, String> _uciValues = {'Threads': '2', 'Hash': '128'};

  @override
  void initState() {
    super.initState();
    // Il nodo radice deve avere un nome (san) e il FEN iniziale
    _rootNode = MoveNode(
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      san: 'Inizio',
    );
    _currentNode = _rootNode;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMemoryAndProbe();
    });
  }

  // NUOVA FUNZIONE: Carica la memoria prima di sondare
  Future<void> _initMemoryAndProbe() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      // Ricorda l'ultimo motore usato (o usa shashchess di default)
      _selectedEngine = _prefs?.getString('selectedEngine') ?? 'shashchess';
    });
    _probeEngineOptions();
  }

  // FUNZIONE SONDA: Accende un motore "fantasma", legge le opzioni e lo spegne
  Future<void> _probeEngineOptions() async {
    if (!mounted) return;
    setState(() => _isLoadingOptions = true);
    _engineOptionsMetadata.clear();

    final probeManager = EngineManager();
    try {
      await probeManager.initEngine(
        _selectedEngine,
        [], // Nessun NNUE per andare velocissimi
        onLine: (line) {
          if (line.trim().startsWith("option name")) {
            _parseUciOption(line);
          }
        },
      );
    } catch (e) {
      debugPrint("Errore Sonda: $e");
    } finally {
      probeManager.dispose(); // Spegniamo il motore spia
      if (mounted) setState(() => _isLoadingOptions = false);
    }
  }

  // <-- OTTIMIZZAZIONE PRESTAZIONI: Tubi diretti per non bloccare il touch -->
  final ValueNotifier<EngineStats> _statsNotifier = ValueNotifier(
    EngineStats(),
  );

  final ValueNotifier<ShashinZone> _zoneNotifier = ValueNotifier(
    ShashinZone(
      "In attesa...",
      "-",
      Colors.grey,
      50.0,
      ["assets/images/capablanca.png"], // <-- Messo tra parentesi quadre
    ),
  );

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _startEngine() async {
    setState(() {
      _outputLines.clear();
      _outputLines.add("Accensione motore $_selectedEngine...");
    });
    try {
      // Se il motore non è mai stato avviato (o è stato distrutto), lo inizializziamo
      if (_engineManager.engineOutput == null) {
        await _engineManager.initEngine(_selectedEngine, [
          'nn-c288c895ea92.nnue',
          'nn-37f18f62d772.nnue',
        ]);

        await Future.delayed(const Duration(milliseconds: 300));

        // Inviamo i parametri personalizzati
        _uciValues.forEach((name, value) {
          _engineManager.sendCommand('setoption name $name value $value');
        });
      }

      setState(() => _isEngineRunning = true);

      // Diamo mezzo secondo di respiro al motore per stabilizzarsi in RAM prima di fare richieste web
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _updateLiveBook();
      });
    } catch (e) {
      setState(() => _outputLines.add("ERRORE FATALE: $e"));
    }
  }

  void _stopAllOrchestrators() {
    _fsm?.stop();
    _crossedFsm?.stop();
    _playFsm?.stop();
    _autoplayFsm?.stop();
    _fsm?.dispose();
    _crossedFsm?.dispose();
    _playFsm?.dispose();
    _autoplayFsm?.dispose();
    _autoplayFsm = null;

    _fsm = null;
    _crossedFsm = null;
    _playFsm = null;

    _isPlayingMode = false;
    _arrowsNotifier.value = [];
    _statsNotifier.value = EngineStats();
  }

  void _stopEngine() {
    _stopAllOrchestrators();

    // INVECE di distruggere il processo, lo fermiamo solo con il comando UCI.
    // Questo permette riavvii istantanei!
    _engineManager.sendCommand('stop');

    setState(() {
      _isEngineRunning = false;
      _outputLines.add("--- ANALISI FERMATA ---");
      _arrowsNotifier.value = [];
    });

    _zoneNotifier.value = ShashinZone(
      "Analisi Fermata",
      "-",
      Colors.grey,
      50.0,
      ["assets/images/capablanca.png"], // <-- Messo tra parentesi quadre
    );

    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
  }

  void _updateLiveBook() async {
    // FIX: Forziamo sempre Lichess per il pannello visivo in modo da avere statistiche umane con la Frequenza!
    bool isShash = false;

    // Calcoliamo la cronologia delle mosse (SAN) dall'inizio alla posizione corrente
    List<String> history = [];
    MoveNode? temp = _currentNode;
    while (temp != null && temp != _rootNode) {
      history.insert(0, temp.san);
      temp = temp.parent;
    }

    var result = await LiveBookScanner.scan(
      _boardController.getFen(),
      history,
      isShash,
    );
    if (mounted) {
      setState(() {
        _liveBookResult = result;
      });
    }
  }

  void _startNormalAnalysis() {
    // Sicurezza: se l'engine non è acceso, non partiamo
    if (!_isEngineRunning) return;

    _stopAllOrchestrators();

    setState(() {
      _isEngineRunning = true;
      _isPlayingMode = false;
      _outputLines.clear();
      _arrowsNotifier.value = []; // Pulisce le frecce vecchie
    });

    _updateLiveBook(); // <-- AGGIUNTO QUI: Scatta all'avvio dell'analisi!

    // RIPRISTINO DELLA TUA STRUTTURA FSM ORIGINALE COMPLETA
    _fsm = ShashinFsm(
      engineManager: _engineManager,
      onLog: (line) {
        setState(() => _outputLines.add(line));
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      },
      onZoneChanged: (zone) {
        _zoneNotifier.value = zone; // Aggiorna il termometro Shashin
      },
      onStateChanged: (state) {},
      onStatsUpdate: (stats) {
        _statsNotifier.value = stats; // Aggiorna il cruscotto
      },
      onOptionFound: (optionLine) => _parseUciOption(optionLine),

      // LA TUA LOGICA ORIGINALE PER LA FRECCIA (È PERFETTA!)
      onPvUpdate: (firstMove) {
        // Se stiamo toccando lo schermo, la mossa è monca, o cerchiamo minacce, ignoriamo!
        if (_isDragging || firstMove.length < 4 || _isScanningThreat) return;

        String fromSq = firstMove.substring(0, 2);
        String toSq = firstMove.substring(2, 4);

        // Aggiorniamo la UI SOLO se la freccia è diversa da quella di prima
        final currentArrows = _arrowsNotifier.value;
        if (currentArrows.isNotEmpty &&
            currentArrows.first.from == fromSq &&
            currentArrows.first.to == toSq) {
          return; // La freccia è identica, evitiamo un rebuild inutile
        }

        _arrowsNotifier.value = [
          BoardArrow(
            from: fromSq,
            to: toSq,
            // Magia: la freccia prende il colore della zona termodinamica attuale!
            color: _zoneNotifier.value.color.withValues(alpha: 0.8),
          ),
        ];
      },
    );

    // AVVIO CORRETTO: Parametro posizionale (FEN) + Parametro nominato (baseTimeMs)
    _fsm!.startAnalysis(
      _boardController.getFen(),
      // Convertiamo il double in int prima di passarlo
      baseTimeMs: (_baseTimeSec * 1000).toInt(),
    );
  }

  @override
  void dispose() {
    _stopAllOrchestrators();
    _engineManager.dispose();
    _engineManagerBlack.dispose(); // <-- NUOVO
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ShashGui Laboratorio'),
        backgroundColor: const Color(0xFF1e1e1e),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. ZONA SCACCHIERA CON PEZZI CATTURATI E FRECCE (Fissa in alto, occupa 6/10 dello spazio)
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // PEZZI PERSI DAL BIANCO (SOPRA)
                Builder(
                  builder: (context) {
                    final mat = _calculateMaterial(_boardController.getFen());
                    return _buildCapturedPieces(
                      mat['whiteCaptured'],
                      mat['score'] > 0 ? mat['score'] : 0,
                    );
                  },
                ),

                const SizedBox(height: 5),

                // SCACCHIERA CENTRALE
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boardSize =
                          constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight;
                      return Listener(
                        onPointerDown: (_) => _isDragging = true,
                        onPointerUp: (_) => _isDragging = false,
                        child: ValueListenableBuilder<List<BoardArrow>>(
                          valueListenable: _arrowsNotifier,
                          builder: (context, arrows, child) {
                            return ChessBoard(
                              size: boardSize,
                              controller: _boardController,
                              boardColor: BoardColor.brown,
                              boardOrientation: _boardOrientation,
                              arrows: arrows,
                              onMove: _onMovePerformed,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 5),

                // PEZZI PERSI DAL NERO (SOTTO)
                Builder(
                  builder: (context) {
                    final mat = _calculateMaterial(_boardController.getFen());
                    return _buildCapturedPieces(
                      mat['blackCaptured'],
                      mat['score'] < 0 ? -mat['score'] : 0,
                    );
                  },
                ),

                // BARRA DI NAVIGAZIONE (FRECCE)
                Container(
                  color: Colors.black26,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.first_page),
                        onPressed: _goToStart,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _goBack,
                      ),
                      IconButton(
                        icon: const Icon(Icons.sync),
                        color: Colors.blueAccent,
                        onPressed: () => setState(
                          () => _boardOrientation =
                              (_boardOrientation == PlayerColor.white)
                              ? PlayerColor.black
                              : PlayerColor.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _goForward,
                      ),
                      IconButton(
                        icon: const Icon(Icons.last_page),
                        onPressed: _goToEnd,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. ZONA INFERIORE SCORREVOLE (Occupa 4/10 dello spazio. Qui LiveBook, WinProb e Notazione scorrono senza sfondare)
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // --- PANNELLO LIVEBOOK (ORACOLO) ---
                  if (_isEngineRunning && _showLiveBook)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blueAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isPlayingMode
                                    ? "🤖 AUTOPLAY ACTIVE"
                                    : "🌐 LIVEBOOK",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              SizedBox(
                                height: 24,
                                child: TextButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Funzione Tratti Posizionali bloccata (Versione Premium)",
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.lock,
                                    size: 12,
                                    color: Colors.orangeAccent,
                                  ),
                                  label: const Text(
                                    "TRAITS",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // INTESTAZIONI DI COLONNA ALLINEATE
                          const Row(
                            children: [
                              SizedBox(
                                width: 70,
                                child: Text(
                                  "MOSSA",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                "VALUTAZIONE",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 8),

                          // --- LISTA MOSSE ---
                          Expanded(
                            flex: 3, // Diamo il 60% di spazio alle mosse
                            child: SingleChildScrollView(
                              child: _liveBookResult == null
                                  ? const Text(
                                      "Scanning cloud data...",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.white70,
                                      ),
                                    )
                                  : Column(
                                      children: _liveBookResult!.moves
                                          .map(
                                            (m) => InkWell(
                                              onTap: () {
                                                if (m.move.length >= 4 &&
                                                    m.move != "-") {
                                                  String fromSq = m.move
                                                      .substring(0, 2);
                                                  String toSq = m.move
                                                      .substring(2, 4);
                                                  if (m.move.length == 5) {
                                                    _boardController
                                                        .makeMoveWithPromotion(
                                                          from: fromSq,
                                                          to: toSq,
                                                          pieceToPromoteTo:
                                                              m.move[4],
                                                        );
                                                  } else {
                                                    _boardController.makeMove(
                                                      from: fromSq,
                                                      to: toSq,
                                                    );
                                                  }
                                                  _onMovePerformed();
                                                }
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4.0,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 60,
                                                      child: Text(
                                                        m.move,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .greenAccent,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        m.description,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                            ),
                          ),

                          // --- AREA TESTO (NOME APERTURA O COMMENTO IA) ---
                          if (_liveBookResult != null &&
                              (_liveBookResult!.openingName.isNotEmpty ||
                                  _liveBookResult!
                                      .engineComment
                                      .isNotEmpty)) ...[
                            const Divider(color: Colors.white24, height: 8),
                            Expanded(
                              flex:
                                  2, // Diamo il 40% di spazio al testo scorrevole
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_liveBookResult!.openingName.isNotEmpty)
                                      Text(
                                        _liveBookResult!.openingName,
                                        style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (_liveBookResult!
                                        .engineComment
                                        .isNotEmpty)
                                      Text(
                                        _liveBookResult!.engineComment,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // --- BARRA WIN PROBABILITY ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 4.0,
                    ),
                    child: ValueListenableBuilder<ShashinZone>(
                      valueListenable: _zoneNotifier,
                      builder: (context, zone, child) {
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "🛡️ Petrosian",
                                  style: TextStyle(
                                    color: Colors.red[300],
                                    fontSize: 11,
                                  ),
                                ),

                                // --- DISEGNATORE MULTI-FACCIA ---
                                Row(
                                  children: [
                                    // Ciclo che estrae e affianca tutte le immagini nell'array
                                    ...zone.avatars.map(
                                      (avatarPath) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4.0,
                                        ),
                                        child: CircleAvatar(
                                          backgroundImage: AssetImage(
                                            avatarPath,
                                          ),
                                          radius: 12,
                                          backgroundColor: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${zone.wp.toStringAsFixed(1)}%",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),

                                // ----------------------------------------
                                Text(
                                  "Tal 🔥",
                                  style: TextStyle(
                                    color: Colors.green[300],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: zone.wp / 100.0,
                                minHeight: 8,
                                backgroundColor: Colors.red[700],
                                color: Colors.green[600],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // --- CRUSCOTTO STATISTICHE MOTORE (PV, Nodi, Profondità) ---
                  ValueListenableBuilder<EngineStats>(
                    valueListenable: _statsNotifier,
                    builder: (context, stats, child) {
                      if (stats.depth == 0) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Profondità: ${stats.depth}/${stats.selDepth}",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                                Text(
                                  "Nodi: ${(stats.nodes / 1000).toStringAsFixed(1)}k",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                                Text(
                                  "NPS: ${stats.nps}",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "PV: ${stats.pv}",
                              style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.white70,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // --- PANNELLO NOTAZIONE E VARIANTI ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: _buildNotationPanel(),
                  ),
                ],
              ),
            ),
          ),

          // 3. CONTROLLI MOTORE E OPZIONI (Fissi in fondo)
          Container(
            padding: const EdgeInsets.only(
              bottom: 10,
              top: 5,
              left: 10,
              right: 10,
            ),
            width: double.infinity,
            child: Row(
              children: [
                // I controlli secondari scorrono orizzontalmente
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // SELETTORE MOTORE
                        DropdownButton<String>(
                          value: _selectedEngine,
                          dropdownColor: const Color(0xFF2b2b2b),
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          underline: Container(
                            height: 2,
                            color: Colors.blueAccent,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'shashchess',
                              child: Text("ShashChess"),
                            ),
                            DropdownMenuItem(
                              value: 'alexander',
                              child: Text("Alexander"),
                            ),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null &&
                                newValue != _selectedEngine) {
                              if (_isEngineRunning) _stopEngine();
                              _engineManager
                                  .dispose(); // <-- FONDAMENTALE: Uccide il vecchio motore prima di cambiare!
                              setState(() {
                                _selectedEngine = newValue;
                                _prefs?.setString('selectedEngine', newValue);
                              });
                            }
                          },
                        ), // Fine DropdownButton
                        const SizedBox(
                          width: 10,
                        ), // Lasciamo solo un piccolo spazio di 10 pixel
                        // BOTTONE OPZIONI MOTORE
                        IconButton(
                          onPressed: () {
                            if (_isEngineRunning) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Spegni il motore per modificare i parametri!",
                                  ),
                                ),
                              );
                            } else {
                              _showUciSettings();
                            }
                          },
                          icon: Icon(
                            Icons.settings,
                            color: _isEngineRunning
                                ? Colors.grey
                                : Colors.white70,
                          ),
                          tooltip: "Configura Parametri",
                        ),
                        // SE IL MOTORE E' ACCESO, MOSTRIAMO I CONTROLLI AVANZATI
                        if (_isEngineRunning) ...[
                          IconButton(
                            // Se l'analisi è attiva la ferma. Se è ferma, APRE IL POPUP!
                            onPressed:
                                (_fsm != null &&
                                    _fsm!.currentState != FsmState.idle)
                                ? _stopEngine
                                : _showAnalysisSetupDialog, // <-- ORA CHIAMA IL POPUP!

                            icon: Icon(
                              Icons.analytics,
                              // Il colore cambia per indicare lo stato
                              color:
                                  (_fsm != null &&
                                      _fsm!.currentState != FsmState.idle)
                                  ? Colors
                                        .orangeAccent // ⬅️ Cambialo in Arancione o altro quando è acceso per contrasto
                                  : Colors.blueAccent,
                            ),
                            tooltip:
                                (_fsm != null &&
                                    _fsm!.currentState != FsmState.idle)
                                ? "Ferma Analisi"
                                : "Avvia Analisi Libera",
                          ),
                          IconButton(
                            onPressed: _startPlayMode, // <-- Sempre cliccabile
                            icon: const Icon(
                              Icons.sports_esports,
                              color: Colors.greenAccent,
                            ),
                            tooltip: "Gioca contro il Motore",
                          ),
                          IconButton(
                            onPressed: _startAutoplayMode,
                            icon: const Icon(
                              Icons.smart_toy,
                              color: Colors.purpleAccent,
                            ),
                            tooltip: "Autoplay (Motore vs Motore)",
                          ),
                          IconButton(
                            onPressed: _scanThreats, // <-- Sempre cliccabile
                            icon: const Icon(
                              Icons.crisis_alert,
                              color: Colors.redAccent,
                            ),
                            tooltip: "Rileva Minacce",
                          ),
                          IconButton(
                            onPressed: _startCrossedAnalysis,
                            icon: const Icon(
                              Icons.call_split,
                              color: Colors
                                  .greenAccent, // Corretto in verde come da te richiesto
                              size:
                                  38, // ⬅️ Ingrandito rispetto agli altri bottoni per dargli risalto
                            ),
                            tooltip: "Valutazione Incrociata",
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // IL PULSANTE PRINCIPALE E' FISSO E ANCORATO A DESTRA
                if (_isEngineRunning) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _stopEngine,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white, width: 2),
                      ),
                      padding: const EdgeInsets.all(14),
                      elevation: 4,
                    ),
                    child: const Icon(Icons.stop, size: 28),
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoadingOptions ? null : _startEngine,
                    icon: const Icon(Icons.power),
                    label: const Text('Accendi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // <-- NUOVA FUNZIONE: Smonta la stringa del motore e salva l'opzione -->
  void _parseUciOption(String line) {
    try {
      // Puliamo spazi doppi o tabulazioni strane
      line = line.replaceAll(RegExp(r'\s+'), ' ');
      if (!line.contains("option name ") || !line.contains(" type ")) return;

      int nameStart = line.indexOf("option name ") + 12;
      int nameEnd = line.indexOf(" type ");
      String name = line.substring(nameStart, nameEnd).trim();

      int typeStart = nameEnd + 6;
      int typeEnd = line.indexOf(" ", typeStart);
      if (typeEnd == -1) typeEnd = line.length;
      String type = line.substring(typeStart, typeEnd).trim();

      String def = "";
      if (line.contains(" default ")) {
        int defStart = line.indexOf(" default ") + 9;
        int defEnd = line.indexOf(" min ", defStart);
        if (defEnd == -1) defEnd = line.indexOf(" max ", defStart);
        if (defEnd == -1) defEnd = line.indexOf(" combo ", defStart);
        if (defEnd == -1) defEnd = line.length;
        def = line.substring(defStart, defEnd).trim();
      }

      if (!_engineOptionsMetadata.any((opt) => opt['name'] == name)) {
        if (mounted) {
          setState(() {
            _engineOptionsMetadata.add({'name': name, 'type': type});

            // Cerchiamo in memoria un valore salvato per QUESTO specifico motore
            String savedValue =
                _prefs?.getString('${_selectedEngine}_$name') ?? "";

            if (savedValue.isNotEmpty) {
              _uciValues[name] = savedValue; // Se c'è, usa quello salvato!
            } else if (!_uciValues.containsKey(name) && def.isNotEmpty) {
              _uciValues[name] = def; // Altrimenti usa il default
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Errore parse: $e su riga: $line");
    }
  }

  // Questa funzione gestisce la creazione di varianti e la cattura della notazione
  Future<void> _onMovePerformed() async {
    String newFen = _boardController.getFen();
    if (_currentNode.fen == newFen) {
      return; // FIX: Previene il doppio innesco che corrompe la storia del LiveBook!
    }

    _isDragging = false;
    _arrowsNotifier.value = [];

    // Recuperiamo il nome della mossa leggendo il PGN ufficiale
    String pgn = _boardController.game.pgn();

    // Puliamo eventuali risultati scritti a fine stringa (es. "1-0" o "*")
    pgn = pgn.replaceAll(RegExp(r'\s*(1-0|0-1|1/2-1/2|\*)\s*$'), '');
    List<String> pgnParts = pgn.split(RegExp(r'\s+'));

    // Cerchiamo l'ultima parola che non contiene un punto (per ignorare i numeri come "1.")
    String moveSan = pgnParts.lastWhere(
      (s) => !s.contains('.'),
      orElse: () => "Mossa",
    );
    try {
      if (moveSan.contains('#')) {
        // Scacco Matto!
        _audioPlayer.play(
          UrlSource(
            'https://images.chesscomfiles.com/chess-themes/sounds/_MP3_/default/game-end.mp3',
          ),
        );
      } else if (moveSan.contains('+')) {
        // Scacco!
        _audioPlayer.play(
          UrlSource(
            'https://images.chesscomfiles.com/chess-themes/sounds/_MP3_/default/move-check.mp3',
          ),
        );
      } else if (moveSan.contains('x')) {
        // Cattura
        _audioPlayer.play(
          UrlSource(
            'https://images.chesscomfiles.com/chess-themes/sounds/_MP3_/default/capture.mp3',
          ),
        );
      } else {
        // Mossa normale
        _audioPlayer.play(
          UrlSource(
            'https://images.chesscomfiles.com/chess-themes/sounds/_MP3_/default/move-self.mp3',
          ),
        );
      }
    } catch (e) {
      debugPrint("Errore riproduzione audio: $e");
    }

    // 1. Controlliamo se la mossa esiste già
    MoveNode? existingChild;
    for (var child in _currentNode.children) {
      if (child.fen == newFen) {
        existingChild = child;
        break;
      }
    }

    if (existingChild != null) {
      _currentNode = existingChild;
    } else {
      if (_currentNode.children.isEmpty) {
        // Linea retta
        final newNode = MoveNode(
          fen: newFen,
          san: moveSan,
          parent: _currentNode,
        );
        _currentNode.children.add(newNode);
        _currentNode = newNode;
      } else {
        // Variante!
        String? choice = await _showBranchingDialog();
        if (choice == 'main') {
          final newNode = MoveNode(
            fen: newFen,
            san: moveSan,
            parent: _currentNode,
          );
          _currentNode.children.insert(0, newNode);
          _currentNode = newNode;
        } else if (choice == 'variant') {
          final newNode = MoveNode(
            fen: newFen,
            san: moveSan,
            parent: _currentNode,
          );
          _currentNode.children.add(newNode);
          _currentNode = newNode;
        } else if (choice == 'overwrite') {
          _currentNode.children.clear();
          final newNode = MoveNode(
            fen: newFen,
            san: moveSan,
            parent: _currentNode,
          );
          _currentNode.children.add(newNode);
          _currentNode = newNode;
        } else {
          _boardController.loadFen(_currentNode.fen);
          return; // Esce senza aggiornare
        }
      }
    }
    setState(() {});
    _triggerEngineAnalysis();
  }

  // Piccolo metodo di supporto per non ripetere il codice di avvio motore
  void _triggerEngineAnalysis() {
    _updateLiveBook(); // <-- AGGIUNTO: Aggiorna il Livebook ad ogni mossa, anche a motore spento!
    if (_isPlayingMode) {
      _playFsm?.playCycle();
    } else if (_isEngineRunning) {
      _startNormalAnalysis();
    }
  }

  // Metodo per generare la stringa PGN completa di Header
  String _buildPgnString({
    String event = "ShashGui Match",
    String white = "Player",
    String black = "Engine",
  }) {
    final game = _boardController.game;
    final fen =
        _currentNode.fen; // Usiamo la FEN del nodo radice dell'albero attuale

    // Calcolo del risultato
    String result = "*";
    if (game.game_over) {
      // <-- CORRETTO: rimosse le parentesi, è una proprietà!
      if (game.in_draw) {
        result = "1/2-1/2";
      } else {
        result = (game.turn.toString() == 'w') ? "0-1" : "1-0";
      }
    }

    String date =
        "${DateTime.now().year}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')}";

    StringBuffer sb = StringBuffer();
    sb.writeln('[Event "$event"]');
    sb.writeln('[Site "Mobile Device"]');
    sb.writeln('[Date "$date"]');
    sb.writeln('[Round "-"]');
    sb.writeln('[White "$white"]');
    sb.writeln('[Black "$black"]');
    sb.writeln('[Result "$result"]');

    // Se la partita non inizia dalla posizione standard, aggiungiamo Setup e FEN
    if (_rootNode.fen !=
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1') {
      sb.writeln('[FEN "${_rootNode.fen}"]');
      sb.writeln('[SetUp "1"]');
    }

    sb.writeln("");
    sb.writeln(game.pgn());
    return sb.toString();
  }

  // Metodo per il salvataggio fisico su file
  Future<void> _savePgnToFile() async {
    final pgnData = _buildPgnString();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = "game_${DateTime.now().millisecondsSinceEpoch}.pgn";
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(pgnData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Partita salvata in: $fileName 💾"),
            action: SnackBarAction(
              label: "COPIA",
              onPressed: () => Clipboard.setData(ClipboardData(text: pgnData)),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Errore salvataggio: $e");
    }
  }

  // --- LOGICA SMART IMPORT (File, Lichess, PGN, FEN) ---

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 1. Lettura File dal Dispositivo
  Future<void> _pickAndLoadFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        // <--- CORRETTO! Rimosso .platform
        type: FileType.custom,
        allowedExtensions: ['pgn', 'epd', 'fen', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        _processImportString(content);
      }
    } catch (e) {
      _showError("Errore nell'apertura del file: $e");
    }
  }

  // 2. Finestra di dialogo per Testo o Link Lichess
  void _showSmartImportDialog() {
    TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2b2b2b),
        title: const Text(
          "Importa Testo / Lichess",
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: TextField(
          controller: textController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Incolla un Link Lichess, un FEN o un PGN intero...",
            hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (textController.text.isNotEmpty) {
                _processImportString(textController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan[700]),
            child: const Text("Importa", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 3. Il Cervello che smista FEN, PGN o Link Lichess
  Future<void> _processImportString(String input) async {
    String data = input.trim();

    // A) È un link di Lichess?
    if (data.startsWith("http") && data.contains("lichess.org")) {
      try {
        String id = data.split('/').last;
        if (id.contains('#')) {
          id = id.split('#').first; // Pulisce ancore come #34
        }

        // Chiamata all'API di export di Lichess
        final response = await http.get(
          Uri.parse(
            "https://lichess.org/game/export/$id?clocks=false&evals=false&tags=true",
          ),
        );
        if (response.statusCode == 200) {
          data =
              response.body; // Sostituiamo il link con il PGN appena scaricato!
        } else {
          _showError(
            "Errore nel download da Lichess (Status: ${response.statusCode})",
          );
          return;
        }
      } catch (e) {
        _showError("Impossibile connettersi a Lichess");
        return;
      }
    }

    // B) È un PGN? (Contiene i tag o le mosse numerate)
    if (data.contains("[Event") || data.contains("1. ")) {
      _loadPgnGame(data);
    }
    // C) Altrimenti lo trattiamo come FEN o EPD
    else {
      try {
        _boardController.loadFen(data);
        setState(() {
          _rootNode = MoveNode(fen: data, san: 'Setup FEN');
          _currentNode = _rootNode;
          _arrowsNotifier.value = [];
        });
        if (_isEngineRunning && !_isPlayingMode) _startNormalAnalysis();
      } catch (e) {
        _showError("Formato FEN non valido");
      }
    }
  }

  // 4. Costruttore dell'Albero delle mosse da un PGN
  void _loadPgnGame(String pgn) {
    try {
      // Usiamo una scacchiera temporanea invisibile per parsare il file
      final tempBoard = ChessBoardController();
      tempBoard.game.load_pgn(pgn);

      // Estraiamo il PGN testuale ripulito per ottenere solo la lista delle mosse SAN
      String cleanPgn = tempBoard.game.pgn();

      // Rimuoviamo gli Header [Event "..."]
      cleanPgn = cleanPgn.replaceAll(RegExp(r'\[.*?\]'), '');
      // Rimuoviamo i commenti { ... }
      cleanPgn = cleanPgn.replaceAll(RegExp(r'\{.*?\}'), '');
      // Rimuoviamo i NAG tattici come $1, $2
      cleanPgn = cleanPgn.replaceAll(RegExp(r'\$\d+'), '');
      // Rimuoviamo le numerazioni delle mosse (es. 1. o 15...)
      cleanPgn = cleanPgn.replaceAll(RegExp(r'\d+\.+'), '');
      // Rimuoviamo i risultati finali (es. 1-0, 0-1, 1/2-1/2, *)
      cleanPgn = cleanPgn.replaceAll(RegExp(r'(1-0|0-1|1/2-1/2|\*)'), '');

      // Ora splittiamo per spazi e otteniamo la lista pulita delle mosse ["e4", "e5", "Nf3"...]
      List<String> sanMoves = cleanPgn
          .split(RegExp(r'\s+'))
          .where((s) => s.trim().isNotEmpty)
          .toList();

      // Ricerchiamo se la partita partiva da un FEN specifico o dalla posizione iniziale
      String startFen =
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      final fenMatch = RegExp(r'\[FEN "([^"]+)"\]').firstMatch(pgn);
      if (fenMatch != null) startFen = fenMatch.group(1)!;

      _boardController.loadFen(startFen);

      setState(() {
        _rootNode = MoveNode(fen: startFen, san: 'Inizio PGN');
        _currentNode = _rootNode;
        _arrowsNotifier.value = [];

        // Ricostruiamo il nostro albero di navigazione applicando una mossa alla volta
        for (String san in sanMoves) {
          _boardController.game.move(
            san,
          ); // Usiamo l'engine interno di chess_board
          MoveNode newNode = MoveNode(
            fen: _boardController.getFen(),
            san: san,
            parent: _currentNode,
          );
          _currentNode.children.add(newNode);
          _currentNode = newNode; // Andiamo in fondo all'albero
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Partita caricata con successo! ✅"),
          backgroundColor: Colors.green,
        ),
      );
      if (_isEngineRunning && !_isPlayingMode) _startNormalAnalysis();
    } catch (e) {
      _showError("Errore nel parsing del file PGN!");
    }
  }

  Widget _buildNotationPanel() {
    List<Widget> widgets = [];

    void buildNotation(MoveNode node, int moveCount) {
      if (node.children.isEmpty) return;
      var mainMove = node.children.first;
      bool isCurrent = (mainMove == _currentNode);
      String prefix = (moveCount % 2 != 0)
          ? "${(moveCount / 2).floor() + 1}. "
          : "";

      widgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _currentNode = mainMove;
              _boardController.loadFen(mainMove.fen);
            });
            _triggerEngineAnalysis();
          },
          child: Text(
            "$prefix${mainMove.san} ",
            style: TextStyle(
              color: isCurrent ? Colors.orangeAccent : Colors.white,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
      );

      if (node.children.length > 1) {
        for (int i = 1; i < node.children.length; i++) {
          var variant = node.children[i];
          widgets.add(
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentNode = variant;
                  _boardController.loadFen(variant.fen);
                });
                _triggerEngineAnalysis();
              },
              child: Text(
                "(${variant.san}) ",
                style: const TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }
      }
      buildNotation(mainMove, moveCount + 1);
    }

    buildNotation(_rootNode, 1);

    return Stack(
      // Usiamo uno Stack per mettere il tasto sopra la notazione
      children: [
        Container(
          width: double.infinity,
          height: 120,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: SingleChildScrollView(
            child: Wrap(
              children: widgets.isEmpty
                  ? [
                      const Text(
                        "Inizia a muovere...",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ]
                  : widgets,
            ),
          ),
        ),
        // --- LA BARRA DEGLI STRUMENTI DEL DATABASE ---
        Positioned(
          top: 0,
          right: 0,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.folder_open,
                  size: 20,
                  color: Colors.amberAccent,
                ),
                tooltip: "Apri File (PGN/FEN)",
                onPressed: _pickAndLoadFile, // <-- APRE IL FILE SYSTEM
              ),
              IconButton(
                icon: const Icon(
                  Icons.link,
                  size: 20,
                  color: Colors.cyanAccent,
                ),
                tooltip: "Importa Link Lichess / Incolla PGN",
                onPressed: _showSmartImportDialog, // <-- APRE LO SMART IMPORT
              ),
              IconButton(
                icon: const Icon(
                  Icons.grid_view,
                  size: 20,
                  color: Colors.greenAccent,
                ),
                tooltip: "Editor Visivo FEN",
                onPressed: _showImportDialog, // <-- IL TUO EDITOR FEN VISIVO
              ),
              IconButton(
                icon: const Icon(
                  Icons.save,
                  size: 20,
                  color: Colors.blueAccent,
                ),
                tooltip: "Salva Partita in locale",
                onPressed: _savePgnToFile,
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy_all,
                  size: 20,
                  color: Colors.orangeAccent,
                ),
                tooltip: "Copia PGN in memoria",
                onPressed: () {
                  String pgn = _boardController.game.pgn();
                  Clipboard.setData(ClipboardData(text: pgn));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("PGN copiato negli appunti! 📋"),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Mostra il popup quando si crea una diramazione
  Future<String?> _showBranchingDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // L'utente deve scegliere o annullare
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2b2b2b),
          title: const Text(
            "Diramazione rilevata",
            style: TextStyle(color: Colors.orangeAccent),
          ),
          content: const Text(
            "Esiste già una continuazione per questa posizione. Cosa vuoi fare?",
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'main'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                  ),
                  child: const Text(
                    "Nuova Linea Principale",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'variant'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                  ),
                  child: const Text(
                    "Aggiungi come Variante",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'overwrite'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                  ),
                  child: const Text(
                    "Sovrascrivi tutto",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text(
                    "Annulla mossa",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Metodo per importare un FEN esterno TRAMITE EDITOR VISIVO
  void _showImportDialog() async {
    final newFen = await showDialog<String>(
      context: context,
      builder: (context) =>
          SetupPositionDialog(initialFen: _boardController.getFen()),
    );

    if (newFen != null && newFen.isNotEmpty) {
      try {
        // 1. Carica la posizione
        _boardController.loadFen(newFen);

        // 2. Resetta l'albero delle mosse partendo da qui
        setState(() {
          _rootNode = MoveNode(fen: newFen, san: 'Posizione Impostata');
          _currentNode = _rootNode;
          _arrowsNotifier.value = []; // Pulisce eventuali frecce
        });

        // 3. Se il motore è acceso, analizza subito la nuova posizione!
        if (_isEngineRunning && !_isPlayingMode) {
          _startNormalAnalysis();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Errore: La scacchiera non ha potuto validare il FEN!",
            ),
          ),
        );
      }
    }
  }

  // CALCOLO MATERIALE CATTURATO
  Map<String, dynamic> _calculateMaterial(String fen) {
    final piecePlacement = fen.split(' ')[0];
    Map<String, int> counts = {
      'P': 0, 'N': 0, 'B': 0, 'R': 0, 'Q': 0, // Bianchi
      'p': 0, 'n': 0, 'b': 0, 'r': 0, 'q': 0, // Neri
    };

    for (var char in piecePlacement.runes) {
      var s = String.fromCharCode(char);
      if (counts.containsKey(s)) counts[s] = counts[s]! + 1;
    }

    List<String> whiteCaptured = [];
    List<String> blackCaptured = [];
    int score = 0;
    Map<String, int> values = {'p': 1, 'n': 3, 'b': 3, 'r': 5, 'q': 9};

    void check(String p, int max, List<String> list) {
      int missing = max - (counts[p] ?? 0);
      for (int i = 0; i < missing; i++) {
        list.add(p.toLowerCase());
        score += p == p.toUpperCase()
            ? -values[p.toLowerCase()]!
            : values[p.toLowerCase()]!;
      }
    }

    check('P', 8, whiteCaptured);
    check('N', 2, whiteCaptured);
    check('B', 2, whiteCaptured);
    check('R', 2, whiteCaptured);
    check('Q', 1, whiteCaptured);
    check('p', 8, blackCaptured);
    check('n', 2, blackCaptured);
    check('b', 2, blackCaptured);
    check('r', 2, blackCaptured);
    check('q', 1, blackCaptured);

    return {
      'whiteCaptured': whiteCaptured,
      'blackCaptured': blackCaptured,
      'score': score,
    };
  }

  // WIDGET PER DISEGNARE I PEZZI CATTURATI
  Widget _buildCapturedPieces(List<String> pieces, int score) {
    Map<String, String> icons = {
      'p': '♟',
      'n': '♞',
      'b': '♝',
      'r': '♜',
      'q': '♛',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...pieces.map(
          (p) => Text(
            icons[p]!,
            style: const TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ),
        if (score > 0)
          Padding(
            padding: const EdgeInsets.only(left: 6.0),
            child: Text(
              "+$score",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }

  void _goBack() {
    if (_currentNode.parent != null) {
      setState(() {
        _currentNode = _currentNode.parent!;
        _boardController.loadFen(_currentNode.fen);
      });
      if (_isEngineRunning && !_isPlayingMode) _startNormalAnalysis();
    }
  }

  void _goForward() {
    if (_currentNode.children.isNotEmpty) {
      setState(() {
        // Segue sempre la prima variante (linea principale)
        _currentNode = _currentNode.children.first;
        _boardController.loadFen(_currentNode.fen);
      });
      if (_isEngineRunning && !_isPlayingMode) _startNormalAnalysis();
    }
  }

  void _goToStart() {
    setState(() {
      _currentNode = _rootNode;
      _boardController.loadFen(_currentNode.fen);
    });
    if (_isEngineRunning && !_isPlayingMode) _startNormalAnalysis();
  }

  void _goToEnd() {
    while (_currentNode.children.isNotEmpty) {
      _currentNode = _currentNode.children.first;
    }
    setState(() {
      _boardController.loadFen(_currentNode.fen);
    });
    if (_isEngineRunning && !_isPlayingMode) _startNormalAnalysis();
  }

  void _startPlayMode() {
    if (!_isEngineRunning) return;

    // Variabili temporanee per il popup
    bool tempLivebook = true;
    PlayerColor tempColor = PlayerColor.white;
    int tempTcType = 0; // 0 = Fischer, 1 = Fisso
    int tempBaseTime = 5; // Minuti o Secondi base
    int tempInc = 3; // Incremento in secondi

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2b2b2b),
              title: const Text(
                "Impostazioni Sfida",
                style: TextStyle(color: Colors.orangeAccent),
              ),
              content: SingleChildScrollView(
                // Evita overflow su schermi piccoli
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. SCELTA COLORE UMANO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Giochi col:",
                          style: TextStyle(color: Colors.white),
                        ),
                        DropdownButton<PlayerColor>(
                          value: tempColor,
                          dropdownColor: const Color(0xFF2b2b2b),
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(
                              value: PlayerColor.white,
                              child: Text("Bianco"),
                            ),
                            DropdownMenuItem(
                              value: PlayerColor.black,
                              child: Text("Nero"),
                            ),
                          ],
                          onChanged: (val) =>
                              setPopupState(() => tempColor = val!),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),

                    // 2. LIVEBOOK E TRATTI (PREMIUM)
                    SwitchListTile(
                      title: const Text(
                        "Usa LiveBook Cloud",
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                      subtitle: const Text(
                        "Il motore pescherà le aperture dal web.",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: tempLivebook,
                      activeThumbColor: Colors.greenAccent,
                      onChanged: (v) => setPopupState(() => tempLivebook = v),
                    ),
                    ListTile(
                      title: const Text(
                        "Filtri Tratti Posizionali",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      subtitle: const Text(
                        "Aggiunge bias strategico alle mosse.",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      trailing: const Icon(
                        Icons.lock,
                        color: Colors.orangeAccent,
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "I Filtri sui Tratti Posizionali sono un'esclusiva della versione Premium!",
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(color: Colors.white24),

                    // 3. LIMITA FORZA
                    if (_selectedEngine == 'alexander') ...[
                      SwitchListTile(
                        title: const Text(
                          "Limita Forza",
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                        value: _limitStrength,
                        activeThumbColor: Colors.blueAccent,
                        onChanged: (v) =>
                            setPopupState(() => _limitStrength = v),
                      ),
                      if (_limitStrength) ...[
                        Text(
                          "Livello ELO: ${_eloValue.toInt()}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Slider(
                          value: _eloValue,
                          min: 1000,
                          max: 2850,
                          divisions: 37,
                          label: _eloValue.toInt().toString(),
                          activeColor: Colors.blueAccent,
                          onChanged: (v) => setPopupState(() => _eloValue = v),
                        ),
                      ],
                      const Divider(color: Colors.white24),
                    ],

                    // 4. OROLOGIO E CADENZE (REPLICA DESKTOP)
                    const Text(
                      "Orologio (Cadenza)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orangeAccent,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    RadioListTile<int>(
                      title: const Text(
                        "Tempo Globale (Fischer)",
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      ),
                      value: 0,
                      groupValue: tempTcType,
                      activeColor: Colors.orangeAccent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setPopupState(() {
                        tempTcType = v!;
                        tempBaseTime = 5;
                      }),
                    ),
                    RadioListTile<int>(
                      title: const Text(
                        "Tempo Fisso per Mossa",
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      ),
                      value: 1,
                      groupValue: tempTcType,
                      activeColor: Colors.orangeAccent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setPopupState(() {
                        tempTcType = v!;
                        tempBaseTime = 3;
                      }),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              tempTcType == 0 ? "Minuti:" : "Secondi:",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            DropdownButton<int>(
                              value: tempBaseTime,
                              dropdownColor: const Color(0xFF2b2b2b),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              items:
                                  (tempTcType == 0
                                          ? [1, 2, 3, 5, 10, 15, 30]
                                          : [1, 2, 3, 5, 10, 15])
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text("$e"),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) =>
                                  setPopupState(() => tempBaseTime = v!),
                            ),
                          ],
                        ),
                        if (tempTcType == 0)
                          Column(
                            children: [
                              const Text(
                                "Incremento (s):",
                                style: TextStyle(color: Colors.white70),
                              ),
                              DropdownButton<int>(
                                value: tempInc,
                                dropdownColor: const Color(0xFF2b2b2b),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                items: [0, 1, 2, 3, 5, 10, 15]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text("$e"),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setPopupState(() => tempInc = v!),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annulla"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Applichiamo le scelte!
                    setState(() => _boardOrientation = tempColor);
                    _executePlayModeStartup(
                      useLivebook: tempLivebook,
                      tcType: tempTcType,
                      baseTime: tempBaseTime,
                      increment: tempInc,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("GIOCA"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Aggiorna anche la firma di questa funzione subito sotto:
  void _executePlayModeStartup({
    bool useLivebook = true,
    int tcType = 1,
    int baseTime = 3,
    int increment = 0,
  }) {
    _stopAllOrchestrators();

    if (_selectedEngine == 'alexander') {
      if (_limitStrength) {
        _engineManager.sendCommand(
          'setoption name UCI_LimitStrength value true',
        );
        _engineManager.sendCommand(
          'setoption name UCI_Elo value ${_eloValue.toInt()}',
        );
      } else {
        _engineManager.sendCommand(
          'setoption name UCI_LimitStrength value false',
        );
      }
    }

    setState(() {
      _isPlayingMode = true;
      _outputLines.clear();
      _arrowsNotifier.value = [];
    });

    _zoneNotifier.value = ShashinZone(
      "Modalità Gioco",
      "⚔️",
      Colors.orange,
      50.0,
      ["assets/images/capablanca.png"], // <-- Messo tra parentesi quadre
    );

    // PASSAGGIO DEI PARAMETRI OROLOGIO ALL'ORCHESTRATORE
    _playFsm = PlayOrchestrator(
      engineManager: _engineManager,
      boardController: _boardController,
      useLivebook: useLivebook,
      tcType: tcType,
      // Convertiamo minuti in millisecondi (Fischer) o secondi in millisecondi (Fisso)
      baseTimeMs: tcType == 0 ? (baseTime * 60 * 1000) : (baseTime * 1000),
      incMs: increment * 1000,
      onLog: (line) {
        setState(() => _outputLines.add(line));
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      },
      onGameOver: (messaggio) => _showGameOverDialog(messaggio!),
    );

    _playFsm!.startGame();

    // Se l'utente è Nero, il motore (Bianco) gioca subito!
    if (_boardOrientation == PlayerColor.black &&
        _boardController.getFen().contains(" w ")) {
      _playFsm?.playCycle();
    }
  }

  // --- 3. POPUP FINE PARTITA ---
  void _showGameOverDialog(String messaggio) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2b2b2b),
        title: const Text(
          "Fine Partita",
          style: TextStyle(color: Colors.orangeAccent),
        ),
        content: Text(messaggio, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopAllOrchestrators();
              setState(() => _isPlayingMode = false);
              // Rimettiamo il motore in analisi automatica
              if (_isEngineRunning) _startNormalAnalysis();
            },
            child: const Text(
              "TORNA AL LABORATORIO",
              style: TextStyle(color: Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showUciSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permette al menu di occupare più spazio
      backgroundColor: const Color(0xFF1e1e1e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height:
              MediaQuery.of(context).size.height *
              0.75, // Occupa il 75% dello schermo
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "OPZIONI ${_selectedEngine.toUpperCase()}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),

              // QUI GENERIAMO DINAMICAMENTE TUTTE LE OPZIONI TROVATE DALLA SONDA
              Expanded(
                child: _engineOptionsMetadata.isEmpty
                    ? const Center(
                        child: Text(
                          "Nessuna opzione trovata o caricamento in corso...",
                        ),
                      )
                    : ListView.builder(
                        itemCount: _engineOptionsMetadata.length,
                        itemBuilder: (context, index) {
                          final opt = _engineOptionsMetadata[index];
                          final name = opt['name']!;

                          // Ignoriamo i bottoni (es. "Clear Hash") per semplificare la UI
                          if (opt['type'] == 'button') {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: TextFormField(
                              initialValue: _uciValues[name] ?? "",
                              decoration: InputDecoration(
                                labelText: name,
                                labelStyle: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                ),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              onChanged: (v) {
                                _uciValues[name] = v;
                                _prefs?.setString(
                                  '${_selectedEngine}_$name',
                                  v,
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- METODO PER IL THREAT DETECTOR (MOSSA NULLA) ---
  void _scanThreats() async {
    if (!_isEngineRunning || _isPlayingMode || _isScanningThreat) return;

    // 1. REGOLE SCACCHISTICHE: Niente mossa nulla se siamo sotto scacco
    if (_boardController.game.in_check) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossibile analizzare le minacce sotto scacco!"),
        ),
      );
      return;
    }

    String currentFen = _boardController.getFen();

    // 2. REGOLE SCACCHISTICHE: Niente mossa nulla alla primissima mossa
    if (currentFen.contains("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nessuna minaccia alla mossa iniziale!")),
      );
      return;
    }

    setState(() => _isScanningThreat = true); // Attiva sicura

    _stopAllOrchestrators();
    _engineManager.sendCommand('stop');

    List<String> fenParts = currentFen.split(' ');
    fenParts[1] = (fenParts[1] == 'w') ? 'b' : 'w'; // Inverte turno
    fenParts[3] =
        '-'; // Rimuove il target en passant, fondamentale per la legalità della FEN
    String nullMoveFen = fenParts.join(' ');

    // 3. FIX TIMING: Diamo al motore 100ms per assorbire lo 'stop' prima di inviare i nuovi comandi
    Future.delayed(const Duration(milliseconds: 100), () {
      _engineManager.sendCommand('position fen $nullMoveFen');
      _engineManager.sendCommand('go movetime 1500');

      StreamSubscription<String>? threatSub;
      threatSub = _engineManager.engineOutput?.listen((line) {
        if (line.startsWith('bestmove')) {
          threatSub?.cancel();
          final parts = line.split(' ');

          if (parts.length > 1 && parts[1] != '(none)' && parts[1] != '0000') {
            setState(() {
              _arrowsNotifier.value = [
                BoardArrow(
                  from: parts[1].substring(0, 2),
                  to: parts[1].substring(2, 4),
                  color: Colors.red.withOpacity(
                    0.85,
                  ), // Un rosso più intenso per le minacce
                ),
              ];
            });

            // Aspetta 3 secondi, poi ripristina la normalità
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() => _isScanningThreat = false);
                _startNormalAnalysis();
              }
            });
          } else {
            // Se l'engine restituisce (none), non ci sono minacce legali trovate
            setState(() => _isScanningThreat = false);
            _startNormalAnalysis();
          }
        }
      });
    });
  }

  // --- METODO PER IL POPUP DELL'ANALISI CONTINUA ---
  void _showAnalysisSetupDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2b2b2b),
              title: const Text(
                "Impostazioni Analisi",
                style: TextStyle(color: Colors.orangeAccent),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Tempo iniziale (T1) per mossa:",
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "${_baseTimeSec.toInt()} secondi",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                      fontSize: 22,
                    ),
                  ),
                  Slider(
                    value: _baseTimeSec,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: "${_baseTimeSec.toInt()} s",
                    activeColor: Colors.blueAccent,
                    onChanged: (v) => setPopupState(() => _baseTimeSec = v),
                  ),
                  const Text(
                    "Il tempo raddoppierà automaticamente ad ogni iterazione della Teoria di Shashin.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Annulla",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _startNormalAnalysis(); // Avvia l'analisi con il tempo scelto
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("AVVIA ANALISI"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- METODO PER L'ANALISI INCROCIATA (Doppie Frecce) ---
  void _startCrossedAnalysis() {
    if (!_isEngineRunning) return;

    int tempCrossedTime = 2; // Default 2 secondi
    int tempCrossedElo = _eloValue.toInt(); // Peschiamo l'Elo di partenza

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2b2b2b),
              title: const Text(
                "Coach: Analisi Incrociata",
                style: TextStyle(color: Colors.cyanAccent),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Il tuo Livello (Elo): $tempCrossedElo",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: tempCrossedElo.toDouble(),
                    min: 1000,
                    max: 3190,
                    divisions: 43,
                    label: tempCrossedElo.toString(),
                    activeColor: Colors.orangeAccent,
                    onChanged: (v) {
                      setPopupState(() {
                        tempCrossedElo = v.toInt();
                        _eloValue = v; // Aggiorna anche la variabile globale
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "Tempo base per valutazione: $tempCrossedTime s",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: tempCrossedTime.toDouble(),
                    min: 1,
                    max: 15,
                    divisions: 14,
                    label: "$tempCrossedTime s",
                    activeColor: Colors.cyanAccent,
                    onChanged: (v) =>
                        setPopupState(() => tempCrossedTime = v.toInt()),
                  ),
                  const Text(
                    "(Da 2500 Elo in poi, il Maestro sarà la Rete Neurale ShashChess)",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annulla"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // ORA PASSIAMO SIA IL TEMPO CHE L'ELO SCELTO!
                    _executeCrossedAnalysis(tempCrossedTime, tempCrossedElo);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("AVVIA COACH"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _executeCrossedAnalysis(int baseTimeSec, int playerElo) {
    _stopAllOrchestrators(); // Stoppa l'analisi normale

    setState(() {
      _outputLines.clear();
      _arrowsNotifier.value = [];
      _outputLines.add(
        "<span style='color: #f39c12; font-weight: bold;'>Inizializzazione Analisi Incrociata in corso...</span>",
      );
    });

    _engineManager.sendCommand('stop');

    // Diamo 100ms al motore per fermarsi davvero
    Future.delayed(const Duration(milliseconds: 100), () {
      _crossedFsm = CrossedEvalOrchestrator(
        engineManager: _engineManager,
        onLog: (msg) {
          setState(() => _outputLines.add(msg));
          Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
        },
        onReportReady: (reportText) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF2b2b2b),
              title: const Text(
                "🔍 Coach: Verdetto Incrociato",
                style: TextStyle(color: Colors.cyanAccent),
              ),
              content: SingleChildScrollView(
                child: Text(
                  reportText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Chiudi",
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),
              ],
            ),
          );
        },
      );

      // Usiamo l'Elo scelto dall'utente e il tempo in millisecondi!
      _crossedFsm!.startCrossedEval(
        _boardController.getFen(),
        playerElo,
        baseTimeSec * 1000,
      );
    });
  }

  void _startAutoplayMode() {
    if (!_isEngineRunning) return;

    String tempWhiteEngine = _selectedEngine;
    String tempBlackEngine = _selectedEngine;
    bool tempWhiteLivebook = true;
    bool tempBlackLivebook = true;
    int tempTcType = 1;
    int tempBaseTime = 2;
    int tempInc = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2b2b2b),
              title: const Text(
                "Impostazioni Autoplay",
                style: TextStyle(color: Colors.purpleAccent),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // BIANCO
                    Container(
                      color: Colors.white10,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          const Text(
                            "MOTORE BIANCO",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          DropdownButton<String>(
                            value: tempWhiteEngine,
                            dropdownColor: const Color(0xFF2b2b2b),
                            style: const TextStyle(color: Colors.white),
                            items: const [
                              DropdownMenuItem(
                                value: 'shashchess',
                                child: Text("ShashChess"),
                              ),
                              DropdownMenuItem(
                                value: 'alexander',
                                child: Text("Alexander"),
                              ),
                            ],
                            onChanged: (val) =>
                                setPopupState(() => tempWhiteEngine = val!),
                          ),
                          SwitchListTile(
                            title: const Text(
                              "LiveBook",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            value: tempWhiteLivebook,
                            activeThumbColor: Colors.greenAccent,
                            onChanged: (v) =>
                                setPopupState(() => tempWhiteLivebook = v),
                          ),
                          ListTile(
                            title: const Text(
                              "Tratti Posizionali",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.lock,
                              size: 16,
                              color: Colors.orangeAccent,
                            ),
                            dense: true,
                            onTap: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Esclusiva Premium!"),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // NERO
                    Container(
                      color: Colors.black45,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          const Text(
                            "MOTORE NERO",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          DropdownButton<String>(
                            value: tempBlackEngine,
                            dropdownColor: const Color(0xFF2b2b2b),
                            style: const TextStyle(color: Colors.white),
                            items: const [
                              DropdownMenuItem(
                                value: 'shashchess',
                                child: Text("ShashChess"),
                              ),
                              DropdownMenuItem(
                                value: 'alexander',
                                child: Text("Alexander"),
                              ),
                            ],
                            onChanged: (val) =>
                                setPopupState(() => tempBlackEngine = val!),
                          ),
                          SwitchListTile(
                            title: const Text(
                              "LiveBook",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            value: tempBlackLivebook,
                            activeThumbColor: Colors.greenAccent,
                            onChanged: (v) =>
                                setPopupState(() => tempBlackLivebook = v),
                          ),
                          ListTile(
                            title: const Text(
                              "Tratti Posizionali",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.lock,
                              size: 16,
                              color: Colors.orangeAccent,
                            ),
                            dense: true,
                            onTap: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Esclusiva Premium!"),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    // CADENZA
                    RadioListTile<int>(
                      title: const Text(
                        "Tempo Globale (Fischer)",
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                      value: 0,
                      groupValue: tempTcType,
                      activeColor: Colors.purpleAccent,
                      onChanged: (v) => setPopupState(() {
                        tempTcType = v!;
                        tempBaseTime = 3;
                      }),
                    ),
                    RadioListTile<int>(
                      title: const Text(
                        "Tempo Fisso per Mossa",
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                      value: 1,
                      groupValue: tempTcType,
                      activeColor: Colors.purpleAccent,
                      onChanged: (v) => setPopupState(() {
                        tempTcType = v!;
                        tempBaseTime = 2;
                      }),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              tempTcType == 0 ? "Minuti:" : "Secondi:",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            DropdownButton<int>(
                              value: tempBaseTime,
                              dropdownColor: const Color(0xFF2b2b2b),
                              style: const TextStyle(color: Colors.white),
                              items: [1, 2, 3, 5, 10]
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text("$e"),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setPopupState(() => tempBaseTime = v!),
                            ),
                          ],
                        ),
                        if (tempTcType == 0)
                          Column(
                            children: [
                              const Text(
                                "Incremento (s):",
                                style: TextStyle(color: Colors.white70),
                              ),
                              DropdownButton<int>(
                                value: tempInc,
                                dropdownColor: const Color(0xFF2b2b2b),
                                style: const TextStyle(color: Colors.white),
                                items: [0, 1, 2, 3]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text("$e"),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setPopupState(() => tempInc = v!),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annulla"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _executeAutoplayModeStartup(
                      tempWhiteEngine,
                      tempBlackEngine,
                      tempWhiteLivebook,
                      tempBlackLivebook,
                      tempTcType,
                      tempBaseTime,
                      tempInc,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("AVVIA MATCH"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _executeAutoplayModeStartup(
    String wEng,
    String bEng,
    bool wLb,
    bool bLb,
    int tcType,
    int baseTime,
    int inc,
  ) async {
    _stopAllOrchestrators();

    setState(() {
      _isPlayingMode = true;
      _outputLines.clear();
      _arrowsNotifier.value = [];
    });

    _zoneNotifier.value = ShashinZone(
      "Autoplay Match",
      "⚔️",
      Colors.purple,
      50.0,
      ["assets/images/capablanca.png"],
    );

    // Accendiamo il motore secondario se necessario
    if (_engineManagerBlack.engineOutput == null) {
      await _engineManagerBlack.initEngine(bEng, [
        'nn-c288c895ea92.nnue',
        'nn-37f18f62d772.nnue',
      ]);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _autoplayFsm = AutoplayOrchestrator(
      whiteEngine: _engineManager,
      blackEngine: _engineManagerBlack,
      boardController: _boardController,
      whiteUseLivebook: wLb,
      blackUseLivebook: bLb,
      tcType: tcType,
      baseTimeMs: tcType == 0 ? (baseTime * 60 * 1000) : (baseTime * 1000),
      incMs: inc * 1000,
      onLog: (line) {
        setState(() => _outputLines.add(line));
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      },
      onGameOver: (messaggio) => _showGameOverDialog(messaggio!),
    );

    // Resettiamo la scacchiera e partiamo!
    _boardController.loadFen(
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    );
    _autoplayFsm!.startMatch();
  }
}

// --- LA SCHERMATA VETRINA (MOCKUP) ---
class PremiumShowcaseScreen extends StatelessWidget {
  const PremiumShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ShashGui Premium ✨"),
        backgroundColor: const Color(0xFF1e1e1e),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "FUNZIONALITÀ CLOUD (COMING SOON)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 10),
          _buildPremiumCard(
            title: "ChessBeauty Analyzer",
            desc:
                "Valutazione estetica e qualimetrica della tua partita tramite algoritmi batch in remoto.",
            icon: Icons.auto_awesome,
            color: Colors.pinkAccent,
          ),
          _buildPremiumCard(
            title: "Nuggets Explorer",
            desc:
                "Accedi a migliaia di pepite tattiche estratte dai database storici dei grandi campioni.",
            icon: Icons.savings,
            color: Colors.amber,
          ),
          _buildPremiumCard(
            title: "Dossier Divergenze XAI",
            desc:
                "Scopri esattamente dove la Rete Neurale e i Grandi Maestri Umani non sono d'accordo.",
            icon: Icons.psychology,
            color: Colors.cyanAccent,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              // Qui andrà l'integrazione con gli acquisti In-App
            },
            icon: const Icon(Icons.workspace_premium),
            label: const Text(
              "SBLOCCA TUTTO (9.99€/mese)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: const Color(0xFF2b2b2b),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.2),
            radius: 25,
            child: Icon(icon, color: color, size: 28),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(desc, style: TextStyle(color: Colors.grey[400])),
          ),
          trailing: const Icon(Icons.lock_outline, color: Colors.grey),
        ),
      ),
    );
  }
}

class MoveNode {
  final String fen;
  final String san;
  MoveNode? parent;
  List<MoveNode> children = [];

  MoveNode({required this.fen, required this.san, this.parent});
}
