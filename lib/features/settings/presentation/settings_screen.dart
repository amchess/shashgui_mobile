import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../main.dart';
import '../../../../l10n/app_localizations.dart';
import 'widgets/about_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.impostazioni),
        backgroundColor: const Color(0xFF1e1e1e),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. CAMBIO LINGUA
          ListTile(
            leading: const Icon(Icons.language, color: Colors.blueAccent),
            title: Text(
              loc.cambiaLingua,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: DropdownButton<String>(
              value: appLocale.value.languageCode,
              dropdownColor: const Color(0xFF2b2b2b),
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'it', child: Text("🇮🇹 Italiano")),
                DropdownMenuItem(value: 'en', child: Text("🇬🇧 English")),
              ],
              onChanged: (String? newLang) async {
                if (newLang != null) {
                  // Cambia lingua istantaneamente
                  appLocale.value = Locale(newLang);
                  // Salva la scelta in memoria
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('language', newLang);
                }
              },
            ),
          ),
          const Divider(color: Colors.white24),

          // 2. INFORMAZIONI APP
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.greenAccent),
            title: Text(
              loc.informazioniSuShashGui,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => showShashGuiAboutDialog(context),
          ),
          const Divider(color: Colors.white24),

          // 3. VETRINA PREMIUM (Estetica)
          Container(
            margin: const EdgeInsets.only(top: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[800]!, Colors.deepOrange[900]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  loc.shashguiPremium,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.ilPotereDeiServerCloud,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    loc.sbloccaIlCloud999mese,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
