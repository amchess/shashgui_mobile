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
  final EngineManager _engineManager = EngineManager();

  ShashinFsm? _fsm;
  CrossedEvalOrchestrator? _crossedFsm;
  PlayOrchestrator? _playFsm;

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
  bool _showLiveBook = true;

  // Memoria del tempo iniziale T1 per il loop infinito
  int _baseTimeSec = 2;

  // Variabili per l'handicap (Modalità Gioco)
  bool _limitStrength = false;
  double _eloValue = 1500;
  bool _simulateBlunders = false;

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
      "assets/images/capablanca.png",
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
      _startNormalAnalysis();
    } catch (e) {
      setState(() => _outputLines.add("ERRORE FATALE: $e"));
    }
  }

  void _stopAllOrchestrators() {
    _fsm?.stop();
    _crossedFsm?.stop();
    _playFsm?.stop();

    _fsm?.dispose();
    _crossedFsm?.dispose();
    _playFsm?.dispose();

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
      "assets/images/capablanca.png",
    );

    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
  }

  void _updateLiveBook() async {
    bool isShash = _selectedEngine.toLowerCase().contains("shash");

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
      baseTimeMs: _baseTimeSec * 1000,
    );
  }

  @override
  void dispose() {
    _stopAllOrchestrators();
    _engineManager.dispose();
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
                                              onTap: () async {
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
                                                  // CHIAMATA FONDAMENTALE PER FAR AVANZARE L'ANALISI (COME IN PYTHON)
                                                  await _onMovePerformed();
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
                                Text(
                                  "${zone.wp.toStringAsFixed(1)}%",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
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
                        ),
                        const SizedBox(width: 10),

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
                            onPressed: _isPlayingMode
                                ? _startNormalAnalysis
                                : null,
                            icon: Icon(
                              Icons.analytics,
                              color: _isPlayingMode
                                  ? Colors.blueAccent
                                  : Colors.grey,
                            ),
                            tooltip: "Modalità Analisi",
                          ),
                          IconButton(
                            onPressed: !_isPlayingMode ? _startPlayMode : null,
                            icon: Icon(
                              Icons.sports_esports,
                              color: !_isPlayingMode
                                  ? Colors.greenAccent
                                  : Colors.grey,
                            ),
                            tooltip: "Modalità Gioco",
                          ),
                          IconButton(
                            onPressed: !_isPlayingMode ? _scanThreats : null,
                            icon: Icon(
                              Icons.crisis_alert,
                              color: !_isPlayingMode
                                  ? Colors.redAccent
                                  : Colors.grey,
                            ),
                            tooltip: "Rileva Minacce (Mossa Nulla)",
                          ),
                          IconButton(
                            onPressed: _startCrossedAnalysis,
                            icon: const Icon(
                              Icons.compare_arrows,
                              color: Colors.orangeAccent,
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
    if (_currentNode.fen == newFen)
      return; // FIX: Previene il doppio innesco che corrompe la storia del LiveBook!

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
        // --- IL TASTO COPIA PGN ---
        Positioned(
          top: 0,
          right: 0,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.paste,
                  size: 20,
                  color: Colors.greenAccent,
                ),
                tooltip: "Importa FEN",
                onPressed:
                    _showImportDialog, // <-- CHIAMA IL NOSTRO NUOVO POPUP
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy_all,
                  size: 20,
                  color: Colors.orangeAccent,
                ),
                tooltip: "Copia PGN negli appunti",
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

  // Metodo per importare un FEN esterno
  void _showImportDialog() {
    TextEditingController fenController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2b2b2b),
          title: const Text(
            "Importa Posizione",
            style: TextStyle(color: Colors.orangeAccent),
          ),
          content: TextField(
            controller: fenController,
            decoration: const InputDecoration(
              hintText: "Incolla qui la stringa FEN...",
              hintStyle: TextStyle(color: Colors.white38),
            ),
            style: const TextStyle(color: Colors.white),
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
                String fen = fenController.text.trim();
                if (fen.isNotEmpty) {
                  try {
                    // 1. Carica la posizione
                    _boardController.loadFen(fen);

                    // 2. Resetta l'albero delle mosse partendo da qui
                    setState(() {
                      _rootNode = MoveNode(
                        fen: fen,
                        san: 'Posizione Importata',
                      );
                      _currentNode = _rootNode;
                      _arrowsNotifier.value = []; // Pulisce eventuali frecce
                    });

                    Navigator.pop(context); // Chiude il popup

                    // 3. Se il motore è acceso, analizza subito la nuova posizione!
                    if (_isEngineRunning && !_isPlayingMode) {
                      _startNormalAnalysis();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Errore: Formato FEN non valido!"),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
              ),
              child: const Text(
                "Importa",
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
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

  // --- 1. POPUP IMPOSTAZIONI SFIDA ---
  void _startPlayMode() {
    if (!_isEngineRunning) return;

    if (_selectedEngine == 'alexander') {
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
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text(
                        "Limita Forza",
                        style: TextStyle(fontSize: 14),
                      ),
                      value: _limitStrength,
                      onChanged: (v) => setPopupState(() => _limitStrength = v),
                    ),
                    if (_limitStrength) ...[
                      Text(
                        "Livello ELO: ${_eloValue.toInt()}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _eloValue,
                        min: 1000,
                        max: 2850,
                        divisions: 37,
                        label: _eloValue.toInt().toString(),
                        onChanged: (v) => setPopupState(() => _eloValue = v),
                      ),
                      SwitchListTile(
                        title: const Text(
                          "Simula Errori Umani",
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          "Attiva lo Skill Level per un gioco più naturale",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        value: _simulateBlunders,
                        onChanged: (v) =>
                            setPopupState(() => _simulateBlunders = v),
                      ),
                    ],
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
                      _executePlayModeStartup();
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
    } else {
      // ShashChess gioca sempre al massimo
      _engineManager.sendCommand(
        'setoption name UCI_LimitStrength value false',
      );
      _executePlayModeStartup();
    }
  }

  // --- 2. AVVIO DELLA PARTITA CONTRO IL MOTORE ---
  void _executePlayModeStartup() {
    _stopAllOrchestrators();

    if (_selectedEngine == 'alexander' && _limitStrength) {
      _engineManager.sendCommand('setoption name UCI_LimitStrength value true');
      _engineManager.sendCommand(
        'setoption name UCI_Elo value ${_eloValue.toInt()}',
      );
      if (_simulateBlunders) {
        _engineManager.sendCommand(
          'setoption name Skill Level value ${(_eloValue / 150).toInt()}',
        );
      } else {
        _engineManager.sendCommand('setoption name Skill Level value 20');
      }
    }

    setState(() {
      _isPlayingMode = true;
      _outputLines.clear();
      _arrowsNotifier.value = []; // Pulisce le frecce analitiche
    });

    _zoneNotifier.value = ShashinZone(
      "Modalità Gioco",
      "⚔️",
      Colors.orange,
      50.0,
      "assets/images/capablanca.png",
    );

    _playFsm = PlayOrchestrator(
      engineManager: _engineManager,
      boardController: _boardController,
      onLog: (line) {
        setState(() => _outputLines.add(line));
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      },
      onGameOver: (messaggio) {
        _showGameOverDialog(messaggio!);
      },
    );
    _playFsm!.startGame();

    // Se giochiamo col Nero, facciamo muovere subito il computer
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
                          if (opt['type'] == 'button')
                            return const SizedBox.shrink();

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

    setState(() => _isScanningThreat = true); // Attiva sicura

    _stopAllOrchestrators();
    _engineManager.sendCommand('stop');

    String currentFen = _boardController.getFen();
    List<String> fenParts = currentFen.split(' ');
    fenParts[1] = (fenParts[1] == 'w') ? 'b' : 'w'; // Inverte turno
    fenParts[3] = '-';
    String nullMoveFen = fenParts.join(' ');

    _engineManager.sendCommand('position fen $nullMoveFen');
    _engineManager.sendCommand('go movetime 1500');

    StreamSubscription<String>? threatSub;
    threatSub = _engineManager.engineOutput?.listen((line) {
      if (line.startsWith('bestmove')) {
        threatSub?.cancel();
        final parts = line.split(' ');
        if (parts.length > 1 && parts[1] != '(none)') {
          setState(() {
            _arrowsNotifier.value = [
              BoardArrow(
                from: parts[1].substring(0, 2),
                to: parts[1].substring(2, 4),
                color: Colors.red.withOpacity(0.8),
              ),
            ];
          });
          // Aspetta 3 secondi, poi torna all'analisi normale
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() => _isScanningThreat = false); // Disattiva sicura
              _startNormalAnalysis();
            }
          });
        }
      }
    });
  }

  // --- METODO PER L'ANALISI INCROCIATA (Doppie Frecce) ---
  void _startCrossedAnalysis() {
    if (!_isEngineRunning) return;

    _stopAllOrchestrators(); // Stoppa l'analisi normale

    // Pulizia visiva per preparare lo schermo
    setState(() {
      _outputLines.clear();
      _arrowsNotifier.value = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Inizio Analisi Incrociata (Maestro vs Allievo)..."),
        backgroundColor: Colors.orangeAccent,
        duration: Duration(seconds: 2),
      ),
    );

    // Diamo il comando esplicito di avvio al motore prima di lanciare l'orchestratore!
    _engineManager.sendCommand('stop');
    _engineManager.sendCommand('position fen ${_boardController.getFen()}');

    _crossedFsm = CrossedEvalOrchestrator(
      engineManager: _engineManager,
      onLog: (msg) {
        // Stampiamo i log dell'orchestratore a schermo per vedere che lavora!
        setState(() => _outputLines.add(msg));
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      },
      onReportReady: (studentMove, studentZone, masterMove, masterZone) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2b2b2b),
            title: const Text(
              "🔍 Verdetto Divergenze",
              style: TextStyle(color: Colors.cyanAccent),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Idea Allievo (Elo ${_eloValue.toInt()}):",
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  "Mossa: $studentMove [${studentZone.name}]",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Risposta Maestro (Depth 12):",
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  "Mossa: $masterMove [${masterZone.name}]",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startNormalAnalysis(); // Riavvia l'analisi normale chiudendo il popup
                },
                child: const Text(
                  "Chiudi",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );

    // Facciamo partire il loop
    _crossedFsm!.startCrossedEval(_boardController.getFen(), _eloValue.toInt());
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
