import 'package:flutter/material.dart';
import 'package:momo_app/core/map_location_helper.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/meeting_chat_screen.dart';

/// 모임 상세 (시트 「상세정보 보기」에서 진입).
/// 택시팟은 시안 참고 레이아웃. 위치 권한 없을 때 참여 CTA는 동의 게이트 후 join.
class MeetingDetailScreen extends StatefulWidget {
  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
    required this.meetingRepository,
  });

  final String meetingId;
  final MeetingRepository meetingRepository;

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  late Future<MeetingDetail> _detailFuture;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _detailFuture = widget.meetingRepository.getMeeting(widget.meetingId);
    });
  }

  /// leave / cancel 등 — 성공 시 pop(true)로 시트·메인 마커 갱신.
  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _isWorking = true);
    try {
      await action();
      _reload();
      if (mounted) Navigator.of(context).pop(true);
    } on MeetingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  /// 참여: 위치 동의 → join → 채팅 진입 → 뒤로 오면 상세도 닫으며 갱신 신호.
  Future<void> _onJoinPressed(MeetingDetail detail) async {
    final allowed = await MapLocationHelper.ensurePermissionForJoin(context);
    if (!allowed || !mounted) return;

    setState(() => _isWorking = true);
    try {
      await widget.meetingRepository.joinMeeting(widget.meetingId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('택시팟에 참여했어요.')),
      );

      // --- [롤백용] 참여 후 바로 pop 만 ---
      // _reload();
      // if (mounted) Navigator.of(context).pop(true);

      // 멤버가 됐으므로 채팅으로 이어줌 (시안: 참여 후 채팅 잠금 해제)
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MeetingChatScreen(
            meetingId: widget.meetingId,
            meetingTitle: detail.title,
            meetingRepository: widget.meetingRepository,
          ),
        ),
      );
      if (!mounted) return;
      // 채팅에서 돌아옴 → 시트/메인 마커 갱신
      Navigator.of(context).pop(true);
    } on MeetingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('참여에 실패했어요.')),
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  // --- [롤백용] 위치 게이트만 하고 _runAction(join) ---
  // Future<void> _onJoinPressed() async {
  //   final allowed = await MapLocationHelper.ensurePermissionForJoin(context);
  //   if (!allowed || !mounted) return;
  //   await _runAction(
  //     () => widget.meetingRepository.joinMeeting(widget.meetingId),
  //   );
  // }

  Future<void> _openChat(MeetingDetail detail) async {
    // 비멤버: 앱바 채팅은 잠금 UI. 여기로 오면 안내만.
    if (!detail.isMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('참여 후 채팅에 입장할 수 있습니다.')),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MeetingChatScreen(
          meetingId: widget.meetingId,
          meetingTitle: detail.title,
          meetingRepository: widget.meetingRepository,
        ),
      ),
    );
  }

  String _formatStartAt(DateTime startAt) {
    final local = startAt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      // --- [롤백용] 단순 AppBar ---
      // appBar: AppBar(
      //   backgroundColor: MomoColors.background,
      //   elevation: 0,
      //   title: const Text('모임 상세', style: MomoTextStyles.heading),
      // ),
      body: FutureBuilder<MeetingDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            final message = snapshot.error is MeetingException
                ? (snapshot.error! as MeetingException).message
                : '모임 정보를 불러오지 못했습니다.';
            return SafeArea(
              child: Center(child: Text(message)),
            );
          }

          final detail = snapshot.data!;
          // --- [롤백용] 예전 단순 리스트 UI ---
          // return _buildLegacyBody(detail);

          return _buildMeetingInfoBody(detail);
        },
      ),
    );
  }

  /// 시안 참고: 모임 정보 (택시팟 참여 흐름).
  Widget _buildMeetingInfoBody(MeetingDetail detail) {
    final destination = detail.categoryFields['destinationName'];
    final destinationLabel =
        destination is String && destination.trim().isNotEmpty
            ? destination.trim()
            : null;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 앱바: 뒤로 / 제목 / 채팅(잠금 or 열림) ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MomoSpacing.xs,
              MomoSpacing.xxs,
              MomoSpacing.xs,
              0,
            ),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: MomoColors.textMain,
                  ),
                  label: Text(
                    '뒤로',
                    style: MomoTextStyles.body.copyWith(
                      color: MomoColors.textMain,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '모임 정보',
                    textAlign: TextAlign.center,
                    style: MomoTextStyles.heading.copyWith(fontSize: 18),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isWorking ? null : () => _openChat(detail),
                  icon: Icon(
                    detail.isMember
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.lock_outline_rounded,
                    color: detail.isMember
                        ? MomoColors.primary
                        : MomoColors.textDisabled,
                    size: 20,
                  ),
                  label: Text(
                    '채팅',
                    style: MomoTextStyles.caption.copyWith(
                      color: detail.isMember
                          ? MomoColors.textMain
                          : MomoColors.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: MomoSpacing.sm),
                  // ── 제목 + 모집 상태 ───────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.category == MeetingCategory.taxi ? '🚕 ' : '',
                        style: const TextStyle(fontSize: 22),
                      ),
                      Expanded(
                        child: Text(
                          detail.title,
                          style: MomoTextStyles.heading,
                        ),
                      ),
                      if (detail.status == 'open')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MomoSpacing.xs,
                            vertical: MomoSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: MomoColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '모집 중',
                            style: MomoTextStyles.caption.copyWith(
                              color: MomoColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (destinationLabel != null) ...[
                    const SizedBox(height: MomoSpacing.xxs),
                    Text(
                      '도착: $destinationLabel',
                      style: MomoTextStyles.caption,
                    ),
                  ],
                  const SizedBox(height: MomoSpacing.md),
                  // ── 약속 장소 카드 ─────────────────────────────────────
                  _InfoCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: MomoColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: MomoSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '약속 장소',
                                style: MomoTextStyles.caption,
                              ),
                              const SizedBox(height: MomoSpacing.xxs),
                              Text(
                                detail.placeName ?? '장소 미정',
                                style: MomoTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MomoSpacing.sm),
                  // ── 시각·인원 카드 ─────────────────────────────────────
                  _InfoCard(
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.schedule_rounded,
                          label: '약속 시각',
                          value: _formatStartAt(detail.startAt),
                          valueColor: MomoColors.primary,
                        ),
                        const SizedBox(height: MomoSpacing.sm),
                        _InfoRow(
                          icon: Icons.people_outline_rounded,
                          label: '참여 인원 현황',
                          value:
                              '${detail.currentMembers} / ${detail.maxMembers}명',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MomoSpacing.md),
                  // ── 참가자 아바타 ──────────────────────────────────────
                  Text('현재 참가자', style: MomoTextStyles.caption),
                  const SizedBox(height: MomoSpacing.xs),
                  if (detail.members.isEmpty)
                    Text(
                      '아직 참가자가 없어요.',
                      style: MomoTextStyles.caption,
                    )
                  else
                    // 아바타(40) + 간격 + 닉네임 한 줄 → 고정 높이 여유 있게
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: detail.members.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: MomoSpacing.xs),
                        itemBuilder: (context, index) {
                          final member = detail.members[index];
                          final initial = member.nickname.isNotEmpty
                              ? member.nickname.substring(0, 1)
                              : '?';
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: MomoColors.primary,
                                child: Text(
                                  initial,
                                  style: MomoTextStyles.body.copyWith(
                                    color: MomoColors.onPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                width: 48,
                                child: Text(
                                  member.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: MomoTextStyles.caption.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  if (detail.description.isNotEmpty) ...[
                    const SizedBox(height: MomoSpacing.md),
                    Text(detail.description, style: MomoTextStyles.body),
                  ],
                  const SizedBox(height: MomoSpacing.xxl),
                ],
              ),
            ),
          ),
          // ── 하단 CTA (역할별) ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MomoSpacing.md,
              MomoSpacing.xs,
              MomoSpacing.md,
              MomoSpacing.md,
            ),
            child: _buildBottomActions(detail),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(MeetingDetail detail) {
    // 비멤버: 참여하기 (위치 동의 게이트 포함)
    if (!detail.isMember) {
      return ElevatedButton(
        onPressed: _isWorking ? null : () => _onJoinPressed(detail),
        child: const Text('참여하기'),
      );
    }

    // 호스트: 채팅 + 모임 취소
    if (detail.isHost) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _isWorking ? null : () => _openChat(detail),
            child: const Text('채팅 열기'),
          ),
          const SizedBox(height: MomoSpacing.xs),
          OutlinedButton(
            onPressed: _isWorking
                ? null
                : () => _runAction(
                      () => widget.meetingRepository.cancelMeeting(
                        widget.meetingId,
                      ),
                    ),
            child: const Text('모임 취소'),
          ),
        ],
      );
    }

    // 일반 멤버: 채팅 + 나가기
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _isWorking ? null : () => _openChat(detail),
          child: const Text('채팅 열기'),
        ),
        const SizedBox(height: MomoSpacing.xs),
        OutlinedButton(
          onPressed: _isWorking
              ? null
              : () => _runAction(
                    () => widget.meetingRepository.leaveMeeting(
                      widget.meetingId,
                    ),
                  ),
          child: const Text('나가기'),
        ),
      ],
    );
  }

  // --- [롤백용] 예전 단순 상세 본문 (AppBar + 리스트 CTA) ---
  // Widget _buildLegacyBody(MeetingDetail detail) {
  //   return Padding(
  //     padding: const EdgeInsets.all(MomoSpacing.md),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.stretch,
  //       children: [
  //         Text(detail.title, style: MomoTextStyles.heading),
  //         const SizedBox(height: MomoSpacing.xs),
  //         Text(
  //           '${meetingCategoryLabel(detail.category)} · ${detail.currentMembers}/${detail.maxMembers}명',
  //           style: MomoTextStyles.caption.copyWith(color: MomoColors.textSub),
  //         ),
  //         if (detail.description.isNotEmpty) ...[
  //           const SizedBox(height: MomoSpacing.sm),
  //           Text(detail.description, style: MomoTextStyles.body),
  //         ],
  //         if (detail.placeName != null) ...[
  //           const SizedBox(height: MomoSpacing.sm),
  //           Text('장소: ${detail.placeName}', style: MomoTextStyles.body),
  //         ],
  //         const SizedBox(height: MomoSpacing.md),
  //         if (!detail.isMember)
  //           ElevatedButton(
  //             onPressed: _isWorking
  //                 ? null
  //                 : () => _runAction(
  //                       () => widget.meetingRepository.joinMeeting(
  //                         widget.meetingId,
  //                       ),
  //                     ),
  //             child: const Text('참여하기'),
  //           ),
  //         if (detail.isMember && !detail.isHost)
  //           OutlinedButton(
  //             onPressed: _isWorking
  //                 ? null
  //                 : () => _runAction(
  //                       () => widget.meetingRepository.leaveMeeting(
  //                         widget.meetingId,
  //                       ),
  //                     ),
  //             child: const Text('나가기'),
  //           ),
  //         if (detail.isHost)
  //           OutlinedButton(
  //             onPressed: _isWorking
  //                 ? null
  //                 : () => _runAction(
  //                       () => widget.meetingRepository.cancelMeeting(
  //                         widget.meetingId,
  //                       ),
  //                     ),
  //             child: const Text('모임 취소'),
  //           ),
  //         if (detail.isMember) ...[
  //           const SizedBox(height: MomoSpacing.sm),
  //           ElevatedButton(
  //             onPressed: _isWorking ? null : () => _openChat(detail),
  //             child: const Text('채팅 열기'),
  //           ),
  //         ],
  //         const SizedBox(height: MomoSpacing.md),
  //         Text('참여자', style: MomoTextStyles.body),
  //         const SizedBox(height: MomoSpacing.xs),
  //         Expanded(
  //           child: ListView.separated(
  //             itemCount: detail.members.length,
  //             separatorBuilder: (_, __) =>
  //                 const SizedBox(height: MomoSpacing.xxs),
  //             itemBuilder: (context, index) {
  //               final member = detail.members[index];
  //               return Text(
  //                 '${member.nickname} (${member.role})',
  //                 style: MomoTextStyles.caption,
  //               );
  //             },
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

/// 모임 정보용 라운드 카드 (theme surface + border).
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MomoSpacing.sm),
      decoration: BoxDecoration(
        color: MomoColors.surface,
        borderRadius: BorderRadius.circular(MomoRadius.component),
        border: Border.all(color: MomoColors.border),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MomoColors.textSub),
        const SizedBox(width: MomoSpacing.xs),
        Expanded(
          child: Text(label, style: MomoTextStyles.caption),
        ),
        Text(
          value,
          style: MomoTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor ?? MomoColors.textMain,
          ),
        ),
      ],
    );
  }
}
