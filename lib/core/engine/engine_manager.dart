import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:async';
import 'package:flutter/foundation.dart';

// Funzione top-level per isolare la scrittura NNUE in background
Future<void> _writeNnueFile(Map<String, dynamic> args) async {
  await File(
    args['path'] as String,
  ).writeAsBytes(args['bytes'] as Uint8List, flush: true);
}

class EngineManager {
  static const platform = MethodChannel('com.shashgui.engine/native');
  Process? _process;

  // Usiamo un Controller per mantenere viva la connessione!
  StreamController<String>? _outputController;
  Stream<String>? get engineOutput => _outputController?.stream;

  Future<void> initEngine(
    String engineName,
    List<String> nnueFiles, {
    Function(String)? onLine,
  }) async {
    print("Inizializzazione motore $engineName in corso...");
    final String libDir = await platform.invokeMethod('getNativeLibDir');
    final String enginePath = p.join(libDir, 'lib$engineName.so');

    final docDir = await getApplicationDocumentsDirectory();

    for (String nnue in nnueFiles) {
      final file = File(p.join(docDir.path, nnue));
      final byteData = await rootBundle.load('assets/engine/$nnue');

      // FIX ANTI-CORRUZIONE: Estrae la rete se non esiste o se il peso in byte è sbagliato!
      bool needsExtraction = !await file.exists();
      if (!needsExtraction) {
        final size = await file.length();
        if (size != byteData.lengthInBytes) {
          print("Rete $nnue corrotta ($size bytes). Re-estrazione forzata...");
          needsExtraction = true;
        }
      }

      if (needsExtraction) {
        print("Estrazione rete neurale: $nnue...");
        // compute() esegue la scrittura in un isolate separato, sbloccando la UI
        await compute(_writeNnueFile, {
          'path': file.path,
          'bytes': byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        });
      }
    }

    _process = await Process.start(enginePath, []);

    // Creiamo la stazione radio che non si spegne MAI (nemmeno a 0 ascoltatori)
    _outputController = StreamController<String>.broadcast();

    // Attacchiamo il motore alla stazione radio in modo permanente
    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          _outputController?.add(line);
        });

    final readyCompleter = Completer<void>();

    _outputController!.stream.listen((line) {
      onLine?.call(line);
      if (line.trim() == 'readyok' && !readyCompleter.isCompleted) {
        readyCompleter.complete();
      }
    });

    sendCommand('uci');
    if (nnueFiles.isNotEmpty) {
      sendCommand(
        'setoption name EvalFile value ${p.join(docDir.path, nnueFiles[0])}',
      );
    }
    if (nnueFiles.length > 1) {
      sendCommand(
        'setoption name EvalFileSmall value ${p.join(docDir.path, nnueFiles[1])}',
      );
    }

    sendCommand('isready');

    // Aspettiamo che il motore sia davvero pronto (timeout sicurezza 60s )
    await readyCompleter.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => debugPrint('⚠️ Timeout readyok'),
    );
  }

  void sendCommand(String command) {
    if (_process != null) {
      print("-> INVIATO: $command");
      _process!.stdin.writeln(command);
    }
  }

  void dispose() {
    sendCommand('quit');
    _process?.kill();
    _outputController?.close(); // Chiudiamo il controller correttamente
    _outputController = null;
  }
}
