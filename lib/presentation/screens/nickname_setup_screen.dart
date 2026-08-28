import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momo_app/core/constants.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/email_otp_auth_repository.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/auth_repository.dart';
import 'package:momo_app/presentation/screens/onboarding_screen.dart';
// [롤백] 온보딩 없이 메인 직행할 때:
// import 'package:momo_app/presentation/screens/main_screen.dart';
// [롤백용] fallback 을 Mock 으로 되돌릴 때:
// import 'package:momo_app/data/mock_auth_repository.dart';

// =============================================================================
// [변경] 가입 플로우에서 생년월일 제거 (2026-08-27)
// - 이전: 생성자에 required DateTime birthDate 있었고 completeSignUp 에 전달
// - 지금: birthDate 인자 삭제. 비밀번호 화면에서 바로 진입
// - fallback: MockAuthRepository → EmailOtpAuthRepository
// - PASS 붙이면 이 화면 앞(비밀번호 뒤)에 신원 화면 추가하면 됨
// - [온보딩] 가입 성공 후 Main 대신 OnboardingScreen (항상 3장)
// =============================================================================
// [롤백] 변경 전 생성자/필드 전문:
// class NicknameSetupScreen extends StatefulWidget {
//   NicknameSetupScreen({
//     super.key,
//     required this.email,
//     required this.verificationToken,
//     required this.password,
//     required this.birthDate,
//     AuthRepository? authRepository,
//   }) : authRepository = authRepository ?? MockAuthRepository();
//
//   final String email;
//   final VerificationToken verificationToken;
//   final String password;
//   final DateTime birthDate;
//   final AuthRepository authRepository;
//   ...
// }
// =============================================================================
enum _NicknameCheckStatus { idle, checking, available, taken }

class NicknameSetupScreen extends StatefulWidget {
  NicknameSetupScreen({
    super.key,
    required this.email,
    required this.verificationToken,
    required this.password,
    // [변경] birthDate 파라미터 제거됨
    // required this.birthDate, // [롤백] 이 줄 살리고 아래 final 도 살릴 것
    AuthRepository? authRepository,
  }) : authRepository = authRepository ?? EmailOtpAuthRepository();
  // [롤백] }) : authRepository = authRepository ?? MockAuthRepository();

  final String email;
  final VerificationToken verificationToken;
  final String password;
  // [변경] final DateTime birthDate; 삭제됨
  // final DateTime birthDate; // [롤백]
  final AuthRepository authRepository;

  @override
  State<NicknameSetupScreen> createState() => _NicknameSetupScreenState();
}

class _NicknameSetupScreenState extends State<NicknameSetupScreen> {
  final _nicknameController = TextEditingController();

  _NicknameCheckStatus _checkStatus = _NicknameCheckStatus.idle;
  String? _checkedNickname;
  bool _isCompleting = false;

  bool get _isNicknameLengthValid {
    final length = _nicknameController.text.trim().length;
    return length >= AuthPolicy.nicknameMinLength &&
        length <= AuthPolicy.nicknameMaxLength;
  }

  bool get _canCheckDuplicate =>
      _isNicknameLengthValid && _checkStatus != _NicknameCheckStatus.checking;

