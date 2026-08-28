// UI 토큰: Intense Peach.
// 공유 위젯 폴더는 비어 있음. 화면마다 Scaffold/버튼을 직접 구성.
import 'package:flutter/material.dart';

/// 브랜드·상태 색. Material ColorScheme 매핑은 [MomoTheme.light].
class MomoColors {
  const MomoColors._();

  // ── 기본 팔레트 (v2: Intense Peach) ──────────────────────────────────────
  static const Color primary = Color(0xFFEE8F8F);

  /// 웜 아이보리 - 전체 배경
  static const Color background = Color(0xFFFFF9F1);

  /// 연한 피치 - 입력창/카드 표면
  static const Color surface = Color(0xFFFFF1EF);

  /// 본문 텍스트 (Deep Brown)
  static const Color textMain = Color(0xFF4D2121);

  /// 보조 텍스트 (Soft Brown)
  static const Color textSub = Color(0xFF6D4C4C);

  // ── 확장 팔레트 (웜 톤 정렬) ──────────────────────────────────────────
  /// 입력창/카드의 외곽선 - 웜 그레이
  static const Color border = Color(0xFFF2E3DE);

  /// 비활성 상태 배경
  static const Color disabled = Color(0xFFE8D9D5);

  /// 비활성 상태 텍스트
  static const Color textDisabled = Color(0xFFA6908C);

  /// 에러/경고
  static const Color error = Color(0xFFE5383B);

  /// 성공/긍정 피드백 (봄 새싹 연두)
  static const Color success = Color(0xFF88C057);

  /// primary 위에 올라가는 텍스트 (버튼 글씨 등)
  static const Color onPrimary = Color(0xFFFFFFFF);
}

/// 8px 배수 spacing 시스템
class MomoSpacing {
  const MomoSpacing._();
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 16.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 40.0;
  static const double xxl = 48.0;
}

/// Shape - BorderRadius 16px 고정
class MomoRadius {
  const MomoRadius._();
  static const double component = 16.0;
  static const BorderRadius all = BorderRadius.all(Radius.circular(component));
  static const RoundedRectangleBorder shape = RoundedRectangleBorder(
    borderRadius: all,
  );
}

/// momo 텍스트 스타일 토큰
class MomoTextStyles {
  const MomoTextStyles._();

  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: MomoColors.textMain,
    height: 1.35,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: MomoColors.textMain,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: MomoColors.textMain,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: MomoColors.textSub,
    height: 1.45,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: MomoColors.onPrimary,
    height: 1.2,
  );
}

/// momo 통합 ThemeData
class MomoTheme {
  const MomoTheme._();

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: MomoColors.primary,
      onPrimary: MomoColors.onPrimary,
      secondary: MomoColors.primary,
      onSecondary: MomoColors.onPrimary,
      error: MomoColors.error,
      onError: MomoColors.onPrimary,
      surface: MomoColors.background,
      onSurface: MomoColors.textMain,
      surfaceContainerHighest: MomoColors.surface,
      outline: MomoColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MomoColors.background,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: const AppBarTheme(
        backgroundColor: MomoColors.background,
        foregroundColor: MomoColors.textMain,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: MomoTextStyles.heading,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MomoColors.primary,
          foregroundColor: MomoColors.onPrimary,
          disabledBackgroundColor: MomoColors.disabled,
          disabledForegroundColor: MomoColors.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(
            horizontal: MomoSpacing.md,
            vertical: MomoSpacing.sm,
          ),
          shape: MomoRadius.shape,
          textStyle: MomoTextStyles.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MomoColors.textSub,
          padding: const EdgeInsets.symmetric(
            horizontal: MomoSpacing.sm,
            vertical: MomoSpacing.xs,
          ),
          shape: MomoRadius.shape,
          textStyle: MomoTextStyles.caption,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MomoColors.textMain,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: MomoColors.border),
          shape: MomoRadius.shape,
          textStyle: MomoTextStyles.button.copyWith(color: MomoColors.textMain),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MomoColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MomoSpacing.sm,
          vertical: MomoSpacing.sm,
        ),
        hintStyle: MomoTextStyles.body.copyWith(color: MomoColors.textDisabled),
        labelStyle: MomoTextStyles.caption,
        border: const OutlineInputBorder(
          borderRadius: MomoRadius.all,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: MomoRadius.all,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: MomoRadius.all,
          borderSide: BorderSide(color: MomoColors.primary, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: MomoRadius.all,
          borderSide: BorderSide(color: MomoColors.error, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: MomoRadius.all,
          borderSide: BorderSide(color: MomoColors.error, width: 1.5),
        ),
      ),

      cardTheme: const CardThemeData(
        color: MomoColors.surface,
        elevation: 0,
        shape: MomoRadius.shape,
      ),

      dividerTheme: const DividerThemeData(
        color: MomoColors.border,
        thickness: 1,
        space: 1,
      ),

      textTheme: const TextTheme(
        headlineLarge: MomoTextStyles.title,
        headlineMedium: MomoTextStyles.heading,
        bodyLarge: MomoTextStyles.body,
        bodyMedium: MomoTextStyles.caption,
        labelLarge: MomoTextStyles.button,
      ),
    );
  }
}
