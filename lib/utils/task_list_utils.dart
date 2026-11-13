import '../models/task_model.dart';

/// Opciones de orden usadas para presentar las tareas en pantalla.
enum TaskSortOrder { newest, dueDate, priority }

/// Filtra y ordena únicamente las tareas que ya cargó la interfaz.
/// [now] puede inyectarse para obtener resultados deterministas en pruebas.
List<TaskModel> filterAndSortTasks({
  required Iterable<TaskModel> tasks,
  required String status,
  required String query,
  required TaskSortOrder sortOrder,
  DateTime? now,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final currentTime = now ?? DateTime.now();
  final result = tasks.where((task) {
    final matchesStatus = switch (status) {
      'Pendientes' => !task.isCompleted,
      'Vencidas' => isTaskOverdue(task, now: currentTime),
      'Completadas' => task.isCompleted,
      _ => true,
    };
    final matchesQuery =
        normalizedQuery.isEmpty ||
        task.title.toLowerCase().contains(normalizedQuery) ||
        task.description.toLowerCase().contains(normalizedQuery);
    return matchesStatus && matchesQuery;
  }).toList();

  result.sort((first, second) {
    switch (sortOrder) {
      case TaskSortOrder.newest:
        return second.createdAt.compareTo(first.createdAt);
      case TaskSortOrder.dueDate:
        final firstDueDate = first.dueDate;
        final secondDueDate = second.dueDate;
        if (firstDueDate == null) return secondDueDate == null ? 0 : 1;
        if (secondDueDate == null) return -1;
        return firstDueDate.compareTo(secondDueDate);
      case TaskSortOrder.priority:
        final priorityOrder = {'Alta': 0, 'Media': 1, 'Baja': 2};
        final comparison = (priorityOrder[first.priority] ?? 3).compareTo(
          priorityOrder[second.priority] ?? 3,
        );
        if (comparison != 0) return comparison;
        return second.createdAt.compareTo(first.createdAt);
    }
  });

  return result;
}

/// Indica si una tarea pendiente tiene una fecha de vencimiento anterior a [now].
bool isTaskOverdue(TaskModel task, {DateTime? now}) {
  final dueDate = task.dueDate;
  return !task.isCompleted &&
      dueDate != null &&
      dueDate.isBefore(now ?? DateTime.now());
}
