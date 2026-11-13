import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/widgets/task_sync_indicator.dart';

void main() {
  testWidgets('shows when offline changes are waiting to sync', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TaskSyncIndicator(isFromCache: true, hasPendingWrites: true),
        ),
      ),
    );

    expect(find.text('Sin conexión · cambios pendientes'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
  });

  testWidgets('shows when server has acknowledged all changes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TaskSyncIndicator(isFromCache: false, hasPendingWrites: false),
        ),
      ),
    );

    expect(find.text('Sincronizado'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });
}
