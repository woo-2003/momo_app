import 'package:flutter/material.dart';

/// 컬러 팔레트 — Peach & Spring 모티브
///
/// 따스함(복숭아) + 생기(봄 새싹) 톤. 토스 스타일의 절제된 구조는 그대로 유지하되,
/// 색 가족만 웜 톤으로 전환한다.
///
/// 새로운 컬러가 필요한 경우 반드시 이곳에 토큰을 먼저 추가한 뒤 사용하셈
class MomoColors {
  const MomoColors._();

  // ── 기본 팔레트 (Peach & Spring) ─────────────────────────────────────────
  /// 피치 코랄 - 메인 포인트
  static const Color primary = Color(0xFFFF8E7A);

  /// 웜 화이트 - 전체 배경
  static const Color background = Color(0xFFFFF9F8);

  /// 연한 피치 - 입력창/카드 표면
  static const Color surface = Color(0xFFFFF1EF);

  /// 본문 텍스트 (가독성 유지)
  static const Color textMain = Color(0xFF191F28);

  /// 보조 텍스트 (가독성 유지)
  static const Color textSub = Color(0xFF4E5968);

  // ── 확장 팔레트 (웜 톤으로 톤 맞춤) ───────────────────────────────────────
  /// 입력창/카드의 외곽선 - 웜 그레이 (peach 계열에 자연스럽게 녹는 톤)
  static const Color border = Color(0xFFF2E3DE);

  /// 비활성 상태(버튼/입력) 배경 - 웜 톤
  static const Color disabled = Color(0xFFE8D9D5);

  /// 비활성 상태의 텍스트 (가독성 유지)
  static const Color textDisabled = Color(0xFF8B95A1);

  /// 에러/경고 - 피치 primary 와 의도적으로 구분되는 정통 레드
  static const Color error = Color(0xFFE5383B);

  /// 성공/긍정 피드백 - 봄 새싹 연두
  static const Color success = Color(0xFF88C057);

  /// primary 위에 올라가는 텍스트
  static const Color onPrimary = Color(0xFFFFFFFF);
}

/// 8px 배수 spacing 시스템
///
/// 모든 padding/margin/gap은 이 토큰만 사용할듯
/// 16, 24가 가장 자주 쓰이는 기준 간격
class MomoSpacing {
  const MomoSpacing._();

  /// 4px - 아이콘 내부 미세 간격 등 예외적 사용
  static const double xxs = 4.0;

  /// 8px (1x)
  static const double xs = 8.0;

  /// 16px (2x) - 컴포넌트 내부 기본
  static const double sm = 16.0;

  /// 24px (3x) - 섹션 간 기본
  static const double md = 24.0;

  /// 32px (4x)
  static const double lg = 32.0;

  /// 40px (5x)
  static const double xl = 40.0;

  /// 48px (6x) - 페이지 상하단 여백
  static const double xxl = 48.0;
}

/// Shape - BorderRadius 16px 고정
///
/// 기획 확정 사항: 모든 버튼/입력창의 BorderRadius는 16px.
class MomoRadius {
  const MomoRadius._();

  /// 컴포넌트 표준 반경 (16px)
  static const double component = 16.0;

  /// 컴포넌트 표준 BorderRadius
  static const BorderRadius all = BorderRadius.all(Radius.circular(component));

  /// 컴포넌트 표준 RoundedRectangleBorder
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
///
/// MaterialApp(theme: MomoTheme.light) 형태로 사용
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

      // AppBar -
      appBarTheme: const AppBarTheme(
        backgroundColor: MomoColors.background,
        foregroundColor: MomoColors.textMain,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: MomoTextStyles.heading,
      ),

      // ElevatedButton - Primary 액션
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

      // TextButton - 보조 액션 (찾기/회원가입 링크 등)
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

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MomoColors.textMain,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: MomoColors.border),
          shape: MomoRadius.shape,
          textStyle: MomoTextStyles.button.copyWith(color: MomoColors.textMain),
        ),
      ),

      // 입력창
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

      // 카드/시트
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
