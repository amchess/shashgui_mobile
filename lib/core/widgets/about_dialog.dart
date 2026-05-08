import 'package:flutter/material.dart';

void showShashGuiAboutDialog(BuildContext context) {
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
            const Text(
              "ShashGUI",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
            const Text(
              "Beyond the eval",
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.cyanAccent,
              ),
            ),
            const Divider(color: Colors.white24, height: 30),

            // --- INFO TESTUALI ---
            const Text(
              "Sviluppatore: Andrea Manzo",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Motori Integrati: ShashChess (NNUE) & Alexander (HCE)",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 15),
            const Text(
              "Interfaccia grafica avanzata per l'analisi posizionale a due fasi, l'elaborazione di dati scacchistici e l'estrazione di tratti dinamici.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "CHIUDI",
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
