import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mantiene el tema seleccionado y lo conserva entre ejecuciones.
class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();
  static const String _preferenceKey = 'taskflow_theme_mode';
  static const String _accentPreferenceKey = 'taskflow_accent_color';
  static const List<Color> accentColors = [
    Color(0xFF7651D5),
    Color(0xFF006B5F),
    Color(0xFF005AA8),
    Color(0xFFB3261E),
    Color(0xFF8A4F00),
    Color(0xFF9A4778),
  ];

  ThemeMode _themeMode = ThemeMode.dark;
  Color _accentColor = accentColors.first;
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;

  /// Restaura las preferencias locales antes de construir la aplicación.
  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final isLight = preferences.getBool(_preferenceKey) ?? false;
    _themeMode = isLight ? ThemeMode.light : ThemeMode.dark;
    _accentColor = accentColors.first;
    final savedAccent = preferences.getInt(_accentPreferenceKey);
    if (savedAccent != null &&
        accentColors.any((color) => color.toARGB32() == savedAccent)) {
      _accentColor = Color(savedAccent);
    }
  }

  /// Persiste el modo visual y notifica a la interfaz cuando cambia.
  Future<void> setThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(
      _preferenceKey,
      mode == ThemeMode.light,
    );
    if (!saved) {
      throw StateError('No se pudo guardar la preferencia del tema.');
    }

    _themeMode = mode;
    notifyListeners();
  }

  /// Acepta únicamente colores disponibles y persiste el acento seleccionado.
  Future<void> setAccentColor(Color color) async {
    if (!accentColors.contains(color)) {
      throw ArgumentError.value(color, 'color', 'Color de acento no admitido.');
    }

    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setInt(
      _accentPreferenceKey,
      color.toARGB32(),
    );
    if (!saved) {
      throw StateError('No se pudo guardar el color seleccionado.');
    }

    _accentColor = color;
    notifyListeners();
  }
}