  bool get _canComplete =>
      _checkStatus == _NicknameCheckStatus.available &&
      _checkedNickname == _nicknameController.text.trim() &&
      !_isCompleting;

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_onNicknameChanged);
  }

  void _onNicknameChanged() {
    final nickname = _nicknameController.text.trim();
    if (_checkedNickname != null && nickname != _checkedNickname) {
      setState(() {
        _checkStatus = _NicknameCheckStatus.idle;
        _checkedNickname = null;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _onCheckDuplicate() async {
    if (!_canCheckDuplicate) return;

    final nickname = _nicknameController.text.trim();

    setState(() => _checkStatus = _NicknameCheckStatus.checking);

    try {
      await widget.authRepository.checkNicknameAvailability(
        nickname: nickname,
      );

      if (!mounted) return;
      setState(() {
        _checkStatus = _NicknameCheckStatus.available;
        _checkedNickname = nickname;
      });
    } on AuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'nickname-taken') {
        setState(() {
          _checkStatus = _NicknameCheckStatus.taken;
          _checkedNickname = nickname;
        });
      } else {
        setState(() => _checkStatus = _NicknameCheckStatus.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _onComplete() async {
    if (!_canComplete) return;

    setState(() => _isCompleting = true);

    try {
      // [변경] completeSignUp 에서 birthDate 인자 제거. 아래처럼만 호출.
      await widget.authRepository.completeSignUp(
        email: widget.email,
        password: widget.password,
        nickname: _nicknameController.text.trim(),
        verificationToken: widget.verificationToken,
      );
      // -----------------------------------------------------------------
      // [롤백] 변경 전 completeSignUp 호출
      // await widget.authRepository.completeSignUp(
      //   email: widget.email,
      //   password: widget.password,
      //   birthDate: widget.birthDate,
      //   nickname: _nicknameController.text.trim(),
      //   verificationToken: widget.verificationToken,
      // );
      // -----------------------------------------------------------------

      // 가입 직후 동일 계정으로 자동 로그인하여 세션(JWT)을 확보·저장한다.
      // 자동 로그인이 실패하더라도 가입 자체는 완료된 것이므로 메인으로 진행한다.
      try {
        final session = await widget.authRepository.login(
          email: widget.email,
          password: widget.password,
        );
        await SessionStore().save(session);

        // ===== [DEBUG] 가입 후 토큰 발급 확인용 — 확인 후 이 블록을 삭제하세요 =====
        if (kDebugMode) {
          debugPrint('[SIGNUP] 가입 + 자동 로그인 성공');
          debugPrint('[SIGNUP] userId=${session.userId}, nickname=${session.nickname}');
          debugPrint('[SIGNUP] token=${session.accessToken}');
          debugPrint('[SIGNUP] expiresAt=${session.accessTokenExpiresAt}');
        }
        // ===== [DEBUG] 끝 =====
      } catch (e) {
        // ===== [DEBUG] 자동 로그인 실패 확인용 — 확인 후 이 블록을 삭제하세요 =====
        if (kDebugMode) {
          debugPrint('[SIGNUP] 가입은 성공했으나 자동 로그인 실패: $e');
        }
        // ===== [DEBUG] 끝 =====
      }

      if (!mounted) return;
      // [변경] 가입 직후 메인 대신 온보딩 3장 (항상 표시, 건너뛰기 가능)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
      // [롤백] 온보딩 없이 메인으로:
      // Navigator.of(context).pushAndRemoveUntil(
      //   MaterialPageRoute<void>(builder: (_) => const MainScreen()),
      //   (route) => false,
      // );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_onNicknameChanged);
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _isCompleting
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: MomoColors.textMain,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: MomoSpacing.lg),
              const Text(
                '사용할 닉네임을 설정하세요',
                style: MomoTextStyles.heading,
              ),
              const SizedBox(height: MomoSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nicknameController,
                      enabled: !_isCompleting &&
                          _checkStatus != _NicknameCheckStatus.checking,
                      style: MomoTextStyles.body,
                      decoration: const InputDecoration(
                        hintText: ValidationMessages.nicknameRule,
                      ),
                    ),
                  ),
                  const SizedBox(width: MomoSpacing.xs),
                  OutlinedButton(
                    onPressed: _canCheckDuplicate ? _onCheckDuplicate : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: MomoColors.surface,
                      foregroundColor: MomoColors.primary,
                      disabledForegroundColor: MomoColors.textDisabled,
                      side: BorderSide.none,
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: MomoSpacing.sm,
                      ),
                      shape: MomoRadius.shape,
                      textStyle: MomoTextStyles.caption.copyWith(
                        color: MomoColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: _checkStatus == _NicknameCheckStatus.checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MomoColors.primary,
                            ),
                          )
                        : const Text('중복 확인'),
                  ),
                ],
              ),
              if (_checkStatus == _NicknameCheckStatus.available) ...[
                const SizedBox(height: MomoSpacing.xs),
                Text(
                  ValidationMessages.nicknameAvailable,
                  style: MomoTextStyles.caption.copyWith(
                    color: MomoColors.success,
                  ),
                ),
              ],
              if (_checkStatus == _NicknameCheckStatus.taken) ...[
                const SizedBox(height: MomoSpacing.xs),
                Text(
                  ValidationMessages.nicknameTaken,
                  style: MomoTextStyles.caption.copyWith(
                    color: MomoColors.error,
                  ),
                ),
              ],
              const SizedBox(height: MomoSpacing.sm),
              ElevatedButton(
                onPressed: _canComplete ? _onComplete : null,
                child: _isCompleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MomoColors.onPrimary,
                        ),
                      )
                    : const Text('가입 완료'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
