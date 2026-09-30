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
/// Android 에뮬레이터는 자동 감지되어 `10.0.2.2`(PC localhost)를 쓴다.
/// 실기기만 [devPcLanIp] 를 쓴다.
/// [useAndroidEmulator] 로 강제할 수 있다.
///
/// USB만 쓸 때 대안: `adb reverse tcp:3000 tcp:3000` 후
/// `--dart-define=API_BASE_URL=http://127.0.0.1:3000` (IP 변경 불필요)
class ServerConfig {
  const ServerConfig._();

  // ── 네트워크 바뀔 때 여기 수정 ──────────────────────────────────────
  /// PC의 IPv4 주소 (`ipconfig` → 무선/이더넷 LAN 어댑터 IPv4)
  static const String devPcLanIp = '172.16.110.193'; //변경ip

  /// momo_server 포트 (server.js 기본값과 동일하게 유지)
  static const int devServerPort = 3000;

  /// true 면 항상 에뮬레이터 URL(10.0.2.2).
  /// false 여도 에뮬레이터는 자동 감지되어 10.0.2.2 를 쓴다.
  // 우영: 에뮬인데 emulator=false 로 나와 172.16.98.27 로 붙어 장소검색 실패 → 에뮬 테스트용 true 로 둠.
  // 우영: 실폰 테스트 시 아래 true 를 주석하고 false 줄을 살리기.
  // static const bool useAndroidEmulator = false;
  static const bool useAndroidEmulator = true;
  // ───────────────────────────────────────────────────────────────────

  /// `--dart-define=API_BASE_URL=http://...` 로 실행 시 최우선 적용
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool? _emulatorCache;
  static bool _loggedBaseUrl = false;

  static String get androidEmulatorUrl => 'http://10.0.2.2:$devServerPort';

  static String get androidLanUrl => 'http://$devPcLanIp:$devServerPort';

  /// 현재 URL이 실패했을 때 Android에서 한 번 더 시도할 주소.
  /// 에뮬레이터↔실기기 설정을 반대로 둔 경우 로그인을 살린다.
  static String? androidFallbackBaseUrl(String current) {
    if (kIsWeb || !Platform.isAndroid) return null;
    if (_envBaseUrl.isNotEmpty) return null;
    if (current == androidEmulatorUrl) return androidLanUrl;
    if (current == androidLanUrl) return androidEmulatorUrl;
    return null;
  }

  static bool get looksLikeAndroidEmulator {
    if (kIsWeb || !Platform.isAndroid) return false;
    return _emulatorCache ??= _detectAndroidEmulator();
  }

  static bool _detectAndroidEmulator() {
    const qemuHints = [
      '/dev/qemu_pipe',
      '/dev/goldfish_pipe',
      '/sys/qemu_trace',
    ];
    for (final path in qemuHints) {
      try {
        if (File(path).existsSync()) return true;
      } catch (_) {}
    }

    try {
      final cpu = File('/proc/cpuinfo').readAsStringSync().toLowerCase();
      if (cpu.contains('goldfish') ||
          cpu.contains('ranchu') ||
          cpu.contains('qemu')) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  static String get baseUrl {
    final url = _resolveBaseUrl();
    if (kDebugMode && !_loggedBaseUrl) {
      _loggedBaseUrl = true;
      debugPrint(
        '[ServerConfig] baseUrl=$url emulator=$looksLikeAndroidEmulator',
      );
    }
    return url;
  }

  static String _resolveBaseUrl() {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:$devServerPort';
    if (Platform.isAndroid) {
      if (useAndroidEmulator || looksLikeAndroidEmulator) {
        return androidEmulatorUrl;
      }
      return androidLanUrl;
    }
    return 'http://localhost:$devServerPort';
  }
}
