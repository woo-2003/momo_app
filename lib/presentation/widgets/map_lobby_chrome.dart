import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';

/// 메인 지도 로비 상·하단 크롬 (도안 robby 톤).
/// 색은 [MomoColors]만 사용.

/// 검색 pill — 이번 Phase는 placeholder만 (검색 로직 없음).
class MapSearchPill extends StatelessWidget {
  const MapSearchPill({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomoColors.onPrimary,
      borderRadius: BorderRadius.circular(24),
      elevation: 3,
      shadowColor: MomoColors.textMain.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.sm),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: MomoColors.textSub.withValues(alpha: 0.85),
              ),
              const SizedBox(width: MomoSpacing.xs),
              Expanded(
                child: Text(
                  '근처 번개 모임 검색...',
                  style: MomoTextStyles.caption.copyWith(
                    color: MomoColors.textDisabled,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카테고리 칩 — 선택 시 피치, 비선택 시 밝은 흰 칩.
class MapFilterChip extends StatelessWidget {
  const MapFilterChip({
    super.key,
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
      color: selected ? MomoColors.primary : MomoColors.onPrimary,
      borderRadius: BorderRadius.circular(20),
      elevation: selected ? 3 : 2,
      shadowColor: selected
          ? MomoColors.primary.withValues(alpha: 0.35)
          : MomoColors.textMain.withValues(alpha: 0.10),
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
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 우상단 피치 + 버튼.
class MapAddButton extends StatelessWidget {
  const MapAddButton({super.key, required this.onPressed});

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
          width: 44,
          height: 44,
          child: Icon(Icons.add, color: MomoColors.onPrimary, size: 26),
        ),
      ),
    );
  }
}

/// 하단 중앙 복숭아 FAB.
class PeachFab extends StatelessWidget {
  const PeachFab({
    super.key,
    required this.onPressed,
    this.badgeCount,
  });

  final VoidCallback onPressed;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount != null && badgeCount! > 0;

    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
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
                  border: Border.all(
                    color: MomoColors.primary.withValues(alpha: 0.55),
                    width: 2.5,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('🍑', style: TextStyle(fontSize: 34)),
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: MomoColors.error,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeCount! > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    color: MomoColors.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
