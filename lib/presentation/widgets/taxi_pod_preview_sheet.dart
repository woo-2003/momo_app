import 'package:flutter/material.dart';
import 'package:momo_app/core/map_location_helper.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/meeting_chat_screen.dart';
import 'package:momo_app/presentation/screens/meeting_detail_screen.dart';

/// 메인 지도 마커 탭 시 뜨는 택시팟 미리보기 하단 시트.
/// 지도는 유지한 채 요약만 보여주고, 상세 / 참여로 이어진다.
Future<bool?> showTaxiPodPreviewSheet({
  required BuildContext context,
  required String meetingId,
  required MeetingRepository meetingRepository,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: MomoColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return TaxiPodPreviewSheet(
        meetingId: meetingId,
        meetingRepository: meetingRepository,
      );
    },
  );
}

class TaxiPodPreviewSheet extends StatefulWidget {
  const TaxiPodPreviewSheet({
    super.key,
    required this.meetingId,
    required this.meetingRepository,
  });

  final String meetingId;
  final MeetingRepository meetingRepository;

  @override
  State<TaxiPodPreviewSheet> createState() => _TaxiPodPreviewSheetState();
}

class _TaxiPodPreviewSheetState extends State<TaxiPodPreviewSheet> {
  late Future<MeetingDetail> _detailFuture;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.meetingRepository.getMeeting(widget.meetingId);
  }

  Future<void> _openDetail(MeetingDetail detail) async {
    // 시트 위에서 상세로 이동. 상세에서 참여/취소 후 돌아오면 마커 갱신 신호로 true.
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MeetingDetailScreen(
          meetingId: widget.meetingId,
          meetingRepository: widget.meetingRepository,
        ),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(changed == true);
  }

  Future<void> _onJoin(MeetingDetail detail) async {
    if (detail.isMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 참여 중인 택시팟이에요.')),
      );
      return;
    }

    // 위치 미동의 시 다이얼로그 → 취소하면 join 하지 않음
    final allowed = await MapLocationHelper.ensurePermissionForJoin(context);
    if (!allowed || !mounted) return;

    setState(() => _isJoining = true);
    try {
      await widget.meetingRepository.joinMeeting(widget.meetingId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('택시팟에 참여했어요.')),
      );

      // --- [롤백용] 참여 후 시트만 닫기 ---
      // Navigator.of(context).pop(true);

      // 참여 직후 채팅으로 이동. 채팅에서 뒤로 오면 시트 닫고 메인 마커 갱신.
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
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MomoSpacing.sm,
          MomoSpacing.sm,
          MomoSpacing.sm,
          MomoSpacing.md,
        ),
        child: FutureBuilder<MeetingDetail>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(MomoSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              final message = snapshot.error is MeetingException
                  ? (snapshot.error! as MeetingException).message
                  : '모임 정보를 불러오지 못했어요.';
              return Padding(
                padding: const EdgeInsets.all(MomoSpacing.md),
                child: Text(
                  message,
                  style: MomoTextStyles.body.copyWith(color: MomoColors.error),
                ),
              );
            }

            final detail = snapshot.data!;
            return _PreviewBody(
              detail: detail,
              isJoining: _isJoining,
              onClose: () => Navigator.of(context).pop(),
              onDetail: () => _openDetail(detail),
              onJoin: () => _onJoin(detail),
            );
          },
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.detail,
    required this.isJoining,
    required this.onClose,
    required this.onDetail,
    required this.onJoin,
  });

  final MeetingDetail detail;
  final bool isJoining;
  final VoidCallback onClose;
  final VoidCallback onDetail;
  final VoidCallback onJoin;

  /// 정원 1명 남으면 시안 참고용 「마감직전」 배지.
  bool get _isAlmostFull =>
      detail.maxMembers > 0 &&
      detail.currentMembers >= detail.maxMembers - 1 &&
      detail.currentMembers < detail.maxMembers;

  String? get _destinationName {
    final raw = detail.categoryFields['destinationName'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 드래그 핸들
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
          children: [
            _Badge(
              label: '택시팟',
              background: MomoColors.surface,
              foreground: MomoColors.textMain,
            ),
            if (_isAlmostFull) ...[
              const SizedBox(width: MomoSpacing.xs),
              _Badge(
                label: '마감직전',
                background: MomoColors.primary.withValues(alpha: 0.2),
                foreground: MomoColors.primary,
              ),
            ],
            const Spacer(),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              color: MomoColors.textSub,
            ),
          ],
        ),
        const SizedBox(height: MomoSpacing.xs),
        Text(detail.title, style: MomoTextStyles.heading.copyWith(fontSize: 18)),
        if (detail.placeName != null) ...[
          const SizedBox(height: MomoSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: MomoColors.primary,
              ),
              const SizedBox(width: MomoSpacing.xxs),
              Expanded(
                child: Text(
                  detail.placeName!,
                  style: MomoTextStyles.caption,
                ),
              ),
            ],
          ),
        ],
        if (_destinationName != null) ...[
          const SizedBox(height: MomoSpacing.xxs),
          Text(
            '도착: $_destinationName',
            style: MomoTextStyles.caption.copyWith(color: MomoColors.textSub),
          ),
        ],
        const SizedBox(height: MomoSpacing.sm),
        Row(
          children: [
            const Icon(
              Icons.people_outline_rounded,
              size: 18,
              color: MomoColors.textSub,
            ),
            const SizedBox(width: MomoSpacing.xxs),
            Text(
              '${detail.currentMembers} / ${detail.maxMembers}명',
              style: MomoTextStyles.body,
            ),
          ],
        ),
        const SizedBox(height: MomoSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isJoining ? null : onDetail,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MomoColors.textMain,
                  side: const BorderSide(color: MomoColors.border),
                  backgroundColor: MomoColors.surface,
                ),
                child: const Text('상세정보 보기'),
              ),
            ),
            const SizedBox(width: MomoSpacing.xs),
            Expanded(
              child: ElevatedButton(
                onPressed: isJoining || detail.isMember ? null : onJoin,
                child: Text(
                  detail.isMember
                      ? '참여 중'
                      : (isJoining ? '참여 중…' : '참여하기'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MomoSpacing.xs,
        vertical: MomoSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MomoColors.border),
      ),
      child: Text(
        label,
        style: MomoTextStyles.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
