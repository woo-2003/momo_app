/// momo 인증 도메인 - Repository 인터페이스
///
/// 화면은 AuthRepository 만 의존. 실구현 EmailOtp / UI용 Mock.
/// findId·changePassword 는 인터페이스만 있고 화면·서버 미구현.

///
/// 모든 메서드는 비동기로 동작하며, 실패 시 [AuthException] 을 던진다.
library;

/// ---------------------------------------------------------------------------
/// AuthRepository
/// ---------------------------------------------------------------------------
abstract class AuthRepository {
  /// 로그인
  ///
  /// 입력
  /// - [email]    : 가입에 사용한 이메일
  /// - [password] : 비밀번호
  ///
  /// 반환: 인증 성공 시 발급된 [AuthSession]
  /// 실패: [AuthException]
  ///   - `invalid-credentials` : 이메일/비밀번호 불일치
  ///   - `network`             : 네트워크 오류
  ///   - `server`              : 서버 오류
  Future<AuthSession> login({required String email, required String password});

  /// 이메일로 OTP(6자리 숫자) 전송
  ///
  /// 입력
  /// - [email]   : 인증 받을 이메일
  /// - [purpose] : OTP 사용 목적 (회원가입 / 비번 변경 / ID 찾기)
  ///
  /// 반환: 정상 발송 시 만료 시각 [DateTime] (UTC 기준 권장)
  /// 실패: [AuthException]
  ///   - `email-not-found`     : 비번 변경/ID 찾기에서 등록되지 않은 이메일
  ///   - `email-already-used`  : 회원가입에서 이미 가입된 이메일
  ///   - `rate-limited`        : 재전송 쿨다운 미경과
  Future<DateTime> sendOtp({
    required String email,
    required OtpPurpose purpose,
  });

  /// OTP 검증
  ///
  /// 입력
  /// - [email] : sendOtp 에 사용한 이메일
  /// - [code]  : 사용자가 입력한 6자리 코드
  ///
  /// 반환: 검증 성공 시 발급되는 단기 인증 토큰 ([VerificationToken]).
  ///       회원가입/비밀번호 변경 후속 단계에서 본 토큰을 제출해야 한다.
  /// 실패: [AuthException]
  ///   - `otp-invalid`  : 코드 불일치
  ///   - `otp-expired`  : 유효 시간 초과
  ///   - `otp-attempts` : 시도 횟수 초과
  Future<VerificationToken> verifyOtp({
    required String email,
    required String code,
  });

  /// ID 찾기 (이메일로 등록된 사용자 ID 조회)
  ///
  /// 본 호출은 OTP 검증이 완료된 직후에만 허용한다.
  ///
  /// 입력
  /// - [verificationToken] : verifyOtp 로 발급된 토큰
  ///
  /// 반환: 등록된 사용자 ID
  /// 실패: [AuthException]
  ///   - `token-invalid` : 토큰 위조/만료
  ///   - `user-not-found`: 해당 이메일로 가입된 계정 없음
  Future<String> findId({required VerificationToken verificationToken});

  /// 비밀번호 변경
  ///
  /// OTP 검증을 통과한 사용자의 비밀번호를 새로 설정한다.
  ///
  /// 입력
  /// - [verificationToken] : verifyOtp 로 발급된 토큰
  /// - [newPassword]       : 정책에 부합하는 새 비밀번호
  ///
  /// 실패: [AuthException]
  ///   - `token-invalid`     : 토큰 위조/만료
  ///   - `password-policy`   : 비밀번호 정책 위반
  ///   - `password-reused`   : 직전 비밀번호와 동일
  Future<void> changePassword({
    required VerificationToken verificationToken,
    required String newPassword,
  });

  /// 닉네임 중복 확인
  ///
  /// 입력
  /// - [nickname] : 2~10자
  ///
  /// 사용 가능하면 정상 종료.
  /// 실패: [AuthException]
  ///   - `nickname-taken`  : 이미 사용 중
  ///   - `nickname-policy` : 길이/형식 위반
  Future<void> checkNicknameAvailability({required String nickname});

