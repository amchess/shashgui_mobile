import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ImportExportService {
  // Ritorna il contenuto del file sotto forma di stringa
  Future<String?> pickAndReadFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pgn', 'epd', 'fen', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        return await file.readAsString();
      }
    } catch (e) {
      throw Exception("Errore nell'apertura del file: $e");
    }
    return null;
  }

  Future<String> fetchLichessGame(String url) async {
    final cleanUrl = url.trim().split('#').first.split('?').first;

    // --- BROADCAST ---
    if (cleanUrl.contains('/broadcast/')) {
      final uri = Uri.parse(cleanUrl);
      final pathSegments = uri.pathSegments;
      final lastSegment = pathSegments.last;

      // Tentativo 1: endpoint sperimentale (se mai funzionerà)
      final testUrl = "$cleanUrl.pgn";
      var response = await http.get(Uri.parse(testUrl));
      if (response.statusCode == 200 && response.body.contains('[Event')) {
        return response.body;
      }

      // Tentativo 2: estrarre l'ID del round e scaricare tutto il round
      // Pattern: .../round-1/{roundId}/{gameId}
      final roundIndex = pathSegments.indexWhere((s) => s.startsWith('round-'));
      if (roundIndex != -1 && roundIndex + 1 < pathSegments.length) {
        final roundId = pathSegments[roundIndex + 1];
        final roundUrl = "https://lichess.org/api/broadcast/round/$roundId.pgn";
        response = await http.get(Uri.parse(roundUrl));
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          // Normalizza i newline (Windows -> Unix) per facilitare il parsing
          String normalizedPgn = response.body.replaceAll('\r\n', '\n');
          // Estrai la partita specifica dal PGN del round
          final gamePgn = _extractGameFromPgn(normalizedPgn, lastSegment);
          if (gamePgn != null) return gamePgn;
        }
      }

      // Se nessun tentativo ha funzionato
      throw Exception('Broadcast game not found: $lastSegment');
    }

    // --- PARTITE STANDARD ---
    String gameId = cleanUrl.split('/').last;
    if (gameId.length == 12) gameId = gameId.substring(0, 8);
    final standardUrl =
        "https://lichess.org/game/export/$gameId?clocks=false&evals=false&tags=true";
    final response = await http.get(Uri.parse(standardUrl));

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      return response.body;
    } else {
      throw Exception(
        'Standard game not found. Status: ${response.statusCode}',
      );
    }
  }

  // Helper per estrarre una partita dal PGN completo del round
  String? _extractGameFromPgn(String fullPgn, String gameId) {
    // ⚠️ FIX: Usa una Lookahead Regex. Taglia il testo ESATTAMENTE prima di ogni
    // "[Event " senza rompere i doppi a capo interni alle mosse.
    final games = fullPgn.split(RegExp(r'\n*(?=\[Event )'));

    for (final game in games) {
      if (game.contains(gameId)) {
        return game.trim();
      }
    }
    return null;
  }
}
