import 'package:flutter/material.dart';
import 'package:momo_app/presentation/widgets/map_icon_button.dart';

/// 현재 위치로 카메라를 되돌리는 지도 버튼.
class MapMyLocationButton extends StatelessWidget {
  const MapMyLocationButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MapIconButton(
      icon: Icons.my_location_rounded,
      onPressed: onPressed,
    );
  }
}
