import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
<<<<<<< HEAD
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/presentation/screens/login_screen.dart';
=======
>>>>>>> origin/main

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

<<<<<<< HEAD
  // ===== [DEBUG] 임시 로그아웃 — 테스트용, 나중에 이 메서드와 버튼을 삭제하세요 =====
  Future<void> _onLogout(BuildContext context) async {
    await SessionStore().clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
  // ===== [DEBUG] 끝 =====

=======
>>>>>>> origin/main
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
<<<<<<< HEAD
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.md),
          child: Column(
            children: [
              // ===== [DEBUG] 임시 로그아웃 버튼 — 테스트용, 나중에 삭제하세요 =====
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
                '무슨 지도 API쓸건지 기획서에 없어서 비워둠',
                textAlign: TextAlign.center,
                style: MomoTextStyles.body.copyWith(color: MomoColors.textSub),
              ),
              const Spacer(),
            ],
=======
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.md),
          child: Text(
            '무슨 지도 API쓸건지 기획서에 없어서 비워둠',
            textAlign: TextAlign.center,
            style: MomoTextStyles.body.copyWith(color: MomoColors.textSub),
>>>>>>> origin/main
          ),
        ),
      ),
    );
  }
}
