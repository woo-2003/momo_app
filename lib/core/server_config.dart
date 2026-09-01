import 'dart:io';

import 'package:flutter/foundation.dart';

/// momo_server HTTP / Socket.IO 공통 Base URL.
///
/// ## 네트워크(와이파이·공유기)가 바뀌었을 때
///
/// 1. PC에서 `ipconfig` → **IPv4 주소** 확인
/// 2. 아래 [devPcLanIp] 를 그 주소로 수정
/// 3. (release 빌드 시) `android/.../network_security_config.xml` 의
///    `<domain>` 도 같은 IP로 수정
/// 4. `flutter run` 다시 실행 (hot reload만으로는 URL이 안 바뀜)
///
/// ## 에뮬레이터 vs USB 실기기
///
/// - 에뮬레이터: [useAndroidEmulator] = true  → `10.0.2.2` (PC localhost)
/// - USB/실기기: [useAndroidEmulator] = false → [devPcLanIp] (PC LAN IP)
///
/// USB만 쓸 때 대안: `adb reverse tcp:3000 tcp:3000` 후
/// `--dart-define=API_BASE_URL=http://127.0.0.1:3000` (IP 변경 불필요)
class ServerConfig {
  const ServerConfig._();

  // ── 네트워크 바뀔 때 여기 수정 ──────────────────────────────────────
  /// PC의 IPv4 주소 (`ipconfig` → 무선/이더넷 LAN 어댑터 IPv4)
  static const String devPcLanIp = '172.16.97.117';

  /// momo_server 포트 (server.js 기본값과 동일하게 유지)
  static const int devServerPort = 3000;

  /// true = Android 에뮬레이터, false = USB/실제 폰·태블릿
  static const bool useAndroidEmulator = false;
  // ───────────────────────────────────────────────────────────────────

  /// `--dart-define=API_BASE_URL=http://...` 로 실행 시 최우선 적용
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:$devServerPort';
    if (Platform.isAndroid) {
      if (useAndroidEmulator) {
        return 'http://10.0.2.2:$devServerPort';
      }
      return 'http://$devPcLanIp:$devServerPort';
    }
    return 'http://localhost:$devServerPort';
  }
}
