import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @laboratorio.
  ///
  /// In it, this message translates to:
  /// **'Laboratorio'**
  String get laboratorio;

  /// No description provided for @premium.
  ///
  /// In it, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @shashguiLaboratorio.
  ///
  /// In it, this message translates to:
  /// **'ShashGui Laboratorio'**
  String get shashguiLaboratorio;

  /// No description provided for @cambiaLingua.
  ///
  /// In it, this message translates to:
  /// **'Cambia Lingua'**
  String get cambiaLingua;

  /// No description provided for @italiano.
  ///
  /// In it, this message translates to:
  /// **'🇮🇹 Italiano'**
  String get italiano;

  /// No description provided for @english.
  ///
  /// In it, this message translates to:
  /// **'🇬🇧 English'**
  String get english;

  /// No description provided for @funzioneTrattiPosizionaliBlocc.
  ///
  /// In it, this message translates to:
  /// **'Funzione Tratti Posizionali bloccata (Versione Premium)'**
  String get funzioneTrattiPosizionaliBlocc;

  /// No description provided for @traits.
  ///
  /// In it, this message translates to:
  /// **'TRAITS'**
  String get traits;

  /// No description provided for @mossa.
  ///
  /// In it, this message translates to:
  /// **'MOSSA'**
  String get mossa;

  /// No description provided for @valutazione.
  ///
  /// In it, this message translates to:
  /// **'VALUTAZIONE'**
  String get valutazione;

  /// No description provided for @scanningCloudData.
  ///
  /// In it, this message translates to:
  /// **'Scanning cloud data...'**
  String get scanningCloudData;

  /// No description provided for @petrosian.
  ///
  /// In it, this message translates to:
  /// **'🛡️ Petrosian'**
  String get petrosian;

  /// No description provided for @tal.
  ///
  /// In it, this message translates to:
  /// **'Tal 🔥'**
  String get tal;

  /// No description provided for @shashchess.
  ///
  /// In it, this message translates to:
  /// **'ShashChess'**
  String get shashchess;

  /// No description provided for @alexander.
  ///
  /// In it, this message translates to:
  /// **'Alexander'**
  String get alexander;

  /// No description provided for @spegniIlMotorePerModificareIPa.
  ///
  /// In it, this message translates to:
  /// **'Spegni il motore per modificare i parametri!'**
  String get spegniIlMotorePerModificareIPa;

  /// No description provided for @configuraParametri.
  ///
  /// In it, this message translates to:
  /// **'Configura Parametri'**
  String get configuraParametri;

  /// No description provided for @giocaControIlMotore.
  ///
  /// In it, this message translates to:
  /// **'Gioca contro il Motore'**
  String get giocaControIlMotore;

  /// No description provided for @autoplayMotoreVsMotore.
  ///
  /// In it, this message translates to:
  /// **'Autoplay (Motore vs Motore)'**
  String get autoplayMotoreVsMotore;

  /// No description provided for @rilevaMinacce.
  ///
  /// In it, this message translates to:
  /// **'Rileva Minacce'**
  String get rilevaMinacce;

  /// No description provided for @valutazioneIncrociata.
  ///
  /// In it, this message translates to:
  /// **'Valutazione Incrociata'**
  String get valutazioneIncrociata;

  /// No description provided for @accendi.
  ///
  /// In it, this message translates to:
  /// **'Accendi'**
  String get accendi;

  /// No description provided for @copia.
  ///
  /// In it, this message translates to:
  /// **'COPIA'**
  String get copia;

  /// No description provided for @importaTestoLichess.
  ///
  /// In it, this message translates to:
  /// **'Importa Testo / Lichess'**
  String get importaTestoLichess;

  /// No description provided for @incollaUnLinkLichessUnFenOUnPg.
  ///
  /// In it, this message translates to:
  /// **'Incolla un Link Lichess, un FEN o un PGN intero...'**
  String get incollaUnLinkLichessUnFenOUnPg;

  /// No description provided for @annulla.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get annulla;

  /// No description provided for @importa.
  ///
  /// In it, this message translates to:
  /// **'Importa'**
  String get importa;

  /// No description provided for @partitaCaricataConSuccesso.
  ///
  /// In it, this message translates to:
  /// **'Partita caricata con successo! ✅'**
  String get partitaCaricataConSuccesso;

  /// No description provided for @iniziaAMuovere.
  ///
  /// In it, this message translates to:
  /// **'Inizia a muovere...'**
  String get iniziaAMuovere;

  /// No description provided for @apriFilePgnfen.
  ///
  /// In it, this message translates to:
  /// **'Apri File (PGN/FEN)'**
  String get apriFilePgnfen;

  /// No description provided for @importaLinkLichessIncollaPgn.
  ///
  /// In it, this message translates to:
  /// **'Importa Link Lichess / Incolla PGN'**
  String get importaLinkLichessIncollaPgn;

  /// No description provided for @editorVisivoFen.
  ///
  /// In it, this message translates to:
  /// **'Editor Visivo FEN'**
  String get editorVisivoFen;

  /// No description provided for @salvaPartitaInLocale.
  ///
  /// In it, this message translates to:
  /// **'Salva Partita in locale'**
  String get salvaPartitaInLocale;

  /// No description provided for @copiaPgnInMemoria.
  ///
  /// In it, this message translates to:
  /// **'Copia PGN in memoria'**
  String get copiaPgnInMemoria;

  /// No description provided for @pgnCopiatoNegliAppunti.
  ///
  /// In it, this message translates to:
  /// **'PGN copiato negli appunti! 📋'**
  String get pgnCopiatoNegliAppunti;

  /// No description provided for @diramazioneRilevata.
  ///
  /// In it, this message translates to:
  /// **'Diramazione rilevata'**
  String get diramazioneRilevata;

  /// No description provided for @esisteGiUnaContinuazionePerQue.
  ///
  /// In it, this message translates to:
  /// **'Esiste già una continuazione per questa posizione. Cosa vuoi fare?'**
  String get esisteGiUnaContinuazionePerQue;

  /// No description provided for @nuovaLineaPrincipale.
  ///
  /// In it, this message translates to:
  /// **'Nuova Linea Principale'**
  String get nuovaLineaPrincipale;

  /// No description provided for @aggiungiComeVariante.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi come Variante'**
  String get aggiungiComeVariante;

  /// No description provided for @sovrascriviTutto.
  ///
  /// In it, this message translates to:
  /// **'Sovrascrivi tutto'**
  String get sovrascriviTutto;

  /// No description provided for @annullaMossa.
  ///
  /// In it, this message translates to:
  /// **'Annulla mossa'**
  String get annullaMossa;

  /// No description provided for @erroreLaScacchieraNonHaPotutoV.
  ///
  /// In it, this message translates to:
  /// **'Errore: La scacchiera non ha potuto validare il FEN!'**
  String get erroreLaScacchieraNonHaPotutoV;

  /// No description provided for @impostazioniSfida.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni Sfida'**
  String get impostazioniSfida;

  /// No description provided for @giochiCol.
  ///
  /// In it, this message translates to:
  /// **'Giochi col:'**
  String get giochiCol;

  /// No description provided for @bianco.
  ///
  /// In it, this message translates to:
  /// **'Bianco'**
  String get bianco;

  /// No description provided for @nero.
  ///
  /// In it, this message translates to:
  /// **'Nero'**
  String get nero;

  /// No description provided for @usaLivebookCloud.
  ///
  /// In it, this message translates to:
  /// **'Usa LiveBook Cloud'**
  String get usaLivebookCloud;

  /// No description provided for @ilMotorePescherLeApertureDalWe.
  ///
  /// In it, this message translates to:
  /// **'Il motore pescherà le aperture dal web.'**
  String get ilMotorePescherLeApertureDalWe;

  /// No description provided for @filtriTrattiPosizionali.
  ///
  /// In it, this message translates to:
  /// **'Filtri Tratti Posizionali'**
  String get filtriTrattiPosizionali;

  /// No description provided for @aggiungeBiasStrategicoAlleMoss.
  ///
  /// In it, this message translates to:
  /// **'Aggiunge bias strategico alle mosse.'**
  String get aggiungeBiasStrategicoAlleMoss;

  /// No description provided for @iFiltriSuiTrattiPosizionaliSon.
  ///
  /// In it, this message translates to:
  /// **'I Filtri sui Tratti Posizionali sono un'**
  String get iFiltriSuiTrattiPosizionaliSon;

  /// No description provided for @limitaForza.
  ///
  /// In it, this message translates to:
  /// **'Limita Forza'**
  String get limitaForza;

  /// No description provided for @orologioCadenza.
  ///
  /// In it, this message translates to:
  /// **'Orologio (Cadenza)'**
  String get orologioCadenza;

  /// No description provided for @tempoGlobaleFischer.
  ///
  /// In it, this message translates to:
  /// **'Tempo Globale (Fischer)'**
  String get tempoGlobaleFischer;

  /// No description provided for @tempoFissoPerMossa.
  ///
  /// In it, this message translates to:
  /// **'Tempo Fisso per Mossa'**
  String get tempoFissoPerMossa;

  /// No description provided for @incrementoS.
  ///
  /// In it, this message translates to:
  /// **'Incremento (s):'**
  String get incrementoS;

  /// No description provided for @gioca.
  ///
  /// In it, this message translates to:
  /// **'GIOCA'**
  String get gioca;

  /// No description provided for @finePartita.
  ///
  /// In it, this message translates to:
  /// **'Fine Partita'**
  String get finePartita;

  /// No description provided for @tornaAlLaboratorio.
  ///
  /// In it, this message translates to:
  /// **'TORNA AL LABORATORIO'**
  String get tornaAlLaboratorio;

  /// No description provided for @nessunaOpzioneTrovataOCaricame.
  ///
  /// In it, this message translates to:
  /// **'Nessuna opzione trovata o caricamento in corso...'**
  String get nessunaOpzioneTrovataOCaricame;

  /// No description provided for @impossibileAnalizzareLeMinacce.
  ///
  /// In it, this message translates to:
  /// **'Impossibile analizzare le minacce sotto scacco!'**
  String get impossibileAnalizzareLeMinacce;

  /// No description provided for @nessunaMinacciaAllaMossaInizia.
  ///
  /// In it, this message translates to:
  /// **'Nessuna minaccia alla mossa iniziale!'**
  String get nessunaMinacciaAllaMossaInizia;

  /// No description provided for @impostazioniAnalisi.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni Analisi'**
  String get impostazioniAnalisi;

  /// No description provided for @tempoInizialeT1PerMossa.
  ///
  /// In it, this message translates to:
  /// **'Tempo iniziale (T1) per mossa:'**
  String get tempoInizialeT1PerMossa;

  /// No description provided for @ilTempoRaddoppierAutomaticamen.
  ///
  /// In it, this message translates to:
  /// **'Il tempo raddoppierà automaticamente ad ogni iterazione della Teoria di Shashin.'**
  String get ilTempoRaddoppierAutomaticamen;

  /// No description provided for @avviaAnalisi.
  ///
  /// In it, this message translates to:
  /// **'AVVIA ANALISI'**
  String get avviaAnalisi;

  /// No description provided for @coachAnalisiIncrociata.
  ///
  /// In it, this message translates to:
  /// **'Coach: Analisi Incrociata'**
  String get coachAnalisiIncrociata;

  /// No description provided for @da2500EloInPoiIlMaestroSarLaRe.
  ///
  /// In it, this message translates to:
  /// **'(Da 2500 Elo in poi, il Maestro sarà la Rete Neurale ShashChess)'**
  String get da2500EloInPoiIlMaestroSarLaRe;

  /// No description provided for @avviaCoach.
  ///
  /// In it, this message translates to:
  /// **'AVVIA COACH'**
  String get avviaCoach;

  /// No description provided for @coachVerdettoIncrociato.
  ///
  /// In it, this message translates to:
  /// **'🔍 Coach: Verdetto Incrociato'**
  String get coachVerdettoIncrociato;

  /// No description provided for @chiudi.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get chiudi;

  /// No description provided for @impostazioniAutoplay.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni Autoplay'**
  String get impostazioniAutoplay;

  /// No description provided for @motoreBianco.
  ///
  /// In it, this message translates to:
  /// **'MOTORE BIANCO'**
  String get motoreBianco;

  /// No description provided for @livebook.
  ///
  /// In it, this message translates to:
  /// **'LiveBook'**
  String get livebook;

  /// No description provided for @trattiPosizionali.
  ///
  /// In it, this message translates to:
  /// **'Tratti Posizionali'**
  String get trattiPosizionali;

  /// No description provided for @esclusivaPremium.
  ///
  /// In it, this message translates to:
  /// **'Esclusiva Premium!'**
  String get esclusivaPremium;

  /// No description provided for @motoreNero.
  ///
  /// In it, this message translates to:
  /// **'MOTORE NERO'**
  String get motoreNero;

  /// No description provided for @avviaMatch.
  ///
  /// In it, this message translates to:
  /// **'AVVIA MATCH'**
  String get avviaMatch;

  /// No description provided for @shashguiPremium.
  ///
  /// In it, this message translates to:
  /// **'ShashGui Premium ✨'**
  String get shashguiPremium;

  /// No description provided for @ilPotereDeiServerCloud.
  ///
  /// In it, this message translates to:
  /// **'IL POTERE DEI SERVER CLOUD'**
  String get ilPotereDeiServerCloud;

  /// No description provided for @leSeguentiFunzionalitRichiedon.
  ///
  /// In it, this message translates to:
  /// **'Le seguenti funzionalità richiedono un'**
  String get leSeguentiFunzionalitRichiedon;

  /// No description provided for @sbloccaIlCloud999mese.
  ///
  /// In it, this message translates to:
  /// **'SBLOCCA IL CLOUD (Premium)'**
  String get sbloccaIlCloud999mese;

  /// No description provided for @beyondTheEval.
  ///
  /// In it, this message translates to:
  /// **'Beyond the eval'**
  String get beyondTheEval;

  /// No description provided for @shashgui.
  ///
  /// In it, this message translates to:
  /// **'ShashGUI'**
  String get shashgui;

  /// No description provided for @sviluppatoreAndreaManzo.
  ///
  /// In it, this message translates to:
  /// **'Sviluppatore: AlphaGambit'**
  String get sviluppatoreAndreaManzo;

  /// No description provided for @motoriIntegratiShashchessNnueA.
  ///
  /// In it, this message translates to:
  /// **'Motori Integrati: ShashChess (NNUE) & Alexander (HCE)'**
  String get motoriIntegratiShashchessNnueA;

  /// No description provided for @interfacciaGraficaAvanzataPerL.
  ///
  /// In it, this message translates to:
  /// **'Interfaccia grafica avanzata per l'**
  String get interfacciaGraficaAvanzataPerL;

  /// No description provided for @chiudi1.
  ///
  /// In it, this message translates to:
  /// **'CHIUDI'**
  String get chiudi1;

  /// No description provided for @editorPosizione.
  ///
  /// In it, this message translates to:
  /// **'🧩 Editor Posizione'**
  String get editorPosizione;

  /// No description provided for @selezionaPezzo.
  ///
  /// In it, this message translates to:
  /// **'Seleziona Pezzo:'**
  String get selezionaPezzo;

  /// No description provided for @svuota.
  ///
  /// In it, this message translates to:
  /// **'Svuota'**
  String get svuota;

  /// No description provided for @iniziale.
  ///
  /// In it, this message translates to:
  /// **'Iniziale'**
  String get iniziale;

  /// No description provided for @turno.
  ///
  /// In it, this message translates to:
  /// **'Turno:'**
  String get turno;

  /// No description provided for @applicaPosizione.
  ///
  /// In it, this message translates to:
  /// **'APPLICA POSIZIONE'**
  String get applicaPosizione;

  /// No description provided for @appTitle.
  ///
  /// In it, this message translates to:
  /// **'ShashGui'**
  String get appTitle;

  /// No description provided for @aboutDev.
  ///
  /// In it, this message translates to:
  /// **'Sviluppatore: AlphaGambit'**
  String get aboutDev;

  /// No description provided for @aboutEngines.
  ///
  /// In it, this message translates to:
  /// **'Motori Integrati: ShashChess (NNUE) & Alexander (HCE)'**
  String get aboutEngines;

  /// No description provided for @aboutDesc.
  ///
  /// In it, this message translates to:
  /// **'Interfaccia grafica avanzata per l\'analisi posizionale a due fasi, l\'elaborazione di dati scacchistici e l\'estrazione di tratti dinamici.'**
  String get aboutDesc;

  /// No description provided for @readManualBtn.
  ///
  /// In it, this message translates to:
  /// **'LEGGI IL MANUALE UTENTE'**
  String get readManualBtn;

  /// No description provided for @closeBtn.
  ///
  /// In it, this message translates to:
  /// **'CHIUDI'**
  String get closeBtn;

  /// No description provided for @schoolBeginner.
  ///
  /// In it, this message translates to:
  /// **'Principianti'**
  String get schoolBeginner;

  /// No description provided for @schoolIntermediate.
  ///
  /// In it, this message translates to:
  /// **'Intermedia'**
  String get schoolIntermediate;

  /// No description provided for @schoolAdvanced.
  ///
  /// In it, this message translates to:
  /// **'Avanzata'**
  String get schoolAdvanced;

  /// No description provided for @schoolExpertHCE.
  ///
  /// In it, this message translates to:
  /// **'Esperta (Max HCE)'**
  String get schoolExpertHCE;

  /// No description provided for @schoolExpert.
  ///
  /// In it, this message translates to:
  /// **'Esperta'**
  String get schoolExpert;

  /// No description provided for @schoolSuperhumanNNUE.
  ///
  /// In it, this message translates to:
  /// **'Super-Umana (NNUE)'**
  String get schoolSuperhumanNNUE;

  /// No description provided for @logQueryingOracles.
  ///
  /// In it, this message translates to:
  /// **'🌐 [Coach] Interrogazione Oracoli Cloud (Lichess/ChessDB)...'**
  String get logQueryingOracles;

  /// No description provided for @logCloudError.
  ///
  /// In it, this message translates to:
  /// **'⚠️ Errore Cloud:'**
  String get logCloudError;

  /// No description provided for @logSemanticScan.
  ///
  /// In it, this message translates to:
  /// **'📍 [Coach] Scansione semantica della posizione (Makogonov/Spazio)...'**
  String get logSemanticScan;

  /// No description provided for @pieceKnight.
  ///
  /// In it, this message translates to:
  /// **'il Cavallo'**
  String get pieceKnight;

  /// No description provided for @pieceBishop.
  ///
  /// In it, this message translates to:
  /// **'l\'Alfiere'**
  String get pieceBishop;

  /// No description provided for @pieceRook.
  ///
  /// In it, this message translates to:
  /// **'la Torre'**
  String get pieceRook;

  /// No description provided for @pieceQueen.
  ///
  /// In it, this message translates to:
  /// **'la Donna'**
  String get pieceQueen;

  /// No description provided for @pieceKing.
  ///
  /// In it, this message translates to:
  /// **'il Re'**
  String get pieceKing;

  /// No description provided for @piecePawn.
  ///
  /// In it, this message translates to:
  /// **'il Pedone'**
  String get piecePawn;

  /// No description provided for @pieceGeneric.
  ///
  /// In it, this message translates to:
  /// **'il pezzo'**
  String get pieceGeneric;

  /// No description provided for @logCalcThermodynamicZone.
  ///
  /// In it, this message translates to:
  /// **'📍 [Coach] Calcolo Zona Termodinamica in corso...'**
  String get logCalcThermodynamicZone;

  /// No description provided for @logStudentThinking1.
  ///
  /// In it, this message translates to:
  /// **'🧑‍🎓 L\'Allievo (Scuola'**
  String get logStudentThinking1;

  /// No description provided for @logStudentThinking2.
  ///
  /// In it, this message translates to:
  /// **'- Elo'**
  String get logStudentThinking2;

  /// No description provided for @logStudentThinking3.
  ///
  /// In it, this message translates to:
  /// **') elabora il piano...'**
  String get logStudentThinking3;

  /// No description provided for @logPrepMaster1.
  ///
  /// In it, this message translates to:
  /// **'🧙‍♂️ Preparazione Maestro (Scuola'**
  String get logPrepMaster1;

  /// No description provided for @logPrepMaster2.
  ///
  /// In it, this message translates to:
  /// **')...'**
  String get logPrepMaster2;

  /// No description provided for @logEngineSwap.
  ///
  /// In it, this message translates to:
  /// **'🚀 Cambio motore in corso: Spegnimento Alexander -> Avvio ShashChess...'**
  String get logEngineSwap;

  /// No description provided for @logShashReady.
  ///
  /// In it, this message translates to:
  /// **'✅ ShashChess pronto alla massima forza.'**
  String get logShashReady;

  /// No description provided for @evalWhiteDominate.
  ///
  /// In it, this message translates to:
  /// **'Il Bianco gode di un netto dominio territoriale, che gli garantisce grande libertà di manovra.\n'**
  String get evalWhiteDominate;

  /// No description provided for @evalWhiteSlightEdge.
  ///
  /// In it, this message translates to:
  /// **'Il Bianco possiede un lieve vantaggio di spazio.\n'**
  String get evalWhiteSlightEdge;

  /// No description provided for @evalBlackDominate.
  ///
  /// In it, this message translates to:
  /// **'Il Nero ha conquistato un forte vantaggio di spazio, asfissiando i pezzi bianchi.\n'**
  String get evalBlackDominate;

  /// No description provided for @evalBlackSlightEdge.
  ///
  /// In it, this message translates to:
  /// **'Il Nero detiene un leggero controllo territoriale superiore.\n'**
  String get evalBlackSlightEdge;

  /// No description provided for @evalSpaceBalanced.
  ///
  /// In it, this message translates to:
  /// **'La gestione dello spazio sulla scacchiera è in perfetto equilibrio.\n'**
  String get evalSpaceBalanced;

  /// No description provided for @evalMakogonovWorst.
  ///
  /// In it, this message translates to:
  /// **'Secondo il principio di Makogonov, il pezzo che richiede più urgenza di essere riattivato è'**
  String get evalMakogonovWorst;

  /// No description provided for @evalComplex.
  ///
  /// In it, this message translates to:
  /// **'Valutazione posizionale complessa.'**
  String get evalComplex;

  /// No description provided for @reportTitleCloud.
  ///
  /// In it, this message translates to:
  /// **'🌐 VALUTAZIONI CLOUD:'**
  String get reportTitleCloud;

  /// No description provided for @reportLichessHumans.
  ///
  /// In it, this message translates to:
  /// **'Lichess (Umani)'**
  String get reportLichessHumans;

  /// No description provided for @reportNoMoves.
  ///
  /// In it, this message translates to:
  /// **'Nessuna giocata predominante'**
  String get reportNoMoves;

  /// No description provided for @reportChessDbNeural.
  ///
  /// In it, this message translates to:
  /// **'ChessDB (Neurali)'**
  String get reportChessDbNeural;

  /// No description provided for @reportTitleStatic.
  ///
  /// In it, this message translates to:
  /// **'📍 SCENOGRAFIA STATICA (Pre-Mossa):'**
  String get reportTitleStatic;

  /// No description provided for @reportZone.
  ///
  /// In it, this message translates to:
  /// **'Zona'**
  String get reportZone;

  /// No description provided for @reportTitleStudent1.
  ///
  /// In it, this message translates to:
  /// **'🧑‍🎓 LA TUA IDEA (Scuola'**
  String get reportTitleStudent1;

  /// No description provided for @reportTitleStudent2.
  ///
  /// In it, this message translates to:
  /// **'):'**
  String get reportTitleStudent2;

  /// No description provided for @reportChosenMove.
  ///
  /// In it, this message translates to:
  /// **'Mossa scelta'**
  String get reportChosenMove;

  /// No description provided for @reportExpectation.
  ///
  /// In it, this message translates to:
  /// **'Aspettativa'**
  String get reportExpectation;

  /// No description provided for @reportTitleMaster1.
  ///
  /// In it, this message translates to:
  /// **'🧙‍♂️ L\'IDEA DEL MAESTRO (Scuola'**
  String get reportTitleMaster1;

  /// No description provided for @reportTitleMaster2.
  ///
  /// In it, this message translates to:
  /// **'):'**
  String get reportTitleMaster2;

  /// No description provided for @reportNnueWorstPiece.
  ///
  /// In it, this message translates to:
  /// **'Pezzo peggiore per la Rete Neurale'**
  String get reportNnueWorstPiece;

  /// No description provided for @reportTitleVerdict.
  ///
  /// In it, this message translates to:
  /// **'💡 VERDETTO DEL COACH:'**
  String get reportTitleVerdict;

  /// No description provided for @nagExcellentTitle.
  ///
  /// In it, this message translates to:
  /// **'🌟 ECCELLENTE!'**
  String get nagExcellentTitle;

  /// No description provided for @nagExcellentDesc.
  ///
  /// In it, this message translates to:
  /// **'Hai trovato la stessa mossa del Maestro. Stai giocando a un livello superiore alla tua categoria, rispettando i canoni posizionali estratti nell\'analisi statica.'**
  String get nagExcellentDesc;

  /// No description provided for @nagBlunderTitle.
  ///
  /// In it, this message translates to:
  /// **'❌ NAG: ?? (Grave Errore)'**
  String get nagBlunderTitle;

  /// No description provided for @nagBlunderDesc1.
  ///
  /// In it, this message translates to:
  /// **'La tua idea cede un vantaggio letale facendo crollare la posizione di'**
  String get nagBlunderDesc1;

  /// No description provided for @nagBlunderDesc2.
  ///
  /// In it, this message translates to:
  /// **'Zone. Il Maestro suggerisce una via diversa per salvare la posizione.'**
  String get nagBlunderDesc2;

  /// No description provided for @nagMistakeTitle.
  ///
  /// In it, this message translates to:
  /// **'⚠️ NAG: ? (Errore)'**
  String get nagMistakeTitle;

  /// No description provided for @nagMistakeDesc1.
  ///
  /// In it, this message translates to:
  /// **'Una svista posizionale o tattica. La posizione scende di'**
  String get nagMistakeDesc1;

  /// No description provided for @nagMistakeDesc2.
  ///
  /// In it, this message translates to:
  /// **'Zone rispetto al potenziale massimizzato dal Maestro.'**
  String get nagMistakeDesc2;

  /// No description provided for @nagInaccuracyTitle.
  ///
  /// In it, this message translates to:
  /// **'🤔 NAG: ?! (Imprecisione)'**
  String get nagInaccuracyTitle;

  /// No description provided for @nagInaccuracyDesc.
  ///
  /// In it, this message translates to:
  /// **'La tua idea è giocabile, ma perdi una Zona Termodinamica rispetto alla mossa del Maestro.'**
  String get nagInaccuracyDesc;

  /// No description provided for @nagInterestingTitle.
  ///
  /// In it, this message translates to:
  /// **'👌 NAG: !? (Interessante)'**
  String get nagInterestingTitle;

  /// No description provided for @nagInterestingDescDiff1.
  ///
  /// In it, this message translates to:
  /// **'La mossa del Maestro'**
  String get nagInterestingDescDiff1;

  /// No description provided for @nagInterestingDescDiff2.
  ///
  /// In it, this message translates to:
  /// **'spreme più vantaggio, ma la tua idea mantiene la stessa Zona'**
  String get nagInterestingDescDiff2;

  /// No description provided for @nagInterestingDescDiff3.
  ///
  /// In it, this message translates to:
  /// **'È saggio giocare il piano che comprendi meglio.'**
  String get nagInterestingDescDiff3;

  /// No description provided for @nagInterestingDescClose.
  ///
  /// In it, this message translates to:
  /// **'Idea validissima! Sei vicino alla valutazione del Maestro e mantieni intatta la Zona Termodinamica.'**
  String get nagInterestingDescClose;

  /// No description provided for @reportTitleAdvVision.
  ///
  /// In it, this message translates to:
  /// **'👁️ VISIONE AVANZATA DEL MAESTRO:'**
  String get reportTitleAdvVision;

  /// No description provided for @advVisionFixed1.
  ///
  /// In it, this message translates to:
  /// **'Il Maestro ha identificato il problema su'**
  String get advVisionFixed1;

  /// No description provided for @advVisionFixed2.
  ///
  /// In it, this message translates to:
  /// **'e lo ha risolto. Ora il punto debole è diventato'**
  String get advVisionFixed2;

  /// No description provided for @advVisionIgnored1.
  ///
  /// In it, this message translates to:
  /// **'Il Maestro ignora la passività di'**
  String get advVisionIgnored1;

  /// No description provided for @advVisionIgnored2.
  ///
  /// In it, this message translates to:
  /// **'indicando un attacco tattico o un sacrificio dinamico (la mossa'**
  String get advVisionIgnored2;

  /// No description provided for @advVisionIgnored3.
  ///
  /// In it, this message translates to:
  /// **'garantisce il picco di attività).'**
  String get advVisionIgnored3;

  /// No description provided for @logEvalComplete.
  ///
  /// In it, this message translates to:
  /// **'✅ Valutazione incrociata completata.'**
  String get logEvalComplete;

  /// No description provided for @impostazioni.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get impostazioni;

  /// No description provided for @informazioniSuShashGui.
  ///
  /// In it, this message translates to:
  /// **'Informazioni su ShashGui'**
  String get informazioniSuShashGui;

  /// No description provided for @modalitaGiocoInArrivo.
  ///
  /// In it, this message translates to:
  /// **'Modalità Gioco (In Arrivo)'**
  String get modalitaGiocoInArrivo;

  /// No description provided for @impostaEGioca.
  ///
  /// In it, this message translates to:
  /// **'Imposta la partita e premi Gioca'**
  String get impostaEGioca;

  /// No description provided for @minuti.
  ///
  /// In it, this message translates to:
  /// **'Minuti:'**
  String get minuti;

  /// No description provided for @secondi.
  ///
  /// In it, this message translates to:
  /// **'Secondi:'**
  String get secondi;

  /// Testo del pulsante nella sezione impostazioni per aprire la vetrina premium
  ///
  /// In it, this message translates to:
  /// **'SCOPRI LE FUNZIONI DESKTOP'**
  String get scopriFunzioniDesktop;

  /// Introduzione dettagliata alle funzionalità premium cloud
  ///
  /// In it, this message translates to:
  /// **'Il passaggio alla versione Premium sblocca l\'accesso ai cluster Cloud ad alte prestazioni. Le analisi profonde, l\'elaborazione di massivi database PGN e il data-mining euristico non peseranno più sulla batteria del tuo smartphone, offrendoti gli stessi strumenti professionali della leggendaria versione Desktop.'**
  String get premiumIntroDesc;

  /// Titolo della feature ChessBeauty
  ///
  /// In it, this message translates to:
  /// **'ChessBeauty Analyzer™'**
  String get featureBeautyTitle;

  /// Sottotitolo della feature ChessBeauty
  ///
  /// In it, this message translates to:
  /// **'Valutazione estetica e qualimetrica'**
  String get featureBeautySub;

  /// Descrizione della feature ChessBeauty
  ///
  /// In it, this message translates to:
  /// **'Calcola il \'Tasso di Bellezza\' matematico di un\'intera partita. L\'algoritmo rileva sacrifici spettacolari, matti annunciati e paradossi scacchistici, basandosi sui celebri Canoni estetici di François Le Lionnais.'**
  String get featureBeautyDesc;

  /// Titolo della feature Nuggets
  ///
  /// In it, this message translates to:
  /// **'Nuggets Explorer'**
  String get featureNuggetsTitle;

  /// Sottotitolo della feature Nuggets
  ///
  /// In it, this message translates to:
  /// **'Data-mining termodinamico'**
  String get featureNuggetsSub;

  /// Descrizione della feature Nuggets
  ///
  /// In it, this message translates to:
  /// **'Scansiona immensi database per estrarre in automatico le \'Pepite\': posizioni critiche in cui la Win Probability umana diverge in modo asimmetrico da quella della Rete Neurale.'**
  String get featureNuggetsDesc;

  /// Titolo della feature XAI
  ///
  /// In it, this message translates to:
  /// **'Dossier Divergenze XAI'**
  String get featureXaiTitle;

  /// Sottotitolo della feature XAI
  ///
  /// In it, this message translates to:
  /// **'Explainable AI & Reportistica'**
  String get featureXaiSub;

  /// Descrizione della feature XAI
  ///
  /// In it, this message translates to:
  /// **'Genera report visivi in formato PDF/HTML. Il sistema mappa la tua accuratezza confrontandola con i Campioni del Mondo, individuando le tue falle di calcolo nelle diverse zone.'**
  String get featureXaiDesc;

  /// Titolo della feature Avatar
  ///
  /// In it, this message translates to:
  /// **'Avatar & Player Card'**
  String get featureAvatarTitle;

  /// Sottotitolo della feature Avatar
  ///
  /// In it, this message translates to:
  /// **'Profilazione algoritmica'**
  String get featureAvatarSub;

  /// Descrizione della feature Avatar
  ///
  /// In it, this message translates to:
  /// **'Analizza lo stile di gioco del tuo prossimo sfidante. ShashGUI ne profilerà le debolezze, assegnandogli un Avatar psicologico e mostrando grafici sulle sue vulnerabilità.'**
  String get featureAvatarDesc;

  /// Titolo della feature ShashIDEA
  ///
  /// In it, this message translates to:
  /// **'ShashIDEA Lab'**
  String get featureIdeaTitle;

  /// Sottotitolo della feature ShashIDEA
  ///
  /// In it, this message translates to:
  /// **'Costruzione repertorio Polyglot'**
  String get featureIdeaSub;

  /// Descrizione della feature ShashIDEA
  ///
  /// In it, this message translates to:
  /// **'Un laboratorio d\'aperture drag&drop. Costruisci il tuo albero interattivo e compilalo automaticamente in formato binario (.bin) per addestrare i tuoi motori personali.'**
  String get featureIdeaDesc;

  /// Titolo della feature Learning
  ///
  /// In it, this message translates to:
  /// **'Tratti & R-Learning'**
  String get featureLearningTitle;

  /// Sottotitolo della feature Learning
  ///
  /// In it, this message translates to:
  /// **'Machine Learning e File .ptr'**
  String get featureLearningSub;

  /// Descrizione della feature Learning
  ///
  /// In it, this message translates to:
  /// **'Estrai i tratti dominanti (spazio, coppia alfieri, avamposti) e forza il motore a giocare simulando esattamente il tuo stile di gioco tramite file .exp e .ptr.'**
  String get featureLearningDesc;

  /// Titolo della feature Batch
  ///
  /// In it, this message translates to:
  /// **'Analisi Batch Automatizzata'**
  String get featureBatchTitle;

  /// Sottotitolo della feature Batch
  ///
  /// In it, this message translates to:
  /// **'Elaborazione massiva notturna'**
  String get featureBatchSub;

  /// Descrizione della feature Batch
  ///
  /// In it, this message translates to:
  /// **'Analizza migliaia di partite automaticamente: le ritroverai annotate con varianti PV, NAG tattici e commenti in linguaggio naturale (NLG).'**
  String get featureBatchDesc;

  /// Titolo della feature SQL
  ///
  /// In it, this message translates to:
  /// **'ShashQL & DB Manager'**
  String get featureSqlTitle;

  /// Sottotitolo della feature SQL
  ///
  /// In it, this message translates to:
  /// **'Query Language Scacchistico'**
  String get featureSqlSub;

  /// Descrizione della feature SQL
  ///
  /// In it, this message translates to:
  /// **'Motore di ricerca database rivoluzionario. Usa query SQL per filtrare partite per pattern: \'Mostrami tutte le partite in Zona Tal con densità K > 0.5\'.'**
  String get featureSqlDesc;

  /// Messaggio per una mossa che non altera la zona termodinamica
  ///
  /// In it, this message translates to:
  /// **'💡 Semplice Idea strategica'**
  String get shashinIdea;

  /// Messaggio per un calo di 1 zona
  ///
  /// In it, this message translates to:
  /// **'⚠️ Minaccia Lieve'**
  String get threatMild;

  /// Messaggio per un calo di 2 zone
  ///
  /// In it, this message translates to:
  /// **'🔥 Minaccia Moderata'**
  String get threatModerate;

  /// Messaggio per un calo di 3 o più zone
  ///
  /// In it, this message translates to:
  /// **'💀 MINACCIA GRAVE!'**
  String get threatSevere;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
