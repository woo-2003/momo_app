import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momo_app/core/constants.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/email_otp_auth_repository.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/auth_repository.dart';
import 'package:momo_app/presentation/screens/main_screen.dart';

// 기존 계정 로그인. 이메일+비밀번호 -> SessionStore -> Main (스택 초기화).
// 기본 repo = EmailOtpAuthRepository.
class LoginFormScreen extends StatefulWidget {
  LoginFormScreen({super.key, AuthRepository? authRepository})
    : authRepository = authRepository ?? EmailOtpAuthRepository();

  final AuthRepository authRepository;

  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

class _LoginFormScreenState extends State<LoginFormScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  bool get _isEmailValid =>
      ValidationPatterns.email.hasMatch(_emailController.text.trim());

  bool get _canSubmit =>
      _isEmailValid && _passwordController.text.isNotEmpty && !_isLoading;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onInputChanged);
    _passwordController.addListener(_onInputChanged);
  }

  void _onInputChanged() => setState(() {});

  Future<void> _onLogin() async {
    if (!_canSubmit) return;

    setState(() => _isLoading = true);

    try {
      final session = await widget.authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 발급받은 세션(JWT)을 기기에 저장한다 → 다음 실행 시 자동 로그인.
      await SessionStore().save(session);

      // ===== [DEBUG] 토큰/로그인 상태 확인용 — 확인 후 이 블록을 삭제하세요 =====
      if (kDebugMode) {
        debugPrint('[LOGIN] 로그인 성공');
        debugPrint(
          '[LOGIN] userId=${session.userId}, nickname=${session.nickname}',
        );
        debugPrint('[LOGIN] token=${session.accessToken}');
        debugPrint('[LOGIN] expiresAt=${session.accessTokenExpiresAt}');
      }
      // ===== [DEBUG] 끝 =====

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onInputChanged);
    _passwordController.removeListener(_onInputChanged);
    _emailController.dispose();
    _passwordController.dispose();
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
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: MomoColors.textMain,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: MomoSpacing.lg),
              const Text('로그인', style: MomoTextStyles.heading),
              const SizedBox(height: MomoSpacing.md),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !_isLoading,
                style: MomoTextStyles.body,
                decoration: const InputDecoration(
                  hintText: 'example@email.com',
                ),
              ),
              const SizedBox(height: MomoSpacing.sm),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_isLoading,
                style: MomoTextStyles.body,
                onSubmitted: (_) => _onLogin(),
                decoration: InputDecoration(
                  hintText: '비밀번호',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: MomoColors.textSub,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MomoSpacing.md),
              ElevatedButton(
                onPressed: _canSubmit ? _onLogin : null,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MomoColors.onPrimary,
                        ),
                      )
                    : const Text('로그인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
