import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../analysis/presentation/analysis_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../play/presentation/play_screen.dart';

// Un widget segnaposto elegante per le funzionalità in arrivo
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // SPOSTATO QUI DENTRO PER POTER USARE "loc" NEL PLACEHOLDER!
    final List<Widget> screens = [
      const AnalysisScreen(),
      const PlayScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF151515),
        selectedItemColor: Colors.orangeAccent,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        // RIMOSSO IL "const" CHE BLOCCAVA IL CAMBIO LINGUA!
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.science),
            label: loc.laboratorio,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.sports_esports),
            label: loc.gioca,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: loc.impostazioni, // <-- USA IL NUOVO LOC
          ),
        ],
      ),
    );
  }
}
