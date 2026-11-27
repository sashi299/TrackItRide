import 'package:flutter/material.dart';

class AppTheme {
  // Brand & Core Colors from Figma System 1.0
  static const Color primaryColor = Color(0xFF800000); // Maroon / 700
  static const Color primarySubtle = Color(0xFFFFF1F2); // Maroon / 50
  static const Color liveMarker = Color(0xFFF59E0B); // Amber - Live Bus Marker
  
  // Status Colors
  static const Color success = Color(0xFF166534); // Green 800
  static const Color successBg = Color(0xFFDCFCE7); // Green 100
  static const Color warning = Color(0xFF9A3412); // Orange 800
  static const Color warningBg = Color(0xFFFFEDD5); // Orange 100
  static const Color error = Color(0xFFB91C1C); // Red 700
  static const Color errorBg = Color(0xFFFEE2E2); // Red 100
  static const Color info = Color(0xFF1D4ED8); // Blue 700
  static const Color infoBg = Color(0xFFDBEAFE); // Blue 100

  // Neutral Palette
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color border = Color(0xFF64748B); // Slate 500
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color text = Color(0xFF0F172A); // Slate 900
  static const Color muted = Color(0xFF475569); // Slate 600

  // Maroon Tint Scale
  static const Color maroon50 = Color(0xFFFFF1F2);
  static const Color maroon100 = Color(0xFFFFE1E3);
  static const Color maroon200 = Color(0xFFFFC5CA);
  static const Color maroon300 = Color(0xFFF59AA4);
  static const Color maroon500 = Color(0xFFB73C4B);
  static const Color maroon700 = Color(0xFF800000);
  static const Color maroon800 = Color(0xFF650000);
  static const Color maroon900 = Color(0xFF450000);

  // Dark Palette
  static const Color darkCanvas = Color(0xFF10151E);
  static const Color darkSurface = Color(0xFF1B2432);

  // Layout Constants
  static const double radiusControl = 12.0;
  static const double targetMin = 48.0;

  static final ThemeData themeData = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      surface: surface,
      background: background,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: text,
        fontFamily: 'Inter',
      ),
      iconTheme: IconThemeData(color: text),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, targetMin),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 1.2),
        minimumSize: const Size(double.infinity, targetMin),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: const BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      labelStyle: const TextStyle(color: text, fontSize: 14),
      hintStyle: const TextStyle(color: muted, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        side: const BorderSide(color: surfaceSubtle, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: text),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: text),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: text),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: text),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: text),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: muted),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
    ),
  );
}
