import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart'; // ⚠️ Importa appLocale dal main

class HelpManualScreen extends StatelessWidget {
  const HelpManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // ⚠️ LA MAGIA: Legge la lingua ESATTA attualmente forzata dalla tua App!
    final langCode = appLocale.value.languageCode;
    final helpFile = 'assets/help/help_$langCode.html';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.appTitle),
        backgroundColor: const Color(0xFF1e1e1e),
      ),
      backgroundColor: const Color(0xFF1e1e1e),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(helpFile).catchError((_) {
          // Fallback di sicurezza all'inglese se manca il file
          return rootBundle.loadString('assets/help/help_en.html');
        }),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HtmlWidget(
                snapshot.data!,
                textStyle: const TextStyle(
                  color: Color(0xFFd4d4d4),
                  fontSize: 14,
                ),
                customStylesBuilder: (element) {
                  if (element.localName == 'h1') return {'color': '#f1c40f'};
                  if (element.localName == 'h2') return {'color': '#4ea8de'};
                  if (element.localName == 'h3') return {'color': '#2ecc71'};
                  return null;
                },
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Errore caricamento manuale: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          return const Center(
            child: CircularProgressIndicator(color: Colors.orangeAccent),
          );
        },
      ),
    );
  }
}
