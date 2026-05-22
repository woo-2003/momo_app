import 'package:flutter/material.dart';
import 'package:momo_app/core/constants.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/mock_auth_repository.dart';
import 'package:momo_app/domain/auth_repository.dart';
import 'package:momo_app/presentation/screens/otp_input_screen.dart';

//시작하기 누르면 뜨는 이메일 인증받는 화면
class EmailInputScreen extends StatefulWidget {
  EmailInputScreen({super.key, AuthRepository? authRepository})
    : authRepository = authRepository ?? MockAuthRepository();

  final AuthRepository authRepository;

  @override
  State<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends State<EmailInputScreen> {
  final _emailController = TextEditingController();
  bool _isSending = false;

  bool get _isEmailValid =>
      ValidationPatterns.email.hasMatch(_emailController.text.trim());

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() => setState(() {});

  Future<void> _onContinue() async {
    if (!_isEmailValid || _isSending) return;

    final email = _emailController.text.trim();

    setState(() => _isSending = true);

    try {
      await widget.authRepository.sendOtp(
        email: email,
        purpose: OtpPurpose.signUp,
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OtpInputScreen(
            email: email,
            authRepository: widget.authRepository,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
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
                  onPressed: _isSending
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: MomoColors.textMain,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: MomoSpacing.lg),
              const Text('이메일 주소를 입력하세요', style: MomoTextStyles.heading),
              const SizedBox(height: MomoSpacing.md),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !_isSending,
                style: MomoTextStyles.body,
                decoration: const InputDecoration(
                  hintText: 'example@email.com',
                ),
              ),
              const SizedBox(height: MomoSpacing.sm),
              ElevatedButton(
                onPressed: _isEmailValid && !_isSending ? _onContinue : null,
                child: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MomoColors.onPrimary,
                        ),
                      )
                    : const Text('계속'),
              ),
              const Spacer(),
              Text(
                '로그인함으로써 서비스 이용약관 및 개인정보처리방침에 동의하게 됩니다.',
                textAlign: TextAlign.center,
                style: MomoTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: MomoColors.textSub,
                ),
              ),
              const SizedBox(height: MomoSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
