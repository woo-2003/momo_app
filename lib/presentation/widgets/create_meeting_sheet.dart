import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';

/// + 버튼으로 열리는 모임 유형 선택 시트 (도안 made 톤).
/// 색은 [MomoColors]만 사용.
enum CreateMeetingType { taxi, gathering }

/// 메인 지도에서 모임 만들기 유형을 고르는 바텀 시트.
Future<CreateMeetingType?> showCreateMeetingSheet(BuildContext context) {
  return showModalBottomSheet<CreateMeetingType>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: MomoColors.textMain.withValues(alpha: 0.35),
    builder: (context) => const _CreateMeetingSheet(),
  );
}

class _CreateMeetingSheet extends StatelessWidget {
  const _CreateMeetingSheet();

  void _close(BuildContext context, [CreateMeetingType? type]) {
    Navigator.of(context).pop(type);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: MomoColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                MomoSpacing.sm,
                MomoSpacing.xs,
                MomoSpacing.sm,
                MomoSpacing.sm,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: MomoSpacing.sm),
                        decoration: BoxDecoration(
                          color: MomoColors.primary.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: MomoSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '어떤 것을 만드시겠어요?',
                                style: MomoTextStyles.heading.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: MomoSpacing.xxs),
                              Text(
                                '만들고자 하는 개설 유형을 선택하세요.',
                                style: MomoTextStyles.caption.copyWith(
                                  color: MomoColors.textSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: MomoColors.surface,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => _close(context),
                            customBorder: const CircleBorder(),
                            child: const SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: MomoColors.textSub,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MomoSpacing.md),
                    _CreateTypeCard(
                      tint: MomoColors.taxiGoldSoft,
                      accent: MomoColors.taxiGoldDark,
                      icon: Icons.local_taxi_rounded,
                      title: '택시팟 만들기',
                      subtitle: '같이 택시 타고 요금 나누기',
                      onTap: () => _close(context, CreateMeetingType.taxi),
                    ),
                    const SizedBox(height: MomoSpacing.sm),
                    _CreateTypeCard(
                      tint: MomoColors.primary.withValues(alpha: 0.14),
                      accent: MomoColors.primary,
                      icon: Icons.handshake_rounded,
                      title: '모임 생성 (스터디/밥약/스포츠)',
                      subtitle: '함께할 파티원 모집하기',
                      onTap: () =>
                          _close(context, CreateMeetingType.gathering),
                    ),
                    const SizedBox(height: MomoSpacing.sm),
                    TextButton(
                      onPressed: () => _close(context),
                      style: TextButton.styleFrom(
                        backgroundColor: MomoColors.neutralFill,
                        foregroundColor: MomoColors.textSub,
                        elevation: 0,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: MomoSpacing.sm,
                          vertical: MomoSpacing.xs,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            MomoRadius.component,
                          ),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: MomoTextStyles.body.copyWith(
                          color: MomoColors.textSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateTypeCard extends StatelessWidget {
  const _CreateTypeCard({
    required this.tint,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color tint;
  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      borderRadius: MomoRadius.all,
      elevation: 1,
      shadowColor: accent.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: MomoRadius.all,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MomoSpacing.sm,
            vertical: MomoSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: MomoRadius.all,
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: MomoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MomoTextStyles.body.copyWith(
                        color: MomoColors.textMain,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MomoSpacing.xxs),
                    Text(
                      subtitle,
                      style: MomoTextStyles.caption.copyWith(
                        color: MomoColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: accent.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
