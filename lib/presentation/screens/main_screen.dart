import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/map_location_helper.dart';
import 'package:momo_app/core/meeting_display.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/meeting_repository_impl.dart';
import 'package:momo_app/data/meeting_store.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
// import 'package:momo_app/domain/taxi_pod_meeting.dart';
import 'package:momo_app/presentation/screens/create_gathering_screen.dart';
import 'package:momo_app/presentation/screens/create_taxi_pod_screen.dart';
import 'package:momo_app/presentation/screens/meeting_detail_screen.dart';
import 'package:momo_app/presentation/widgets/app_menu_drawer.dart';
import 'package:momo_app/presentation/widgets/create_meeting_sheet.dart';
import 'package:momo_app/service/meeting_location_service.dart';
import 'package:momo_app/service/meeting_location_share_service.dart';
import 'package:momo_app/presentation/widgets/map_icon_button.dart';
import 'package:momo_app/presentation/widgets/map_lobby_chrome.dart';
import 'package:momo_app/presentation/widgets/map_my_location_button.dart';
import 'package:momo_app/presentation/widgets/meeting_preview_sheet.dart';
import 'package:momo_app/presentation/widgets/my_joined_meetings_sheet.dart';
import 'package:momo_app/presentation/widgets/taxi_marker_icon.dart';
import 'package:momo_app/presentation/widgets/taxi_pod_preview_sheet.dart';

// 로그인 후 홈 — 장면 A(메인 지도 / 로비).
// 마커: GET /meetings (좌표 있는 것). 칩으로 카테고리 필터.
// 로컬 MeetingStore는 롤백용으로 유지.
class MainScreen extends StatefulWidget {
  MainScreen({super.key, MeetingRepository? meetingRepository})
    : meetingRepository = meetingRepository ?? MeetingRepositoryImpl();

  final MeetingRepository meetingRepository;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// 로비 칩. [kinds] null = 전체.
/// 식사/공부는 sportType prefix 기반 (서버 meal/study enum 전 임시).
class _LobbyFilter {
  const _LobbyFilter(this.label, this.kinds);

  final String label;
  final Set<MeetingDisplayKind>? kinds;

  bool matches(MeetingSummary meeting) {
    final set = kinds;
    if (set == null) return true;
    return set.contains(MeetingDisplay.kindOf(meeting));
  }
}

class _MainScreenState extends State<MainScreen> {
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 14,
  );

  /// 도안 칩 순서. 표시 종류는 [MeetingDisplay] (서버 enum + sportType prefix).
  static const List<_LobbyFilter> _filters = [
    _LobbyFilter('전체', null),
    _LobbyFilter('식사', {
      MeetingDisplayKind.meal,
      MeetingDisplayKind.drink,
      MeetingDisplayKind.dating,
    }),
    _LobbyFilter('스포츠', {MeetingDisplayKind.sports}),
    _LobbyFilter('공부', {MeetingDisplayKind.study}),
    _LobbyFilter('택시팟', {MeetingDisplayKind.taxi}),
  ];

  int _selectedFilterIndex = 0;
  GoogleMapController? _mapController;
  bool _myLocationEnabled = false;
  Set<Marker> _markers = {};
  List<MeetingMemberGps> _memberGps = const [];
  StreamSubscription<List<MeetingMemberGps>>? _gpsSubscription;
  String? _myUserId;

  /// 서버에서 받은 모임 (좌표 있는 것만 마커에 사용).
  List<MeetingSummary> _serverMeetings = const [];

  /// 서버 모임 마커. GPS 갱신 때 이 집합 위에 멤버 핀을 다시 얹는다.
  Set<Marker> _meetingMarkers = {};

  /// 복숭아 FAB 뱃지 (가입 번개 수). 시트 로드 시 갱신.
  int? _joinedBadgeCount;

  @override
  void initState() {
    super.initState();
    // _markers = _buildMarkers(); // 로컬 MeetingStore
    _loadMeetingsFromServer();
    _initMyLocation();
    _listenMemberGps();
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    // 비동기 animateCamera 가 dispose 이후에 돌지 않도록 먼저 null.
    final controller = _mapController;
    _mapController = null;
    controller?.dispose();
    super.dispose();
  }

  Future<void> _listenMemberGps() async {
    final session = await SessionStore().read();
    if (!mounted) return;
    _myUserId = session?.accountId;
    setState(() {
      _memberGps = MeetingLocationShareService.instance.currentMembers;
      _markers = _buildMarkers();
    });

    _gpsSubscription = MeetingLocationShareService.instance.members.listen((
      items,
    ) {
      if (!mounted) return;
      setState(() {
        _memberGps = items;
        _markers = _buildMarkers();
      });
    });
  }

