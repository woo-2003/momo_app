import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/meeting_chat_screen.dart';

/// 모임 종료 안내 + 매너 평가 슬롯 (평가 API 없음 → UI만).
class MeetingEndedScreen extends StatefulWidget {
  const MeetingEndedScreen({
    super.key,
    required this.meeting,
    required this.meetingRepository,
  });

  final MeetingDetail meeting;
  final MeetingRepository meetingRepository;

  @override
  State<MeetingEndedScreen> createState() => _MeetingEndedScreenState();
}

enum _MannerLevel { bad, good, best }

class _MeetingEndedScreenState extends State<MeetingEndedScreen> {
  String? _myId;
  final Map<String, _MannerLevel> _ratings = {};

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final session = await SessionStore().read();
    if (!mounted) return;
    setState(() {
      _myId = session?.accountId ?? session?.userId;
    });
  }

  List<MeetingMember> get _others {
    final me = _myId;
    return widget.meeting.members.where((m) {
      if (me == null) return true;
      return m.userId != me;
    }).toList();
  }

  Future<void> _openChat() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MeetingChatScreen(
          meetingId: widget.meeting.meetingId,
          meetingTitle: widget.meeting.title,
          meetingRepository: widget.meetingRepository,
          forceReadOnly: true,
        ),
      ),
    );
  }

  void _popToMap() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final others = _others;

    return Scaffold(
      backgroundColor: MomoColors.surface,
      appBar: AppBar(
        backgroundColor: MomoColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: MomoColors.textMain,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('← 뒤로'),
        ),
        title: Text(
          '모임 종료',
          style: MomoTextStyles.heading.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(MomoSpacing.sm),
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: MomoColors.primary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('🏁', style: TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(height: MomoSpacing.sm),
            Text(
              '「${widget.meeting.title}」 모임이 종료되었습니다',
              style: MomoTextStyles.heading.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MomoSpacing.xs),
            Text(
              '함께한 멤버들에게 매너 칭찬을 남겨보세요.',
              style: MomoTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MomoSpacing.md),
            Container(
              padding: const EdgeInsets.all(MomoSpacing.sm),
              decoration: BoxDecoration(
                color: MomoColors.background,
                borderRadius: MomoRadius.all,
                border: Border.all(color: MomoColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '🍑 함께한 멤버 매너 평가',
                    style: MomoTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '터치하여 평가를 남겨보세요 (서버 연동 전 · 기기만 저장)',
                    style: MomoTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: MomoSpacing.sm),
                  if (others.isEmpty)
                    Text(
                      '평가할 다른 멤버가 없어요.',
                      style: MomoTextStyles.caption,
                    )
                  else
                    ...others.map((m) => _MemberRateCard(
                          member: m,
                          selected: _ratings[m.userId],
                          onSelect: (level) {
                            setState(() => _ratings[m.userId] = level);
                          },
                        )),
                  const SizedBox(height: MomoSpacing.sm),
                  Text(
                    '약속 미이행 또는 비매너 행동이 있었나요?',
                    style: MomoTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('신고 접수는 서버 연동 후예요.'),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: MomoColors.error,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('🚨 사용자 신고하기'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MomoSpacing.md),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _openChat,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('💬 채팅 내역 확인하기 (읽기 전용)'),
              ),
            ),
            const SizedBox(height: MomoSpacing.xs),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _popToMap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: MomoColors.neutralFill,
                ),
                child: const Text('🗺️ 메인 지도로 돌아가기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRateCard extends StatelessWidget {
  const _MemberRateCard({
    required this.member,
    required this.selected,
    required this.onSelect,
  });

  final MeetingMember member;
  final _MannerLevel? selected;
  final ValueChanged<_MannerLevel> onSelect;

  String get _initial {
    final n = member.nickname.trim();
    if (n.isEmpty) return '?';
    return n.substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: MomoSpacing.sm),
      padding: const EdgeInsets.all(MomoSpacing.sm),
      decoration: BoxDecoration(
        color: MomoColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MomoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: MomoColors.primary,
                child: Text(
                  _initial,
                  style: MomoTextStyles.caption.copyWith(
                    color: MomoColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: MomoSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.nickname,
                      style: MomoTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      member.role == 'host' ? '호스트' : '참여자',
                      style: MomoTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MomoSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _RateChip(
                  label: '🙄 별로에요',
                  selected: selected == _MannerLevel.bad,
                  onTap: () => onSelect(_MannerLevel.bad),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _RateChip(
                  label: '😀 좋아요',
                  selected: selected == _MannerLevel.good,
                  onTap: () => onSelect(_MannerLevel.good),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _RateChip(
                  label: '🥳 최고에요',
                  selected: selected == _MannerLevel.best,
                  onTap: () => onSelect(_MannerLevel.best),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MomoColors.primary : MomoColors.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? MomoColors.primary : MomoColors.border,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? MomoColors.onPrimary : MomoColors.textMain,
            ),
          ),
        ),
      ),
    );
  }
}
