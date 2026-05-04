import 'core/logic/shashin_logic.dart';
import 'core/orchestrators/shashin_fsm.dart';
import 'core/orchestrators/crossed_eval.dart';
import 'core/orchestrators/play_orchestrator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'core/engine/engine_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // --- NUOVE VARIABILI PER NAVIGAZIONE E ORIENTAMENTO ---
  PlayerColor _boardOrientation = PlayerColor.white; // Bianco o Nero in basso
  late MoveNode _rootNode;
  late MoveNode _currentNode;

  // Memoria del tempo iniziale T1 per il loop infinito
  int _baseTimeSec = 2;

  // --- VARIABILI REINSERITE ---
  SharedPreferences? _prefs;
  String _selectedEngine = 'shashchess';
  bool _isLoadingOptions = false;
  final List<Map<String, String>> _engineOptionsMetadata = [];
  final Map<String, String> _uciValues = {'Threads': '2', 'Hash': '128'};

  // Variabili per l'handicap (Modalità Gioco)
  bool _limitStrength = false;
  double _eloValue = 1500;
  bool _simulateBlunders = false;

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
  final ValueNotifier<List<BoardArrow>> _arrowsNotifier = ValueNotifier([]);
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
      // Le opzioni le abbiamo già catturate con la Sonda, quindi avviamo e basta!
      await _engineManager.initEngine(_selectedEngine, [
        'nn-c288c895ea92.nnue',
        'nn-37f18f62d772.nnue',
      ]);

      await Future.delayed(const Duration(milliseconds: 300));

      // Inviamo i parametri personalizzati
      _uciValues.forEach((name, value) {
        _engineManager.sendCommand('setoption name $name value $value');
      });

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
    // Aggiorniamo i notifier in modo ultra-fluido, niente setState!
    _arrowsNotifier.value = [];
    _statsNotifier.value = EngineStats();
  }

  void _startNormalAnalysis() {
    if (!_isEngineRunning) return;
    _stopAllOrchestrators();

    _fsm = ShashinFsm(
      engineManager: _engineManager,
      onLog: (line) {
        // <-- Tolto l'if
        setState(() => _outputLines.add(line));
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      },
      onZoneChanged: (zone) {
        _zoneNotifier.value = zone;
      },
      onStateChanged: (state) {},
      onPvUpdate: (firstMove) {
        // 1. Se stiamo toccando lo schermo, IGNORIAMO gli aggiornamenti per non rompere il drag!
        if (_isDragging || firstMove.length < 4) return;

        String fromSq = firstMove.substring(0, 2);
        String toSq = firstMove.substring(2, 4);

        // 2. Aggiorniamo la UI SOLO se la freccia è diversa da quella di prima
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
            color: _zoneNotifier.value.color.withValues(alpha: 0.8),
          ),
        ];
      },
      onStatsUpdate: (stats) {
        _statsNotifier.value = stats;
      },
      onOptionFound: (optionLine) => _parseUciOption(optionLine),
    );

    // Invia i secondi selezionati all'FSM per il ciclo ricorsivo
    _fsm!.startAnalysis(
      _boardController.getFen(),
      baseTimeMs: _baseTimeSec * 1000,
    );
  }

  void _startCrossedAnalysis() {
    if (!_isEngineRunning) return;
    _stopAllOrchestrators();

    _crossedFsm = CrossedEvalOrchestrator(
      engineManager: _engineManager,
      onLog: (line) {
        setState(() {
          _outputLines.add(line);
          // MANTIENE SOLO LE ULTIME 100 RIGHE
          if (_outputLines.length > 100) {
            _outputLines.removeAt(0);
          }
        });
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      },
      onReportReady: (sMove, sZone, mMove, mZone) =>
          _showCrossedEvalReport(sMove, sZone, mMove, mZone),
    );
    _crossedFsm!.startCrossedEval(_boardController.getFen(), 1200);
  }

  // 1. IL POPUP DI HANDICAP (Intercetta il click sul tasto Gioca)
  void _startPlayMode() {
    if (!_isEngineRunning) return;

    if (_selectedEngine == 'alexander') {
      showDialog(
        context: context,
        builder: (context) {
          // StatefulBuilder ci serve per far muovere il pallino dello slider dentro il popup
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
                        divisions: 37, // Scatti da 50 Elo
                        label: _eloValue.toInt().toString(),
                        onChanged: (v) => setPopupState(() => _eloValue = v),
                      ),
                      SwitchListTile(
                        title: const Text(
                          "Simula Errori Umani",
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          "Attiva lo Skill Level per non farlo giocare 'da computer'",
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
                      Navigator.pop(context); // Chiude il popup
                      _executePlayModeStartup(); // Avvia davvero la partita
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
      // Se è ShashChess non ha pietà, resetta l'handicap e parte subito!
      _engineManager.sendCommand(
        'setoption name UCI_LimitStrength value false',
      );
      _executePlayModeStartup();
    }
  }

  // 2. L'AVVIO VERO E PROPRIO (Contiene la tua vecchia logica + l'invio comandi)

  void _executePlayModeStartup() {
    _stopAllOrchestrators();

    // INVIO COMANDI HANDICAP AL MOTORE
    if (_selectedEngine == 'alexander' && _limitStrength) {
      _engineManager.sendCommand('setoption name UCI_LimitStrength value true');
      _engineManager.sendCommand(
        'setoption name UCI_Elo value ${_eloValue.toInt()}',
      );
      if (_simulateBlunders) {
        // Parametriamo brutalmente lo Skill Level in base all'Elo
        _engineManager.sendCommand(
          'setoption name Skill Level value ${(_eloValue / 150).toInt()}',
        );
      } else {
        _engineManager.sendCommand('setoption name Skill Level value 20');
      }
    }

    setState(() {
      _isPlayingMode = true;
    });
    // Aggiorniamo la zona usando il Notifier, fuori dal setState!
    _zoneNotifier.value = ShashinZone(
      "Modalità Gioco",
      "⚔️",
      Colors.orange,
      50.0,
      "🎮",
    );

    _playFsm = PlayOrchestrator(
      engineManager: _engineManager,
      boardController: _boardController,
      onLog: (line) {
        setState(() => _outputLines.add(line));
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      },
      onGameOver: (messaggio) {
        _showGameOverDialog(messaggio!); // Mostra il popup di fine partita
      },
    );
    _playFsm!.startGame();

    // <-- NUOVO: LOGICA PER GIOCARE COL NERO -->
    // Se hai girato la scacchiera (Nero in basso) e il FEN dice che tocca al Bianco (" w "),
    // forziamo il motore a eseguire la primissima mossa del Bianco!
    if (_boardOrientation == PlayerColor.black &&
        _boardController.getFen().contains(" w ")) {
      _playFsm?.playCycle();
    }
  }

  void _showCrossedEvalReport(
    String sMove,
    ShashinZone sZone,
    String mMove,
    ShashinZone mZone,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isMatch = sZone.name == mZone.name;
        return AlertDialog(
          backgroundColor: const Color(0xFF2b2b2b),
          title: const Row(
            children: [
              Icon(Icons.school, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text(
                "Verdetto del Maestro",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "🧑‍🎓 L'idea dell'Allievo:",
                style: TextStyle(color: Colors.grey[400]),
              ),
              Text(
                "Mossa: $sMove",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                "Porta in Zona: ${sZone.name} ${sZone.symbol}",
                style: TextStyle(
                  color: sZone.color,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(color: Colors.grey),
              ),

              Text(
                "🧙‍♂️ L'idea del Maestro:",
                style: TextStyle(color: Colors.grey[400]),
              ),
              Text(
                "Mossa: $mMove",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                "Porta in Zona: ${mZone.name} ${mZone.symbol}",
                style: TextStyle(
                  color: mZone.color,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isMatch
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isMatch ? Colors.green : Colors.orange,
                  ),
                ),
                child: Text(
                  isMatch
                      ? "✅ Eccellente! Il piano dell'Allievo mantiene la tensione termodinamica corretta."
                      : "❌ Attenzione! L'idea dell'Allievo cambia radicalmente la natura della posizione rispetto al piano ideale.",
                  style: TextStyle(
                    color: isMatch ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startNormalAnalysis();
              },
              child: const Text("Ho capito"),
            ),
          ],
        );
      },
    );
  }

  void _stopEngine() {
    _stopAllOrchestrators();
    _engineManager.dispose();

    setState(() {
      _isEngineRunning = false;
      _outputLines.add("--- MOTORE SPENTO ---");
    });

    // Aggiorniamo la zona usando il Notifier!
    _zoneNotifier.value = ShashinZone(
      "Motore Spento",
      "-",
      Colors.grey,
      50.0,
      "assets/images/capablanca.png",
    );

    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
  }

  @override
  void dispose() {
    _stopAllOrchestrators();
    _engineManager.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // <-- FUNZIONE HELPER PER IL TESTO DEL CRUSCOTTO -->
  Widget _statText(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
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
          // 1. SCACCHIERA
          Expanded(
            flex: 5,
            child: Column(
              // Avvolgiamo in una colonna per mettere i tasti sotto
              children: [
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
                              boardOrientation: _boardOrientation, // DINAMICO
                              arrows: arrows,
                              onMove: _onMovePerformed, // USA LA NUOVA LOGICA
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                // Barra di navigazione esistente
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
                        onPressed: () => setState(() {
                          _boardOrientation =
                              (_boardOrientation == PlayerColor.white)
                              ? PlayerColor.black
                              : PlayerColor.white;
                        }),
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
          // Qui sotto di solito iniziano le statistiche del motore...
          // 2. BARRA DELLA WIN PROBABILITY (WP) E AVATAR
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
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
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          "${zone.wp.toStringAsFixed(1)}%",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "Tal 🔥",
                          style: TextStyle(
                            color: Colors.green[300],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: zone.wp / 100.0,
                        minHeight: 12,
                        backgroundColor: Colors.red[700],
                        color: Colors.green[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.transparent,
                          child: Image.asset(
                            zone.avatar,
                            errorBuilder: (context, error, stackTrace) =>
                                const Text(
                                  "👤",
                                  style: TextStyle(fontSize: 24),
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${zone.symbol} ${zone.name.toUpperCase()}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: zone.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // <-- 3. IL CRUSCOTTO DEL MOTORE (Ora con la PV!) -->
          if (_isEngineRunning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: ValueListenableBuilder<EngineStats>(
                valueListenable: _statsNotifier,
                builder: (context, stats, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statText(
                            "Profondità",
                            "${stats.depth}/${stats.selDepth}",
                          ),
                          _statText(
                            "Nodi",
                            "${(stats.nodes / 1000).toStringAsFixed(1)}k",
                          ),
                          _statText(
                            "Velocità (NPS)",
                            "${(stats.nps / 1000).toStringAsFixed(1)}k",
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "PV: ",
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              stats.pv.isEmpty ? "..." : stats.pv,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          // 4. FINESTRA DI NOTAZIONE (NUOVA CON VARIANTI)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
            child:
                _buildNotationPanel(), // <-- CHIAMIAMO FINALMENTE IL NUOVO PANNELLO!
          ),
          // 5. PULSANTI ESTESI CON ICONE E SELETTORE TEMPO
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!_isEngineRunning) ...[
                  // 1. SELETTORE MOTORE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedEngine,
                        items: ['shashchess', 'alexander'].map((String engine) {
                          return DropdownMenuItem(
                            value: engine,
                            child: Text(engine),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) {
                            return;
                          } // Aggiunte graffe
                          setState(() => _selectedEngine = val);
                          _prefs?.setString(
                            'selectedEngine',
                            val,
                          ); // Ora val è 100% sicuro!
                          _probeEngineOptions();
                        },
                      ),
                    ),
                  ),

                  // 2. INGRANAGGIO DINAMICO (Mostra lo spinner se sta caricando)
                  _isLoadingOptions
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _showUciSettings,
                          icon: const Icon(
                            Icons.settings,
                            color: Colors.orangeAccent,
                          ),
                          tooltip: "Parametri UCI",
                        ),

                  // 3. TASTO ACCENDI (Disabilitato finché la sonda non ha finito)
                  ElevatedButton.icon(
                    onPressed: _isLoadingOptions ? null : _startEngine,
                    icon: const Icon(Icons.power, size: 18),
                    label: const Text(
                      'Accendi',
                      style: TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1e1e1e),
                      border: Border.all(color: Colors.grey[700]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "T1: ",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        DropdownButton<int>(
                          value: _baseTimeSec,
                          dropdownColor: const Color(0xFF2b2b2b),
                          underline: const SizedBox(),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                            size: 16,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          items: [1, 2, 3, 5, 10].map((int val) {
                            return DropdownMenuItem<int>(
                              value: val,
                              child: Text("${val}s"),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _baseTimeSec = val;
                              });
                              _startNormalAnalysis();
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: _startNormalAnalysis,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text(
                      'Analizza',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _startCrossedAnalysis,
                    icon: const Icon(Icons.school, size: 16),
                    label: const Text(
                      'Cross Eval',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _startPlayMode,
                    icon: const Icon(Icons.videogame_asset, size: 16),
                    label: const Text('Gioca', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _stopEngine,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Icon(Icons.stop),
                  ),
                ],
              ],
            ),
          ),

          // 6. TERMINALE ESTESO
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF111111),
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _outputLines.length,
                itemBuilder: (context, index) {
                  return Text(
                    _outputLines[index],
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  );
                },
              ),
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

  void _showUciSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Opzioni $_selectedEngine"),
        backgroundColor: const Color(0xFF2b2b2b),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _engineOptionsMetadata.length,
            // USA QUESTA LOGICA PIÙ LEGGERA
            itemBuilder: (context, index) {
              final opt = _engineOptionsMetadata[index];
              final name = opt['name']!;
              if (opt['type'] == 'button') return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: TextFormField(
                  // TextFormField è più efficiente di TextField in liste
                  initialValue: _uciValues[name] ?? "",
                  decoration: InputDecoration(
                    labelText: name,
                    labelStyle: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (v) {
                    _uciValues[name] = v;
                    _prefs?.setString('${_selectedEngine}_$name', v);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CHIUDI"),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog(String messaggio) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Fine Partita"),
        content: Text(messaggio),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopAllOrchestrators(); // Ora riconosce questo comando!
              setState(() => _isPlayingMode = false);
            },
            child: const Text("TORNA AL LABORATORIO"),
          ),
        ],
      ),
    );
  }

  // Questa funzione gestisce la creazione di varianti e la cattura della notazione
  Future<void> _onMovePerformed() async {
    _isDragging = false;

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

    String newFen = _boardController.getFen();

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
    if (_isPlayingMode) {
      _playFsm?.playCycle();
    } else if (_isEngineRunning) {
      _startNormalAnalysis();
    }
  }

  Widget _buildNotationPanel() {
    List<Widget> widgets = [];

    // Funzione interna che attraversa l'albero per costruire la vista
    void buildNotation(MoveNode node, int moveCount) {
      if (node.children.isEmpty) return;

      // La linea principale è il primo figlio (indice 0)
      var mainMove = node.children.first;
      bool isCurrent = (mainMove == _currentNode);

      // Aggiungiamo il numero di mossa (solo se tocca al bianco)
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

      // --- QUI GESTIAMO LE VARIANTI ---
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

      // Continua ricorsivamente sulla linea principale
      buildNotation(mainMove, moveCount + 1);
    }

    buildNotation(_rootNode, 1);

    return Container(
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
