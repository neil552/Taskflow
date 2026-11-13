import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';
import '../utils/firebase_error_message.dart';
import '../utils/task_list_utils.dart';
import '../widgets/task_card.dart';
import '../widgets/task_sync_indicator.dart';
import '../widgets/taskflow_navigation_bar.dart';
import '../widgets/user_avatar.dart';
import 'task_form_dialog.dart';

/// Lista, filtra y administra tareas junto con sus recordatorios locales.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Mantiene filtros y páginas, y coordina las acciones sobre tareas.
class _HomeScreenState extends State<HomeScreen> {
  // Colores semánticos tomados del tema activo para ambas apariencias.
  Color get morado => Theme.of(context).colorScheme.primary;
  Color get fondo => Theme.of(context).scaffoldBackgroundColor;
  // La consulta inicial permanece activa; las siguientes se cargan bajo demanda.
  final TaskService _taskService = TaskService();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<TaskPage> _primeraPagina;
  final List<TaskPage> _paginasAnteriores = [];
  User? _usuario = FirebaseAuth.instance.currentUser;
  String _filtro = 'Todas';
  String _busqueda = '';
  TaskSortOrder _orden = TaskSortOrder.newest;
  String? _idCursorPrimeraPagina;
  bool _cursorInicializado = false;
  bool _cargandoMas = false;

  @override
  /// Abre la observación en tiempo real de la primera página de tareas.
  void initState() {
    super.initState();
    _primeraPagina = _taskService.watchFirstPage();
  }

  @override
  /// Libera el campo de búsqueda al cerrar la pantalla principal.
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Muestra un aviso breve para resultados o advertencias de una operación.
  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Convierte errores técnicos en mensajes útiles y registra el detalle.
  void _mostrarError(String operacion, Object error) {
    debugPrint('Error al $operacion: $error');
    final mensaje = error is FirebaseException
        ? FirebaseErrorMessage.fromFirebase(
            error,
            fallback: 'No se pudo $operacion. Inténtalo de nuevo.',
          )
        : 'No se pudo $operacion. Inténtalo de nuevo.';
    _mostrarMensaje(mensaje);
  }

