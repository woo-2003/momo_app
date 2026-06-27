import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.md),
          child: Text(
            '무슨 지도 API쓸건지 기획서에 없어서 비워둠',
            textAlign: TextAlign.center,
            style: MomoTextStyles.body.copyWith(color: MomoColors.textSub),
          ),
        ),
      ),
    );
  }
}
