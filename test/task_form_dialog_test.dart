import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task_model.dart';
import 'package:taskflow/screens/task_form_dialog.dart';

void main() {
  /// Comprueba que una escritura correcta cierre y desmonte el formulario.
  testWidgets('saves and disposes the form dialog without framework errors', (
    tester,
  ) async {
    TaskModel? savedTask;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TaskFormDialog(
                  onSave: (task) async {
                    savedTask = task;
                    return true;
                  },
                ),
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Preparar entrega');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(savedTask?.title, 'Preparar entrega');
    expect(find.byType(TaskFormDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  /// Un resultado fallido mantiene el diálogo abierto y muestra el error.
  testWidgets('keeps the form open when saving fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TaskFormDialog(onSave: (_) async => false),
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Preparar entrega');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskFormDialog), findsOneWidget);
    expect(
      find.text('No se pudo guardar la tarea. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves subtasks added in the task form', (tester) async {
    TaskModel? savedTask;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TaskFormDialog(
                  onSave: (task) async {
                    savedTask = task;
                    return true;
                  },
                ),
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Preparar entrega');
    final subtaskField = find.byType(TextField).last;
    await tester.ensureVisible(subtaskField);
    await tester.enterText(subtaskField, 'Revisar documento');
    await tester.tap(find.byTooltip('Agregar subtarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(savedTask?.subtasks, hasLength(1));
    expect(savedTask?.subtasks.single.title, 'Revisar documento');
    expect(tester.takeException(), isNull);
  });
}
