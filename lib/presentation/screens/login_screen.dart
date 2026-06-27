import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/presentation/screens/email_input_screen.dart';
import 'package:momo_app/presentation/screens/login_form_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.md),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Center(
                child: Column(
                  children: [
                    Text(
                      'momo',
                      style: MomoTextStyles.title.copyWith(
                        fontSize: 100,
                        color: MomoColors.primary,
                        letterSpacing: -6,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: MomoSpacing.xs),
                    const Text(
                      '모든 모임, 한 곳에서 자유롭게.',
                      style: MomoTextStyles.body,
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 4),
              Column(
                children: [
                  // 메인 버튼: 시작하기
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EmailInputScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MomoColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(60),
                      elevation: 4,
                      shadowColor: const Color(0xFFE55A4F),
                    ),
                    child: const Text('시작하기'),
                  ),
                  const SizedBox(height: MomoSpacing.sm),

                  // 보조 버튼: 이미 계정이 있습니다
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LoginFormScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: MomoColors.background,
                      foregroundColor: MomoColors.primary,
                      side: const BorderSide(
                        color: MomoColors.border,
                        width: 2,
                      ),
                      minimumSize: const Size.fromHeight(60),
                    ),
                    child: const Text('계정이 이미 있습니다'),
                  ),
                  const SizedBox(height: MomoSpacing.lg),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
