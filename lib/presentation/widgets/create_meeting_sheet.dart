import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';

/// + 버튼으로 열리는 모임 유형 선택 시트.
enum CreateMeetingType { taxi, gathering }

/// 메인 지도에서 모임 만들기 유형을 고르는 바텀 시트.
Future<CreateMeetingType?> showCreateMeetingSheet(BuildContext context) {
  return showModalBottomSheet<CreateMeetingType>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: MomoColors.textMain.withValues(alpha: 0.35),
    builder: (context) => const _CreateMeetingSheet(),
  );
}

class _CreateMeetingSheet extends StatelessWidget {
  const _CreateMeetingSheet();

  static const Color _gatheringAccent = Color(0xFFF2B84B);

  void _close(BuildContext context, [CreateMeetingType? type]) {
    Navigator.of(context).pop(type);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MomoColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(
        MomoSpacing.sm,
        MomoSpacing.xs,
        MomoSpacing.sm,
        MomoSpacing.md,
      ),
      child: SafeArea(
        top: false,
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
                        style: MomoTextStyles.heading.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: MomoSpacing.xxs),
                      Text(
                        '만들고자 하는 모임 유형을 선택하세요.',
                        style: MomoTextStyles.caption.copyWith(
                          color: MomoColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _close(context),
                  icon: const Icon(Icons.close_rounded),
                  color: MomoColors.textSub,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MomoSpacing.md),
            _CreateTypeCard(
              backgroundColor: MomoColors.primary,
              icon: Icons.local_taxi_rounded,
              title: '택시팟 만들기',
              subtitle: '같이 택시 타고 요금 나누기',
              onTap: () => _close(context, CreateMeetingType.taxi),
            ),
            const SizedBox(height: MomoSpacing.sm),
            _CreateTypeCard(
              backgroundColor: _gatheringAccent,
              icon: Icons.handshake_rounded,
              title: '모임 생성 (스터디/밥약/스포츠)',
              subtitle: '함께할 파티원 모집하기',
              onTap: () => _close(context, CreateMeetingType.gathering),
            ),
            const SizedBox(height: MomoSpacing.sm),
            TextButton(
              onPressed: () => _close(context),
              style: TextButton.styleFrom(
                backgroundColor: MomoColors.surface,
                foregroundColor: MomoColors.textSub,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MomoRadius.component),
                  side: const BorderSide(color: MomoColors.border),
                ),
              ),
              child: Text(
                '취소',
                style: MomoTextStyles.body.copyWith(color: MomoColors.textSub),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTypeCard extends StatelessWidget {
  const _CreateTypeCard({
    required this.backgroundColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color backgroundColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: MomoRadius.all,
      elevation: 2,
      shadowColor: backgroundColor.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        borderRadius: MomoRadius.all,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MomoSpacing.sm,
            vertical: MomoSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: MomoColors.onPrimary, size: 28),
              const SizedBox(width: MomoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MomoTextStyles.body.copyWith(
                        color: MomoColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MomoSpacing.xxs),
                    Text(
                      subtitle,
                      style: MomoTextStyles.caption.copyWith(
                        color: MomoColors.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
