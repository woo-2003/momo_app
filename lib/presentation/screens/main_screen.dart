import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/presentation/screens/login_screen.dart';

// 로그인 후 홈. 지도·번개·합류 UI 미구현 (플레이스홀더 문구만).
// 뉴기획서 장면 A(메인 지도) 가 여기로 들어올 예정.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
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
              // 지도 SDK·모임 API 연동 전 스텁.
              Text(
                '무슨 지도 API쓸건지 기획서에 없어서 비워둠',
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
