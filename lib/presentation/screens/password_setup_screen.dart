import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/mock_auth_repository.dart';
import 'package:momo_app/domain/auth_repository.dart';
import 'package:momo_app/presentation/screens/birthdate_input_screen.dart';

class PasswordSetupScreen extends StatefulWidget {
  PasswordSetupScreen({
    super.key,
    required this.email,
    required this.verificationToken,
    AuthRepository? authRepository,
  }) : authRepository = authRepository ?? MockAuthRepository();

  final String email;
  final VerificationToken verificationToken;
  final AuthRepository authRepository;

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool get _canContinue {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    return password.isNotEmpty && password == confirm;
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onInputChanged);
    _confirmController.addListener(_onInputChanged);
  }

  void _onInputChanged() => setState(() {});

  void _onContinue() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BirthdateInputScreen(
          email: widget.email,
          verificationToken: widget.verificationToken,
          password: _passwordController.text,
          authRepository: widget.authRepository,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onInputChanged);
    _confirmController.removeListener(_onInputChanged);
    _passwordController.dispose();
    _confirmController.dispose();
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
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: MomoColors.textMain,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: MomoSpacing.lg),
              const Text(
                '비밀번호를 설정하세요',
                style: MomoTextStyles.heading,
              ),
              const SizedBox(height: MomoSpacing.md),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                style: MomoTextStyles.body,
                decoration: InputDecoration(
                  hintText: '비밀번호 입력 (8자 이상)',
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
              const SizedBox(height: MomoSpacing.sm),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                autocorrect: false,
                enableSuggestions: false,
                style: MomoTextStyles.body,
                decoration: InputDecoration(
                  hintText: '비밀번호 확인',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscureConfirm = !_obscureConfirm);
                    },
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: MomoColors.textSub,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MomoSpacing.sm),
              ElevatedButton(
                onPressed: _canContinue ? _onContinue : null,
                child: const Text('계속'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
