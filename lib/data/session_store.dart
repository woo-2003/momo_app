// 로컬 세션 영속. 앱 재실행 시 main._AppEntry 가 read() 로 자동 로그인.
// hasValidSession() 은 정의만 있고 현재 호출처 없음.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:momo_app/domain/auth_repository.dart';

/// 로그인 세션(JWT 등)을 기기에 영속 저장한다.
///
/// 개발 단계에서는 [SharedPreferences] 를 사용한다.
/// 운영 단계에서는 보안 저장소(예: flutter_secure_storage)로 교체를 권장한다.
class SessionStore {
  static const String _key = 'auth_session';

  /// 세션을 저장한다.
  Future<void> save(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode({
      'userId': session.userId,
      'nickname': session.nickname,
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'accessTokenExpiresAt': session.accessTokenExpiresAt.toIso8601String(),
    });
    await prefs.setString(_key, json);
  }

  /// 저장된 세션을 읽는다. 없거나 깨졌으면 null.
  Future<AuthSession?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AuthSession(
        userId: map['userId'] as String,
        nickname: map['nickname'] as String?,
        accessToken: map['accessToken'] as String,
        refreshToken: map['refreshToken'] as String?,
        accessTokenExpiresAt:
            DateTime.parse(map['accessTokenExpiresAt'] as String),
      );
    } catch (_) {
      // 형식이 깨졌으면 폐기한다.
      await prefs.remove(_key);
      return null;
    }
  }

  /// 저장된 세션을 제거한다(로그아웃).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// 저장된 세션이 있고, 액세스 토큰이 아직 만료되지 않았는지 여부.
  Future<bool> hasValidSession() async {
    final session = await read();
    if (session == null) return false;
    return session.accessTokenExpiresAt.isAfter(DateTime.now().toUtc());
  }
}
