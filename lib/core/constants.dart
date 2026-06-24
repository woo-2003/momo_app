/// momo 앱 전역 상수
///
/// 검증 규칙, 정책성 수치, 라우트 경로 등 값으로서 고정되어야 하는 것만 모아놨음
/// UI 토큰(컬러/간격)은 `theme.dart`에 저장

/// 앱 메타 정보
class AppMeta {
  const AppMeta._();

  static const String name = 'momo';
  static const String fullName = '모든 모임';
  static const String description = '대학생 모임 앱';
}

/// 인증 정책
///
/// - ID  : 영문 + 숫자, 4~20자 (영문 시작 권장 / 단독 영문 또는 숫자 허용)
/// - PW  : 영문 + 숫자 조합, 최소 8자
/// - OTP : 6자리 숫자, 5분 유효
class AuthPolicy {
  const AuthPolicy._();

  static const int idMinLength = 4;
  static const int idMaxLength = 20;
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 32;

  static const int otpLength = 6;
  static const Duration otpValidity = Duration(minutes: 5);
  static const Duration otpResendCooldown = Duration(seconds: 30);

  static const int nicknameMinLength = 2;
  static const int nicknameMaxLength = 10;
}

/// 입력값 검증용 정규식 모음
///
/// 화면 단의 1차 검증용. 서버 측에서도 동일 정책으로 재검증되어야 함
class ValidationPatterns {
  const ValidationPatterns._();

  /// ID: 영문/숫자만, 4~20자
  static final RegExp userId = RegExp(
    '^[a-zA-Z0-9]{${AuthPolicy.idMinLength},${AuthPolicy.idMaxLength}}\$',
  );

  /// PW: 영문과 숫자를 모두 포함, 8~32자
  /// (특수문자/한글 등은 정책 결정 전까지 허용 X — 기획 확정 시 갱신)
  static final RegExp password = RegExp(
    '^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{'
    '${AuthPolicy.passwordMinLength},${AuthPolicy.passwordMaxLength}'
    '}\$',
  );

  /// 이메일 (RFC 5322 단순화 버전)
  static final RegExp email = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  /// OTP: 숫자 6자리
  static final RegExp otpCode = RegExp(r'^\d{6}$');
}

/// 화면에 노출되는 안내 문구의 단일 소스 (오타/일관성 관리)
class ValidationMessages {
  const ValidationMessages._();

  static const String idRule = '영문/숫자 조합 4~20자';
  static const String passwordRule = '영문 + 숫자 포함 8자 이상';
  static const String emailRule = '올바른 이메일 형식이 아닙니다.';
  static const String otpRule = '6자리 숫자를 입력해주세요.';
  static const String otpInvalid = '인증번호가 올바르지 않습니다. 다시 입력해주세요.';
  static const String nicknameRule = '닉네임 입력 (2~10자)';
  static const String nicknameAvailable = '사용 가능한 닉네임입니다!';
  static const String nicknameTaken = '이미 사용 중인 닉네임입니다.';
}
