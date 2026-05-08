// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ShashGui';

  @override
  String get aboutDev => 'Developer: Andrea Manzo';

  @override
  String get aboutEngines =>
      'Integrated Engines: ShashChess (NNUE) & Alexander (HCE)';

  @override
  String get aboutDesc =>
      'Advanced graphical interface for two-phase positional analysis, chess data processing, and dynamic trait extraction.';

  @override
  String get closeBtn => 'CLOSE';

  @override
  String get readManualBtn => 'READ USER MANUAL';
}
