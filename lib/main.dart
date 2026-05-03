import 'core/logic/shashin_logic.dart';
import 'core/orchestrators/shashin_fsm.dart';
import 'core/orchestrators/crossed_eval.dart';
import 'core/orchestrators/play_orchestrator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'core/engine/engine_manager.dart';

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

// --- IL TUO ENGINE TEST SCREEN (ESTESO E COMPLETO) ---
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
  final ScrollController _scrollController = ScrollController();

  bool _isEngineRunning = false;
  bool _isPlayingMode = false;

  ShashinZone _currentZone = ShashinZone("In attesa...", "-", Colors.grey);

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
      _outputLines.add("Accensione motore ShashChess...");
    });

    try {
      await _engineManager.initEngine('shashchess', [
        'nn-c288c895ea92.nnue',
        'nn-37f18f62d772.nnue',
      ]);

      setState(() {
        _isEngineRunning = true;
      });

      await Future.delayed(const Duration(milliseconds: 500));
      _startNormalAnalysis();
    } catch (e) {
      setState(() {
        _outputLines.add("ERRORE FATALE: $e");
      });
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
  }

  void _startNormalAnalysis() {
    if (!_isEngineRunning) return;
    _stopAllOrchestrators();

    _fsm = ShashinFsm(
      engineManager: _engineManager,
      onLog: (line) {
        setState(() {
          _outputLines.add(line);
        });
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      },
      onZoneChanged: (zone) {
        setState(() {
          _currentZone = zone;
        });
      },
      onStateChanged: (state) {},
    );

    _fsm!.startAnalysis(_boardController.getFen());
  }

  void _startCrossedAnalysis() {
    if (!_isEngineRunning) return;
    _stopAllOrchestrators();

    _crossedFsm = CrossedEvalOrchestrator(
      engineManager: _engineManager,
      onLog: (line) {
        setState(() {
          _outputLines.add(line);
        });
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      },
      onReportReady: (studentMove, studentZone, masterMove, masterZone) {
        _showCrossedEvalReport(
          studentMove,
          studentZone,
          masterMove,
          masterZone,
        );
      },
    );

    int simulatedElo = 1200;
    _crossedFsm!.startCrossedEval(_boardController.getFen(), simulatedElo);
  }

  void _startPlayMode() {
    if (!_isEngineRunning) return;
    _stopAllOrchestrators();

    setState(() {
      _isPlayingMode = true;
      _currentZone = ShashinZone("Modalità Gioco", "⚔️", Colors.orange);
    });

    _playFsm = PlayOrchestrator(
      engineManager: _engineManager,
      boardController: _boardController,
      onLog: (line) {
        setState(() {
          _outputLines.add(line);
        });
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
      _currentZone = ShashinZone("Motore Spento", "-", Colors.grey);
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

          // 2. TERMOMETRO SHASHIN
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: _currentZone.color.withValues(alpha: 0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentZone.symbol,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _currentZone.color,
                  ),
                ),
                const SizedBox(width: 15),
                Text(
                  _currentZone.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _currentZone.color,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // 3. PULSANTI ESTESI CON ICONE
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: [
                if (!_isEngineRunning)
                  ElevatedButton.icon(
                    onPressed: _startEngine,
                    icon: const Icon(Icons.power, size: 18),
                    label: const Text(
                      'Accendi',
                      style: TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  )
                else ...[
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

          // 4. TERMINALE ESTESO
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
