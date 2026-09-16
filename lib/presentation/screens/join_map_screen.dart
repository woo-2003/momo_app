import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/map_location_helper.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/meeting_repository.dart';

/// 합류 지도 (FE 더미/로컬 단계).
///
/// - 집결 핀 + 내 GPS + 더미 멤버로 UI·거리 익음을 먼저 검증.
/// - 서버/소켓은 동준 합의 후 교체. 아래 계약만 참고용.
///
/// ### 동준용 Socket 계약 (미구현)
/// - C→S `location`: `{ meetingId, latitude, longitude }`
/// - S→C `location`: `{ meetingId, userId, nickname, latitude, longitude, updatedAt }`
/// - S→C `location:clear`: `{ meetingId, userId }`
/// - `join` ack에 `locations: [...]` 스냅샷 (선택)
///
/// 더미 [_MemberPin] 목록은 이후 소켓 스트림으로 바꾸기 쉽게 분리해 둠.
class JoinMapScreen extends StatefulWidget {
  const JoinMapScreen({
    super.key,
    required this.meeting,
  });

  final MeetingDetail meeting;

  @override
  State<JoinMapScreen> createState() => _JoinMapScreenState();
}

class _JoinMapScreenState extends State<JoinMapScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;
  Timer? _dummyTimer;

  LatLng? _myLatLng;
  late List<_MemberPin> _members;
  bool _ready = false;
  String? _initError;

  LatLng? get _gatherLatLng {
    final lat = widget.meeting.latitude;
    final lng = widget.meeting.longitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @override
  void initState() {
    super.initState();
    _members = _buildDummyMembers(_gatherLatLng);
    _bootstrap();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _dummyTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final gather = _gatherLatLng;
    if (gather == null) {
      if (!mounted) return;
      setState(() {
        _initError = '집결 위치가 없어 합류 지도를 열 수 없어요.';
        _ready = true;
      });
      return;
    }

    final ok = await MapLocationHelper.ensurePermission();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 권한이 없어 합류 지도를 열 수 없어요.')),
      );
      Navigator.of(context).pop();
      return;
    }

    final me = await MapLocationHelper.currentLatLng();
    if (!mounted) return;

    setState(() {
      _myLatLng = me;
      _ready = true;
    });

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _myLatLng = LatLng(pos.latitude, pos.longitude);
      });
    });

    // 더미가 집결 쪽으로 조금씩 다가오는 시뮬레이션 (데모용).
    _dummyTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final target = _gatherLatLng;
      if (target == null) return;
      setState(() {
        _members = [
          for (final m in _members)
            m.copyWith(
              latLng: _lerpToward(m.latLng, target, 0.12),
            ),
        ];
      });
    });
  }

  /// 집결지 기준 오프셋 더미 2~3명. 소켓 연동 시 이 리스트만 교체하면 됨.
  List<_MemberPin> _buildDummyMembers(LatLng? gather) {
    if (gather == null) return const [];
    // ~111m per 0.001° lat. 대략 450m / 180m / 70m.
    return [
      _MemberPin(
        userId: 'dummy-1',
        nickname: '민수',
        latLng: LatLng(gather.latitude + 0.0040, gather.longitude - 0.0015),
        isMe: false,
        isDummy: true,
      ),
      _MemberPin(
        userId: 'dummy-2',
        nickname: '지아',
        latLng: LatLng(gather.latitude - 0.0016, gather.longitude + 0.0012),
        isMe: false,
        isDummy: true,
      ),
      _MemberPin(
        userId: 'dummy-3',
        nickname: '현우',
        latLng: LatLng(gather.latitude + 0.0005, gather.longitude + 0.0006),
        isMe: false,
        isDummy: true,
      ),
    ];
  }

  LatLng _lerpToward(LatLng from, LatLng to, double t) {
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  Set<Marker> _buildMarkers() {
    final gather = _gatherLatLng;
    final markers = <Marker>{};

    if (gather != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('gather'),
          position: gather,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRose,
          ),
          infoWindow: InfoWindow(
            title: '집결',
            snippet: widget.meeting.placeName ?? widget.meeting.title,
          ),
          zIndexInt: 2,
        ),
      );
    }

    final me = _myLatLng;
    if (me != null) {
      final label = gather == null
          ? '나'
          : '나 · ${_ripenessLabel(_distanceMeters(me, gather))}';
      markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: me,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: label),
          zIndexInt: 3,
        ),
      );
    }

    for (final m in _members) {
      final dist = gather == null
          ? null
          : _distanceMeters(m.latLng, gather);
      final ripeness = dist == null ? '' : _ripenessLabel(dist);
      markers.add(
        Marker(
          markerId: MarkerId(m.userId),
          position: m.latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: m.nickname,
            snippet: ripeness.isEmpty ? '더미' : '$ripeness · 더미',
          ),
          zIndexInt: 1,
        ),
      );
    }

    return markers;
  }

  List<_MemberPin> get _listRows {
    final rows = <_MemberPin>[
      if (_myLatLng != null)
        _MemberPin(
          userId: 'me',
          nickname: '나',
          latLng: _myLatLng!,
          isMe: true,
          isDummy: false,
        ),
      ..._members,
    ];
    final gather = _gatherLatLng;
    if (gather == null) return rows;
    rows.sort((a, b) {
      return _distanceMeters(a.latLng, gather)
          .compareTo(_distanceMeters(b.latLng, gather));
    });
    return rows;
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  /// 기획 거리 익음: 500m+ / 200~500 / 50~200 / 도착(<50).
  static String _ripenessLabel(double meters) {
    if (meters < 50) return '도착';
    if (meters < 200) return '50~200m';
    if (meters < 500) return '200~500m';
    return '500m+';
  }

  static String _formatMeters(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  Future<void> _goMyLocation() async {
    final ok = await MapLocationHelper.moveCameraToCurrent(_mapController);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치를 가져오지 못했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gather = _gatherLatLng;
    final initial = gather ??
        _myLatLng ??
        const LatLng(37.5665, 126.9780);

    return Scaffold(
      backgroundColor: MomoColors.background,
      appBar: AppBar(
        title: Text(
          '합류 지도',
          style: MomoTextStyles.heading.copyWith(fontSize: 18),
        ),
        backgroundColor: MomoColors.background,
        foregroundColor: MomoColors.textMain,
        elevation: 0,
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _initError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MomoSpacing.md),
                    child: Text(
                      _initError!,
                      style: MomoTextStyles.body.copyWith(
                        color: MomoColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        MomoSpacing.sm,
                        0,
                        MomoSpacing.sm,
                        MomoSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.meeting.title,
                              style: MomoTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: MomoSpacing.xs,
                              vertical: MomoSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: MomoColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '더미 위치 · 로컬',
                              style: MomoTextStyles.caption.copyWith(
                                color: MomoColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: initial,
                              zoom: 15,
                            ),
                            markers: _buildMarkers(),
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            onMapCreated: (c) => _mapController = c,
                          ),
                          Positioned(
                            right: MomoSpacing.sm,
                            bottom: MomoSpacing.sm,
                            child: FloatingActionButton.small(
                              heroTag: 'join_map_my_location',
                              backgroundColor: MomoColors.surface,
                              foregroundColor: MomoColors.primary,
                              onPressed: _goMyLocation,
                              child: const Icon(Icons.my_location_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _MemberPanel(
                        gather: gather,
                        rows: _listRows,
                        distanceOf: (pin) =>
                            gather == null
                                ? null
                                : _distanceMeters(pin.latLng, gather),
                        ripenessOf: _ripenessLabel,
                        formatMeters: _formatMeters,
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// 합류 맵에 그릴 사람 핀. 소켓 연동 시 필드 유지한 채 소스만 교체.
class _MemberPin {
  const _MemberPin({
    required this.userId,
    required this.nickname,
    required this.latLng,
    required this.isMe,
    required this.isDummy,
  });

  final String userId;
  final String nickname;
  final LatLng latLng;
  final bool isMe;
  final bool isDummy;

  _MemberPin copyWith({LatLng? latLng}) {
    return _MemberPin(
      userId: userId,
      nickname: nickname,
      latLng: latLng ?? this.latLng,
      isMe: isMe,
      isDummy: isDummy,
    );
  }
}

class _MemberPanel extends StatelessWidget {
  const _MemberPanel({
    required this.gather,
    required this.rows,
    required this.distanceOf,
    required this.ripenessOf,
    required this.formatMeters,
  });

  final LatLng? gather;
  final List<_MemberPin> rows;
  final double? Function(_MemberPin) distanceOf;
  final String Function(double) ripenessOf;
  final String Function(double) formatMeters;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MomoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: MomoColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MomoSpacing.sm,
              MomoSpacing.sm,
              MomoSpacing.sm,
              MomoSpacing.xs,
            ),
            child: Text(
              '오는 중 · 거리 익음',
              style: MomoTextStyles.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      '표시할 위치가 없어요.',
                      style: MomoTextStyles.caption,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      MomoSpacing.sm,
                      0,
                      MomoSpacing.sm,
                      MomoSpacing.sm,
                    ),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: MomoSpacing.xs),
                    itemBuilder: (context, index) {
                      final pin = rows[index];
                      final dist = distanceOf(pin);
                      final ripeness =
                          dist == null ? '-' : ripenessOf(dist);
                      final distText =
                          dist == null ? '-' : formatMeters(dist);
                      return Container(
                        padding: const EdgeInsets.all(MomoSpacing.xs),
                        decoration: BoxDecoration(
                          color: MomoColors.background,
                          borderRadius:
                              BorderRadius.circular(MomoRadius.component),
                          border: Border.all(color: MomoColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: pin.isMe
                                  ? MomoColors.primary
                                  : MomoColors.primary.withValues(alpha: 0.25),
                              child: Text(
                                pin.nickname.isEmpty
                                    ? '?'
                                    : pin.nickname.substring(0, 1),
                                style: MomoTextStyles.caption.copyWith(
                                  color: pin.isMe
                                      ? MomoColors.onPrimary
                                      : MomoColors.textMain,
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
                                    pin.isDummy
                                        ? '${pin.nickname} (더미)'
                                        : pin.nickname,
                                    style: MomoTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    gather == null
                                        ? '집결 좌표 없음'
                                        : '집결까지 $distText',
                                    style: MomoTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MomoSpacing.xs,
                                vertical: MomoSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: _ripenessColor(ripeness)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                ripeness,
                                style: MomoTextStyles.caption.copyWith(
                                  color: _ripenessColor(ripeness),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _ripenessColor(String label) {
    switch (label) {
      case '도착':
        return MomoColors.success;
      case '50~200m':
        return const Color(0xFF6B9E3E);
      case '200~500m':
        return MomoColors.primary;
      case '500m+':
        return MomoColors.textSub;
      default:
        return MomoColors.textDisabled;
    }
  }
}
