import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';

/// [MAIN1] 로그인 화면
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MomoSpacing.md,
            vertical: MomoSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: MomoSpacing.xxl),
              Center(child: _LogoPlaceholder()),
              SizedBox(height: MomoSpacing.xxl),
              _IdField(),
              SizedBox(height: MomoSpacing.sm),
              _PasswordField(),
              SizedBox(height: MomoSpacing.md),
              _LoginButton(),
              SizedBox(height: MomoSpacing.md),
              _AuxiliaryLinks(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 100 x 100 원형 로고 자리 (실제 로고 에셋은 추후 교체)
class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        color: MomoColors.surface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        'momo',
        style: MomoTextStyles.heading.copyWith(color: MomoColors.textSub),
      ),
    );
  }
}

class _IdField extends StatelessWidget {
  const _IdField();

  @override
  Widget build(BuildContext context) {
    return const TextField(
      decoration: InputDecoration(hintText: '아이디'),
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.text,
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField();

  @override
  Widget build(BuildContext context) {
    return const TextField(
      obscureText: true,
      decoration: InputDecoration(hintText: '비밀번호'),
      textInputAction: TextInputAction.done,
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: () {}, child: const Text('로그인'));
  }
}

/// 비밀번호 찾기 | 아이디 찾기 | 회원가입 — 가운데 정렬, 사이에 얇은 세로 구분선.
class _AuxiliaryLinks extends StatelessWidget {
  const _AuxiliaryLinks();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(onPressed: () {}, child: const Text('비밀번호 찾기')),
        const _LinkDivider(),
        TextButton(onPressed: () {}, child: const Text('아이디 찾기')),
        const _LinkDivider(),
        TextButton(onPressed: () {}, child: const Text('회원가입')),
      ],
    );
  }
}

class _LinkDivider extends StatelessWidget {
  const _LinkDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 12, color: MomoColors.border);
  }
}
