import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
            Text(
              loc.beyondTheEval,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.cyanAccent,
              ),
            ),
            const Divider(color: Colors.white24, height: 30),

            // --- INFO TESTUALI ---
            Text(
              loc.sviluppatoreAndreaManzo,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              loc.motoriIntegratiShashchessNnueA,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 15),
            Text(
              // <-- Niente "const" qui!
              loc.aboutDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              loc.chiudi1,
              style: TextStyle(
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
