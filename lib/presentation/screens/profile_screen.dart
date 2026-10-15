import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/profile_prefs.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/meeting_detail_screen.dart';
import 'package:momo_app/presentation/screens/profile_edit_screen.dart';

/// 내 프로필 — 만든/참여 모임 피드 + 프로필 수정 진입.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.meetingRepository});

  final MeetingRepository meetingRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _nickname = '모모';
  String _status = ProfilePrefs.defaultStatusMessage;
  String _school = ProfilePrefs.defaultSchoolLabel;
  int _tabIndex = 0; // 0: 내가 만든, 1: 참여했던
  late Future<_ProfileFeeds> _feedsFuture;

  @override
  void initState() {
    super.initState();
    _feedsFuture = _loadFeeds();
    _loadProfileHeader();
  }

  Future<void> _loadProfileHeader() async {
    final session = await SessionStore().read();
    final prefs = ProfilePrefs();
    final status = await prefs.statusMessage();
    final school = await prefs.schoolLabel();
    if (!mounted) return;
    setState(() {
      _nickname = (session?.nickname?.trim().isNotEmpty ?? false)
          ? session!.nickname!.trim()
          : '모모';
      _status = status;
      _school = school;
    });
  }

  Future<_ProfileFeeds> _loadFeeds() async {
    final summaries = await widget.meetingRepository.listMeetings();
    if (summaries.isEmpty) {
      return const _ProfileFeeds(created: [], joined: []);
    }

    final details = await Future.wait(
      summaries.map((s) => widget.meetingRepository.getMeeting(s.meetingId)),
    );

    final created = details.where((d) => d.isHost).toList();
    final joined = details.where((d) => d.isMember).toList();
    return _ProfileFeeds(created: created, joined: joined);
  }

  Future<void> _openEdit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileEditScreen(
          initialNickname: _nickname,
          initialStatusMessage: _status,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _loadProfileHeader();
    }
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
    if (!mounted) return;
    setState(() {
      _feedsFuture = _loadFeeds();
    });
  }

  String _formatStartAt(DateTime startAt) {
    final local = startAt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day} $hh:$mm';
  }

  String get _initial {
    if (_nickname.isEmpty) return '?';
    return _nickname.substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      body: FutureBuilder<_ProfileFeeds>(
        future: _feedsFuture,
        builder: (context, snapshot) {
          final feeds = snapshot.data;
          final list = _tabIndex == 0
              ? (feeds?.created ?? const <MeetingDetail>[])
              : (feeds?.joined ?? const <MeetingDetail>[]);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MomoSpacing.sm,
                    MomoSpacing.sm,
                    MomoSpacing.sm,
                    MomoSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ProfileTab(
                          label: '👑 내가 만든 모임',
                          selected: _tabIndex == 0,
                          onTap: () => setState(() => _tabIndex = 0),
                        ),
                      ),
                      const SizedBox(width: MomoSpacing.xs),
                      Expanded(
                        child: _ProfileTab(
                          label: '🤝 참여했던 모임',
                          selected: _tabIndex == 1,
                          onTap: () => setState(() => _tabIndex = 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MomoSpacing.sm,
                    MomoSpacing.xs,
                    MomoSpacing.sm,
                    MomoSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tabIndex == 0 ? '내가 만든 모임 피드' : '내가 참여했던 모임 피드',
                          style: MomoTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: MomoColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: MomoColors.border),
                        ),
                        child: Text(
                          '${list.length}개',
                          style: MomoTextStyles.caption.copyWith(
                            color: MomoColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(MomoSpacing.md),
                      child: Text(
                        snapshot.error is MeetingException
                            ? (snapshot.error! as MeetingException).message
                            : '모임을 불러오지 못했어요.',
                        style: MomoTextStyles.body.copyWith(
                          color: MomoColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      _tabIndex == 0 ? '아직 만든 모임이 없어요.' : '아직 참여한 모임이 없어요.',
                      style: MomoTextStyles.body.copyWith(
                        color: MomoColors.textSub,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    MomoSpacing.sm,
                    0,
                    MomoSpacing.sm,
                    MomoSpacing.lg,
                  ),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: MomoSpacing.sm),
                    itemBuilder: (context, index) {
                      final meeting = list[index];
                      return _ProfileMeetingCard(
                        meeting: meeting,
                        meta:
                            '${meetingCategoryLabel(meeting.category)} · ${_formatStartAt(meeting.startAt)} · ${meeting.currentMembers}명',
                        onView: () => _openDetail(meeting),
                        onPrimaryAction: () {
                          if (meeting.status == 'closed' ||
                              meeting.status == 'cancelled') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('매너 평가는 준비 중이에요.')),
                            );
                            return;
                          }
                          _openDetail(meeting);
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MomoColors.primary,
            MomoColors.primary.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MomoSpacing.sm,
            MomoSpacing.xs,
            MomoSpacing.sm,
            MomoSpacing.md,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Material(
                    color: MomoColors.onPrimary.withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: MomoColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _openEdit,
                    style: TextButton.styleFrom(
                      backgroundColor: MomoColors.onPrimary,
                      foregroundColor: MomoColors.textMain,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('프로필 수정'),
                  ),
                ],
              ),
              const SizedBox(height: MomoSpacing.sm),
              CircleAvatar(
                radius: 44,
                backgroundColor: MomoColors.onPrimary,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: MomoColors.primary,
                  child: Text(
                    _initial,
                    style: MomoTextStyles.title.copyWith(
                      color: MomoColors.onPrimary,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MomoSpacing.sm),
              Text(
                _nickname,
                style: MomoTextStyles.heading.copyWith(
                  color: MomoColors.textMain,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _status,
                style: MomoTextStyles.caption.copyWith(
                  color: MomoColors.textSub,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: MomoSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: MomoColors.background.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: MomoColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _school,
                  style: MomoTextStyles.caption.copyWith(
                    color: MomoColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileFeeds {
  const _ProfileFeeds({required this.created, required this.joined});

  final List<MeetingDetail> created;
  final List<MeetingDetail> joined;
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
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
      color: selected ? MomoColors.background : MomoColors.surface,
      elevation: selected ? 1 : 0,
      shadowColor: MomoColors.textMain.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? MomoColors.border : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: MomoTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: MomoColors.textMain,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMeetingCard extends StatelessWidget {
  const _ProfileMeetingCard({
    required this.meeting,
    required this.meta,
    required this.onView,
    required this.onPrimaryAction,
  });

  final MeetingDetail meeting;
  final String meta;
  final VoidCallback onView;
  final VoidCallback onPrimaryAction;

  bool get _ended =>
      meeting.status == 'closed' || meeting.status == 'cancelled';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomoColors.background,
      borderRadius: MomoRadius.all,
      child: InkWell(
        onTap: onView,
        borderRadius: MomoRadius.all,
        child: Container(
          padding: const EdgeInsets.all(MomoSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: MomoRadius.all,
            border: Border.all(color: MomoColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meeting.title,
                      style: MomoTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: MomoSpacing.xs),
                  Text(
                    '보기 →',
                    style: MomoTextStyles.caption.copyWith(
                      color: MomoColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(meta, style: MomoTextStyles.caption),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _ended ? MomoColors.neutralFill : MomoColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _ended ? '🏁 모임 종료됨' : '🟢 진행 중',
                    style: MomoTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: MomoSpacing.xs),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: onPrimaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ended
                        ? MomoColors.primary
                        : MomoColors.neutralFill,
                    foregroundColor: _ended
                        ? MomoColors.onPrimary
                        : MomoColors.textMain,
                    elevation: 0,
                    minimumSize: const Size(0, 44),
                    maximumSize: const Size(double.infinity, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _ended ? '🍓 모임 평가하기 (준비중)' : '상세 보기',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MomoTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _ended
                          ? MomoColors.onPrimary
                          : MomoColors.textMain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
