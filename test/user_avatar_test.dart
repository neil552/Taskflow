import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/widgets/user_avatar.dart';

void main() {
  testWidgets('shows initials from the first and last name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            displayName: 'Ana María Pérez',
            email: 'ana@example.com',
            radius: 30,
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );

    expect(find.text('AP'), findsOneWidget);
  });

  testWidgets('uses the email when the display name is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            displayName: ' ',
            email: 'ana@example.com',
            radius: 30,
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
  });
}
