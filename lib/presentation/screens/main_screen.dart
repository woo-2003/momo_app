import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/map_location_helper.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/data/meeting_repository_impl.dart';
// import 'package:momo_app/data/meeting_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
// import 'package:momo_app/domain/taxi_pod_meeting.dart';
import 'package:momo_app/presentation/screens/create_taxi_pod_screen.dart';
import 'package:momo_app/presentation/screens/login_screen.dart';
import 'package:momo_app/presentation/screens/meeting_detail_screen.dart';
import 'package:momo_app/presentation/screens/meeting_list_screen.dart';
import 'package:momo_app/presentation/widgets/create_meeting_sheet.dart';
import 'package:momo_app/presentation/widgets/map_icon_button.dart';
import 'package:momo_app/presentation/widgets/map_my_location_button.dart';

// 로그인 후 홈 — 장면 A(메인 지도).
// 택시 마커: GET /meetings?category=taxi (집결 좌표). 로컬 MeetingStore는 롤백용으로 유지.
class MainScreen extends StatefulWidget {
  MainScreen({super.key, MeetingRepository? meetingRepository})
    : meetingRepository = meetingRepository ?? MeetingRepositoryImpl();

  final MeetingRepository meetingRepository;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 14,
  );

  static const List<String> _filters = [
    '전체',
    '택시팟',
    '스터디',
    '스포츠',
    '밥약',
  ];

  int _selectedFilterIndex = 0;
  GoogleMapController? _mapController;
  bool _myLocationEnabled = false;
  Set<Marker> _markers = {};

  /// 서버에서 받은 택시 모임 (좌표 있는 것만 마커에 사용).
  List<MeetingSummary> _serverTaxiMeetings = const [];

  @override
  void initState() {
    super.initState();
    // _markers = _buildMarkers(); // 로컬 MeetingStore
    _loadTaxiMarkersFromServer();
    _initMyLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
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

  /// open 택시 목록을 받아 지도 마커로 반영. 필터가 택시가 아니면 빈 세트.
  Future<void> _loadTaxiMarkersFromServer() async {
    try {
      final items = await widget.meetingRepository.listMeetings(
        category: MeetingCategory.taxi,
      );
      if (!mounted) return;

      _serverTaxiMeetings = items
          .where((m) => m.latitude != null && m.longitude != null)
          .toList();
      setState(() => _markers = _buildServerTaxiMarkers());
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

  Set<Marker> _buildServerTaxiMarkers() {
    // 전체(0) · 택시팟(1)만 표시. 스터디/스포츠/밥약은 이번 스프린트 미연동.
    final showTaxi = _selectedFilterIndex == 0 || _selectedFilterIndex == 1;
    if (!showTaxi) return {};

    return {
      for (final meeting in _serverTaxiMeetings)
        Marker(
          markerId: MarkerId(meeting.meetingId),
          position: LatLng(meeting.latitude!, meeting.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: meeting.title),
          onTap: () => _openMeetingDetail(meeting.meetingId),
        ),
    };
  }

  void _applyMarkerFilter() {
    setState(() => _markers = _buildServerTaxiMarkers());
  }

  Future<void> _openMeetingDetail(String meetingId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MeetingDetailScreen(
          meetingId: meetingId,
          meetingRepository: widget.meetingRepository,
        ),
      ),
    );
    if (!mounted) return;
    // 취소·참여 변경 반영
    await _loadTaxiMarkersFromServer();
  }

  Future<void> _onAddPressed() async {
    final type = await showCreateMeetingSheet(context);
    if (!mounted || type == null) return;

    if (type == CreateMeetingType.gathering) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임 생성은 준비 중이에요.')),
      );
      return;
    }

    // --- [로컬 생성 — 롤백용] ---
    // final created = await Navigator.of(context).push<TaxiPodMeeting>(
    //   MaterialPageRoute(builder: (_) => const CreateTaxiPodScreen()),
    // );
    // if (!mounted) return;
    // _refreshMarkers();
    // if (created != null) {
    //   await _mapController?.animateCamera(
    //     CameraUpdate.newLatLngZoom(created.markerPosition, 16),
    //   );
    // }

    final focus = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => CreateTaxiPodScreen(
          meetingRepository: widget.meetingRepository,
        ),
      ),
    );

    if (!mounted) return;
    await _loadTaxiMarkersFromServer();

    if (focus != null) {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(focus, 16),
      );
    }
  }

  void _onFilterSelected(int index) {
    setState(() => _selectedFilterIndex = index);
    // _refreshMarkers();
    _applyMarkerFilter();
  }

  void _openMeetingList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MeetingListScreen()),
    );
  }

  // ===== [DEBUG] 임시 로그아웃 — 테스트용, 나중에 이 메서드와 Drawer 항목을 삭제하세요 =====
  Future<void> _onLogout() async {
    await SessionStore().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
  // ===== [DEBUG] 끝 =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      drawer: Drawer(
        backgroundColor: MomoColors.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(MomoSpacing.sm),
                child: Text('메뉴', style: MomoTextStyles.heading),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.forum_outlined, color: MomoColors.textSub),
                title: Text(
                  '모임 목록',
                  style: MomoTextStyles.body.copyWith(color: MomoColors.textSub),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _openMeetingList();
                },
              ),
              // ===== [DEBUG] 임시 로그아웃 — 테스트용, 나중에 삭제하세요 =====
              ListTile(
                leading: const Icon(Icons.logout, color: MomoColors.textSub),
                title: Text(
                  '로그아웃',
                  style: MomoTextStyles.body.copyWith(color: MomoColors.textSub),
                ),
                onTap: _onLogout,
              ),
              // ===== [DEBUG] 끝 =====
            ],
          ),
        ),
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
                      const Spacer(),
                      _MapAddButton(onPressed: _onAddPressed),
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
                      return _MapFilterChip(
                        label: _filters[index],
                        selected: selected,
                        onTap: () => _onFilterSelected(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 복숭아 FAB(72) 위 — 내 위치 버튼과 겹치지 않게.
          Positioned(
            right: MomoSpacing.sm,
            bottom: MomoSpacing.lg + 72 + MomoSpacing.sm,
            child: MapMyLocationButton(onPressed: _onMyLocationPressed),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MomoSpacing.lg,
            child: Center(
              child: _PeachFab(onPressed: _openMeetingList),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapAddButton extends StatelessWidget {
  const _MapAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomoColors.primary,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: MomoColors.primary.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.add, color: MomoColors.onPrimary, size: 28),
        ),
      ),
    );
  }
}

class _MapFilterChip extends StatelessWidget {
  const _MapFilterChip({
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
      color: selected ? MomoColors.textMain : MomoColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MomoSpacing.sm,
            vertical: MomoSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? null
                : Border.all(color: MomoColors.border),
          ),
          child: Text(
            label,
            style: MomoTextStyles.caption.copyWith(
              color: selected ? MomoColors.onPrimary : MomoColors.textMain,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeachFab extends StatelessWidget {
  const _PeachFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomoColors.onPrimary,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: MomoColors.primary.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: MomoColors.primary, width: 2),
          ),
          alignment: Alignment.center,
          child: const Text('🍑', style: TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}
