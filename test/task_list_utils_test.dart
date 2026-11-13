import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task_model.dart';
import 'package:taskflow/utils/task_list_utils.dart';

void main() {
  // Datos fijos para que el resultado no dependa de la fecha del equipo.
  final now = DateTime(2026, 11, 9, 12);
  final tasks = [
    TaskModel(
      id: 'later',
      title: 'Comprar pan',
      description: 'Pan de centeno',
      priority: 'Baja',
      dueDate: DateTime(2026, 11, 12),
      createdAt: DateTime(2026, 11, 8),
    ),
    TaskModel(
      id: 'overdue',
      title: 'Entregar informe',
      description: 'Informe mensual',
      priority: 'Alta',
      dueDate: DateTime(2026, 11, 8),
      createdAt: DateTime(2026, 11, 7),
    ),
    TaskModel(
      id: 'completed',
      title: 'Revisar correo',
      description: '',
      priority: 'Media',
      isCompleted: true,
      createdAt: DateTime(2026, 11, 9),
    ),
  ];

  /// El filtro de estado se combina con la búsqueda textual.
  test('filters tasks by status and searches title and description', () {
    final pending = filterAndSortTasks(
      tasks: tasks,
      status: 'Pendientes',
      query: 'informe',
      sortOrder: TaskSortOrder.newest,
      now: now,
    );

    expect(pending.map((task) => task.id), ['overdue']);

    final overdue = filterAndSortTasks(
      tasks: tasks,
      status: 'Vencidas',
      query: '',
      sortOrder: TaskSortOrder.newest,
      now: now,
    );
    expect(overdue.map((task) => task.id), ['overdue']);
  });

  /// Las opciones de orden aplican sus criterios y desempates esperados.
  test('sorts by due date and then priority', () {
    final byDate = filterAndSortTasks(
      tasks: tasks,
      status: 'Todas',
      query: '',
      sortOrder: TaskSortOrder.dueDate,
      now: now,
    );
    final byPriority = filterAndSortTasks(
      tasks: tasks,
      status: 'Todas',
      query: '',
      sortOrder: TaskSortOrder.priority,
      now: now,
    );

    expect(byDate.map((task) => task.id), ['overdue', 'later', 'completed']);
    expect(byPriority.map((task) => task.id), [
      'overdue',
      'completed',
      'later',
    ]);
  });

  /// Una tarea completada no se considera vencida aunque su fecha haya pasado.
  test('flags only incomplete tasks with past due dates as overdue', () {
    expect(isTaskOverdue(tasks[1], now: now), isTrue);
    expect(isTaskOverdue(tasks[0], now: now), isFalse);
    expect(isTaskOverdue(tasks[2], now: now), isFalse);
  });
}
