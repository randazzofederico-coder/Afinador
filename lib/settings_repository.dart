import 'package:shared_preferences/shared_preferences.dart';

/// Singleton repository for app-level settings stored in SharedPreferences.
class SettingsRepository {
  static final SettingsRepository _instance = SettingsRepository._internal();
  static SettingsRepository get instance => _instance;

  SettingsRepository._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _removeLegacyPermissionCache();
  }

  /// One-time cleanup: drop the permission-cache keys left behind by the old
  /// (removed) login/AuthGate flow. No-op once they are gone.
  Future<void> _removeLegacyPermissionCache() async {
    const legacyKeys = [
      'perm_has_access',
      'perm_has_profile',
      'perm_rol',
      'perm_trial_active',
      'perm_trial_days_left',
      'perm_trial_expired',
      'perm_trial_used',
      'perm_last_verified',
    ];
    for (final key in legacyKeys) {
      if (_prefs.containsKey(key)) await _prefs.remove(key);
    }
  }

  // =========================================================================
  // APP LANGUAGE
  // =========================================================================

  static const String _keyLocale = 'app_locale';

  /// Language code chosen by the user (e.g. 'es', 'en'), or null to follow
  /// the system language.
  String? loadLocaleCode() => _prefs.getString(_keyLocale);

  /// Save the chosen language code; null means "follow the system".
  Future<void> saveLocaleCode(String? code) async {
    if (code == null) {
      await _prefs.remove(_keyLocale);
    } else {
      await _prefs.setString(_keyLocale, code);
    }
  }
}
