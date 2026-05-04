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

  // Memoria del tempo iniziale T1 per il loop infinito
  int _baseTimeSec = 2;

  // --- NUOVE VARIABILI PER IL MOTORE DINAMICO ---
  String _selectedEngine = 'shashchess';
  final Map<String, String> _uciValues = {'Threads': '2', 'Hash': '128'};
  // --- PARAMETRI HANDICAP PER ALEXANDER ---
  bool _limitStrength = false;
  double _eloValue = 1500;
  bool _simulateBlunders = false; // Per i parametri "Human-like"
  final List<Map<String, String>> _engineOptionsMetadata = [];
  bool _isLoadingOptions = false;

  SharedPreferences? _prefs; // <-- La nostra "memoria"

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMemoryAndProbe(); // <-- Chiamiamo la nuova funzione
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

  List<BoardArrow> _currentArrows = [];

  // <-- VARIABILE AGGIUNTA PER I DATI DEL MOTORE -->
  EngineStats _currentStats = EngineStats();

  ShashinZone _currentZone = ShashinZone(
    "In attesa...",
    "-",
    Colors.grey,
    50.0,
    "assets/images/capablanca.png",
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
    setState(() {
      _currentArrows.clear();
      _currentStats = EngineStats(); // <-- AZZERA LE STATISTICHE ALLO STOP
    });
  }

  void _startNormalAnalysis() {
    if (!_isEngineRunning) return;
    _stopAllOrchestrators();

    _fsm = ShashinFsm(
      engineManager: _engineManager,
      onLog: (line) {
        setState(() => _outputLines.add(line));
        _scrollToBottom();
      },
      onZoneChanged: (zone) => setState(() => _currentZone = zone),
      onStateChanged: (state) {},
      onPvUpdate: (move) {
        setState(() {
          String fromSq = move.substring(0, 2);
          String toSq = move.substring(2, 4);
          _currentArrows = [
            BoardArrow(
              from: fromSq,
              to: toSq,
              color: _currentZone.color.withValues(alpha: 0.8),
            ),
          ];
        });
      },
      // <-- IL CALLBACK CHE AGGIORNA I DATI SULLA UI -->
      onStatsUpdate: (stats) {
        setState(() {
          _currentStats = stats;
        });
      },
      // <-- NUOVO: Invia alla UI le opzioni UCI scoperte
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
        setState(() => _outputLines.add(line));
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
      _currentZone = ShashinZone(
        "Modalità Gioco",
        "⚔️",
        Colors.orange,
        50.0,
        "🎮",
      );
    });

    _playFsm = PlayOrchestrator(
      engineManager: _engineManager,
      boardController: _boardController,
      onLog: (line) {
        setState(() => _outputLines.add(line));
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      },
      onStateChanged: (state) {},
    );
    _playFsm!.startGame();
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
      _currentZone = ShashinZone(
        "Motore Spento",
        "-",
        Colors.grey,
        50.0,
        "assets/images/capablanca.png",
      );
      _outputLines.add("--- MOTORE SPENTO ---");
    });
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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ChessBoard(
                  controller: _boardController,
                  boardColor: BoardColor.brown,
                  boardOrientation: PlayerColor.white,
                  arrows: _currentArrows,
                  onMove: () {
                    if (_isPlayingMode) {
                      _playFsm?.onUserMoved();
                    } else {
                      _startNormalAnalysis();
                    }
                  },
                ),
              ),
            ),
          ),

          // 2. BARRA DELLA WIN PROBABILITY (WP) E AVATAR
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "🛡️ Petrosian",
                      style: TextStyle(color: Colors.red[300], fontSize: 12),
                    ),
                    Text(
                      "${_currentZone.wp.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "Tal 🔥",
                      style: TextStyle(color: Colors.green[300], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _currentZone.wp / 100.0,
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
                        _currentZone.avatar,
                        errorBuilder: (context, error, stackTrace) =>
                            const Text("👤", style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "${_currentZone.symbol} ${_currentZone.name.toUpperCase()}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _currentZone.color,
                      ),
                    ),
                  ],
                ),
              ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statText(
                        "Profondità",
                        "${_currentStats.depth}/${_currentStats.selDepth}",
                      ),
                      _statText(
                        "Nodi",
                        "${(_currentStats.nodes / 1000).toStringAsFixed(1)}k",
                      ),
                      _statText(
                        "Velocità (NPS)",
                        "${(_currentStats.nps / 1000).toStringAsFixed(1)}k",
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
                          _currentStats.pv.isEmpty ? "..." : _currentStats.pv,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                          maxLines:
                              2, // Limita a 2 righe per non invadere troppo lo schermo
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // 4. FINESTRA DI NOTAZIONE E CONTROLLI PGN/FEN
          Container(
            height: 60,
            width: double.infinity,
            margin: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.orangeAccent),
                  onPressed: () {
                    _boardController.undoMove();
                    _startNormalAnalysis();
                  },
                ),
                const VerticalDivider(color: Colors.grey),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: _boardController,
                    builder: (context, value, child) {
                      String history = _boardController.game.san_moves().join(
                        " ",
                      );
                      if (history.isEmpty) history = "Nessuna mossa giocata.";
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(
                          history,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const VerticalDivider(color: Colors.grey),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: "Stampa FEN in console",
                  onPressed: () {
                    debugPrint("FEN Corrente: ${_boardController.getFen()}");
                  },
                ),
              ],
            ),
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
                          if (val == null)
                            return; // Sicurezza extra: se è nullo, fermati
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
            itemBuilder: (context, index) {
              final opt = _engineOptionsMetadata[index];
              final name = opt['name']!;

              // Saltiamo opzioni di tipo "button" (che in UCI sono solo comandi eseguibili)
              if (opt['type'] == 'button') return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: name,
                    labelStyle: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  // Se il valore è null mettiamo una stringa vuota per non far crashare il controller
                  controller: TextEditingController(
                    text: _uciValues[name] ?? "",
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (v) {
                    _uciValues[name] = v;
                    // Salva sul telefono (aggiungiamo il prefisso del motore per non mischiare i parametri)
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
