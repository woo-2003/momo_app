import 'package:momo_app/core/constants.dart';
import 'package:momo_app/domain/auth_repository.dart';

/// 백엔드 연동 전 프론트 UI·흐름 검증용 Mock.
///
/// - OTP 성공 코드: [validOtpCode] (`123456`)
/// - 그 외 코드 입력 시 `otp-invalid` 발생
class MockAuthRepository implements AuthRepository {
  MockAuthRepository();

  /// Mock 검증 성공 OTP (개발·테스트용)
  static const String validOtpCode = '123456';

  @override
  Future<AuthSession> login({
    required String userId,
    required String password,
  }) {
    throw _notImplemented('login');
  }

  @override
  Future<DateTime> sendOtp({
    required String email,
    required OtpPurpose purpose,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return DateTime.now().toUtc().add(AuthPolicy.otpValidity);
  }

  @override
  Future<VerificationToken> verifyOtp({
    required String email,
    required String code,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (code == validOtpCode) {
      return VerificationToken(
        value: 'mock-verification-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      );
    }

    throw const AuthException(
      code: 'otp-invalid',
      message: ValidationMessages.otpInvalid,
    );
  }

  @override
  Future<String> findId({required VerificationToken verificationToken}) {
    throw _notImplemented('findId');
  }

  @override
  Future<void> changePassword({
    required VerificationToken verificationToken,
    required String newPassword,
  }) {
    throw _notImplemented('changePassword');
  }

  AuthException _notImplemented(String method) => AuthException(
        code: 'network',
        message: '$method 은(는) Mock에서 지원하지 않습니다.',
      );
}
