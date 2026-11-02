import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('es'),
  ];

  /// Full app name (window/tab title, About section)
  ///
  /// In es, this message translates to:
  /// **'Afinador Musical'**
  String get appTitle;

  /// Short app name shown on the tuner screen app bar
  ///
  /// In es, this message translates to:
  /// **'Afinador'**
  String get appBarTitle;

  /// No description provided for @waitingForMicrophone.
  ///
  /// In es, this message translates to:
  /// **'Esperando micrófono...'**
  String get waitingForMicrophone;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settingsTitle;

  /// No description provided for @referencePitch.
  ///
  /// In es, this message translates to:
  /// **'Afinación de Referencia'**
  String get referencePitch;

  /// No description provided for @instrumentTransposition.
  ///
  /// In es, this message translates to:
  /// **'Transposición de Instrumento'**
  String get instrumentTransposition;

  /// No description provided for @transposeNone.
  ///
  /// In es, this message translates to:
  /// **'C (0, Sin transposición)'**
  String get transposeNone;

  /// No description provided for @transposeEb.
  ///
  /// In es, this message translates to:
  /// **'Eb (+3, Saxo Alto/Barítono)'**
  String get transposeEb;

  /// No description provided for @transposeF.
  ///
  /// In es, this message translates to:
  /// **'F (+5, Corno Francés)'**
  String get transposeF;

  /// No description provided for @transposeBb.
  ///
  /// In es, this message translates to:
  /// **'Bb (-2, Trompeta/Clarinete/Tenor)'**
  String get transposeBb;

  /// No description provided for @keepScreenOn.
  ///
  /// In es, this message translates to:
  /// **'Mantener pantalla encendida'**
  String get keepScreenOn;

  /// No description provided for @keepScreenOnSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Evita que el dispositivo se bloquee mientras afinás'**
  String get keepScreenOnSubtitle;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Idioma del sistema'**
  String get languageSystem;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @visitWebsite.
  ///
  /// In es, this message translates to:
  /// **'Visitar federicorandazzo.com.ar/apps/'**
  String get visitWebsite;

  /// No description provided for @inputMicrophone.
  ///
  /// In es, this message translates to:
  /// **'Micrófono de Entrada'**
  String get inputMicrophone;

  /// No description provided for @refreshDevices.
  ///
  /// In es, this message translates to:
  /// **'Actualizar dispositivos'**
  String get refreshDevices;

  /// No description provided for @selectMicrophoneHint.
  ///
  /// In es, this message translates to:
  /// **'Seleccioná qué micrófono usar para la afinación'**
  String get selectMicrophoneHint;

  /// No description provided for @noInputDevices.
  ///
  /// In es, this message translates to:
  /// **'No se detectaron dispositivos de entrada.'**
  String get noInputDevices;

  /// No description provided for @useSystemDefaultMicrophone.
  ///
  /// In es, this message translates to:
  /// **'Usar micrófono por defecto del sistema'**
  String get useSystemDefaultMicrophone;

  /// No description provided for @systemDefaultMicrophone.
  ///
  /// In es, this message translates to:
  /// **'Micrófono por defecto del sistema'**
  String get systemDefaultMicrophone;

  /// No description provided for @deviceFallbackName.
  ///
  /// In es, this message translates to:
  /// **'Dispositivo {id}'**
  String deviceFallbackName(String id);

  /// No description provided for @usingDevice.
  ///
  /// In es, this message translates to:
  /// **'Usando: {name}'**
  String usingDevice(String name);

  /// No description provided for @microphoneActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad del Micrófono'**
  String get microphoneActivity;

  /// No description provided for @sampleRate.
  ///
  /// In es, this message translates to:
  /// **'Frecuencia de muestreo: {rate} Hz'**
  String sampleRate(int rate);

  /// No description provided for @installApp.
  ///
  /// In es, this message translates to:
  /// **'Instalar Aplicación'**
  String get installApp;

  /// No description provided for @installAppDescription.
  ///
  /// In es, this message translates to:
  /// **'Instalá el Afinador en tu dispositivo para acceso rápido y uso sin conexión.'**
  String get installAppDescription;

  /// No description provided for @install.
  ///
  /// In es, this message translates to:
  /// **'Instalar'**
  String get install;

  /// No description provided for @appInstalled.
  ///
  /// In es, this message translates to:
  /// **'App Instalada'**
  String get appInstalled;

  /// No description provided for @appInstalledDescription.
  ///
  /// In es, this message translates to:
  /// **'Estás usando la versión instalada del Afinador.'**
  String get appInstalledDescription;

  /// No description provided for @manualInstallIntro.
  ///
  /// In es, this message translates to:
  /// **'Podés instalar esta app desde el menú de tu navegador:'**
  String get manualInstallIntro;

  /// No description provided for @manualInstallChromeAndroid.
  ///
  /// In es, this message translates to:
  /// **'Menú ⋮ → \"Instalar aplicación\" o \"Añadir a pantalla de inicio\"'**
  String get manualInstallChromeAndroid;

  /// No description provided for @manualInstallChromeDesktop.
  ///
  /// In es, this message translates to:
  /// **'Icono de instalación en la barra de direcciones o Menú ⋮ → \"Instalar app\"'**
  String get manualInstallChromeDesktop;

  /// No description provided for @manualInstallSafariIos.
  ///
  /// In es, this message translates to:
  /// **'Tocar el botón Compartir → \"Agregar a pantalla de inicio\"'**
  String get manualInstallSafariIos;
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
