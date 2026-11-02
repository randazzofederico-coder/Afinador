// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tuner';

  @override
  String get appBarTitle => 'Tuner';

  @override
  String get waitingForMicrophone => 'Waiting for microphone...';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get referencePitch => 'Reference Pitch';

  @override
  String get instrumentTransposition => 'Instrument Transposition';

  @override
  String get transposeNone => 'C (0, No transposition)';

  @override
  String get transposeEb => 'Eb (+3, Alto/Baritone Sax)';

  @override
  String get transposeF => 'F (+5, French Horn)';

  @override
  String get transposeBb => 'Bb (-2, Trumpet/Clarinet/Tenor Sax)';

  @override
  String get keepScreenOn => 'Keep screen on';

  @override
  String get keepScreenOnSubtitle =>
      'Prevents the device from locking while you tune';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System language';

  @override
  String get about => 'About';

  @override
  String get visitWebsite => 'Visit federicorandazzo.com.ar/apps/';

  @override
  String get forum => 'Forum';

  @override
  String get forumSubtitle => 'Questions, suggestions and community';

  @override
  String get inputMicrophone => 'Input Microphone';

  @override
  String get refreshDevices => 'Refresh devices';

  @override
  String get selectMicrophoneHint =>
      'Choose which microphone to use for tuning';

  @override
  String get noInputDevices => 'No input devices detected.';

  @override
  String get useSystemDefaultMicrophone => 'Use the system default microphone';

  @override
  String get systemDefaultMicrophone => 'System default microphone';

  @override
  String deviceFallbackName(String id) {
    return 'Device $id';
  }

  @override
  String usingDevice(String name) {
    return 'Using: $name';
  }

  @override
  String get microphoneActivity => 'Microphone Activity';

  @override
  String sampleRate(int rate) {
    return 'Sample rate: $rate Hz';
  }

  @override
  String get installApp => 'Install App';

  @override
  String get installAppDescription =>
      'Install the Tuner on your device for quick access and offline use.';

  @override
  String get install => 'Install';

  @override
  String get appInstalled => 'App Installed';

  @override
  String get appInstalledDescription =>
      'You are using the installed version of the Tuner.';

  @override
  String get manualInstallIntro =>
      'You can install this app from your browser menu:';

  @override
  String get manualInstallChromeAndroid =>
      'Menu ⋮ → \"Install app\" or \"Add to Home screen\"';

  @override
  String get manualInstallChromeDesktop =>
      'Install icon in the address bar or Menu ⋮ → \"Install app\"';

  @override
  String get manualInstallSafariIos =>
      'Tap the Share button → \"Add to Home Screen\"';
}
