import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:momo_app/core/map_location_helper.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/meeting_chat_screen.dart';
import 'package:momo_app/presentation/screens/meeting_detail_screen.dart';

/// 메인 지도 마커 탭 시 뜨는 택시팟 미리보기 하단 시트.
/// 색은 [MomoColors]만 사용.
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
  String? _distanceLabel;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.meetingRepository.getMeeting(widget.meetingId);
    _detailFuture.then(_resolveDistance).catchError((_) {});
  }

  Future<void> _resolveDistance(MeetingDetail detail) async {
    final lat = detail.latitude;
    final lng = detail.longitude;
    if (lat == null || lng == null) return;
    if (!await MapLocationHelper.hasPermission()) return;

    try {
      final me = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final meters = Geolocator.distanceBetween(
        me.latitude,
        me.longitude,
        lat,
        lng,
      );
      if (!mounted) return;
      setState(() => _distanceLabel = _formatDistance(meters));
    } catch (_) {
      // 거리 실패 시 라벨만 숨김
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m 근처';
    return '${(meters / 1000).toStringAsFixed(1)}km 근처';
  }

  Future<void> _openDetail(MeetingDetail detail) async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 참여 중인 택시팟이에요.')));
      return;
    }

    final allowed = await MapLocationHelper.ensurePermissionForJoin(context);
    if (!allowed || !mounted) return;

    setState(() => _isJoining = true);
    try {
      await widget.meetingRepository.joinMeeting(widget.meetingId);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('택시팟에 참여했어요.')));

      // --- [롤백용] 참여 후 시트만 닫기 ---
      // Navigator.of(context).pop(true);

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('참여에 실패했어요.')));
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
              distanceLabel: _distanceLabel,
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
    required this.distanceLabel,
    required this.isJoining,
    required this.onClose,
    required this.onDetail,
    required this.onJoin,
  });

  final MeetingDetail detail;
  final String? distanceLabel;
  final bool isJoining;
  final VoidCallback onClose;
  final VoidCallback onDetail;
  final VoidCallback onJoin;

  bool get _isAlmostFull =>
      detail.maxMembers > 0 &&
      detail.currentMembers >= detail.maxMembers - 1 &&
      detail.currentMembers < detail.maxMembers;

  String? get _destinationName {
    final raw = detail.categoryFields['destinationName'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return detail.destinationName;
  }

  @override
  Widget build(BuildContext context) {
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
          children: [
            const _Badge(
              label: '택시팟',
              background: MomoColors.taxiGoldSoft,
              foreground: MomoColors.taxiGoldDark,
            ),
            if (_isAlmostFull) ...[
              const SizedBox(width: MomoSpacing.xs),
              _Badge(
                label: '마감직전 🚨',
                background: MomoColors.primary.withValues(alpha: 0.18),
                foreground: MomoColors.primary,
              ),
            ],
            const Spacer(),
            if (distanceLabel != null) ...[
              Text(
                distanceLabel!,
                style: MomoTextStyles.caption.copyWith(
                  color: MomoColors.textSub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: MomoSpacing.xxs),
            ],
            Material(
              color: MomoColors.surface,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onClose,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: MomoColors.textSub,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MomoSpacing.sm),
        Text(
          detail.title,
          style: MomoTextStyles.heading.copyWith(fontSize: 18),
        ),
        if (detail.placeName != null) ...[
          const SizedBox(height: MomoSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on,
                size: 18,
                color: MomoColors.primary,
              ),
              const SizedBox(width: MomoSpacing.xxs),
              Expanded(
                child: Text(detail.placeName!, style: MomoTextStyles.caption),
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
            Icon(
              Icons.people_alt_rounded,
              size: 18,
              color: MomoColors.primary.withValues(alpha: 0.85),
            ),
            const SizedBox(width: MomoSpacing.xxs),
            Text(
              '${detail.currentMembers} / ${detail.maxMembers}명',
              style: MomoTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: MomoSpacing.md),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: isJoining ? null : onDetail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MomoColors.textMain,
                    side: const BorderSide(color: MomoColors.border),
                    backgroundColor: MomoColors.neutralFill,
                    // theme minHeight 56 > SizedBox 48 → 제약 예외 방지
                    minimumSize: const Size(0, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MomoRadius.component,
                      ),
                    ),
                  ),
                  child: const Text('상세정보 보기'),
                ),
              ),
            ),
            const SizedBox(width: MomoSpacing.xs),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isJoining || detail.isMember ? null : onJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MomoColors.primary,
                    foregroundColor: MomoColors.onPrimary,
                    disabledBackgroundColor: MomoColors.disabled,
                    elevation: 2,
                    shadowColor: MomoColors.primary.withValues(alpha: 0.35),
                    minimumSize: const Size(0, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MomoRadius.component,
                      ),
                    ),
                  ),
                  child: Text(
                    detail.isMember
                        ? '참여 중'
                        : (isJoining ? '참여 중…' : '참여하기'),
                    style: MomoTextStyles.button,
                  ),
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
      ),
      child: Text(
        label,
        style: MomoTextStyles.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
