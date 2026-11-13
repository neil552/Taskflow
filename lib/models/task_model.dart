import 'package:cloud_firestore/cloud_firestore.dart';

/// Elemento individual de la lista de verificación de una tarea.
class TaskSubtask {
  const TaskSubtask({required this.title, this.isCompleted = false});

  final String title;
  final bool isCompleted;

  Map<String, dynamic> toMap() => {'title': title, 'isCompleted': isCompleted};

  factory TaskSubtask.fromMap(Map<String, dynamic> map) {
    return TaskSubtask(
      title: map['title'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }

  TaskSubtask copyWith({String? title, bool? isCompleted}) {
    return TaskSubtask(
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Modelo inmutable que convierte tareas entre Dart y Firestore.
class TaskModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final DateTime? dueDate;
  final bool isCompleted;
  final String recurrence;
  final int? recurrenceDay;
  final List<TaskSubtask> subtasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Crea una tarea; las fechas de auditoría usan la hora actual por defecto.
  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    this.category = 'Personal',
    this.priority = 'Media',
    this.dueDate,
    this.isCompleted = false,
    this.recurrence = 'none',
    int? recurrenceDay,
    this.subtasks = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : recurrenceDay = recurrenceDay ?? dueDate?.day,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Convierte la tarea al formato compatible con los documentos de Firestore.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
      'isCompleted': isCompleted,
      'recurrence': recurrence,
      'recurrenceDay': recurrenceDay,
      'subtasks': subtasks.map((subtask) => subtask.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Reconstruye una tarea, aplicando valores predeterminados a datos antiguos.
  factory TaskModel.fromMap(String id, Map<String, dynamic> map) {
    return TaskModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'Personal',
      priority: map['priority'] as String? ?? 'Media',
      dueDate: map['dueDate'] is Timestamp
          ? (map['dueDate'] as Timestamp).toDate()
          : null,
      isCompleted: map['isCompleted'] as bool? ?? false,
      recurrence:
          const [
            'none',
            'daily',
            'weekly',
            'monthly',
          ].contains(map['recurrence'])
          ? map['recurrence'] as String
          : 'none',
      recurrenceDay:
          map['recurrenceDay'] is int &&
              (map['recurrenceDay'] as int) >= 1 &&
              (map['recurrenceDay'] as int) <= 31
          ? map['recurrenceDay'] as int
          : map['dueDate'] is Timestamp
          ? (map['dueDate'] as Timestamp).toDate().day
          : null,
      subtasks: map['subtasks'] is List
          ? (map['subtasks'] as List)
                .whereType<Map>()
                .map(
                  (item) =>
                      TaskSubtask.fromMap(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Calcula la fecha siguiente del ciclo y conserva la hora programada.
  DateTime? get nextDueDate {
    final date = dueDate;
    if (date == null) return null;

    return switch (recurrence) {
      'daily' => DateTime(
        date.year,
        date.month,
        date.day + 1,
        date.hour,
        date.minute,
        date.second,
        date.millisecond,
        date.microsecond,
      ),
      'weekly' => DateTime(
        date.year,
        date.month,
        date.day + 7,
        date.hour,
        date.minute,
        date.second,
        date.millisecond,
        date.microsecond,
      ),
      'monthly' => _nextMonth(date, recurrenceDay ?? date.day),
      _ => null,
    };
  }

  /// Omite los ciclos pasados si la tarea se completó después de su vencimiento.
  DateTime? nextOccurrenceAfter(DateTime reference) {
    var next = nextDueDate;
    while (next != null && !next.isAfter(reference)) {
      next = copyWith(dueDate: next).nextDueDate;
    }
    return next;
  }

  static DateTime _nextMonth(DateTime date, int dayOfMonth) {
    final nextMonth = DateTime(date.year, date.month + 1);
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    return DateTime(
      nextMonth.year,
      nextMonth.month,
      dayOfMonth.clamp(1, lastDay),
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isCompleted,
    String? recurrence,
    int? recurrenceDay,
    List<TaskSubtask>? subtasks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      recurrence: recurrence ?? this.recurrence,
      recurrenceDay: recurrenceDay ?? this.recurrenceDay,
      subtasks: subtasks ?? this.subtasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
