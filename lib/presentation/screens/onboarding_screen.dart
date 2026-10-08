import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/presentation/screens/main_screen.dart';

// =============================================================================
// 온보딩 (가입 직후 · 메인 직전) — 엑셀 `온보딩` 3장 소개
// - 진입: NicknameSetupScreen 가입 성공 후
// - 종료: 건너뛰기 / 시작하기 → MainScreen (스택 초기화)
// - 선호 설문(S-ONBOARD)은 이번 범위 밖
// =============================================================================

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.emoji,
    required this.badge,
    required this.title,
    required this.description,
  });

  final String emoji;
  final String badge;
  final String title;
  final String description;
}

/// 가입 완료 후 메인 지도 전에 보여주는 3장 온보딩.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      emoji: '🗺️',
      badge: '✨ 내 주변 실시간 모임 탐색',
      title: '내 주변의 모든 모임을\n지도에서 한눈에!',
      description:
          '스터디, 밥약, 스포츠, 취미까지!\n내 위치 근처에서 열리는 다양한 모임을\n실시간 지도 핀으로 탐색하고 참여해보세요.',
    ),
    _OnboardingPageData(
      emoji: '🚕',
      badge: '🚕 동승자 모집 & 알뜰 이동',
      title: '목적지가 같을 땐\n택시팟으로 함께 가요',
      description:
          '동승자를 모아 택시 요금을 알뜰하게 나누고,\n사전 집결 장소에서 안전하게 합승하여 이동하세요.',
    ),
    _OnboardingPageData(
      emoji: '🎉',
      badge: '🚀 시작 준비 완료',
      title: '지금 바로 모든모임을\n시작해보세요!',
      description:
          '이웃들과 함께 만드는 즐거운 소통과 약속!\n아래 버튼을 눌러 모임을 둘러보세요.',
    ),
  ];

  final PageController _pageController = PageController();
  int _index = 0;

  bool get _isFirst => _index == 0;
  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goMain() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => MainScreen()),
      (route) => false,
    );
  }

  void _onNext() {
    if (_isLast) {
      _goMain();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPrev() {
    if (_isFirst) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.md),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) =>
                      _OnboardingPageBody(data: _pages[i]),
                ),
              ),
              _buildDots(),
              const SizedBox(height: MomoSpacing.sm),
              _buildBottomBar(),
              const SizedBox(height: MomoSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: MomoSpacing.xs),
      child: Row(
        children: [
          const Text('🍑', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          Text(
            '모든모임',
            style: MomoTextStyles.heading.copyWith(
              color: MomoColors.textMain,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _goMain,
            style: OutlinedButton.styleFrom(
              foregroundColor: MomoColors.textSub,
              side: const BorderSide(color: MomoColors.border),
              backgroundColor: MomoColors.neutralFill,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(
                horizontal: MomoSpacing.sm,
                vertical: MomoSpacing.xs,
              ),
              shape: const StadiumBorder(),
              textStyle: MomoTextStyles.caption,
            ),
            child: const Text('건너뛰기'),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: MomoSpacing.xxs),
          height: 8,
          width: active ? 24 : 8,
          decoration: BoxDecoration(
            color: active ? MomoColors.primary : MomoColors.disabled,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _buildBottomBar() {
    if (_isFirst) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _onNext,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 56),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('다음'),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: _onPrev,
            style: OutlinedButton.styleFrom(
              foregroundColor: MomoColors.textSub,
              backgroundColor: MomoColors.neutralFill,
              side: const BorderSide(color: MomoColors.border),
              minimumSize: const Size(88, 56),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('이전'),
          ),
        ),
        const SizedBox(width: MomoSpacing.sm),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _onNext,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 56),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(_isLast ? '✨ 시작하기' : '다음'),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingPageBody extends StatelessWidget {
  const _OnboardingPageBody({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 2),
        Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            color: MomoColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: MomoColors.border),
            boxShadow: [
              BoxShadow(
                color: MomoColors.primary.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(data.emoji, style: const TextStyle(fontSize: 56)),
        ),
        const SizedBox(height: MomoSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MomoSpacing.sm,
            vertical: MomoSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: MomoColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            data.badge,
            style: MomoTextStyles.caption.copyWith(
              color: MomoColors.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: MomoSpacing.md),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: MomoTextStyles.heading.copyWith(fontSize: 22, height: 1.35),
        ),
        const SizedBox(height: MomoSpacing.sm),
        Text(
          data.description,
          textAlign: TextAlign.center,
          style: MomoTextStyles.caption.copyWith(
            height: 1.5,
            color: MomoColors.textSub,
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}
