import 'package:shared_preferences/shared_preferences.dart';
import 'models/permission_cache.dart';

/// Singleton repository for app-level settings stored in SharedPreferences.
/// Currently handles the permission cache for offline access.
class SettingsRepository {
  static final SettingsRepository _instance = SettingsRepository._internal();
  static SettingsRepository get instance => _instance;

  SettingsRepository._internal();

  late SharedPreferences _prefs;

  // Permission cache keys
  static const String _keyPermHasAccess = 'perm_has_access';
  static const String _keyPermHasProfile = 'perm_has_profile';
  static const String _keyPermRol = 'perm_rol';
  static const String _keyPermTrialActive = 'perm_trial_active';
  static const String _keyPermTrialDaysLeft = 'perm_trial_days_left';
  static const String _keyPermTrialExpired = 'perm_trial_expired';
  static const String _keyPermTrialUsed = 'perm_trial_used';
  static const String _keyPermLastVerified = 'perm_last_verified';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // =========================================================================
  // PERMISSION CACHE — Offline Access
  // =========================================================================

  /// Save the result of a successful Firestore permission check.
  Future<void> savePermissionCache({
    required bool hasAccess,
    required bool hasProfile,
    required String rol,
    required bool trialActive,
    required int trialDaysLeft,
    required bool trialExpired,
    required bool trialUsed,
  }) async {
    await _prefs.setBool(_keyPermHasAccess, hasAccess);
    await _prefs.setBool(_keyPermHasProfile, hasProfile);
    await _prefs.setString(_keyPermRol, rol);
    await _prefs.setBool(_keyPermTrialActive, trialActive);
    await _prefs.setInt(_keyPermTrialDaysLeft, trialDaysLeft);
    await _prefs.setBool(_keyPermTrialExpired, trialExpired);
    await _prefs.setBool(_keyPermTrialUsed, trialUsed);
    await _prefs.setString(
      _keyPermLastVerified,
      DateTime.now().toIso8601String(),
    );
  }

  /// Load the cached permission state. Returns null if no cache exists.
  PermissionCache? loadPermissionCache() {
    final lastVerifiedStr = _prefs.getString(_keyPermLastVerified);
    if (lastVerifiedStr == null) return null;

    return PermissionCache(
      hasAccess: _prefs.getBool(_keyPermHasAccess) ?? false,
      hasProfile: _prefs.getBool(_keyPermHasProfile) ?? false,
      rol: _prefs.getString(_keyPermRol) ?? 'pendiente',
      trialActive: _prefs.getBool(_keyPermTrialActive) ?? false,
      trialDaysLeft: _prefs.getInt(_keyPermTrialDaysLeft) ?? 0,
      trialExpired: _prefs.getBool(_keyPermTrialExpired) ?? false,
      trialUsed: _prefs.getBool(_keyPermTrialUsed) ?? false,
      lastVerified: DateTime.parse(lastVerifiedStr),
    );
  }

  /// Clear the permission cache (used on logout).
  Future<void> clearPermissionCache() async {
    await _prefs.remove(_keyPermHasAccess);
    await _prefs.remove(_keyPermHasProfile);
    await _prefs.remove(_keyPermRol);
    await _prefs.remove(_keyPermTrialActive);
    await _prefs.remove(_keyPermTrialDaysLeft);
    await _prefs.remove(_keyPermTrialExpired);
    await _prefs.remove(_keyPermTrialUsed);
    await _prefs.remove(_keyPermLastVerified);
  }
}
