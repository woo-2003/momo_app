import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/selected_place.dart';

/// 지도 pan + 가운데 고정 핀으로 장소 선택.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.screenTitle,
    required this.confirmPrompt,
    this.initialPosition,
    this.initialLabel,
  });

  final String screenTitle;
  final String confirmPrompt;
  final LatLng? initialPosition;
  final String? initialLabel;

  static const LatLng defaultPosition = LatLng(37.5665, 126.9780);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const double _defaultZoom = 16;

  late LatLng _center;
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _center = widget.initialPosition ?? LocationPickerScreen.defaultPosition;
    _labelController = TextEditingController(
      text: widget.initialLabel ?? '선택한 위치',
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _onCameraMove(CameraPosition position) {
    _center = position.target;
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
    return Scaffold(
      backgroundColor: MomoColors.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: _defaultZoom,
            ),
            onCameraMove: _onCameraMove,
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
              child: Row(
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
