import 'package:flutter/material.dart';

/// Define paletas y componentes comunes para los temas claro y oscuro.
class AppTheme {
  static const Color primary = Color(0xFF7651D5);
  static const Color darkBackground = Color(0xFF100B1D);
  static const Color darkSurface = Color(0xFF1D152D);

  static ThemeData get darkTheme => darkThemeFor(primary);

  /// Construye la paleta oscura y aclara el acento para conservar contraste.
  static ThemeData darkThemeFor(Color accent) {
    final accessibleAccent = Color.lerp(accent, Colors.white, 0.34)!;
    return _buildTheme(
      brightness: Brightness.dark,
      background: darkBackground,
      surface: darkSurface,
      primary: accessibleAccent,
      secondary: accessibleAccent,
      onSurface: Colors.white,
    );
  }

  static ThemeData get lightTheme => lightThemeFor(primary);

  /// Construye la paleta clara a partir del color de acento elegido.
  static ThemeData lightThemeFor(Color accent) => _buildTheme(
    brightness: Brightness.light,
    background: const Color(0xFFF7F5FC),
    surface: Colors.white,
    primary: accent,
    secondary: accent,
    onSurface: const Color(0xFF211A2D),
  );

  /// Comparte estilos de controles y superficies para ambas apariencias.
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color primary,
    required Color secondary,
    required Color onSurface,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: isDark ? const Color(0xFF211432) : Colors.white,
      secondary: secondary,
      onSecondary: isDark ? const Color(0xFF211432) : Colors.white,
      error: isDark ? const Color(0xFFFF6B75) : const Color(0xFFB3261E),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: isDark
          ? const Color(0xFF30263F)
          : const Color(0xFFEDE8F6),
      outline: onSurface.withValues(alpha: 0.25),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: onSurface.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: isDark ? const Color(0xFF160F20) : Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: isDark ? 0.28 : 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        side: BorderSide(color: onSurface.withValues(alpha: 0.14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? darkSurface : const Color(0xFF30263F),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
