import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:momo_app/core/map_location_helper.dart';
import 'package:momo_app/core/meeting_display.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/meeting_chat_screen.dart';
import 'package:momo_app/presentation/screens/meeting_detail_screen.dart';

/// 일반 모임(비택시) 마커 탭 프리뷰.
Future<bool?> showMeetingPreviewSheet({
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
      return MeetingPreviewSheet(
        meetingId: meetingId,
        meetingRepository: meetingRepository,
      );
    },
  );
}

class MeetingPreviewSheet extends StatefulWidget {
  const MeetingPreviewSheet({
    super.key,
    required this.meetingId,
    required this.meetingRepository,
  });

  final String meetingId;
  final MeetingRepository meetingRepository;

  @override
  State<MeetingPreviewSheet> createState() => _MeetingPreviewSheetState();
}

class _MeetingPreviewSheetState extends State<MeetingPreviewSheet> {
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
      setState(() {
        _distanceLabel = meters < 1000
            ? '${meters.round()}m 근처'
            : '${(meters / 1000).toStringAsFixed(1)}km 근처';
      });
    } catch (_) {}
  }

  Future<void> _openDetail() async {
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
        const SnackBar(content: Text('이미 참여 중인 모임이에요.')),
      );
      return;
    }

    if (detail.meetingMode == MeetingMode.offline) {
      final allowed = await MapLocationHelper.ensurePermissionForJoin(context);
      if (!allowed || !mounted) return;
    }

    setState(() => _isJoining = true);
    try {
      await widget.meetingRepository.joinMeeting(widget.meetingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임에 참여했어요.')),
      );
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
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  String _formatStart(DateTime at) {
    final local = at.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day} $hh:$mm';
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
            if (snapshot.hasError || snapshot.data == null) {
              return Padding(
                padding: const EdgeInsets.all(MomoSpacing.md),
                child: Text(
                  snapshot.error is MeetingException
                      ? (snapshot.error! as MeetingException).message
                      : '모임 정보를 불러오지 못했어요.',
                  style: MomoTextStyles.body.copyWith(color: MomoColors.error),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final detail = snapshot.data!;
            final kindLabel = MeetingDisplay.labelOf(detail);
            final detailText = MeetingDisplay.detailOf(detail);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: MomoSpacing.sm),
                    decoration: BoxDecoration(
                      color: MomoColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MomoColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: MomoColors.border),
                      ),
                      child: Text(
                        kindLabel,
                        style: MomoTextStyles.caption.copyWith(
                          color: MomoColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_distanceLabel != null)
                      Text(
                        _distanceLabel!,
                        style: MomoTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: MomoColors.textSub,
                    ),
                  ],
                ),
                Text(
                  detail.title,
                  style: MomoTextStyles.heading.copyWith(fontSize: 18),
                ),
                if (detailText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detailText,
                    style: MomoTextStyles.caption,
                  ),
                ],
                if (detail.placeName != null) ...[
                  const SizedBox(height: MomoSpacing.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: MomoColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          detail.placeName!,
                          style: MomoTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: MomoSpacing.xs),
                Text(
                  '${_formatStart(detail.startAt)} · ${detail.currentMembers}/${detail.maxMembers}명'
                  '${detail.meetingMode == MeetingMode.online ? ' · 온라인' : ''}',
                  style: MomoTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: MomoSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isJoining ? null : _openDetail,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: MomoSpacing.sm,
                            vertical: MomoSpacing.xs,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: MomoColors.neutralFill,
                        ),
                        child: const Text(
                          '상세정보 보기',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: MomoSpacing.xs),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isJoining || detail.isMember
                            ? null
                            : () => _onJoin(detail),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: MomoSpacing.sm,
                            vertical: MomoSpacing.xs,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          detail.isMember
                              ? '참여 중'
                              : (_isJoining ? '참여 중…' : '참여하기'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
