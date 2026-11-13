import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task_model.dart';
import 'package:taskflow/services/notification_service.dart';

void main() {
  // Comprueba conversión entre el modelo de Dart y el formato Firestore.
  group('TaskModel', () {
    /// La serialización conserva tanto campos normales como marcas de tiempo.
    test('serializes and restores task data', () {
      final createdAt = DateTime(2026, 11, 9, 8);
      final updatedAt = DateTime(2026, 11, 9, 9);
      final dueDate = DateTime(2026, 11, 10, 14, 30);
      final task = TaskModel(
        id: 'task-1',
        title: 'Revisar proyecto',
        description: 'Comprobar recordatorios',
        category: 'Trabajo',
        priority: 'Alta',
        dueDate: dueDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final restored = TaskModel.fromMap(task.id, task.toMap());

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.description, task.description);
      expect(restored.category, task.category);
      expect(restored.priority, task.priority);
      expect(restored.dueDate, dueDate);
      expect(restored.recurrence, task.recurrence);
      expect(restored.subtasks, isEmpty);
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, updatedAt);
    });

    /// Los documentos antiguos sin campos opcionales reciben valores seguros.
    test('uses defaults when optional Firestore values are absent', () {
      final task = TaskModel.fromMap('task-2', <String, dynamic>{});

      expect(task.title, isEmpty);
      expect(task.description, isEmpty);
      expect(task.category, 'Personal');
      expect(task.priority, 'Media');
      expect(task.dueDate, isNull);
      expect(task.isCompleted, isFalse);
      expect(task.recurrence, 'none');
      expect(task.subtasks, isEmpty);
    });

    test('serializes subtasks and advances recurring due dates', () {
      final dueDate = DateTime(2026, 1, 31, 9, 30);
      final task = TaskModel(
        id: 'monthly-task',
        title: 'Revisar presupuesto',
        description: '',
        dueDate: dueDate,
        recurrence: 'monthly',
        subtasks: const [
          TaskSubtask(title: 'Revisar ingresos', isCompleted: true),
        ],
      );

      final restored = TaskModel.fromMap(task.id, task.toMap());

      expect(restored.recurrence, 'monthly');
      expect(restored.subtasks, hasLength(1));
      expect(restored.subtasks.single.title, 'Revisar ingresos');
      expect(restored.subtasks.single.isCompleted, isTrue);
      expect(task.nextDueDate, DateTime(2026, 2, 28, 9, 30));
      expect(
        task.copyWith(dueDate: task.nextDueDate).nextDueDate,
        DateTime(2026, 3, 31, 9, 30),
      );
    });

    test('advances daily and weekly tasks while preserving their time', () {
      final dueDate = DateTime(2026, 11, 9, 14, 15);

      expect(
        TaskModel(
          id: 'daily',
          title: 'Diaria',
          description: '',
          dueDate: dueDate,
          recurrence: 'daily',
        ).nextDueDate,
        DateTime(2026, 11, 10, 14, 15),
      );
      expect(
        TaskModel(
          id: 'weekly',
          title: 'Semanal',
          description: '',
          dueDate: dueDate,
          recurrence: 'weekly',
        ).nextDueDate,
        DateTime(2026, 11, 16, 14, 15),
      );
    });

    test('skips elapsed recurrence dates after late completion', () {
      final task = TaskModel(
        id: 'daily',
        title: 'Diaria',
        description: '',
        dueDate: DateTime(2026, 11, 1, 9),
        recurrence: 'daily',
      );

      expect(
        task.nextOccurrenceAfter(DateTime(2026, 11, 9, 10)),
        DateTime(2026, 11, 10, 9),
      );
    });
  });

  /// La misma tarea debe producir el mismo identificador local de aviso.
  test('notification IDs are stable and positive', () {
    final first = NotificationService.notificationIdForTask('task-123');
    final second = NotificationService.notificationIdForTask('task-123');

    expect(first, second);
    expect(first, greaterThan(0));
    expect(first, lessThanOrEqualTo(0x7fffffff));
  });
}
