import 'package:flutter/material.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const EngineTestScreen(),
    );
  }
}

class EngineTestScreen extends StatefulWidget {
  const EngineTestScreen({super.key});

  @override
  State<EngineTestScreen> createState() => _EngineTestScreenState();
}

class _EngineTestScreenState extends State<EngineTestScreen> {
  final EngineManager _engineManager = EngineManager();
  final List<String> _outputLines = [];
  bool _isEngineRunning = false;

  void _startEngine() async {
    setState(() {
      _outputLines.clear();
      _outputLines.add("Avvio procedura di test...");
    });

    try {
      // Sostituisci con i nomi ESATTI delle tue reti se sono diversi!
      await _engineManager.initEngine('shashchess', [
        'nn-c288c895ea92.nnue',
        'nn-37f18f62d772.nnue'
      ]);
      
      setState(() {
        _isEngineRunning = true;
      });

      // Ascolta l'output del motore e stampalo a schermo
      _engineManager.engineOutput?.listen((line) {
        setState(() {
          _outputLines.add(line);
        });
      });

      // Chiediamo al motore di presentarsi e valutare la posizione iniziale
      await Future.delayed(const Duration(milliseconds: 500));
      _engineManager.sendCommand('position startpos');
      _engineManager.sendCommand('go depth 10'); // Facciamo un calcolo veloce a profondità 10

    } catch (e) {
      setState(() {
        _outputLines.add("ERRORE FATALE: $e");
      });
    }
  }

  void _stopEngine() {
    _engineManager.dispose();
    setState(() {
      _isEngineRunning = false;
      _outputLines.add("--- MOTORE SPENTO ---");
    });
  }

  @override
  void dispose() {
    _engineManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test FFI - ShashChess'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isEngineRunning ? null : _startEngine,
                  icon: const Icon(Icons.power),
                  label: const Text('Accendi & Analizza'),
                ),
                ElevatedButton.icon(
                  onPressed: _isEngineRunning ? _stopEngine : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Spegni'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black87,
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                itemCount: _outputLines.length,
                itemBuilder: (context, index) {
                  return Text(
                    _outputLines[index],
                    style: const TextStyle(
                      color: Colors.greenAccent, 
                      fontFamily: 'monospace',
                      fontSize: 12,
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