  /// 회원가입 완료
  ///
  /// OTP 인증을 통과한 이메일로 계정을 생성한다.
  ///
  /// 입력
  /// - [email]             : 인증을 통과한 이메일
  /// - [password]          : 정책에 부합하는 비밀번호 (서버에서 해싱 저장)
  /// - [nickname]          : 2~10자, 중복되지 않은 닉네임
  /// - [verificationToken] : verifyOtp 로 발급된 토큰
  ///
  /// [변경 2026-08-27] birthDate 파라미터 제거.
  ///   앱 가입 플로우에서 생년월일 화면을 빼서 더 이상 받지 않음.
  ///   PASS 연동 시 서버/통신사에서 신원 수신 예정.
  ///
  /// 성공 시 정상 종료.
  /// 실패: [AuthException]
  ///   - `email-not-verified` : 이메일 미인증
  ///   - `conflict`           : 이메일/닉네임 중복
  ///   - `validation`         : 입력값 정책 위반
  ///   - `network` / `server` : 통신/서버 오류
  Future<void> completeSignUp({
    required String email,
    required String password,
    // [변경] required DateTime birthDate 삭제됨
    required String nickname,
    required VerificationToken verificationToken,
  });
  // ---------------------------------------------------------------------------
  // [롤백] 변경 전 시그니처
  // Future<void> completeSignUp({
  //   required String email,
  //   required String password,
  //   required DateTime birthDate,
  //   required String nickname,
  //   required VerificationToken verificationToken,
  // });
  // ---------------------------------------------------------------------------
}

/// ---------------------------------------------------------------------------
/// 보조 타입
/// ---------------------------------------------------------------------------

/// OTP 사용 목적
/// changePassword·findId 는 enum만 존재. 가입(signUp)만 화면에서 사용.
enum OtpPurpose {
  /// 회원가입 - 이메일 인증
  signUp,

  /// 비밀번호 변경 - 본인 확인
  changePassword,

  /// 아이디 찾기 - 본인 확인
  findId,
}

/// OTP 검증 통과 후 발급되는 단기 인증 토큰
///
/// - 후속 API(findId / changePassword / signUp 완료) 호출 시 함께 제출.
/// - 짧은 만료 시간을 가져야 하며, 1회성 사용을 권장한다.
class VerificationToken {
  /// 서버가 발급한 불투명(opaque) 토큰 문자열
  final String value;

  /// 만료 시각 (UTC 권장)
  final DateTime expiresAt;

  const VerificationToken({required this.value, required this.expiresAt});
}

/// 로그인 성공 시 발급되는 세션 정보
class AuthSession {
  /// 로그인 이메일 (표시·식별용)
  final String userId;

  /// 서버 users 문서 ID (= JWT sub). 모임 API 사용자 키.
  final String? accountId;

  /// 표시용 닉네임 (선택)
  final String? nickname;

  /// API 호출용 액세스 토큰
  final String accessToken;

  /// 액세스 토큰 갱신용 (선택)
  final String? refreshToken;

  /// 액세스 토큰 만료 시각 (UTC 권장)
  final DateTime accessTokenExpiresAt;

  const AuthSession({
    required this.userId,
    this.accountId,
    this.nickname,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    this.refreshToken,
  });
}

/// 인증 도메인 공통 예외
///
/// 위 각 메서드의 doc-comment 에 정의된 `code` 문자열을 사용한다.
class AuthException implements Exception {
  /// 기계 판독용 에러 코드 (예: `otp-expired`)
  final String code;

  /// 사용자 노출용/로깅용 메시지
  final String message;

  /// 원인 예외 (네트워크/직렬화 오류 래핑 시)
  final Object? cause;

  const AuthException({required this.code, required this.message, this.cause});

  @override
  String toString() => 'AuthException($code): $message';
}
