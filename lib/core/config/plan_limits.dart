import '../constants/tone_modes.dart';

class PlanLimits {
  /// Daily voice typing limit for free tier users
  static const int freeDailyLimit = 20;

  /// Daily voice typing limit for Pro tier (-1 denotes unlimited)
  static const int proDailyLimit = -1;

  /// Tone modes accessible in Free tier (Bengali only)
  static const List<String> freeAllowedModes = [
    ToneModes.bangla,
  ];

  /// Tone modes accessible in Pro tier (All 5 modes)
  static final List<String> proAllowedModes = ToneModes.allModes.map((m) => m.key).toList();

  /// Check whether a specific mode is permitted under current tier
  static bool isModeAllowed(String modeKey, {required bool isPro}) {
    if (isPro) return true;
    final normalized = ToneModes.getByKey(modeKey).key;
    return freeAllowedModes.contains(normalized);
  }

  /// Get daily limit for given tier
  static int getDailyLimit({required bool isPro}) {
    return isPro ? proDailyLimit : freeDailyLimit;
  }

  /// Check whether user has hit the daily limit
  static bool isDailyLimitReached(int currentDailyCount, {required bool isPro}) {
    if (isPro) return false;
    return currentDailyCount >= freeDailyLimit;
  }
}
