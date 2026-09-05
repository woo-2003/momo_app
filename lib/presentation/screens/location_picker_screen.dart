import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/map_location_helper.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/selected_place.dart';
import 'package:momo_app/presentation/widgets/map_icon_button.dart';
import 'package:momo_app/presentation/widgets/map_my_location_button.dart';
import 'package:momo_app/service/place_service.dart';

/// 지도 pan + 가운데 고정 핀으로 장소 선택.
/// 카메라 정지 시 서버(/places/reverse)로 주소 표시, 상단 검색은 /places/search.
///
/// 상단은 뒤로가기+검색만 두고, 역할(출발/도착 등)은 [confirmButtonLabel]로 구분한다.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.screenTitle,
    required this.confirmPrompt,
    this.confirmButtonLabel = '이 위치로 설정',
    this.initialPosition,
    this.initialLabel,
    this.placeService,
  });

  /// 호환용. UI에는 표시하지 않음 (역할은 confirmButtonLabel 사용).
  final String screenTitle;

  /// 호환용. UI에는 표시하지 않음.
  final String confirmPrompt;

  /// 하단 확정 버튼 문구. 출발/도착/집결을 여기서 구분.
  final String confirmButtonLabel;

  final LatLng? initialPosition;
  final String? initialLabel;
  final PlaceService? placeService;

  static const LatLng defaultPosition = LatLng(37.5665, 126.9780);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const double _defaultZoom = 16;
  static const Duration _reverseDebounce = Duration(milliseconds: 400);

  late LatLng _center;
  late final TextEditingController _labelController;
  late final TextEditingController _searchController;
  late final PlaceService _placeService;
  GoogleMapController? _mapController;
  bool _myLocationEnabled = false;

  Timer? _reverseTimer;
  int _reverseRequestId = 0;
  bool _reverseLoading = false;
  String? _reverseError;
  bool _programmaticMove = false;

  List<PlaceSearchItem> _searchResults = const [];
  bool _searchLoading = false;
  String? _searchError;
  Timer? _searchTimer;

  /// true일 때만 검색 결과/로딩/에러 패널을 표시.
  /// 결과 항목을 고르거나 검색어를 비우면 false → 패널 잔상 방지.
  bool _isSearchSessionActive = false;

  @override
  void initState() {
    super.initState();
    _placeService = widget.placeService ?? PlaceService();
    _center = widget.initialPosition ?? LocationPickerScreen.defaultPosition;
    _labelController = TextEditingController(
      text: widget.initialLabel ?? '선택한 위치',
    );
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleReverseGeocode();
    });
  }

  @override
  void dispose() {
    _reverseTimer?.cancel();
    _searchTimer?.cancel();
    _labelController.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    _center = position.target;
  }

  void _onCameraIdle() {
    if (_programmaticMove) {
      _programmaticMove = false;
      return;
    }
    _scheduleReverseGeocode();
  }

  void _scheduleReverseGeocode() {
    _reverseTimer?.cancel();
    _reverseTimer = Timer(_reverseDebounce, _runReverseGeocode);
  }

  Future<void> _runReverseGeocode() async {
    final requestId = ++_reverseRequestId;
    setState(() {
      _reverseLoading = true;
      _reverseError = null;
    });

    try {
      final result = await _placeService.reverseGeocode(
        latitude: _center.latitude,
        longitude: _center.longitude,
      );
      if (!mounted || requestId != _reverseRequestId) return;
      setState(() {
        _labelController.text = result.label;
        _reverseLoading = false;
        _reverseError = null;
      });
    } on PlaceServiceException catch (e) {
      if (!mounted || requestId != _reverseRequestId) return;
      setState(() {
        _reverseLoading = false;
        _reverseError = e.message;
      });
    } catch (_) {
      if (!mounted || requestId != _reverseRequestId) return;
      setState(() {
        _reverseLoading = false;
        _reverseError = '주소를 불러오지 못했어요.';
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        // 검색어가 없으면 세션 종료 → 패널 숨김
        _isSearchSessionActive = false;
        _searchResults = const [];
        _searchError = null;
        _searchLoading = false;
      });
      return;
    }

    // 타이핑 중이면 검색 세션 시작 (패널 표시 허용)
    setState(() => _isSearchSessionActive = true);

    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      _runSearch(q);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searchLoading = true;
      _searchError = null;
    });

    try {
      final items = await _placeService.search(query);
      if (!mounted) return;
      setState(() {
        _searchResults = items;
        _searchLoading = false;
      });
    } on PlaceServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _searchLoading = false;
        _searchError = e.message;
        _searchResults = const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchLoading = false;
        _searchError = '검색에 실패했어요.';
        _searchResults = const [];
      });
    }
  }

  Future<void> _onSearchItemTap(PlaceSearchItem item) async {
    FocusScope.of(context).unfocus();
    final target = LatLng(item.latitude, item.longitude);
    setState(() {
      _center = target;
      _labelController.text = item.name;
      _searchResults = const [];
      _searchController.text = item.name;
      _reverseError = null;
      _programmaticMove = true;
      // 선택 완료 → 검색 세션 종료. 검색창에 이름이 남아도 패널은 닫힘.
      _isSearchSessionActive = false;
      _searchError = null;
      _searchLoading = false;
    });

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, _defaultZoom),
    );
  }

  /// 검색창·결과·에러를 초기화하고 패널을 닫는다. (X 버튼)
  void _closeSearchSession() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _isSearchSessionActive = false;
      _searchResults = const [];
      _searchError = null;
      _searchLoading = false;
    });
  }

  /// 결과 패널만 닫는다. 검색어는 유지 (지도 탭 등).
  void _dismissSearchPanel() {
    if (!_isSearchSessionActive) return;
    _searchTimer?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearchSessionActive = false;
      _searchResults = const [];
      _searchError = null;
      _searchLoading = false;
    });
  }

  Future<void> _onMyLocationPressed() async {
    _dismissSearchPanel();

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

    // programmaticMove를 쓰지 않음 → idle 후 reverse로 하단 주소 갱신.
    final moved = await MapLocationHelper.moveCameraToCurrent(
      _mapController,
      zoom: _defaultZoom,
    );
    if (!mounted || moved) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('현재 위치를 가져오지 못했어요.')),
    );
  }

  void _confirm() {
    if (_reverseLoading) return;

    final label = _labelController.text.trim();
    if (label.isEmpty) return;

    Navigator.of(context).pop(
      SelectedPlace(
        label: label,
        latitude: _center.latitude,
        longitude: _center.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 이전: 검색창에 글자만 있어도 패널을 열어, 선택 후 "결과 없음" 잔상이 남았음.
    // final showSearchPanel =
    //     _searchLoading ||
    //     _searchError != null ||
    //     _searchResults.isNotEmpty ||
    //     _searchController.text.trim().isNotEmpty;

    // 검색 세션이 살아 있을 때만 패널 표시 (출발/도착/집결 공통).
    final showSearchPanel =
        _isSearchSessionActive &&
        (_searchLoading ||
            _searchError != null ||
            _searchResults.isNotEmpty ||
            _searchController.text.trim().isNotEmpty);

    // 결과 패널이 가운데 핀을 과도하게 가리지 않도록 높이 제한.
    // 이전: const BoxConstraints(maxHeight: 220)
    final panelMaxHeight = (MediaQuery.sizeOf(context).height * 0.28).clamp(
      120.0,
      180.0,
    );

    return Scaffold(
      backgroundColor: MomoColors.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: _defaultZoom,
            ),
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            // 지도 빈 곳 탭 → 검색 결과만 닫기 (pan/줌은 지도가 처리).
            onTap: (_) => _dismissSearchPanel(),
            myLocationEnabled: _myLocationEnabled,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_on,
                size: 48,
                color: MomoColors.primary,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      MapIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      // 타이틀은 하단 버튼 라벨로 역할을 구분해 제거.
                      // const SizedBox(width: MomoSpacing.xs),
                      // Expanded(
                      //   child: Text(
                      //     widget.screenTitle,
                      //     style: MomoTextStyles.heading.copyWith(fontSize: 18),
                      //   ),
                      // ),
                    ],
                  ),
                  const SizedBox(height: MomoSpacing.sm),
                  Material(
                    color: MomoColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 2,
                    shadowColor: MomoColors.textMain.withValues(alpha: 0.12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '장소 검색 (예: 성결대학교)',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : (_searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      // X: 검색어·패널 함께 닫기
                                      onPressed: _closeSearchSession,
                                    )),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: MomoSpacing.sm,
                          vertical: MomoSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  if (showSearchPanel) ...[
                    const SizedBox(height: MomoSpacing.xs),
                    Material(
                      color: MomoColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 2,
                      child: ConstrainedBox(
                        // constraints: const BoxConstraints(maxHeight: 220),
                        constraints: BoxConstraints(maxHeight: panelMaxHeight),
                        child: _buildSearchPanel(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: MomoColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(
                MomoSpacing.sm,
                MomoSpacing.md,
                MomoSpacing.sm,
                MomoSpacing.md,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_reverseLoading)
                      Text(
                        '주소를 찾는 중…',
                        style: MomoTextStyles.caption.copyWith(
                          color: MomoColors.textSub,
                        ),
                      ),
                    if (_reverseError != null)
                      Text(
                        _reverseError!,
                        style: MomoTextStyles.caption.copyWith(
                          color: MomoColors.error,
                        ),
                      ),
                    TextField(
                      controller: _labelController,
                      style: MomoTextStyles.heading.copyWith(fontSize: 20),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    // 버튼 문구와 중복되어 안내 문장은 숨김.
                    // const SizedBox(height: MomoSpacing.xxs),
                    // Text(
                    //   widget.confirmPrompt,
                    //   style: MomoTextStyles.caption.copyWith(
                    //     color: MomoColors.textSub,
                    //   ),
                    // ),
                    const SizedBox(height: MomoSpacing.md),
                    ElevatedButton(
                      // 주소 reverse 중에는 확정 불가 (잘못된 좌표·라벨 확정 방지).
                      // onPressed: _confirm,
                      onPressed: _reverseLoading ? null : _confirm,
                      child: Text(widget.confirmButtonLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 하단 시트 바로 위 오른쪽 (시트보다 위에 그려 탭 가능).
          Positioned(
            right: MomoSpacing.sm,
            bottom: MediaQuery.paddingOf(context).bottom + 188,
            child: MapMyLocationButton(onPressed: _onMyLocationPressed),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.all(MomoSpacing.sm),
        child: Text(
          _searchError!,
          style: MomoTextStyles.caption.copyWith(color: MomoColors.error),
        ),
      );
    }

    if (_searchLoading && _searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(MomoSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(MomoSpacing.sm),
        child: Text(
          '검색 결과가 없어요.',
          style: MomoTextStyles.caption.copyWith(color: MomoColors.textSub),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: MomoColors.border),
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return ListTile(
          dense: true,
          title: Text(item.name, style: MomoTextStyles.body),
          subtitle: item.address.isEmpty
              ? null
              : Text(
                  item.address,
                  style: MomoTextStyles.caption.copyWith(
                    color: MomoColors.textSub,
                  ),
                ),
          onTap: () => _onSearchItemTap(item),
        );
      },
    );
  }
}
