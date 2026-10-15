import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/meeting_display.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/ended_meetings_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/join_map_screen.dart';
import 'package:momo_app/presentation/screens/meeting_chat_screen.dart';
import 'package:momo_app/presentation/screens/meeting_detail_screen.dart';
import 'package:momo_app/presentation/screens/meeting_ended_screen.dart';
import 'package:momo_app/presentation/utils/meeting_end_helper.dart';

/// 복숭아 버튼 → 「내가 가입한 번개」하단 시트.
/// 색은 [MomoColors]만 사용.
///
/// - 데이터: listMeetings 전체 → getMeeting → isMember 만 표시
/// - 카드 탭 / 영역: 모임 상세
/// - 채팅하기: 시트 유지한 채 채팅 push
/// - 지도 위치: 집결 좌표를 pop → 메인에서 카메라 이동
/// - 합류 지도: JoinMapScreen (로컬 GPS + 더미 멤버, 서버 미연동)
/// - 높이: 내용만큼 (최대 화면 70%).
Future<LatLng?> showMyJoinedMeetingsSheet({
  required BuildContext context,
  required MeetingRepository meetingRepository,
  ValueChanged<int>? onJoinedCount,
}) {
  return showModalBottomSheet<LatLng?>(
    context: context,
    backgroundColor: MomoColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return MyJoinedMeetingsSheet(
        meetingRepository: meetingRepository,
        onJoinedCount: onJoinedCount,
      );
    },
  );
}

class MyJoinedMeetingsSheet extends StatefulWidget {
  const MyJoinedMeetingsSheet({
    super.key,
    required this.meetingRepository,
    this.onJoinedCount,
  });

  final MeetingRepository meetingRepository;
  final ValueChanged<int>? onJoinedCount;

  @override
  State<MyJoinedMeetingsSheet> createState() => _MyJoinedMeetingsSheetState();
}

class _MyJoinedMeetingsSheetState extends State<MyJoinedMeetingsSheet> {
  late Future<_JoinedSheetData> _sheetFuture;
  int _tabIndex = 0; // 0 전체, 1 진행중, 2 종료

  @override
  void initState() {
    super.initState();
    _sheetFuture = _loadSheetData();
  }

  void _reload() {
    setState(() {
      _sheetFuture = _loadSheetData();
    });
  }

  /// open 목록 → 상세 → 멤버만 + 로컬 종료 스냅샷.
  /// 상세 1건 실패해도 시트 전체는 유지 (메인 지도 enrichment 과 동일).
  Future<_JoinedSheetData> _loadSheetData() async {
    final summaries = await widget.meetingRepository.listMeetings();
    final details = <MeetingDetail>[];
    if (summaries.isNotEmpty) {
      final results = await Future.wait(
        summaries.map((s) async {
          try {
            return await widget.meetingRepository.getMeeting(s.meetingId);
          } catch (_) {
            return null;
          }
        }),
      );
      for (final detail in results) {
        if (detail != null) details.add(detail);
      }
    }
    final active = details.where((d) => d.isMember).toList();
    final ended = await EndedMeetingsStore().list();
    // 아직 open 목록에 남아 있으면 종료 탭에서 제외
    final activeIds = active.map((e) => e.meetingId).toSet();
    final endedOnly =
        ended.where((e) => !activeIds.contains(e.meetingId)).toList();

    widget.onJoinedCount?.call(active.length);
    return _JoinedSheetData(active: active, ended: endedOnly);
  }

  Future<void> _openDetail(MeetingDetail meeting) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MeetingDetailScreen(
          meetingId: meeting.meetingId,
          meetingRepository: widget.meetingRepository,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _openChat(
    MeetingDetail meeting, {
    bool forceReadOnly = false,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MeetingChatScreen(
          meetingId: meeting.meetingId,
          meetingTitle: meeting.title,
          meetingRepository: widget.meetingRepository,
          forceReadOnly: forceReadOnly,
        ),
      ),
    );
  }

  Future<void> _endMeeting(MeetingDetail meeting) async {
    final ended = await endMeetingAsHost(
      context: context,
      meetingRepository: widget.meetingRepository,
      meeting: meeting,
    );
    if (ended && mounted) _reload();
  }

