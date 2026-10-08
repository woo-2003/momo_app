import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';

/// 지도 위 공통 아이콘 버튼 (메뉴, 뒤로가기, 내 위치 등).
///
/// 도안 로비는 원형. [circular] false면 예전 둥근 사각.
class MapIconButton extends StatelessWidget {
  const MapIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.circular = true,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// true: 흰 원형 (로비 햄버거·내 위치). false: 기존 12px 사각.
  final bool circular;

  @override
  Widget build(BuildContext context) {
    if (circular) {
      return Material(
        color: MomoColors.onPrimary,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: MomoColors.textMain.withValues(alpha: 0.12),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: MomoColors.textMain, size: 22),
          ),
        ),
      );
    }

    // 이전 사각 스타일 (롤백용으로 유지)
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
