import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:async';
import 'package:flutter/foundation.dart';

class EngineManager {
  static const platform = MethodChannel('com.shashgui.engine/native');
  Process? _process;

  // --- FIX: Salviamo il flusso broadcast in una variabile ---
  Stream<String>? _broadcastOutput;

  // Il getter ora restituisce semplicemente la "Radio" già sintonizzata
  Stream<String>? get engineOutput => _broadcastOutput;

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
        await file.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
          flush: true, // Assicura che la scrittura sul disco sia completata
        );
      }
    }

    _process = await Process.start(enginePath, []);
    // --- FIX CRITICO: Trasformiamo lo stdout in Broadcast UNA SOLA VOLTA ---
    _broadcastOutput = _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();

    final readyCompleter = Completer<void>();

    _broadcastOutput!.listen((line) {
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

    // Aspettiamo che il motore sia davvero pronto (timeout sicurezza 10s)
    await readyCompleter.future.timeout(
      const Duration(seconds: 10),
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
    _broadcastOutput = null; // Pulizia
  }
}