  Future<void> _openEndedChat(EndedMeetingSnapshot snap) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MeetingChatScreen(
          meetingId: snap.meetingId,
          meetingTitle: snap.title,
          meetingRepository: widget.meetingRepository,
          forceReadOnly: true,
        ),
      ),
    );
  }

  Future<void> _openEndedSummary(EndedMeetingSnapshot snap) async {
    try {
      final detail =
          await widget.meetingRepository.getMeeting(snap.meetingId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MeetingEndedScreen(
            meeting: detail,
            meetingRepository: widget.meetingRepository,
          ),
        ),
      );
    } on MeetingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _openJoinMap(MeetingDetail meeting) async {
    if (meeting.latitude == null || meeting.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('집결 위치가 없어 합류 지도를 열 수 없어요.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JoinMapScreen(
          meeting: meeting,
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
          child: FutureBuilder<_JoinedSheetData>(
            future: _sheetFuture,
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

              final data = snapshot.data ??
                  const _JoinedSheetData(active: [], ended: []);
              final showActive = _tabIndex != 2;
              final showEnded = _tabIndex != 1;
              final active = data.active;
              final ended = data.ended;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MomoColors.primary.withValues(alpha: 0.45),
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
                              '내 번개 모임',
                              style: MomoTextStyles.heading.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '진행중 ${active.length} · 종료 ${ended.length}',
                              style: MomoTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: MomoColors.surface,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
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
                  const SizedBox(height: MomoSpacing.sm),
                  _SheetTabs(
                    index: _tabIndex,
                    activeCount: active.length,
                    endedCount: ended.length,
                    onChanged: (i) => setState(() => _tabIndex = i),
                  ),
                  const SizedBox(height: MomoSpacing.sm),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (showActive) ...[
                          _SectionLabel(
                            label: '진행중 모임',
                            count: active.length,
                          ),
                          const SizedBox(height: MomoSpacing.xs),
                          if (active.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: MomoSpacing.sm,
                              ),
                              child: Text(
                                '진행 중인 번개가 없어요.',
                                style: MomoTextStyles.caption,
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            ...active.map(
                              (meeting) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: MomoSpacing.sm,
                                ),
                                child: _JoinedMeetingCard(
                                  meeting: meeting,
                                  startAtLabel:
                                      _formatStartAt(meeting.startAt),
                                  onOpenDetail: () => _openDetail(meeting),
                                  onChat: () => _openChat(meeting),
                                  onJoinMap: () => _openJoinMap(meeting),
                                  onMapLocation: () => _focusOnMap(meeting),
                                  onEnd: meeting.isHost
                                      ? () => _endMeeting(meeting)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                        if (showEnded) ...[
                          _SectionLabel(
                            label: '종료된 모임',
                            count: ended.length,
                          ),
                          const SizedBox(height: MomoSpacing.xs),
                          if (ended.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: MomoSpacing.sm,
                              ),
                              child: Text(
                                '종료된 모임이 없어요.',
                                style: MomoTextStyles.caption,
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            ...ended.map(
                              (snap) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: MomoSpacing.sm,
                                ),
                                child: _EndedMeetingCard(
                                  snapshot: snap,
                                  onChat: () => _openEndedChat(snap),
                                  onSummary: () => _openEndedSummary(snap),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: MomoSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: MomoColors.neutralFill,
                      foregroundColor: MomoColors.textMain,
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
                      '닫기',
                      style: MomoTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _JoinedSheetData {
  const _JoinedSheetData({required this.active, required this.ended});

  final List<MeetingDetail> active;
  final List<EndedMeetingSnapshot> ended;
}

class _SheetTabs extends StatelessWidget {
  const _SheetTabs({
    required this.index,
    required this.activeCount,
    required this.endedCount,
    required this.onChanged,
  });

  final int index;
  final int activeCount;
  final int endedCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(int i, String label) {
      final selected = index == i;
      return Expanded(
        child: Material(
          color: selected ? MomoColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          elevation: selected ? 1 : 0,
          shadowColor: MomoColors.textMain.withValues(alpha: 0.08),
          child: InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: MomoTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: MomoColors.textMain,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MomoColors.neutralFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          chip(0, '전체'),
          chip(1, '🟢 진행중 ($activeCount)'),
          chip(2, '🏁 종료 ($endedCount)'),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: MomoTextStyles.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: MomoColors.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count건',
            style: MomoTextStyles.caption.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _JoinedMeetingCard extends StatelessWidget {
  const _JoinedMeetingCard({
    required this.meeting,
    required this.startAtLabel,
    required this.onOpenDetail,
    required this.onChat,
    required this.onJoinMap,
    required this.onMapLocation,
    this.onEnd,
  });

  final MeetingDetail meeting;
  final String startAtLabel;
  final VoidCallback onOpenDetail;
  final VoidCallback onChat;
  final VoidCallback onJoinMap;
  final VoidCallback onMapLocation;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final chip = _categoryChip(meeting);

    return Material(
      color: MomoColors.onPrimary,
      borderRadius: BorderRadius.circular(MomoRadius.component),
      elevation: 1,
      shadowColor: MomoColors.textMain.withValues(alpha: 0.08),
      child: Container(
        padding: const EdgeInsets.all(MomoSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MomoRadius.component),
          border: Border.all(color: MomoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 정보 영역 탭 → 상세 (하단 버튼과 분리)
            InkWell(
              onTap: onOpenDetail,
              borderRadius: BorderRadius.circular(12),
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
                          color: chip.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          chip.label,
                          style: MomoTextStyles.caption.copyWith(
                            color: chip.foreground,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${meeting.currentMembers} / ${meeting.maxMembers}명',
                        style: MomoTextStyles.caption.copyWith(
                          color: MomoColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MomoSpacing.xs),
                  Text(
                    meeting.title,
                    style: MomoTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700),
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
                ],
              ),
            ),
            const SizedBox(height: MomoSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _CardActionButton(
                    icon: Icons.gps_fixed_rounded,
                    label: '합류 지도',
                    variant: _CardActionVariant.joinMap,
                    onPressed: onJoinMap,
                  ),
                ),
                const SizedBox(width: MomoSpacing.xxs),
                Expanded(
                  child: _CardActionButton(
                    icon: Icons.chat_bubble_rounded,
                    label: '채팅방',
                    variant: _CardActionVariant.chat,
                    onPressed: onChat,
                  ),
                ),
                const SizedBox(width: MomoSpacing.xxs),
                Expanded(
                  child: _CardActionButton(
                    icon: onEnd != null
                        ? Icons.flag_rounded
                        : Icons.place_rounded,
                    label: onEnd != null ? '종료' : '지도 위치',
                    variant: onEnd != null
                        ? _CardActionVariant.end
                        : _CardActionVariant.map,
                    onPressed: onEnd ?? onMapLocation,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EndedMeetingCard extends StatelessWidget {
  const _EndedMeetingCard({
    required this.snapshot,
    required this.onChat,
    required this.onSummary,
  });

  final EndedMeetingSnapshot snapshot;
  final VoidCallback onChat;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    final chip = _categoryChipFromKind(
      MeetingDisplay.kindFromFields(category: snapshot.category),
    );
    return Container(
      padding: const EdgeInsets.all(MomoSpacing.sm),
      decoration: BoxDecoration(
        color: MomoColors.onPrimary,
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
                  color: chip.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  chip.label,
                  style: MomoTextStyles.caption.copyWith(
                    color: chip.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '🏁 종료됨',
                style: MomoTextStyles.caption.copyWith(
                  color: MomoColors.textSub,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: MomoSpacing.xs),
          Text(
            snapshot.title,
            style: MomoTextStyles.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${snapshot.placeName ?? '장소 미정'} · 참여 ${snapshot.memberCount}명',
            style: MomoTextStyles.caption,
          ),
          Text(
            '위치공유 OFF · 채팅 30일 보관',
            style: MomoTextStyles.caption.copyWith(fontSize: 11),
          ),
          const SizedBox(height: MomoSpacing.sm),
          ElevatedButton(
            onPressed: onSummary,
            style: ElevatedButton.styleFrom(
              backgroundColor: MomoColors.textMain,
              foregroundColor: MomoColors.onPrimary,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(
                horizontal: MomoSpacing.sm,
                vertical: MomoSpacing.xs,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
            ),
            child: Text(
              '🍑 매너 평가 & 채팅 확인',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MomoTextStyles.button.copyWith(fontSize: 14),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: onChat,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(
                horizontal: MomoSpacing.sm,
                vertical: MomoSpacing.xs,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '채팅만 보기 (읽기 전용)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MomoTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: MomoColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip {
  const _CategoryChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

_CategoryChip _categoryChip(MeetingSummary meeting) =>
    _categoryChipFromKind(MeetingDisplay.kindOf(meeting));

_CategoryChip _categoryChipFromKind(MeetingDisplayKind kind) {
  final label = MeetingDisplay.label(kind);
  switch (kind) {
    case MeetingDisplayKind.taxi:
      return const _CategoryChip(
        label: '택시팟',
        background: MomoColors.taxiGoldSoft,
        foreground: MomoColors.taxiGoldDark,
      );
    case MeetingDisplayKind.sports:
      return _CategoryChip(
        label: label,
        background: MomoColors.primary.withValues(alpha: 0.16),
        foreground: MomoColors.primary,
      );
    case MeetingDisplayKind.meal:
    case MeetingDisplayKind.drink:
    case MeetingDisplayKind.dating:
      return _CategoryChip(
        label: label,
        background: MomoColors.primary.withValues(alpha: 0.12),
        foreground: MomoColors.primary,
      );
    case MeetingDisplayKind.study:
      return _CategoryChip(
        label: label,
        background: MomoColors.success.withValues(alpha: 0.18),
        foreground: MomoColors.textMain,
      );
    case MeetingDisplayKind.hobby:
    case MeetingDisplayKind.other:
      return _CategoryChip(
        label: label,
        background: MomoColors.surface,
        foreground: MomoColors.textSub,
      );
  }
}

enum _CardActionVariant { chat, joinMap, map, end }

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.icon,
    required this.label,
    required this.variant,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final _CardActionVariant variant;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    late final Color bg;
    late final Color fg;
    late final Color? border;

    switch (variant) {
      case _CardActionVariant.chat:
        bg = MomoColors.surface;
        fg = MomoColors.primary;
        border = MomoColors.border;
      case _CardActionVariant.joinMap:
        bg = enabled ? MomoColors.primary : MomoColors.disabled;
        fg = MomoColors.onPrimary;
        border = null;
      case _CardActionVariant.map:
        bg = MomoColors.neutralFill;
        fg = MomoColors.textMain;
        border = null;
      case _CardActionVariant.end:
        bg = MomoColors.background;
        fg = MomoColors.error;
        border = MomoColors.error.withValues(alpha: 0.35);
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(MomoRadius.component),
      elevation: variant == _CardActionVariant.joinMap && enabled ? 2 : 0,
      shadowColor: MomoColors.primary.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(MomoRadius.component),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MomoRadius.component),
            border: border == null ? null : Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
