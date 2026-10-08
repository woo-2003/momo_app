import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/utils/meeting_end_helper.dart';

/// 합류맵에서 전원 도착 시 1회 노출하는 축하 시트.
Future<void> showAllGatheredSheet({
  required BuildContext context,
  required MeetingDetail meeting,
  required MeetingRepository meetingRepository,
  required VoidCallback onOpenChat,
  required VoidCallback onStayOnMap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: MomoColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MomoSpacing.sm,
            MomoSpacing.sm,
            MomoSpacing.sm,
            MomoSpacing.md,
          ),
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
                    color: MomoColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: MomoColors.primary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('🎉', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: MomoSpacing.sm),
              Text(
                '다들 모였어요!',
                style: MomoTextStyles.heading.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MomoSpacing.xs),
              Text(
                '「${meeting.title}」\n전원 집결 완료 · 위치 공유는 합류맵에서 유지돼요.',
                style: MomoTextStyles.caption.copyWith(height: 1.45),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MomoSpacing.md),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onOpenChat();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('채팅 열기'),
                ),
              ),
              const SizedBox(height: MomoSpacing.xs),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onStayOnMap();
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: MomoColors.neutralFill,
                  ),
                  child: const Text('합류맵 계속 보기'),
                ),
              ),
              if (meeting.isHost) ...[
                const SizedBox(height: MomoSpacing.xs),
                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await endMeetingAsHost(
                        context: context,
                        meetingRepository: meetingRepository,
                        meeting: meeting,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: MomoColors.error,
                      minimumSize: const Size(0, 48),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('모임 종료'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
