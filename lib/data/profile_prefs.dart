import 'package:shared_preferences/shared_preferences.dart';

/// 프로필 부가 정보(상태메시지·학교 배지). 서버 프로필 API 전까지 로컬만.
class ProfilePrefs {
  static const _statusKey = 'profile_status_message';
  static const _schoolKey = 'profile_school_label';

  static const String defaultStatusMessage =
      '오늘도 모임에서 같이 모이는 중!';
  static const String defaultSchoolLabel = '성결대학교';

  Future<String> statusMessage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_statusKey) ?? defaultStatusMessage;
  }

  Future<void> setStatusMessage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusKey, value.trim());
  }

  Future<String> schoolLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_schoolKey) ?? defaultSchoolLabel;
  }

  Future<void> setSchoolLabel(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_schoolKey, value.trim());
  }
}
