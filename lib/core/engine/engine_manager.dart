import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class EngineManager {
  static const platform = MethodChannel('com.shashgui.engine/native');
  Process? _process;

  Stream<String>? get engineOutput => 
      _process?.stdout.transform(utf8.decoder).transform(const LineSplitter());

  Future<void> initEngine(String engineName, List<String> nnueFiles) async {
    print("Inizializzazione motore $engineName in corso...");

    final String libDir = await platform.invokeMethod('getNativeLibDir');
    final String enginePath = p.join(libDir, 'lib$engineName.so');

    final docDir = await getApplicationDocumentsDirectory();
    for (String nnue in nnueFiles) {
      final file = File(p.join(docDir.path, nnue));
      if (!await file.exists()) {
        print("Estrazione rete neurale: $nnue...");
        final byteData = await rootBundle.load('assets/engine/$nnue');
        await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      }
    }

    _process = await Process.start(enginePath, []);

    sendCommand('uci');
    
    if (nnueFiles.isNotEmpty) {
      sendCommand('setoption name EvalFile value ${p.join(docDir.path, nnueFiles[0])}');
    }
    if (nnueFiles.length > 1) {
      sendCommand('setoption name EvalFileSmall value ${p.join(docDir.path, nnueFiles[1])}');
    }
    
    sendCommand('setoption name Use NNUE value true');
    sendCommand('isready');
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
  }
}