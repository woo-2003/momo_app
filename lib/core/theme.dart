// UI 토큰: Intense Peach.
// 공유 위젯 폴더는 비어 있음. 화면마다 Scaffold/버튼을 직접 구성.
import 'package:flutter/material.dart';

/// 브랜드·상태 색. Material ColorScheme 매핑은 [MomoTheme.light].
class MomoColors {
  const MomoColors._();

  // ── 기본 팔레트 (v3: Fresh Peach / 더 하얀 배경) ────────────────────────
  /// 쨍한 피치 (버튼·강조)
  /// 이전: Color(0xFFEE8F8F)
  static const Color primary = Color(0xFFFF8575);

  /// 거의 화이트에 가까운 배경
  /// 이전: Color(0xFFFFF9F1) → Color(0xFFFEFCFA)
  static const Color background = Color(0xFFFFFFFE);

  /// 연한 피치 - 입력창/카드 표면
  /// 이전: Color(0xFFFFF1EF)
  static const Color surface = Color(0xFFFFF5F2);

  /// 본문 텍스트 (Deep Brown)
  static const Color textMain = Color(0xFF4D2121);

  /// 보조 텍스트 (Soft Brown)
  static const Color textSub = Color(0xFF6D4C4C);

  // ── 확장 팔레트 (웜 톤 정렬) ──────────────────────────────────────────
  /// 입력창/카드의 외곽선 - 맑은 피치 보더
  /// 이전: Color(0xFFF2E3DE)
  static const Color border = Color(0xFFFFE4DC);

  /// 비활성 상태 배경
  /// 이전: Color(0xFFE8D9D5)
  static const Color disabled = Color(0xFFF5D0C8);

  /// 비활성 상태 텍스트
  /// 이전: Color(0xFFA6908C)
  static const Color textDisabled = Color(0xFFB89A94);

  /// 에러/경고
  static const Color error = Color(0xFFE5383B);

  /// 성공/긍정 피드백 (봄 새싹 연두)
  static const Color success = Color(0xFF88C057);

  /// primary 위에 올라가는 텍스트 (버튼 글씨 등)
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── 역할 액센트 (화면에서 hex 직접 쓰지 말고 여기만) ───────────────────
  /// 택시팟 말풍·배지 골드
  static const Color taxiGold = Color(0xFFF0C24B);

  /// 택시 골드 테두리/강조
  static const Color taxiGoldDark = Color(0xFFE0A820);

  /// 택시 배지 연한 배경
  static const Color taxiGoldSoft = Color(0xFFFFF3D0);

  /// 택시 골드 위 글씨/아이콘
  static const Color onTaxiGold = Color(0xFFFFFFFF);

  /// 보조 필 (닫기·지도위치 등 중립 버튼 배경)
  static const Color neutralFill = Color(0xFFF3F1F0);
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
          // Size.fromHeight(56) = 가로 infinity → Row/AppBar 안 버튼에서
          // BoxConstraints 예외가 난다. 최소 너비만 유한하게 둔다.
          minimumSize: const Size(64, 56),
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
          minimumSize: const Size(64, 56),
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
