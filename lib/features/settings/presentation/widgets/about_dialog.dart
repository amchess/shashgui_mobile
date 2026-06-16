import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'help_manual_screen.dart'; // ⚠️ Importiamo la schermata che abbiamo appena creato

void showShashGuiAboutDialog(BuildContext context) {
  final loc = AppLocalizations.of(context)!;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF2b2b2b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- LOGO ---
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orangeAccent, width: 2),
                image: const DecorationImage(
                  image: AssetImage('assets/images/icon.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 15),

            // --- TITOLO E SOTTOTITOLO ---
            Text(
              loc.shashgui,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
            Text(
              loc.beyondTheEval,
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.cyanAccent,
              ),
            ),
            const Divider(color: Colors.white24, height: 30),

            // --- INFO TESTUALI ---
            Text(
              loc.sviluppatoreAndreaManzo,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),

            // ⚠️ NUOVO: INDIRIZZO EMAIL CON ICONA E TESTO SELEZIONABILE
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email, color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                SelectableText(
                  "alphagambitlabs@gmail.com",
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              loc.motoriIntegratiShashchessNnueA,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 15),
            Text(
              loc.aboutDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // --- PULSANTE MANUALE UTENTE ---
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Chiude prima il popup "Info"
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpManualScreen()),
                );
              },
              icon: const Icon(Icons.menu_book),
              label: Text(loc.readManualBtn),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              loc.chiudi1,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}
