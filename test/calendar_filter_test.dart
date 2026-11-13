import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task_model.dart';
import 'package:taskflow/screens/calendar_screen.dart';

void main() {
  // Usa un instante fijo para reproducir de forma estable el estado vencido.
  final now = DateTime(2026, 11, 9, 12);
  final tasks = [
    TaskModel(
      id: 'later',
      title: 'Trabajo después',
      description: '',
      category: 'Trabajo',
      priority: 'Alta',
      dueDate: DateTime(2026, 11, 12),
    ),
    TaskModel(
      id: 'overdue',
      title: 'Estudiar',
      description: '',
      category: 'Estudio',
      priority: 'Media',
      dueDate: DateTime(2026, 11, 8),
    ),
    TaskModel(
      id: 'done',
      title: 'Personal completada',
      description: '',
      category: 'Personal',
      priority: 'Baja',
      dueDate: DateTime(2026, 11, 10),
      isCompleted: true,
    ),
    TaskModel(
      id: 'no-date',
      title: 'Sin fecha',
      description: '',
      dueDate: null,
    ),
  ];

  /// Los filtros de estado, categoría y prioridad se aplican conjuntamente.
  test('filters calendar tasks by status, category and priority', () {
    final visible = filterCalendarTasks(
      tasks: tasks,
      status: 'Vencidas',
      category: 'Estudio',
      priority: 'Media',
      now: now,
    );

    expect(visible.map((task) => task.id), ['overdue']);
  });

  /// La agenda excluye tareas sin fecha y ordena las restantes por vencimiento.
  test('returns only scheduled tasks in due-date order', () {
    final visible = filterCalendarTasks(
      tasks: tasks,
      status: 'Todas',
      category: 'Todas',
      priority: 'Todas',
      now: now,
    );

    expect(visible.map((task) => task.id), ['overdue', 'done', 'later']);
  });
}