  Future<void> _initMyLocation() async {
    final granted = await MapLocationHelper.ensurePermission();
    if (!granted || !mounted) return;

    setState(() => _myLocationEnabled = true);
    await MapLocationHelper.moveCameraToCurrent(_mapController);
  }

  Future<void> _onMyLocationPressed() async {
    final granted = await MapLocationHelper.ensurePermission();
    if (!mounted) return;

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 권한을 허용해 주세요.')),
      );
      return;
    }

    if (!_myLocationEnabled) {
      setState(() => _myLocationEnabled = true);
    }

    final moved = await MapLocationHelper.moveCameraToCurrent(_mapController);
    if (!mounted || moved) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('현재 위치를 가져오지 못했어요.')),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_myLocationEnabled) {
      MapLocationHelper.moveCameraToCurrent(_mapController);
    }
  }

  Set<Marker> _buildMarkers() {
    final filter = _filters[_selectedFilterIndex];
    final showLocalTaxi =
        filter.kinds == null ||
        filter.kinds!.contains(MeetingDisplayKind.taxi);
    final taxiMarkers = showLocalTaxi
        ? {
            for (final meeting in MeetingStore.instance.taxiPods)
              Marker(
                markerId: MarkerId('taxi_${meeting.id}'),
                position: meeting.markerPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
                infoWindow: InfoWindow(title: meeting.title),
              ),
          }
        : <Marker>{};

    final gpsMarkers = {
      for (final member in _memberGps)
        if (member.userId != _myUserId)
          Marker(
            markerId: MarkerId('gps_${member.meetingId}_${member.userId}'),
            position: LatLng(member.latitude, member.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
    };

    return {..._meetingMarkers, ...taxiMarkers, ...gpsMarkers};
  }

  // --- [로컬 마커 — 롤백용] MeetingStore.taxiPods ---
  // Set<Marker> _buildMarkers() {
  //   final showTaxi = _selectedFilterIndex == 0 || _selectedFilterIndex == 1;
  //   if (!showTaxi) return {};
  //
  //   return {
  //     for (final meeting in MeetingStore.instance.taxiPods)
  //       Marker(
  //         markerId: MarkerId('taxi_${meeting.id}'),
  //         position: meeting.markerPosition,
  //         icon: BitmapDescriptor.defaultMarkerWithHue(
  //           BitmapDescriptor.hueOrange,
  //         ),
  //         infoWindow: InfoWindow(title: meeting.title),
  //       ),
  //   };
  // }
  //
  // void _refreshMarkers() {
  //   setState(() => _markers = _buildMarkers());
  // }

  /// open 모임 목록을 받아 지도 마커로 반영. 칩은 [_filteredMeetings]로 걸러짐.
  Future<void> _loadMeetingsFromServer() async {
    try {
      final items = await widget.meetingRepository.listMeetings();
      if (!mounted) return;

      final withCoords = items
          .where((m) => m.latitude != null && m.longitude != null)
          .toList();

      // 목록 API에 categoryFields 없으면 상세로 보강 (필터·말풍용).
      // 동준이 GET /meetings 에 fields 넣으면 이 블록은 제거해도 됨.
      final enriched = await Future.wait(
        withCoords.map((summary) async {
          final needsEnrich = switch (summary.category) {
            MeetingCategory.taxi => summary.destinationName == null,
            MeetingCategory.sports => summary.sportType == null,
            MeetingCategory.game => summary.gameName == null,
          };
          if (!needsEnrich) return summary;
          try {
            final detail =
                await widget.meetingRepository.getMeeting(summary.meetingId);
            return MeetingSummary(
              meetingId: summary.meetingId,
              category: summary.category,
              meetingMode: summary.meetingMode,
              status: summary.status,
              title: summary.title,
              startAt: summary.startAt,
              currentMembers: detail.currentMembers,
              maxMembers: detail.maxMembers,
              placeName: detail.placeName ?? summary.placeName,
              latitude: summary.latitude,
              longitude: summary.longitude,
              destinationName: detail.destinationName,
              departPlaceName:
                  detail.departPlaceName ?? summary.departPlaceName,
              sportType: detail.sportType ?? summary.sportType,
              gameName: detail.gameName ?? summary.gameName,
            );
          } catch (_) {
            return summary;
          }
        }),
      );

      if (!mounted) return;
      _serverMeetings = enriched;
      await _rebuildCustomMarkers();
    } on MeetingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임 목록을 불러오지 못했어요.')),
      );
    }
  }

  List<MeetingSummary> get _filteredMeetings {
    final filter = _filters[_selectedFilterIndex];
    return _serverMeetings.where(filter.matches).toList();
  }

  /// 필터된 모임으로 마커 생성 후 setState.
  Future<void> _rebuildCustomMarkers() async {
    final meetings = _filteredMeetings;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final next = <Marker>{};

    for (final meeting in meetings) {
      if (meeting.category == MeetingCategory.taxi) {
        final icon = await TaxiMarkerIcon.create(
          routeLabel: meeting.markerRouteLabel,
          currentMembers: meeting.currentMembers,
          maxMembers: meeting.maxMembers,
          pixelRatio: pixelRatio,
        );
        next.add(
          Marker(
            markerId: MarkerId(meeting.meetingId),
            position: LatLng(meeting.latitude!, meeting.longitude!),
            icon: icon,
            anchor: const Offset(0.5, 1.0),
            onTap: () => _showTaxiPodPreview(meeting.meetingId),
          ),
        );
        continue;
      }

      // 비택시: 색 핀 + 프리뷰 시트.
      final kind = MeetingDisplay.kindOf(meeting);
      next.add(
        Marker(
          markerId: MarkerId(meeting.meetingId),
          position: LatLng(meeting.latitude!, meeting.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _hueForDisplayKind(kind),
          ),
          infoWindow: InfoWindow(
            title: meeting.title,
            snippet:
                '${MeetingDisplay.label(kind)} · ${meeting.currentMembers}/${meeting.maxMembers}명',
          ),
          onTap: () => _showMeetingPreview(meeting.meetingId),
        ),
      );
    }

    if (!mounted) return;
    _meetingMarkers = next;
    setState(() => _markers = _buildMarkers());
  }

  double _hueForDisplayKind(MeetingDisplayKind kind) {
    switch (kind) {
      case MeetingDisplayKind.meal:
      case MeetingDisplayKind.drink:
      case MeetingDisplayKind.dating:
        return BitmapDescriptor.hueRose;
      case MeetingDisplayKind.sports:
        return BitmapDescriptor.hueOrange;
      case MeetingDisplayKind.study:
        return BitmapDescriptor.hueGreen;
      case MeetingDisplayKind.hobby:
        return BitmapDescriptor.hueAzure;
      case MeetingDisplayKind.taxi:
        return BitmapDescriptor.hueYellow;
      case MeetingDisplayKind.other:
        return BitmapDescriptor.hueViolet;
    }
  }

  Future<void> _showMeetingPreview(String meetingId) async {
    final changed = await showMeetingPreviewSheet(
      context: context,
      meetingId: meetingId,
      meetingRepository: widget.meetingRepository,
    );
    if (!mounted) return;
    if (changed == true) {
      await _loadMeetingsFromServer();
    }
  }

  // --- [롤백용] 기본 주황 핀 마커 ---
  // Set<Marker> _buildServerTaxiMarkers() {
  //   final showTaxi = _selectedFilterIndex == 0 || _selectedFilterIndex == 1;
  //   if (!showTaxi) return {};
  //
  //   return {
  //     for (final meeting in _serverTaxiMeetings)
  //       Marker(
  //         markerId: MarkerId(meeting.meetingId),
  //         position: LatLng(meeting.latitude!, meeting.longitude!),
  //         icon: BitmapDescriptor.defaultMarkerWithHue(
  //           BitmapDescriptor.hueOrange,
  //         ),
  //         infoWindow: InfoWindow(title: meeting.title),
  //         onTap: () => _showTaxiPodPreview(meeting.meetingId),
  //       ),
  //   };
  // }

  void _applyMarkerFilter() {
    // setState(() => _markers = _buildServerTaxiMarkers());
    _rebuildCustomMarkers();
  }

  // --- [롤백용] 마커 탭 → 상세 화면으로 바로 이동 ---
  // Future<void> _openMeetingDetail(String meetingId) async {
  //   await Navigator.of(context).push<void>(
  //     MaterialPageRoute<void>(
  //       builder: (_) => MeetingDetailScreen(
  //         meetingId: meetingId,
  //         meetingRepository: widget.meetingRepository,
  //       ),
  //     ),
  //   );
  //   if (!mounted) return;
  //   await _loadMeetingsFromServer();
  // }

  /// 마커 탭 → 지도 유지 + 하단 미리보기 시트.
  /// 시트에서 참여/상세 후 true면 마커 목록 갱신.
  Future<void> _showTaxiPodPreview(String meetingId) async {
    final changed = await showTaxiPodPreviewSheet(
      context: context,
      meetingId: meetingId,
      meetingRepository: widget.meetingRepository,
    );
    if (!mounted) return;
    if (changed == true) {
      await _loadMeetingsFromServer();
    }
  }

  Future<void> _onAddPressed() async {
    final type = await showCreateMeetingSheet(context);
    if (!mounted || type == null) return;

    if (type == CreateMeetingType.gathering) {
      final created = await Navigator.of(context).push<CreateGatheringResult>(
        MaterialPageRoute(
          builder: (_) => CreateGatheringScreen(
            meetingRepository: widget.meetingRepository,
          ),
        ),
      );
      if (!mounted || created == null) return;
      await _loadMeetingsFromServer();
      if (created.focus != null) {
        await _safeAnimateCamera(created.focus!);
      }
      if (!mounted || created.meetingId.isEmpty) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MeetingDetailScreen(
            meetingId: created.meetingId,
            meetingRepository: widget.meetingRepository,
          ),
        ),
      );
      if (!mounted) return;
      await _loadMeetingsFromServer();
      return;
    }

    // 택시팟 개설 → 마커 갱신 → 집결지 카메라 → 상세
    final created = await Navigator.of(context).push<CreateTaxiPodResult>(
      MaterialPageRoute(
        builder: (_) => CreateTaxiPodScreen(
          meetingRepository: widget.meetingRepository,
        ),
      ),
    );

    if (!mounted || created == null) return;

    await _loadMeetingsFromServer();
    await _safeAnimateCamera(created.focus);

    if (!mounted) return;
    if (created.meetingId.isEmpty) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MeetingDetailScreen(
          meetingId: created.meetingId,
          meetingRepository: widget.meetingRepository,
        ),
      ),
    );
    if (!mounted) return;
    await _loadMeetingsFromServer();
  }

  void _onFilterSelected(int index) {
    setState(() => _selectedFilterIndex = index);
    // _refreshMarkers();
    _applyMarkerFilter();
  }

  /// 복숭아: 내가 참여 중인 번개 시트.
  /// 「지도 위치」선택 시 LatLng 반환 → 카메라 이동.
  Future<void> _showMyJoinedMeetings() async {
    final focus = await showMyJoinedMeetingsSheet(
      context: context,
      meetingRepository: widget.meetingRepository,
      onJoinedCount: (count) {
        if (!mounted) return;
        setState(() => _joinedBadgeCount = count);
      },
    );
    if (!mounted || focus == null) return;

    await _safeAnimateCamera(focus);
  }

  Future<void> _safeAnimateCamera(LatLng target, {double zoom = 16}) async {
    final controller = _mapController;
    if (controller == null || !mounted) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(target, zoom),
      );
    } on StateError {
      // 지도 dispose 이후 — 무시
    } catch (_) {}
  }

  void _disposeMapForLogout() {
    MeetingLocationShareService.instance.stopAll();
    final controller = _mapController;
    _mapController = null;
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: MomoColors.background,
      drawer: AppMenuDrawer(
        meetingRepository: widget.meetingRepository,
        onLogoutMapCleanup: _disposeMapForLogout,
        onJoinedCount: (count) {
          if (!mounted) return;
          setState(() => _joinedBadgeCount = count);
        },
        onJoinedMapFocus: (focus) {
          _safeAnimateCamera(focus);
        },
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              onMapCreated: _onMapCreated,
              markers: _markers,
              myLocationEnabled: _myLocationEnabled,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MomoSpacing.sm,
                    MomoSpacing.xs,
                    MomoSpacing.sm,
                    MomoSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) => MapIconButton(
                          icon: Icons.menu_rounded,
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                      const SizedBox(width: MomoSpacing.xs),
                      const Expanded(child: MapSearchPill()),
                      const SizedBox(width: MomoSpacing.xs),
                      MapAddButton(onPressed: _onAddPressed),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: MomoSpacing.sm,
                    ),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: MomoSpacing.xs),
                    itemBuilder: (context, index) {
                      final selected = index == _selectedFilterIndex;
                      return MapFilterChip(
                        label: _filters[index].label,
                        selected: selected,
                        onTap: () => _onFilterSelected(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 복숭아 FAB(72) 위 — 시스템 내비/제스처 바 inset 포함.
          Positioned(
            right: MomoSpacing.sm,
            bottom: MomoSpacing.lg + bottomInset + 72 + MomoSpacing.sm,
            child: MapMyLocationButton(onPressed: _onMyLocationPressed),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MomoSpacing.lg + bottomInset,
            child: Center(
              child: PeachFab(
                onPressed: _showMyJoinedMeetings,
                badgeCount: _joinedBadgeCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
