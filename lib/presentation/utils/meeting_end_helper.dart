import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/ended_meetings_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/meeting_ended_screen.dart';

/// 호스트 모임 종료: 확인 → cancel API → 로컬 스냅샷 → 종료 화면.
Future<bool> endMeetingAsHost({
  required BuildContext context,
  required MeetingRepository meetingRepository,
  required MeetingDetail meeting,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: MomoColors.background,
        title: Text(
          '모임을 종료할까요?',
          style: MomoTextStyles.heading.copyWith(fontSize: 18),
        ),
        content: Text(
          '종료 후 위치 공유가 꺼지고 채팅은 읽기 전용으로 바뀝니다.\n(서버: cancel API)',
          style: MomoTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: MomoColors.primary),
            child: const Text('종료'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return false;

  try {
    await meetingRepository.cancelMeeting(meeting.meetingId);
    await EndedMeetingsStore().upsert(
      EndedMeetingSnapshot.fromDetail(meeting),
    );
    if (!context.mounted) return true;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MeetingEndedScreen(
          meeting: meeting,
          meetingRepository: meetingRepository,
        ),
      ),
    );
    return true;
  } on MeetingException catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
    return false;
  }
}
