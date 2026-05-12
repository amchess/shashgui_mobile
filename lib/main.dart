import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'features/navigation/presentation/main_navigation_screen.dart';
import 'core/services/shared_prefs_provider.dart';

final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('it'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('language') ?? 'it';
  appLocale.value = Locale(savedLang);

  runApp(
    ProviderScope(
      overrides: [
        // ⚠️ MAGIA RIVERPOD: Iniettiamo le prefs caricate in tutta l'app!
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const ShashGuiApp(),
    ),
  );
}

class ShashGuiApp extends StatelessWidget {
  const ShashGuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, child) {
        return MaterialApp(
          title: 'ShashGui',
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2b2b2b),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),

          // 2. SOSTITUISCI LA HOME CON LA NUOVA SCHERMATA:
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}
