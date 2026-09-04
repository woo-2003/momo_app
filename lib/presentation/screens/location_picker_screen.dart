import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/selected_place.dart';
import 'package:momo_app/service/place_service.dart';

/// 지도 pan + 가운데 고정 핀으로 장소 선택.
/// 카메라 정지 시 서버(/places/reverse)로 주소 표시, 상단 검색은 /places/search.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.screenTitle,
    required this.confirmPrompt,
    this.initialPosition,
    this.initialLabel,
    this.placeService,
  });

  final String screenTitle;
  final String confirmPrompt;
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

  Timer? _reverseTimer;
  int _reverseRequestId = 0;
  bool _reverseLoading = false;
  String? _reverseError;
  bool _programmaticMove = false;

  List<PlaceSearchItem> _searchResults = const [];
  bool _searchLoading = false;
  String? _searchError;
  Timer? _searchTimer;

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
        _searchResults = const [];
        _searchError = null;
        _searchLoading = false;
      });
      return;
    }

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
    });

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, _defaultZoom),
    );
  }

  void _confirm() {
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
    final showSearchPanel =
        _searchLoading ||
        _searchError != null ||
        _searchResults.isNotEmpty ||
        _searchController.text.trim().isNotEmpty;

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
            myLocationEnabled: true,
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
                      _MapIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: MomoSpacing.xs),
                      Expanded(
                        child: Text(
                          widget.screenTitle,
                          style: MomoTextStyles.heading.copyWith(fontSize: 18),
                        ),
                      ),
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
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
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
                        constraints: const BoxConstraints(maxHeight: 220),
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
                    const SizedBox(height: MomoSpacing.xxs),
                    Text(
                      widget.confirmPrompt,
                      style: MomoTextStyles.caption.copyWith(
                        color: MomoColors.textSub,
                      ),
                    ),
                    const SizedBox(height: MomoSpacing.md),
                    ElevatedButton(
                      onPressed: _confirm,
                      child: const Text('이 위치로 설정'),
                    ),
                  ],
                ),
              ),
            ),
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

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomoColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: MomoColors.textMain.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: MomoColors.primary, size: 24),
        ),
      ),
    );
  }
}
