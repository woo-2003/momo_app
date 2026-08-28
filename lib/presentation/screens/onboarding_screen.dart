import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/presentation/screens/main_screen.dart';

// =============================================================================
// 온보딩 (가입 직후 · 메인 직전)
// - 진입: NicknameSetupScreen 가입 성공 후 (항상 3장 표시, 별도 "본 적 있음" 저장 없음)
// - 종료: 건너뛰기 / 시작하기 → MainScreen (스택 초기화)
// - 로그인·자동로그인은 이 화면을 거치지 않음
// - 카피·아이콘은 _pages 만 수정하면 됨 (레이아웃 재사용)
// =============================================================================

/// 한 장의 온보딩 콘텐츠. 문구·아이콘 교체 시 여기만 바꾸면 된다.
class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.badge,
    required this.title,
    required this.description,
  });

  final IconData icon;
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
  // 페이지 수·문구 바꿀 때: _pages 길이 = 점 개수와 동일하게 유지
  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      icon: Icons.map_outlined,
      badge: '내 주변 실시간 모임 탐색',
      title: '내 주변의 모든 모임을\n지도에서 한눈에!',
      description:
          '스터디, 밥약, 스포츠까지!\n내 위치 근처에서 열리는 다양한 모임을\n실시간 지도 핀으로 탐색하고 참여해보세요.',
    ),
    _OnboardingPageData(
      icon: Icons.local_taxi_outlined,
      badge: '동승자 모집 & 알뜰 이동',
      title: '목적지가 같을 땐\n택시팟으로 함께 가요',
      description: '동승자를 모아 택시 요금을 알뜰하게 나누고,\n사전 집결 장소에서 안전하게 합승하여 이동하세요.',
    ),
    _OnboardingPageData(
      icon: Icons.celebration_outlined,
      badge: '시작 준비 완료',
      title: '지금 바로 momo를\n시작해보세요!',
      description: '이웃들과 함께 만드는 즐거운 소통과 약속!\n아래 버튼을 눌러 모임을 둘러보세요.',
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
    // 가입 스택(랜딩~닉네임)을 비우고 메인만 남긴다.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainScreen()),
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

  /// 상단: 로그인과 같은 momo 워드마크 + 건너뛰기
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: MomoSpacing.xs),
      child: Row(
        children: [
          Text(
            'momo',
            style: MomoTextStyles.heading.copyWith(
              color: MomoColors.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _goMain,
            style: OutlinedButton.styleFrom(
              foregroundColor: MomoColors.textSub,
              side: const BorderSide(color: MomoColors.border),
              minimumSize: Size.zero,
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
        child: ElevatedButton(onPressed: _onNext, child: const Text('다음')),
      );
    }

    return Row(
      children: [
        TextButton(
          onPressed: _onPrev,
          child: Text(
            '이전',
            style: MomoTextStyles.body.copyWith(color: MomoColors.textSub),
          ),
        ),
        const SizedBox(width: MomoSpacing.sm),
        Expanded(
          child: ElevatedButton(
            onPressed: _onNext,
            child: Text(_isLast ? '시작하기' : '다음'),
          ),
        ),
      ],
    );
  }
}

/// 가운데: 아이콘 카드 + 배지 + 제목 + 설명
class _OnboardingPageBody extends StatelessWidget {
  const _OnboardingPageBody({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 2),
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            color: MomoColors.surface,
            borderRadius: MomoRadius.all,
          ),
          child: Icon(data.icon, size: 56, color: MomoColors.primary),
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
          style: MomoTextStyles.caption.copyWith(height: 1.5),
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}
