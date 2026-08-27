import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/presentation/screens/login_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  // ===== [DEBUG] 임시 로그아웃 =====
  Future<void> _onLogout(BuildContext context) async {
    await SessionStore().clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
  // ===== [DEBUG] 끝 =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.md),
          child: Column(
            children: [
              // ===== [DEBUG] 임시 로그아웃 버튼 =====
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _onLogout(context),
                  child: Text(
                    '로그아웃',
                    style: MomoTextStyles.caption.copyWith(
                      color: MomoColors.textSub,
                    ),
                  ),
                ),
              ),
              // ===== [DEBUG] 끝 =====
              const Spacer(),
              Text(
                '무슨 지도 API쓸건지 기획서에 없어서 비워둠', //결정되면 지우기 google map api 사용
                textAlign: TextAlign.center,
                style: MomoTextStyles.body.copyWith(color: MomoColors.textSub),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
