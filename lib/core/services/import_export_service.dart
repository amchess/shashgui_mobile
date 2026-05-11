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

  // Ritorna il PGN scaricato da Lichess
  Future<String> fetchLichessGame(String url) async {
    String id = url.split('/').last;
    if (id.contains('#')) id = id.split('#').first;

    final response = await http.get(
      Uri.parse(
        "https://lichess.org/game/export/$id?clocks=false&evals=false&tags=true",
      ),
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("Errore Lichess (Status: ${response.statusCode})");
    }
  }
}
