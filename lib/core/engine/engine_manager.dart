import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:async';
import 'package:flutter/foundation.dart';

Future<void> _writeNnueFile(Map<String, dynamic> args) async {
  await File(
    args['path'] as String,
  ).writeAsBytes(args['bytes'] as Uint8List, flush: true);
}

class EngineManager {
  static const platform = MethodChannel('com.shashgui.engine/native');
  Process? _process;
  bool _isDead = true;

  StreamController<String>? _outputController;
  Stream<String>? get engineOutput => _outputController?.stream;

  Future<void> initEngine(
    String engineName,
    List<String> nnueFiles, {
    Function(String)? onLine,
  }) async {
    debugPrint("Inizializzazione motore $engineName in corso...");
    final String libDir = await platform.invokeMethod('getNativeLibDir');
    final String enginePath = p.join(libDir, 'lib$engineName.so');

    final docDir = await getApplicationDocumentsDirectory();

    for (String nnue in nnueFiles) {
      final file = File(p.join(docDir.path, nnue));

      // ⚠️ IL FIX ANTI-ANR: Controlliamo SOLO se il file esiste!
      // Nessun caricamento massivo in RAM se la rete è già installata.
      bool needsExtraction = !await file.exists();

      if (needsExtraction) {
        debugPrint("Estrazione rete neurale: $nnue...");
        final byteData = await rootBundle.load('assets/engine/$nnue');
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
    _isDead = false;

    _process!.exitCode.then((code) {
      debugPrint(
        "💀 Motore $engineName terminato autonomamente (codice $code)",
      );
      _isDead = true;
    });

    _process!.stderr.listen((_) {});

    _outputController = StreamController<String>.broadcast();

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

    await readyCompleter.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint('⚠️ Timeout readyok: il motore non risponde.');
        throw TimeoutException('Il motore non ha risposto entro i limiti.');
      },
    );
  }

  void sendCommand(String command) {
    if (_process != null && !_isDead) {
      try {
        _process!.stdin.writeln(command);
      } catch (_) {}
    }
  }

  void dispose() {
    final processToKill = _process;
    _process = null;
    _isDead = true;

    if (processToKill != null) {
      Future.microtask(() {
        try {
          processToKill.kill();
        } catch (e) {
          debugPrint("Errore durante kill OS: $e");
        }
      });
    }

    try {
      _outputController?.close();
    } catch (_) {}
    _outputController = null;
  }
}
