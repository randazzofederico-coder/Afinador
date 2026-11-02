import 'package:flutter/material.dart';
import 'settings_repository.dart';

/// Holds the app language selected by the user.
///
/// `null` means "follow the system language" (the default on first launch).
/// MaterialApp listens to [locale] and rebuilds when it changes.
class LocaleController {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  /// Load the saved choice. Call after [SettingsRepository.init].
  void init() {
    final code = SettingsRepository.instance.loadLocaleCode();
    locale.value = code == null ? null : Locale(code);
  }

  /// Change the language; pass null to go back to the system language.
  Future<void> setLocale(Locale? newLocale) async {
    locale.value = newLocale;
    await SettingsRepository.instance.saveLocaleCode(newLocale?.languageCode);
  }
}
