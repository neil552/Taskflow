import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/widgets/taskflow_navigation_bar.dart';

void main() {
  /// La barra muestra destinos y delega la selección al callback recibido.
  testWidgets('renders section labels and reports navigation taps', (
    tester,
  ) async {
    var selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: TaskFlowNavigationBar(
            currentIndex: selectedIndex,
            onDestinationSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Calendario'));
    await tester.pump();

    expect(selectedIndex, 1);
    expect(find.text('Tareas'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });
}
