import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task_model.dart';

/// Agrupa una página de resultados y el cursor para continuar la consulta.
class TaskPage {
  const TaskPage({
    required this.tasks,
    required this.lastDocument,
    this.isFromCache = false,
    this.hasPendingWrites = false,
  });

  final List<TaskModel> tasks;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool isFromCache;
  final bool hasPendingWrites;

  /// Indica si Firestore devolvió un cursor para solicitar otra página.
  bool get hasMore => lastDocument != null;
}

/// Administra la colección de tareas del usuario autenticado.
class TaskService {
  /// Permite inyectar Firebase durante pruebas; en producción usa sus instancias.
  TaskService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Obtiene el UID actual y evita acceder a datos sin autenticar.
  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Debes iniciar sesión para gestionar tareas.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('users').doc(_userId).collection('tasks');

  /// Guarda la tarea y devuelve su ID de Firestore para el recordatorio.
  Future<String> addTask(TaskModel task) async {
    final now = FieldValue.serverTimestamp();
    final document = await _tasks.add({
      ...task.toMap(),
      'createdAt': now,
      'updatedAt': now,
    });
    return document.id;
  }

  /// Observa las tareas en orden de creación descendente.
  Stream<List<TaskModel>> getTasks() {
    return _tasks
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// Observa la primera página para la pantalla principal.
  Stream<TaskPage> watchFirstPage({int pageSize = 30}) {
    return _tasks
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => _toPage(snapshot, pageSize));
  }

  /// Carga una página después de [lastDocument] sin descargar toda la lista.
  Future<TaskPage> fetchNextPage({
    required QueryDocumentSnapshot<Map<String, dynamic>> lastDocument,
    int pageSize = 30,
  }) async {
    final snapshot = await _tasks
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDocument)
        .limit(pageSize)
        .get();
    return _toPage(snapshot, pageSize);
  }

  /// Convierte los documentos de una consulta en modelos y cursor de paginación.
  TaskPage _toPage(QuerySnapshot<Map<String, dynamic>> snapshot, int pageSize) {
    final documents = snapshot.docs;
    return TaskPage(
      tasks: documents
          .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
          .toList(growable: false),
      lastDocument: documents.length == pageSize ? documents.last : null,
      isFromCache: snapshot.metadata.isFromCache,
      hasPendingWrites: snapshot.metadata.hasPendingWrites,
    );
  }

  /// Busca en títulos y descripciones de las tareas observadas en tiempo real.
  Stream<List<TaskModel>> searchTasks(String query) {
    final texto = query.toLowerCase().trim();
    return getTasks().map((tasks) {
      if (texto.isEmpty) return tasks;
      return tasks
          .where(
            (task) =>
                task.title.toLowerCase().contains(texto) ||
                task.description.toLowerCase().contains(texto),
          )
          .toList(growable: false);
    });
  }

  /// Actualiza los campos editables sin reemplazar el estado de finalización.
  Future<void> updateTask(TaskModel task) async {
    await _tasks.doc(task.id).update({
      'title': task.title,
      'description': task.description,
      'category': task.category,
      'priority': task.priority,
      'dueDate': task.dueDate == null
          ? null
          : Timestamp.fromDate(task.dueDate!),
      'recurrence': task.recurrence,
      'recurrenceDay': task.recurrenceDay,
      'subtasks': task.subtasks.map((subtask) => subtask.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Avanza una tarea recurrente con una escritura que se puede encolar offline.
  Future<void> advanceRecurringTask(
    TaskModel task,
    DateTime nextDueDate,
  ) async {
    await _tasks.doc(task.id).update({
      'dueDate': Timestamp.fromDate(nextDueDate),
      'isCompleted': false,
      'subtasks': task.subtasks
          .map((subtask) => subtask.copyWith(isCompleted: false).toMap())
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cambia solo el estado de finalización y la fecha de modificación.
  Future<void> toggleTask(String taskId, bool completed) async {
    await _tasks.doc(taskId).update({
      'isCompleted': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Actualiza solo la lista de subtareas y permite encolar el cambio sin red.
  Future<void> updateSubtasks(String taskId, List<TaskSubtask> subtasks) async {
    await _tasks.doc(taskId).update({
      'subtasks': subtasks.map((subtask) => subtask.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina una tarea individual de la colección del usuario actual.
  Future<void> deleteTask(String taskId) async {
    await _tasks.doc(taskId).delete();
  }

  /// Elimina en lotes menores al límite de 500 escrituras de Firestore.
  Future<void> deleteAllTasks() async {
    while (true) {
      final snapshot = await _tasks.limit(450).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _db.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
}
