import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/map_location_helper.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/meeting_chat_screen.dart';
import 'package:momo_app/presentation/widgets/all_gathered_sheet.dart';
import 'package:momo_app/presentation/widgets/join_map_member_panel.dart';
import 'package:momo_app/presentation/widgets/map_icon_button.dart';

/// 합류 지도 (FE 더미/로컬 단계).
///
/// - 집결 핀 + 내 GPS + 더미 멤버. 색은 [MomoColors]만.
/// - 서버/소켓은 동준 합의 후 교체.
///
/// ### 동준용 Socket 계약 (미구현)
/// - C→S `location`: `{ meetingId, latitude, longitude }`
/// - S→C `location`: `{ meetingId, userId, nickname, latitude, longitude, updatedAt }`
/// - S→C `location:clear`: `{ meetingId, userId }`
/// - `join` ack에 `locations: [...]` 스냅샷 (선택)
class JoinMapScreen extends StatefulWidget {
  const JoinMapScreen({
    super.key,
    required this.meeting,
    required this.meetingRepository,
  });

  final MeetingDetail meeting;
  final MeetingRepository meetingRepository;

  @override
  State<JoinMapScreen> createState() => _JoinMapScreenState();
}

class _JoinMapScreenState extends State<JoinMapScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;
  Timer? _dummyTimer;

  LatLng? _myLatLng;
  late List<_MemberPin> _members;
  Set<Marker> _markers = {};
  final Map<String, BitmapDescriptor> _iconCache = {};

  bool _ready = false;
  String? _initError;
  bool _rebuildingMarkers = false;

  /// 집결 도착 판정(m). 기획 ALG-02 근처/도착 구간.
  static const double _arriveMeters = 80;

  /// 전원 도착 축하 시트 1회만.
  bool _allGatheredSheetShown = false;
  bool _showingGatheredSheet = false;

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
    final controller = _mapController;
    _mapController = null;
    controller?.dispose();
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
    await _rebuildMarkers();
    _maybeShowAllGathered();

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
      _rebuildMarkers();
      _maybeShowAllGathered();
    });

    _dummyTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final target = _gatherLatLng;
      if (target == null) return;
      setState(() {
        _members = [
          for (final m in _members)
            m.copyWith(latLng: _lerpToward(m.latLng, target, 0.18)),
        ];
      });
      _rebuildMarkers();
      _maybeShowAllGathered();
    });
  }

  List<_MemberPin> _buildDummyMembers(LatLng? gather) {
    if (gather == null) return const [];
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
        isHost: true,
      ),
    ];
  }

  LatLng _lerpToward(LatLng from, LatLng to, double t) {
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  Future<void> _rebuildMarkers() async {
    if (_rebuildingMarkers || !mounted) return;
    _rebuildingMarkers = true;
    try {
      final gather = _gatherLatLng;
      final next = <Marker>{};
      final ratio = MediaQuery.devicePixelRatioOf(context);

      if (gather != null) {
        next.add(
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
            zIndexInt: 1,
          ),
        );
      }

      final me = _myLatLng;
      if (me != null) {
        final icon = await _iconFor(
          key: 'me',
          letter: '나',
          color: MomoColors.primary,
          pixelRatio: ratio,
        );
        next.add(
          Marker(
            markerId: const MarkerId('me'),
            position: me,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 3,
          ),
        );
      }

      for (final m in _members) {
        final letter =
            m.nickname.isEmpty ? '?' : m.nickname.substring(0, 1);
        final icon = await _iconFor(
          key: m.userId,
          letter: letter,
          color: MomoColors.success,
          pixelRatio: ratio,
        );
        next.add(
          Marker(
            markerId: MarkerId(m.userId),
            position: m.latLng,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 2,
          ),
        );
      }

      if (!mounted) return;
      setState(() => _markers = next);
    } finally {
      _rebuildingMarkers = false;
    }
  }

  Future<BitmapDescriptor> _iconFor({
    required String key,
    required String letter,
    required Color color,
    required double pixelRatio,
  }) async {
    final cached = _iconCache[key];
    if (cached != null) return cached;
    final created = await _InitialMarkerIcon.create(
      letter: letter,
      fill: color,
      pixelRatio: pixelRatio,
    );
    _iconCache[key] = created;
    return created;
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

  List<JoinMapMemberRowData> get _panelRows {
    final gather = _gatherLatLng;
    final out = <JoinMapMemberRowData>[];
    for (final pin in _listRows) {
      final dist =
          gather == null ? null : _distanceMeters(pin.latLng, gather);
      final arrived = dist != null && dist <= _arriveMeters;
      final status = dist == null
          ? '위치 없음'
          : arrived
              ? '도착 완료 (≤${_arriveMeters.round()}m)'
              : '집결까지 ${_formatMeters(dist)} · ${_ripenessLabel(dist)}';
      out.add(
        JoinMapMemberRowData(
          nickname: pin.nickname,
          statusText: status,
          chipLabel: arrived ? '도착' : '이동 중',
          isArrived: arrived,
          isMe: pin.isMe,
          isDummy: pin.isDummy,
          isHost: pin.isHost,
        ),
      );
    }
    return out;
  }

  bool get _allArrived {
    final gather = _gatherLatLng;
    if (gather == null) return false;
    final rows = _listRows;
    if (rows.isEmpty) return false;
    for (final pin in rows) {
      if (_distanceMeters(pin.latLng, gather) > _arriveMeters) {
        return false;
      }
    }
    return true;
  }

  String get _overallStatus {
    if (_allArrived) return '전원 도착 🎉';
    final gather = _gatherLatLng;
    final me = _myLatLng;
    if (gather == null || me == null) return '이동 중';
    final dist = _distanceMeters(me, gather);
    return dist <= _arriveMeters ? '도착' : '이동 중';
  }

  Future<void> _maybeShowAllGathered() async {
    if (!_ready ||
        _initError != null ||
        _allGatheredSheetShown ||
        _showingGatheredSheet ||
        !_allArrived ||
        !mounted) {
      return;
    }
    _allGatheredSheetShown = true;
    _showingGatheredSheet = true;
    try {
      await showAllGatheredSheet(
        context: context,
        meeting: widget.meeting,
        meetingRepository: widget.meetingRepository,
        onOpenChat: _openChat,
        onStayOnMap: () {},
      );
    } finally {
      _showingGatheredSheet = false;
    }
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  static String _ripenessLabel(double meters) {
    if (meters <= _arriveMeters) return '도착';
    if (meters < 200) return '근처';
    if (meters < 500) return '이동 중';
    return '멀리';
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

  Future<void> _openChat() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MeetingChatScreen(
          meetingId: widget.meeting.meetingId,
          meetingTitle: widget.meeting.title,
          meetingRepository: widget.meetingRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gather = _gatherLatLng;
    final initial = gather ??
        _myLatLng ??
        const LatLng(37.5665, 126.9780);
    final place = widget.meeting.placeName?.trim().isNotEmpty == true
        ? widget.meeting.placeName!
        : '집결 장소';

    return Scaffold(
      backgroundColor: MomoColors.background,
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _initError != null
              ? SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(MomoSpacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _initError!,
                            style: MomoTextStyles.body.copyWith(
                              color: MomoColors.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: MomoSpacing.sm),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('돌아가기'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: initial,
                              zoom: 15,
                            ),
                            markers: _markers,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            onMapCreated: (c) {
                              _mapController = c;
                              if (_myLocationEnabledSafe) {
                                MapLocationHelper.moveCameraToCurrent(c);
                              }
                            },
                          ),
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                MomoSpacing.sm,
                                MomoSpacing.xs,
                                MomoSpacing.sm,
                                0,
                              ),
                              child: Row(
                                children: [
                                  MapIconButton(
                                    icon: Icons.close_rounded,
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                  const Spacer(),
                                  MapIconButton(
                                    icon: Icons.chat_bubble_rounded,
                                    onPressed: _openChat,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: MomoSpacing.sm,
                            bottom: MomoSpacing.sm,
                            child: MapIconButton(
                              icon: Icons.my_location_rounded,
                              onPressed: _goMyLocation,
                            ),
                          ),
                          Positioned(
                            left: MomoSpacing.sm,
                            bottom: MomoSpacing.sm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MomoSpacing.xs,
                                vertical: MomoSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: MomoColors.onPrimary.withValues(
                                  alpha: 0.92,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: MomoColors.border),
                              ),
                              child: Text(
                                '더미 · 로컬',
                                style: MomoTextStyles.caption.copyWith(
                                  color: MomoColors.textSub,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: JoinMapMemberPanel(
                        title: widget.meeting.title,
                        placeLabel: place,
                        overallStatus: _overallStatus,
                        rows: _panelRows,
                        onChat: _openChat,
                        onLeave: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
    );
  }

  bool get _myLocationEnabledSafe => _myLatLng != null;
}

class _MemberPin {
  const _MemberPin({
    required this.userId,
    required this.nickname,
    required this.latLng,
    required this.isMe,
    required this.isDummy,
    this.isHost = false,
  });

  final String userId;
  final String nickname;
  final LatLng latLng;
  final bool isMe;
  final bool isDummy;
  final bool isHost;

  _MemberPin copyWith({LatLng? latLng}) {
    return _MemberPin(
      userId: userId,
      nickname: nickname,
      latLng: latLng ?? this.latLng,
      isMe: isMe,
      isDummy: isDummy,
      isHost: isHost,
    );
  }
}

/// 이니셜 원형 마커 비트맵.
class _InitialMarkerIcon {
  _InitialMarkerIcon._();

  static Future<BitmapDescriptor> create({
    required String letter,
    required Color fill,
    double pixelRatio = 3,
  }) async {
    const size = 40.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    final center = const Offset(size / 2, size / 2);
    canvas.drawCircle(
      center.translate(0, 1),
      size / 2 - 1,
      Paint()..color = MomoColors.textMain.withValues(alpha: 0.2),
    );
    canvas.drawCircle(
      center,
      size / 2 - 2,
      Paint()..color = fill,
    );
    canvas.drawCircle(
      center,
      size / 2 - 2,
      Paint()
        ..color = MomoColors.onPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final text = letter.length > 1 ? letter.substring(0, 1) : letter;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: MomoColors.onPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        (size - painter.width) / 2,
        (size - painter.height) / 2,
      ),
    );

    final image = await recorder.endRecording().toImage(
      (size * pixelRatio).ceil(),
      (size * pixelRatio).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }
}
