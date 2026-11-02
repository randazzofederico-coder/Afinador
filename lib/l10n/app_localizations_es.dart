// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Afinador Musical';

  @override
  String get appBarTitle => 'Afinador';

  @override
  String get waitingForMicrophone => 'Esperando micrófono...';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get referencePitch => 'Afinación de Referencia';

  @override
  String get instrumentTransposition => 'Transposición de Instrumento';

  @override
  String get transposeNone => 'C (0, Sin transposición)';

  @override
  String get transposeEb => 'Eb (+3, Saxo Alto/Barítono)';

  @override
  String get transposeF => 'F (+5, Corno Francés)';

  @override
  String get transposeBb => 'Bb (-2, Trompeta/Clarinete/Tenor)';

  @override
  String get keepScreenOn => 'Mantener pantalla encendida';

  @override
  String get keepScreenOnSubtitle =>
      'Evita que el dispositivo se bloquee mientras afinás';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Idioma del sistema';

  @override
  String get about => 'Acerca de';

  @override
  String get visitWebsite => 'Visitar federicorandazzo.com.ar/apps/';

  @override
  String get inputMicrophone => 'Micrófono de Entrada';

  @override
  String get refreshDevices => 'Actualizar dispositivos';

  @override
  String get selectMicrophoneHint =>
      'Seleccioná qué micrófono usar para la afinación';

  @override
  String get noInputDevices => 'No se detectaron dispositivos de entrada.';

  @override
  String get useSystemDefaultMicrophone =>
      'Usar micrófono por defecto del sistema';

  @override
  String get systemDefaultMicrophone => 'Micrófono por defecto del sistema';

  @override
  String deviceFallbackName(String id) {
    return 'Dispositivo $id';
  }

  @override
  String usingDevice(String name) {
    return 'Usando: $name';
  }

  @override
  String get microphoneActivity => 'Actividad del Micrófono';

  @override
  String sampleRate(int rate) {
    return 'Frecuencia de muestreo: $rate Hz';
  }

  @override
  String get installApp => 'Instalar Aplicación';

  @override
  String get installAppDescription =>
      'Instalá el Afinador en tu dispositivo para acceso rápido y uso sin conexión.';

  @override
  String get install => 'Instalar';

  @override
  String get appInstalled => 'App Instalada';

  @override
  String get appInstalledDescription =>
      'Estás usando la versión instalada del Afinador.';

  @override
  String get manualInstallIntro =>
      'Podés instalar esta app desde el menú de tu navegador:';

  @override
  String get manualInstallChromeAndroid =>
      'Menú ⋮ → \"Instalar aplicación\" o \"Añadir a pantalla de inicio\"';

  @override
  String get manualInstallChromeDesktop =>
      'Icono de instalación en la barra de direcciones o Menú ⋮ → \"Instalar app\"';

  @override
  String get manualInstallSafariIos =>
      'Tocar el botón Compartir → \"Agregar a pantalla de inicio\"';
}
