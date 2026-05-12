import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider che conterrà l'istanza globale delle SharedPreferences
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPrefsProvider deve essere overridato nel main.dart',
  );
});
