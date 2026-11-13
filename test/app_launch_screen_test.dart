import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/theme/app_theme.dart';

void main() {
  /// La intro animada aparece antes de que la aplicación complete el enrutado.
  testWidgets('shows the animated TaskFlow intro before routing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const AppLaunchScreen()),
    );

    expect(find.byKey(const ValueKey('taskflow-logo')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const ValueKey('taskflow-logo')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
