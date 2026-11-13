import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/theme/app_theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Comprueba valores iniciales y persistencia de tema y color de acento.
  test('loads dark mode by default and persists the selected theme', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppThemeController.instance;

    await controller.load();
    expect(controller.themeMode, ThemeMode.dark);

    await controller.setThemeMode(ThemeMode.light);
    expect(controller.themeMode, ThemeMode.light);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('taskflow_theme_mode'), isTrue);

    await controller.setAccentColor(AppThemeController.accentColors[2]);
    expect(controller.accentColor, AppThemeController.accentColors[2]);
    expect(
      preferences.getInt('taskflow_accent_color'),
      AppThemeController.accentColors[2].toARGB32(),
    );

    await controller.setThemeMode(ThemeMode.dark);
    await controller.setAccentColor(AppThemeController.accentColors.first);
  });
}
