import 'package:flutter/material.dart';

/// Dark, art-forward palette. The accent is a warm record-label amber.
abstract final class Palette {
  static const background = Color(0xFF0E0E0E);
  static const surface = Color(0xFF181818);
  static const elevated = Color(0xFF242424);
  static const hover = Color(0xFF2A2A2A);
  static const outline = Color(0xFF3A3A3A);
  static const text = Color(0xFFFFFFFF);
  static const subtext = Color(0xFFB3B3B3);
  static const muted = Color(0xFF7A7A7A);
  static const accent = Color(0xFFF2A03D);
  static const accentDeep = Color(0xFF8A4B16);
  static const onAccent = Color(0xFF1A1206);
  static const error = Color(0xFFF15E6C);

  /// Only used on the "Continue with Spotify" button.
  static const spotifyGreen = Color(0xFF1ED760);

  /// Vinyl colours.
  static const vinyl = Color(0xFF111111);
  static const groove = Color(0xFF1C1C1C);
  static const sticker = Color(0xFFFFD34E);
}

const fontFamily = 'Figtree';

ThemeData buildVinylssTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.accent,
    onPrimary: Palette.onAccent,
    primaryContainer: Palette.accentDeep,
    onPrimaryContainer: Palette.text,
    secondary: Palette.accent,
    onSecondary: Palette.onAccent,
    secondaryContainer: Palette.elevated,
    onSecondaryContainer: Palette.text,
    surface: Palette.background,
    onSurface: Palette.text,
    onSurfaceVariant: Palette.subtext,
    surfaceContainerLowest: Palette.background,
    surfaceContainerLow: Palette.surface,
    surfaceContainer: Palette.surface,
    surfaceContainerHigh: Palette.elevated,
    surfaceContainerHighest: Palette.hover,
    outline: Palette.outline,
    outlineVariant: Palette.elevated,
    error: Palette.error,
  );

  final base = ThemeData(brightness: Brightness.dark, colorScheme: scheme, fontFamily: fontFamily);
  final text = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall
        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.2, color: Palette.text),
    headlineMedium: base.textTheme.headlineMedium
        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Palette.text),
    headlineSmall: base.textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Palette.text),
    titleLarge: base.textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3, color: Palette.text),
    titleMedium: base.textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700, color: Palette.text),
    titleSmall: base.textTheme.titleSmall
        ?.copyWith(fontWeight: FontWeight.w700, color: Palette.text),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(color: Palette.text),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(color: Palette.subtext),
    bodySmall: base.textTheme.bodySmall?.copyWith(color: Palette.subtext),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    labelSmall: base.textTheme.labelSmall
        ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
  );

  const pill = StadiumBorder();
  return base.copyWith(
    scaffoldBackgroundColor: Palette.background,
    canvasColor: Palette.background,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    hoverColor: Colors.white.withValues(alpha: 0.06),
    highlightColor: Colors.white.withValues(alpha: 0.04),
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.accent,
        foregroundColor: Palette.onAccent,
        disabledBackgroundColor: Palette.elevated,
        disabledForegroundColor: Palette.muted,
        shape: pill,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.text,
        side: const BorderSide(color: Palette.muted),
        shape: pill,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.text,
        shape: pill,
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: Palette.subtext),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.onAccent : Palette.subtext,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.accent : Palette.elevated,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.accent : Palette.outline,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.accent : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Palette.onAccent),
      side: const BorderSide(color: Palette.muted, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Palette.accent,
      inactiveTrackColor: Palette.elevated,
      thumbColor: Palette.text,
      trackHeight: 4,
      overlayColor: Color(0x22F2A03D),
      valueIndicatorColor: Palette.elevated,
      valueIndicatorTextStyle: TextStyle(fontFamily: fontFamily, color: Palette.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Palette.surface,
        foregroundColor: Palette.subtext,
        selectedBackgroundColor: Palette.accent,
        selectedForegroundColor: Palette.onAccent,
        side: const BorderSide(color: Palette.outline),
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.elevated,
      selectedColor: Palette.accent,
      side: BorderSide.none,
      shape: pill,
      showCheckmark: false,
      labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily, fontWeight: FontWeight.w600, color: Palette.onAccent),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.elevated,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Palette.text, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Palette.subtext),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Palette.elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(fontFamily: fontFamily, color: Palette.text),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Palette.muted,
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.text,
      contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Palette.background),
      actionTextColor: Palette.accentDeep,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? Palette.text : Palette.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? Palette.text : Palette.muted,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Palette.background,
      indicatorColor: Palette.elevated,
      selectedIconTheme: const IconThemeData(color: Palette.text),
      unselectedIconTheme: const IconThemeData(color: Palette.muted),
      selectedLabelTextStyle: const TextStyle(
          fontFamily: fontFamily, color: Palette.text, fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelTextStyle: const TextStyle(
          fontFamily: fontFamily, color: Palette.muted, fontWeight: FontWeight.w600, fontSize: 12),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: Palette.elevated, borderRadius: BorderRadius.circular(4)),
      textStyle: const TextStyle(fontFamily: fontFamily, color: Palette.text, fontSize: 12),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.accent,
      linearTrackColor: Palette.elevated,
    ),
    dividerTheme: const DividerThemeData(color: Palette.elevated, space: 1),
    listTileTheme: const ListTileThemeData(
      iconColor: Palette.subtext,
      titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, color: Palette.text),
      subtitleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 13, color: Palette.subtext),
    ),
  );
}
