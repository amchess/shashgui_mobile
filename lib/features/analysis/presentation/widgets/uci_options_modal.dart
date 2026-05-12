import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ⚠️ Aggiunto
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/engine/engine_manager.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/engine_controller.dart'; // ⚠️ Aggiunto

// ⚠️ Trasformato in ConsumerStatefulWidget
class UciOptionsModal extends ConsumerStatefulWidget {
  final String engineName;
  const UciOptionsModal({super.key, required this.engineName});

  @override
  ConsumerState<UciOptionsModal> createState() => _UciOptionsModalState();
}

class _UciOptionsModalState extends ConsumerState<UciOptionsModal> {
  final EngineManager _probeManager = EngineManager();
  final List<Map<String, String>> _optionsMeta = [];
  final Map<String, String> _uciValues = {};
  bool _isLoading = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _probeOptions();
  }

  Future<void> _probeOptions() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      await _probeManager.initEngine(
        widget.engineName,
        [],
        onLine: (line) {
          if (line.trim().startsWith("option name")) {
            _parseUciOption(line);
          }
        },
      );
    } catch (e) {
      debugPrint("Errore Sonda UCI: $e");
    } finally {
      _probeManager.dispose();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _parseUciOption(String line) {
    line = line.replaceAll(RegExp(r'\s+'), ' ');
    if (!line.contains("option name ") || !line.contains(" type ")) return;

    int nameStart = line.indexOf("option name ") + 12;
    int nameEnd = line.indexOf(" type ");
    String name = line.substring(nameStart, nameEnd).trim();

    int typeStart = nameEnd + 6;
    int typeEnd = line.indexOf(" ", typeStart);
    if (typeEnd == -1) typeEnd = line.length;
    String type = line.substring(typeStart, typeEnd).trim();

    String def = "";
    if (line.contains(" default ")) {
      int defStart = line.indexOf(" default ") + 9;
      int defEnd = line.indexOf(" min ", defStart);
      if (defEnd == -1) defEnd = line.indexOf(" max ", defStart);
      if (defEnd == -1) defEnd = line.indexOf(" combo ", defStart);
      if (defEnd == -1) defEnd = line.length;
      def = line.substring(defStart, defEnd).trim();
    }

    if (!_optionsMeta.any((opt) => opt['name'] == name)) {
      if (mounted) {
        setState(() {
          _optionsMeta.add({'name': name, 'type': type});
          String savedValue =
              _prefs?.getString('${widget.engineName}_$name') ?? "";
          if (savedValue.isNotEmpty) {
            _uciValues[name] = savedValue;
          } else if (!_uciValues.containsKey(name) && def.isNotEmpty) {
            _uciValues[name] = def;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1e1e1e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "OPZIONI ${widget.engineName.toUpperCase()}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.orangeAccent,
                    ),
                  )
                : _optionsMeta.isEmpty
                ? Center(
                    child: Text(
                      loc.nessunaOpzioneTrovataOCaricame,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _optionsMeta.length,
                    itemBuilder: (context, index) {
                      final opt = _optionsMeta[index];
                      final name = opt['name']!;

                      if (opt['type'] == 'button') {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: TextFormField(
                          initialValue: _uciValues[name] ?? "",
                          decoration: InputDecoration(
                            labelText: name,
                            labelStyle: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 12,
                            ),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          onChanged: (v) {
                            _uciValues[name] = v;
                            _prefs?.setString('${widget.engineName}_$name', v);
                            // ⚠️ LA MAGIA: Applica l'opzione in tempo reale!
                            ref
                                .read(engineControllerProvider.notifier)
                                .setUciOption(name, v);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
