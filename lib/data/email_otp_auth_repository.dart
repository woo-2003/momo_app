// 실서버 연동 AuthRepository.
// Email/Login/OTP 화면의 기본 구현체.
// findId·changePassword 는 not-implemented.
import 'package:momo_app/core/constants.dart';
import 'package:momo_app/domain/auth_repository.dart';
import 'package:momo_app/service/email_otp_service.dart';

/// [EmailOtpService]를 [AuthRepository] 인터페이스에 맞게 연결한다.
class EmailOtpAuthRepository implements AuthRepository {
  EmailOtpAuthRepository({EmailOtpService? otpService})
    : _otpService = otpService ?? EmailOtpService();

  final EmailOtpService _otpService;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _otpService.login(
        email: email.trim(),
        password: password,
      );
      return AuthSession(
        userId: result.email,
        nickname: result.nickname,
        accessToken: result.token,
        accessTokenExpiresAt: DateTime.now().toUtc().add(
          const Duration(days: 7),
        ),
      );
    } on ApiException catch (e) {
      throw _mapLoginException(e);
    }
  }

  AuthException _mapLoginException(ApiException e) {
    switch (e.statusCode) {
      case 0:
        return AuthException(code: 'network', message: e.message);
      case 401:
        return AuthException(
          code: 'invalid-credentials',
          message: e.message.isNotEmpty ? e.message : '이메일 또는 비밀번호가 올바르지 않습니다.',
        );
      case 400:
        return AuthException(
          code: 'validation',
          message: e.message.isNotEmpty ? e.message : '입력값을 확인해 주세요.',
        );
      default:
        return AuthException(
          code: 'server',
          message: e.message.isNotEmpty ? e.message : '로그인에 실패했습니다.',
        );
    }
  }

  @override
  Future<DateTime> sendOtp({
    required String email,
    required OtpPurpose purpose,
  }) async {
    try {
      await _otpService.sendEmailOtp(email);
      return DateTime.now().toUtc().add(AuthPolicy.otpValidity);
    } on EmailOtpServiceException catch (e) {
      throw _mapSendException(e.result);
    }
  }

  @override
  Future<VerificationToken> verifyOtp({
    required String email,
    required String code,
  }) async {
    final result = await _otpService.verifyEmailOtp(email, code);

    if (result.success) {
      // 클라이언트 opaque 토큰. signup HTTP body에는 안 실리고
      // 서버는 이메일 OTP verified 상태로 가입을 게이트한다.
      return VerificationToken(
        value: 'email-verified:$email',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      );
    }

    throw _mapVerifyException(result);
  }

  @override
  Future<String> findId({required VerificationToken verificationToken}) {
    throw const AuthException(
      code: 'not-implemented',
      message: 'ID 찾기 기능은 준비 중입니다.',
    );
  }

  @override
  Future<void> changePassword({
    required VerificationToken verificationToken,
    required String newPassword,
  }) {
    throw const AuthException(
      code: 'not-implemented',
      message: '비밀번호 변경 기능은 준비 중입니다.',
    );
  }

  @override
  Future<void> checkNicknameAvailability({required String nickname}) async {
    try {
      final available = await _otpService.checkNicknameAvailable(
        nickname.trim(),
      );
      if (!available) {
        throw const AuthException(
          code: 'nickname-taken',
          message: ValidationMessages.nicknameTaken,
        );
      }
    } on ApiException catch (e) {
      if (e.statusCode == 400) {
        throw AuthException(
          code: 'nickname-policy',
          message: e.message.isNotEmpty
              ? e.message
              : ValidationMessages.nicknameRule,
        );
      }
      throw AuthException(
        code: e.statusCode == 0 ? 'network' : 'server',
        message: e.message,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // [변경 2026-08-27] completeSignUp
  // - 이전: birthDate 필수 → _formatBirthdate → signup(birthdate: ...)
  // - 지금: birthDate 없음. signup 에 email/password/nickname 만 전달
  // - _formatBirthdate 헬퍼도 제거됨
  // ---------------------------------------------------------------------------
  @override
  Future<void> completeSignUp({
    required String email,
    required String password,
    required String nickname,
    required VerificationToken verificationToken,
  }) async {
    try {
      await _otpService.signup(
        email: email.trim(),
        password: password,
        nickname: nickname.trim(),
      );
    } on ApiException catch (e) {
      throw _mapSignupException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // [롤백] 변경 전 completeSignUp + _formatBirthdate 전문
  //
  // @override
  // Future<void> completeSignUp({
  //   required String email,
  //   required String password,
  //   required DateTime birthDate,
  //   required String nickname,
  //   required VerificationToken verificationToken,
  // }) async {
  //   try {
  //     await _otpService.signup(
  //       email: email.trim(),
  //       password: password,
  //       nickname: nickname.trim(),
  //       birthdate: _formatBirthdate(birthDate),
  //     );
  //   } on ApiException catch (e) {
  //     throw _mapSignupException(e);
  //   }
  // }
  //
  // String _formatBirthdate(DateTime date) {
  //   final year = date.year.toString().padLeft(4, '0');
  //   final month = date.month.toString().padLeft(2, '0');
  //   final day = date.day.toString().padLeft(2, '0');
  //   return '$year-$month-$day';
  // }
  // ---------------------------------------------------------------------------

  AuthException _mapSignupException(ApiException e) {
    switch (e.statusCode) {
      case 0:
        return AuthException(code: 'network', message: e.message);
      case 403:
        return AuthException(
          code: 'email-not-verified',
          message: e.message.isNotEmpty ? e.message : '이메일 인증이 필요합니다.',
        );
      case 409:
        return AuthException(
          code: 'conflict',
          message: e.message.isNotEmpty ? e.message : '이미 가입된 정보입니다.',
        );
      case 400:
        return AuthException(
          code: 'validation',
          message: e.message.isNotEmpty ? e.message : '입력값을 확인해 주세요.',
        );
      default:
        return AuthException(
          code: 'server',
          message: e.message.isNotEmpty ? e.message : '회원가입에 실패했습니다.',
        );
    }
  }

  AuthException _mapSendException(EmailOtpResult result) {
    switch (result.errorType) {
      case EmailOtpErrorType.tooManyRequests:
        return const AuthException(
          code: 'rate-limited',
          message: '재전송 제한: 잠시 후 다시 시도하세요.',
        );
      case EmailOtpErrorType.alreadyVerified:
        return const AuthException(
          code: 'email-already-used',
          message: '이미 인증이 완료된 이메일입니다.',
        );
      case EmailOtpErrorType.network:
        return AuthException(code: 'network', message: result.message);
      case EmailOtpErrorType.server:
        return AuthException(code: 'server', message: result.message);
      case EmailOtpErrorType.invalidCode:
      case EmailOtpErrorType.expired:
      case EmailOtpErrorType.notFound:
      case EmailOtpErrorType.unknown:
      case null:
        return AuthException(
          code: 'unknown',
          message: result.message.isNotEmpty
              ? result.message
              : '알 수 없는 오류가 발생했습니다.',
        );
    }
  }

  AuthException _mapVerifyException(EmailOtpResult result) {
    switch (result.errorType) {
      case EmailOtpErrorType.invalidCode:
        return const AuthException(
          code: 'otp-invalid',
          message: ValidationMessages.otpInvalid,
        );
      case EmailOtpErrorType.expired:
        return const AuthException(
          code: 'otp-expired',
          message: '인증번호가 만료되었습니다. 다시 전송해 주세요.',
        );
      case EmailOtpErrorType.notFound:
        return const AuthException(
          code: 'otp-expired',
          message: '인증번호를 먼저 전송해 주세요.',
        );
      case EmailOtpErrorType.alreadyVerified:
        return const AuthException(
          code: 'email-already-used',
          message: '이미 인증이 완료된 이메일입니다.',
        );
      case EmailOtpErrorType.tooManyRequests:
        return const AuthException(
          code: 'rate-limited',
          message: '잠시 후 다시 시도해 주세요.',
        );
      case EmailOtpErrorType.network:
        return AuthException(code: 'network', message: result.message);
      case EmailOtpErrorType.server:
        return AuthException(code: 'server', message: result.message);
      case EmailOtpErrorType.unknown:
      case null:
        return AuthException(
          code: 'unknown',
          message: result.message.isNotEmpty
              ? result.message
              : '알 수 없는 오류가 발생했습니다.',
        );
    }
  }
}
