import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/meeting_chat_screen.dart';

/// 복숭아 버튼 → 「내가 가입한 번개」하단 시트.
///
/// - 데이터: listMeetings 전체 → getMeeting → isMember 만 표시
/// - 채팅하기: 시트 유지한 채 채팅 push
/// - 지도 위치: 집결 좌표를 pop → 메인에서 카메라 이동
/// - 합류 지도: 이후 구현 (버튼 비활성)
/// - 높이: 내용만큼 (최대 화면 70%). 예전엔 SizedBox(height: 70%) 고정이라 공백이 큼.
Future<LatLng?> showMyJoinedMeetingsSheet({
  required BuildContext context,
  required MeetingRepository meetingRepository,
}) {
  return showModalBottomSheet<LatLng?>(
    context: context,
    backgroundColor: MomoColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return MyJoinedMeetingsSheet(meetingRepository: meetingRepository);
    },
  );
}

class MyJoinedMeetingsSheet extends StatefulWidget {
  const MyJoinedMeetingsSheet({
    super.key,
    required this.meetingRepository,
  });

  final MeetingRepository meetingRepository;

  @override
  State<MyJoinedMeetingsSheet> createState() => _MyJoinedMeetingsSheetState();
}

class _MyJoinedMeetingsSheetState extends State<MyJoinedMeetingsSheet> {
  late Future<List<MeetingDetail>> _joinedFuture;

  @override
  void initState() {
    super.initState();
    _joinedFuture = _loadJoinedMeetings();
  }

  /// open 목록 → 상세 조회 → 내가 멤버(호스트 포함)인 것만.
  Future<List<MeetingDetail>> _loadJoinedMeetings() async {
    final summaries = await widget.meetingRepository.listMeetings();
    if (summaries.isEmpty) return const [];

    final details = await Future.wait(
      summaries.map(
        (s) => widget.meetingRepository.getMeeting(s.meetingId),
      ),
    );
    return details.where((d) => d.isMember).toList();
  }

  Future<void> _openChat(MeetingDetail meeting) async {
    // 시트는 닫지 않음 (권장: 채팅 후 목록으로 복귀)
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MeetingChatScreen(
          meetingId: meeting.meetingId,
          meetingTitle: meeting.title,
          meetingRepository: widget.meetingRepository,
        ),
      ),
    );
  }

  void _focusOnMap(MeetingDetail meeting) {
    final lat = meeting.latitude;
    final lng = meeting.longitude;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지도에 표시할 위치가 없어요.')),
      );
      return;
    }
    Navigator.of(context).pop(LatLng(lat, lng));
  }

  String _formatStartAt(DateTime startAt) {
    final local = startAt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MomoSpacing.sm,
            MomoSpacing.sm,
            MomoSpacing.sm,
            MomoSpacing.md,
          ),
          child: FutureBuilder<List<MeetingDetail>>(
            future: _joinedFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(MomoSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                final message = snapshot.error is MeetingException
                    ? (snapshot.error! as MeetingException).message
                    : '참여 중인 번개를 불러오지 못했어요.';
                return Padding(
                  padding: const EdgeInsets.all(MomoSpacing.md),
                  child: Text(
                    message,
                    style: MomoTextStyles.body.copyWith(
                      color: MomoColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final joined = snapshot.data ?? const <MeetingDetail>[];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MomoColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: MomoSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🍑', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: MomoSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '내가 가입한 번개',
                              style: MomoTextStyles.heading.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              joined.isEmpty
                                  ? '참여 중인 번개가 없어요.'
                                  : '현재 ${joined.length}개 번개에 참여 중입니다.',
                              style: MomoTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: MomoColors.textSub,
                      ),
                    ],
                  ),
                  const SizedBox(height: MomoSpacing.sm),
                  if (joined.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: MomoSpacing.md,
                      ),
                      child: Text(
                        '지도에서 택시팟에 참여해 보세요.',
                        style: MomoTextStyles.body.copyWith(
                          color: MomoColors.textSub,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: joined.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: MomoSpacing.sm),
                        itemBuilder: (context, index) {
                          final meeting = joined[index];
                          return _JoinedMeetingCard(
                            meeting: meeting,
                            startAtLabel: _formatStartAt(meeting.startAt),
                            onChat: () => _openChat(meeting),
                            onMapLocation: () => _focusOnMap(meeting),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: MomoSpacing.sm),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MomoColors.textMain,
                      side: const BorderSide(color: MomoColors.border),
                      backgroundColor: MomoColors.surface,
                    ),
                    child: const Text('닫기'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _JoinedMeetingCard extends StatelessWidget {
  const _JoinedMeetingCard({
    required this.meeting,
    required this.startAtLabel,
    required this.onChat,
    required this.onMapLocation,
  });

  final MeetingDetail meeting;
  final String startAtLabel;
  final VoidCallback onChat;
  final VoidCallback onMapLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MomoSpacing.sm),
      decoration: BoxDecoration(
        color: MomoColors.surface,
        borderRadius: BorderRadius.circular(MomoRadius.component),
        border: Border.all(color: MomoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MomoSpacing.xs,
                  vertical: MomoSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: MomoColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  meetingCategoryLabel(meeting.category),
                  style: MomoTextStyles.caption.copyWith(
                    color: MomoColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${meeting.currentMembers} / ${meeting.maxMembers}명',
                style: MomoTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: MomoSpacing.xs),
          Text(
            meeting.title,
            style: MomoTextStyles.body.copyWith(fontWeight: FontWeight.w700),
          ),
          if (meeting.placeName != null) ...[
            const SizedBox(height: MomoSpacing.xxs),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: MomoColors.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    meeting.placeName!,
                    style: MomoTextStyles.caption,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: MomoSpacing.xxs),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: MomoColors.primary,
              ),
              const SizedBox(width: 4),
              Text(startAtLabel, style: MomoTextStyles.caption),
            ],
          ),
          const SizedBox(height: MomoSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _CardActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '채팅하기',
                  filled: false,
                  onPressed: onChat,
                ),
              ),
              const SizedBox(width: MomoSpacing.xxs),
              Expanded(
                child: _CardActionButton(
                  icon: Icons.my_location_rounded,
                  label: '합류 지도',
                  filled: true,
                  onPressed: null,
                ),
              ),
              const SizedBox(width: MomoSpacing.xxs),
              Expanded(
                child: _CardActionButton(
                  icon: Icons.place_outlined,
                  label: '지도 위치',
                  filled: false,
                  onPressed: onMapLocation,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    if (filled) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          backgroundColor: enabled ? MomoColors.primary : MomoColors.disabled,
          foregroundColor: MomoColors.onPrimary,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        foregroundColor: MomoColors.textMain,
        side: const BorderSide(color: MomoColors.border),
        backgroundColor: MomoColors.background,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: MomoColors.primary),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
