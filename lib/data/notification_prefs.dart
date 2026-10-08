import 'package:shared_preferences/shared_preferences.dart';

/// 알림 토글. 푸시 서버 연동 전 로컬 저장만.
class NotificationPrefs {
  static const _allKey = 'notif_all';
  static const _chatKey = 'notif_chat';
  static const _meetingKey = 'notif_meeting';

  Future<bool> allEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_allKey) ?? true;
  }

  Future<bool> chatEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chatKey) ?? true;
  }

  Future<bool> meetingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_meetingKey) ?? true;
  }

  Future<void> setAllEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_allKey, value);
    if (!value) {
      await prefs.setBool(_chatKey, false);
      await prefs.setBool(_meetingKey, false);
    }
  }

  Future<void> setChatEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chatKey, value);
    if (value) await prefs.setBool(_allKey, true);
  }

  Future<void> setMeetingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_meetingKey, value);
    if (value) await prefs.setBool(_allKey, true);
  }
}
