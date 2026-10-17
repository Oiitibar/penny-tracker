import 'package:flutter/material.dart';

abstract final class C {
  static const primary = Color(0xFF4ECDC4),
      navy = Color(0xFF1F3C88),
      orange = Color(0xFFFFA568);
  static const background = Color(0xFFF4FAF8),
      text = Color(0xFF14211F),
      secondary = Color(0xFF66736F);
  static const border = Color(0xFFDCE9E6),
      mint = Color(0xFFE8F7F4),
      success = Color(0xFF0B8F78),
      error = Color(0xFFD84C4C);
  static const blue = Color(0xFFEEF2FF),
      peach = Color(0xFFFFF1E4),
      green = Color(0xFFD6F5EF);
}

TextStyle heading(
  double size, {
  Color color = C.text,
  FontWeight weight = FontWeight.w700,
}) => TextStyle(
  fontFamily: 'Plus Jakarta Sans',
  fontFamilyFallback: const ['Noto Color Emoji', 'Apple Color Emoji'],
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: -.5,
);
ThemeData appTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito Sans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.primary,
      primary: C.success,
      onPrimary: C.text,
      surface: Colors.white,
      error: C.error,
    ),
    scaffoldBackgroundColor: C.background,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.text, displayColor: C.text),
    dividerColor: C.border,
    appBarTheme: AppBarTheme(
      backgroundColor: C.background,
      foregroundColor: C.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: heading(20),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.primary,
        foregroundColor: C.text,
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(
          fontFamily: 'Nunito Sans',
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.text,
        minimumSize: const Size(48, 50),
        side: const BorderSide(color: C.border),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.success,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: 'Nunito Sans',
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: C.secondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.success, width: 1.5),
      ),
      errorMaxLines: 3,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.background,
      modalBackgroundColor: C.background,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.text,
      contentTextStyle: const TextStyle(
        fontFamily: 'Nunito Sans',
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

Color categoryColor(String hex) =>
    Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
IconData categoryIcon(String key) => switch (key) {
  'food' => Icons.restaurant_outlined,
  'transport' => Icons.directions_bus_outlined,
  'study' => Icons.menu_book_outlined,
  'shop' => Icons.shopping_bag_outlined,
  'health' => Icons.favorite_border_rounded,
  'bills' => Icons.receipt_long_outlined,
  'fun' => Icons.sports_esports_outlined,
  _ => Icons.sell_outlined,
};
