import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';

/// 지도 위 공통 아이콘 버튼 (메뉴, 뒤로가기, 내 위치 등).
class MapIconButton extends StatelessWidget {
  const MapIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

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
