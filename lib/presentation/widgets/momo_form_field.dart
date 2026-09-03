import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';

/// 라벨 + 둥근 입력창 + (선택) 지도 아이콘.
class MomoFormField extends StatelessWidget {
  const MomoFormField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.readOnly = false,
    this.onTap,
    this.onMapTap,
    this.helperText,
  });

  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final VoidCallback? onMapTap;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: MomoTextStyles.caption.copyWith(
            color: MomoColors.textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: MomoSpacing.xs),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          style: MomoTextStyles.body,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: onMapTap == null
                ? null
                : IconButton(
                    onPressed: onMapTap,
                    icon: const Icon(
                      Icons.map_outlined,
                      color: MomoColors.primary,
                    ),
                  ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: MomoSpacing.xxs),
          Text(
            helperText!,
            style: MomoTextStyles.caption.copyWith(
              color: MomoColors.textSub,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