  /// Invalida páginas antiguas cuando cambia el cursor de la página en vivo.
  void _sincronizarPaginas(TaskPage primeraPagina) {
    final nuevoCursor = primeraPagina.lastDocument?.id;
    if (!_cursorInicializado) {
      _cursorInicializado = true;
      _idCursorPrimeraPagina = nuevoCursor;
      return;
    }

    if (_idCursorPrimeraPagina == nuevoCursor) return;
    _idCursorPrimeraPagina = nuevoCursor;
    if (_paginasAnteriores.isNotEmpty) {
      // Recarga las páginas anteriores si cambia el límite de la página en vivo.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_paginasAnteriores.clear);
      });
    }
  }

  /// Solicita la siguiente página sin duplicar una carga ya activa.
  Future<void> _cargarMas(TaskPage primeraPagina) async {
    if (_cargandoMas) return;
    final cursor = _paginasAnteriores.isEmpty
        ? primeraPagina.lastDocument
        : _paginasAnteriores.last.lastDocument;
    if (cursor == null) return;

    setState(() => _cargandoMas = true);
    try {
      final pagina = await _taskService.fetchNextPage(lastDocument: cursor);
      if (!mounted) return;
      setState(() => _paginasAnteriores.add(pagina));
    } catch (error) {
      _mostrarError('cargar más tareas', error);
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  /// Abre el formulario y coordina escritura de Firestore y recordatorio.
  Future<void> _mostrarFormulario({TaskModel? tarea}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => TaskFormDialog(
        task: tarea,
        onSave: (updatedTask) async {
          String taskId;
          try {
            if (tarea == null) {
              taskId = await _taskService.addTask(updatedTask);
            } else {
              taskId = tarea.id;
              await _taskService.updateTask(updatedTask);
            }
          } catch (error) {
            _mostrarError('guardar la tarea', error);
            return false;
          }

          String? notificationWarning;
          try {
            final notificationId = NotificationService.notificationIdForTask(
              taskId,
            );
            await NotificationService.instance.cancelarNotificacion(
              id: notificationId,
            );
            final dueDate = updatedTask.dueDate;
            if (dueDate != null && !updatedTask.isCompleted) {
              final scheduled = await NotificationService.instance
                  .programarNotificacion(
                    id: notificationId,
                    titulo: 'Recordatorio: ${updatedTask.title}',
                    cuerpo: 'Tu tarea vence pronto.',
                    fechaProgramada: dueDate,
                  );
              if (!scheduled) {
                notificationWarning = 'La tarea se guardó, pero no se pudo programar el recordatorio. Revisa la fecha y los permisos.';
              }
            }
          } catch (error) {
            debugPrint('Error al sincronizar el recordatorio: $error');
            notificationWarning = 'La tarea se guardó, pero no se pudo actualizar su recordatorio.';
          }

          if (notificationWarning != null) {
            _mostrarMensaje(notificationWarning);
          }
          return true;
        },
      ),
    );
  }

  /// Actualiza el estado remoto y sincroniza la notificación de la tarea.
  Future<void> _cambiarEstado(TaskModel tarea, bool completada) async {
    try {
      final nextDueDate = completada
          ? tarea.nextOccurrenceAfter(DateTime.now())
          : null;
      if (nextDueDate != null) {
        await _taskService.advanceRecurringTask(tarea, nextDueDate);
        _mostrarMensaje(
          'Tarea recurrente: próxima fecha ${nextDueDate.day}/${nextDueDate.month}/${nextDueDate.year}.',
        );
      } else {
        await _taskService.toggleTask(tarea.id, completada);
      }

      final notificationId = NotificationService.notificationIdForTask(
        tarea.id,
      );
      final dueDate = nextDueDate ?? tarea.dueDate;
      final shouldCancel =
          (completada && nextDueDate == null) || dueDate == null;
      if (shouldCancel) {
        await NotificationService.instance.cancelarNotificacion(
          id: notificationId,
        );
      } else {
        final programada = await NotificationService.instance
            .programarNotificacion(
              id: notificationId,
              titulo: 'Recordatorio: ${tarea.title}',
              cuerpo: 'Tu tarea vence pronto.',
              fechaProgramada: dueDate,
            );
        if (!programada) {
          _mostrarMensaje(
            'La tarea se actualizó, pero el recordatorio no pudo programarse.',
          );
        }
      }
    } catch (error) {
      _mostrarError('actualizar la tarea', error);
    }
  }

  /// Guarda el estado de una subtarea dentro de la tarea padre.
  Future<void> _cambiarSubtarea(
    TaskModel tarea,
    int index,
    bool completada,
  ) async {
    if (index < 0 || index >= tarea.subtasks.length) return;
    final subtasks = List<TaskSubtask>.of(tarea.subtasks);
    subtasks[index] = subtasks[index].copyWith(isCompleted: completada);

    try {
      await _taskService.updateSubtasks(tarea.id, subtasks);
    } catch (error) {
      _mostrarError('actualizar la subtarea', error);
    }
  }

  /// Confirma y luego elimina tanto la tarea remota como su recordatorio.
  /// Solicita confirmación antes de borrar la tarea y su recordatorio.
  Future<void> _eliminarTarea(TaskModel tarea) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Quieres eliminar "${tarea.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await _taskService.deleteTask(tarea.id);
      await NotificationService.instance.cancelarNotificacion(
        id: NotificationService.notificationIdForTask(tarea.id),
      );
    } catch (error) {
      _mostrarError('eliminar la tarea', error);
    }
  }

  /// Elige colores de prioridad legibles según el tema y el estado actual.
  Color _obtenerColorPrioridad(String prioridad) {
    switch (prioridad) {
      case 'Alta':
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFFF8A80)
            : const Color(0xFFB3261E);
      case 'Baja':
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF80CBC4)
            : const Color(0xFF006B5F);
      default:
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFFFCC80)
            : const Color(0xFF8A4F00);
    }
  }

  /// Presenta prioridad, vencimiento, categoría y acciones de una tarea.
  Widget _construirTarea(TaskModel tarea) {
    return TaskCard(
      task: tarea,
      priorityColor: _obtenerColorPrioridad(tarea.priority),
      onToggle: (completed) => _cambiarEstado(tarea, completed),
      onToggleSubtask: (index, completed) =>
          _cambiarSubtarea(tarea, index, completed),
      onEdit: () => _mostrarFormulario(tarea: tarea),
      onDelete: () => _eliminarTarea(tarea),
    );
  }

  /// Combina páginas, aplica filtros y muestra resultados o estado vacío.
  Widget _construirLista(TaskPage primeraPagina) {
    final tareasPorId = <String, TaskModel>{
      for (final tarea in primeraPagina.tasks) tarea.id: tarea,
      for (final pagina in _paginasAnteriores)
        for (final tarea in pagina.tasks) tarea.id: tarea,
    };
    final tareas = filterAndSortTasks(
      tasks: tareasPorId.values,
      status: _filtro,
      query: _busqueda,
      sortOrder: _orden,
    );
    final puedeCargarMas = _paginasAnteriores.isEmpty
        ? primeraPagina.hasMore
        : _paginasAnteriores.last.hasMore;

    if (tareas.isEmpty && !puedeCargarMas) {
      final searching = _busqueda.isNotEmpty;
      final noTasks = _filtro == 'Todas' && !searching;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                searching
                    ? Icons.search_off_rounded
                    : noTasks
                    ? Icons.task_alt_rounded
                    : Icons.filter_list_off_rounded,
                size: 58,
                color: morado.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 14),
              Text(
                searching
                    ? 'No encontramos coincidencias'
                    : noTasks
                    ? 'Tu lista está lista para empezar'
                    : 'No hay tareas en este filtro',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                searching
                    ? 'Prueba con otras palabras o limpia la búsqueda.'
                    : noTasks
                    ? 'Agrega una tarea y organiza lo que sigue.'
                    : 'Prueba otro filtro para ver tus tareas.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.7),
                ),
              ),
              if (noTasks) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _mostrarFormulario,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear primera tarea'),
                ),
              ],
              if (searching)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _busqueda = '');
                  },
                  child: const Text('Limpiar búsqueda'),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      itemCount: tareas.length + (puedeCargarMas ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == tareas.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _cargandoMas
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: () => _cargarMas(primeraPagina),
                      child: const Text('Cargar más tareas'),
                    ),
            ),
          );
        }
        return TweenAnimationBuilder<Offset>(
          key: ValueKey(tareas[index].id),
          tween: Tween(begin: const Offset(0, 0.025), end: Offset.zero),
          duration: Duration(milliseconds: 180 + (index.clamp(0, 5) * 35)),
          curve: Curves.easeOutCubic,
          builder: (context, offset, child) =>
              FractionalTranslation(translation: offset, child: child),
          child: _construirTarea(tareas[index]),
        );
      },
    );
  }

  /// Resume las tareas actualmente cargadas, no todo el historial remoto.
  Widget _construirResumen(TaskPage primeraPagina) {
    final tasksById = <String, TaskModel>{
      for (final task in primeraPagina.tasks) task.id: task,
      for (final page in _paginasAnteriores)
        for (final task in page.tasks) task.id: task,
    };
    final tasks = tasksById.values.toList(growable: false);
    final pending = tasks.where((task) => !task.isCompleted).length;
    final overdue = tasks.where(isTaskOverdue).length;
    final completed = tasks.where((task) => task.isCompleted).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de tareas cargadas',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _resumenItem(
                'Pendientes',
                pending,
                Icons.pending_actions,
                morado,
              ),
              const SizedBox(width: 8),
              _resumenItem(
                'Vencidas',
                overdue,
                Icons.warning_amber_rounded,
                Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              _resumenItem(
                'Hechas',
                completed,
                Icons.task_alt,
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF80CBC4)
                    : const Color(0xFF006B5F),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construye una métrica compacta para el resumen superior.
  Widget _resumenItem(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: count.toDouble()),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, _) => Text(
                      value.round().toString(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cambia entre las tres secciones principales de la aplicación.
  Future<void> _navigateToSection(int index) async {
    if (index == 0) return;
    await Navigator.of(context).pushNamedAndRemoveUntil(
      index == 1 ? '/calendar' : '/profile',
      (route) => route.isFirst,
    );
    if (mounted && index == 2) {
      setState(() => _usuario = FirebaseAuth.instance.currentUser);
    }
  }

  @override
  /// Ensambla saludo, filtros, búsqueda, lista y navegación de tareas.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: fondo,
        title: const Text(
          'TaskFlow',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: morado,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
      bottomNavigationBar: TaskFlowNavigationBar(
        currentIndex: 0,
        onDestinationSelected: _navigateToSection,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Presenta el contexto de la cuenta sin ocupar espacio de navegación.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  UserAvatar(
                    displayName: _usuario?.displayName,
                    email: _usuario?.email,
                    radius: 22,
                    backgroundColor: morado.withValues(alpha: 0.14),
                    foregroundColor: morado,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hola, ${_usuario?.displayName?.trim().isNotEmpty == true ? _usuario!.displayName! : 'Usuario'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Los filtros por estado permiten reducir rápidamente la lista.
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Todas', 'Pendientes', 'Vencidas', 'Completadas']
                    .map((filtro) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(filtro),
                          selected: _filtro == filtro,
                          selectedColor: morado,
                          onSelected: (_) => setState(() => _filtro = filtro),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
            // Búsqueda y orden afectan a las páginas cargadas en memoria.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Buscar tareas cargadas',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _busqueda.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _busqueda = '');
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                    onChanged: (value) => setState(() => _busqueda = value),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: DropdownButton<TaskSortOrder>(
                      value: _orden,
                      items: const [
                        DropdownMenuItem(
                          value: TaskSortOrder.newest,
                          child: Text('Recientes'),
                        ),
                        DropdownMenuItem(
                          value: TaskSortOrder.dueDate,
                          child: Text('Vencimiento'),
                        ),
                        DropdownMenuItem(
                          value: TaskSortOrder.priority,
                          child: Text('Prioridad'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _orden = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // La suscripción en vivo refresca la primera página y el resumen.
            Expanded(
              child: StreamBuilder<TaskPage>(
                stream: _primeraPagina,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No se pudieron cargar las tareas: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final primeraPagina = snapshot.data;
                  if (primeraPagina == null) {
                    return const Center(
                      child: Text('No se recibieron tareas.'),
                    );
                  }
                  _sincronizarPaginas(primeraPagina);
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          24,
                          0,
                          24,
                          8,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TaskSyncIndicator(
                            isFromCache: primeraPagina.isFromCache,
                            hasPendingWrites: primeraPagina.hasPendingWrites,
                          ),
                        ),
                      ),
                      _construirResumen(primeraPagina),
                      Expanded(child: _construirLista(primeraPagina)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
