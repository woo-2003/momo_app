import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/meeting_chat_screen.dart';

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

  Future<void> _openChat(MeetingDetail detail) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      appBar: AppBar(
        backgroundColor: MomoColors.background,
        elevation: 0,
        title: const Text('모임 상세', style: MomoTextStyles.heading),
      ),
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
            return Center(child: Text(message));
          }

          final detail = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(MomoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(detail.title, style: MomoTextStyles.heading),
                const SizedBox(height: MomoSpacing.xs),
                Text(
                  '${meetingCategoryLabel(detail.category)} · ${detail.currentMembers}/${detail.maxMembers}명',
                  style: MomoTextStyles.caption.copyWith(
                    color: MomoColors.textSub,
                  ),
                ),
                if (detail.description.isNotEmpty) ...[
                  const SizedBox(height: MomoSpacing.sm),
                  Text(detail.description, style: MomoTextStyles.body),
                ],
                if (detail.placeName != null) ...[
                  const SizedBox(height: MomoSpacing.sm),
                  Text(
                    '장소: ${detail.placeName}',
                    style: MomoTextStyles.body,
                  ),
                ],
                const SizedBox(height: MomoSpacing.md),
                if (!detail.isMember)
                  ElevatedButton(
                    onPressed: _isWorking
                        ? null
                        : () => _runAction(
                            () => widget.meetingRepository.joinMeeting(
                              widget.meetingId,
                            ),
                          ),
                    child: const Text('참여하기'),
                  ),
                if (detail.isMember && !detail.isHost)
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
                if (detail.isHost)
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
                if (detail.isMember) ...[
                  const SizedBox(height: MomoSpacing.sm),
                  ElevatedButton(
                    onPressed: _isWorking ? null : () => _openChat(detail),
                    child: const Text('채팅 열기'),
                  ),
                ],
                const SizedBox(height: MomoSpacing.md),
                Text('참여자', style: MomoTextStyles.body),
                const SizedBox(height: MomoSpacing.xs),
                Expanded(
                  child: ListView.separated(
                    itemCount: detail.members.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: MomoSpacing.xxs),
                    itemBuilder: (context, index) {
                      final member = detail.members[index];
                      return Text(
                        '${member.nickname} (${member.role})',
                        style: MomoTextStyles.caption,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
