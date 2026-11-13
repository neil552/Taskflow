import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task_model.dart';
import 'package:taskflow/theme/app_theme.dart';
import 'package:taskflow/widgets/task_card.dart';

void main() {
  testWidgets('renders the task title and details inside the card', (
    tester,
  ) async {
    final dueDate = DateTime.now().add(const Duration(days: 3));
    final task = TaskModel(
      id: 'task-1',
      title: 'Revisar el proyecto',
      description: 'Comprobar el guardado',
      category: 'Trabajo',
      priority: 'Alta',
      dueDate: dueDate,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ListView(
            children: [
              TaskCard(
                task: task,
                priorityColor: const Color(0xFFB3261E),
                onToggle: (_) {},
                onToggleSubtask: (_, _) {},
                onEdit: () {},
                onDelete: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Revisar el proyecto'), findsOneWidget);
    expect(find.text('Comprobar el guardado'), findsOneWidget);
    expect(find.text('Trabajo'), findsOneWidget);
    expect(find.text('Alta'), findsOneWidget);
    final formattedDueDate =
        '${dueDate.day}/${dueDate.month}/${dueDate.year} '
        '${dueDate.hour.toString().padLeft(2, '0')}:'
        '${dueDate.minute.toString().padLeft(2, '0')}';
    expect(find.text('Vence: $formattedDueDate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders checklist progress and reports subtask changes', (
    tester,
  ) async {
    final task = TaskModel(
      id: 'task-2',
      title: 'Preparar informe',
      description: '',
      dueDate: DateTime(2026, 11, 12, 9),
      recurrence: 'weekly',
      subtasks: const [
        TaskSubtask(title: 'Revisar datos'),
        TaskSubtask(title: 'Escribir conclusiones', isCompleted: true),
      ],
    );
    int? changedIndex;
    bool? changedValue;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ListView(
            children: [
              TaskCard(
                task: task,
                priorityColor: const Color(0xFFB3261E),
                onToggle: (_) {},
                onToggleSubtask: (index, completed) {
                  changedIndex = index;
                  changedValue = completed;
                },
                onEdit: () {},
                onDelete: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subtareas: 1/2'), findsOneWidget);
    expect(find.text('Repite: Semanal'), findsOneWidget);
    expect(find.text('Revisar datos'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();

    expect(changedIndex, 0);
    expect(changedValue, isTrue);
    expect(tester.takeException(), isNull);
  });
}
