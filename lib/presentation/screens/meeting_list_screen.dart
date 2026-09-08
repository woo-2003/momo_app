import 'package:momo_app/data/meeting_repository_impl.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/meeting_create_screen.dart';
import 'package:momo_app/presentation/screens/meeting_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/presentation/screens/login_screen.dart';
import 'package:momo_app/service/meeting_location_share_service.dart';

class MeetingListScreen extends StatefulWidget {
  MeetingListScreen({super.key, MeetingRepository? meetingRepository})
    : meetingRepository = meetingRepository ?? MeetingRepositoryImpl();

  final MeetingRepository meetingRepository;

  @override
  State<MeetingListScreen> createState() => _MeetingListScreenState();
}

class _MeetingListScreenState extends State<MeetingListScreen> {
  late Future<List<MeetingSummary>> _meetingsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _meetingsFuture = widget.meetingRepository.listMeetings();
    });
  }

  Future<void> _onLogout() async {
    MeetingLocationShareService.instance.stopAll();
    await SessionStore().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      appBar: AppBar(
        backgroundColor: MomoColors.background,
        elevation: 0,
        title: const Text('모임', style: MomoTextStyles.heading),
        actions: [
          TextButton(
            onPressed: _onLogout,
            child: Text(
              '로그아웃',
              style: MomoTextStyles.caption.copyWith(color: MomoColors.textSub),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MomoColors.primary,
        foregroundColor: MomoColors.onPrimary,
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => MeetingCreateScreen(
                meetingRepository: widget.meetingRepository,
              ),
            ),
          );
          if (created == true) _reload();
        },
        label: const Text('모임 만들기'),
        icon: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<MeetingSummary>>(
        future: _meetingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is MeetingException
                ? error.message
                : '모임 목록을 불러오지 못했습니다.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(MomoSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: MomoSpacing.sm),
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            );
          }

          final meetings = snapshot.data ?? const [];
          if (meetings.isEmpty) {
            return Center(
              child: Text(
                '진행 중인 모임이 없습니다.\n모임 만들기로 시작해 보세요.',
                textAlign: TextAlign.center,
                style: MomoTextStyles.body.copyWith(color: MomoColors.textSub),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                MomoSpacing.md,
                MomoSpacing.xs,
                MomoSpacing.md,
                96,
              ),
              itemCount: meetings.length,
              separatorBuilder: (_, __) => const SizedBox(height: MomoSpacing.xs),
              itemBuilder: (context, index) {
                final meeting = meetings[index];
                return _MeetingCard(
                  meeting: meeting,
                  onTap: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => MeetingDetailScreen(
                          meetingId: meeting.meetingId,
                          meetingRepository: widget.meetingRepository,
                        ),
                      ),
                    );
                    if (changed == true) _reload();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.onTap});

  final MeetingSummary meeting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomoColors.surface,
      borderRadius: MomoRadius.all,
      child: InkWell(
        borderRadius: MomoRadius.all,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MomoSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CategoryChip(category: meeting.category),
                  const SizedBox(width: MomoSpacing.xs),
                  Text(
                    meeting.meetingMode == MeetingMode.online ? '온라인' : '오프라인',
                    style: MomoTextStyles.caption.copyWith(
                      color: MomoColors.textSub,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MomoSpacing.xs),
              Text(meeting.title, style: MomoTextStyles.body),
              const SizedBox(height: MomoSpacing.xxs),
              Text(
                '${meeting.currentMembers}/${meeting.maxMembers}명 · ${_formatStartAt(meeting.startAt)}',
                style: MomoTextStyles.caption.copyWith(color: MomoColors.textSub),
              ),
              if (meeting.placeName != null) ...[
                const SizedBox(height: MomoSpacing.xxs),
                Text(
                  meeting.placeName!,
                  style: MomoTextStyles.caption.copyWith(
                    color: MomoColors.textSub,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatStartAt(DateTime value) {
    final local = value.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final MeetingCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MomoSpacing.xs,
        vertical: MomoSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: MomoColors.primary.withValues(alpha: 0.15),
        borderRadius: MomoRadius.all,
      ),
      child: Text(
        meetingCategoryLabel(category),
        style: MomoTextStyles.caption.copyWith(
          color: MomoColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
