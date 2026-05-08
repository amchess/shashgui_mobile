// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'ShashGui';

  @override
  String get aboutDev => 'Sviluppatore: Andrea Manzo';

  @override
  String get aboutEngines =>
      'Motori Integrati: ShashChess (NNUE) & Alexander (HCE)';

  @override
  String get aboutDesc =>
      'Interfaccia grafica avanzata per l\'analisi posizionale a due fasi, l\'elaborazione di dati scacchistici e l\'estrazione di tratti dinamici.';

  @override
  String get closeBtn => 'CHIUDI';

  @override
  String get readManualBtn => 'LEGGI IL MANUALE UTENTE';
}
