import 'package:shared_preferences/shared_preferences.dart';

/// 위치 공유 마스터 스위치. 실시간 소켓 연동 전 UI/로컬만.
class LocationSharePrefs {
  static const _enabledKey = 'location_share_enabled';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }
}
