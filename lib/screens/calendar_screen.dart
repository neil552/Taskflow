import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/task_model.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';
import '../utils/task_list_utils.dart';
import '../widgets/taskflow_navigation_bar.dart';
import 'task_form_dialog.dart';

/// Presentaciones disponibles para revisar tareas con vencimiento.
enum CalendarView { month, agenda }

/// Filtra tareas calendarizadas y las devuelve en orden de vencimiento.
/// Las tareas sin fecha se excluyen porque no pertenecen a la agenda.
List<TaskModel> filterCalendarTasks({
  required Iterable<TaskModel> tasks,
  required String status,
  required String category,
  required String priority,
  DateTime? now,
}) {
  final filtered = tasks.where((task) {
    final matchesStatus = switch (status) {
      'Pendientes' => !task.isCompleted,
      'Completadas' => task.isCompleted,
      'Vencidas' => isTaskOverdue(task, now: now),
      _ => true,
    };
    final matchesCategory = category == 'Todas' || task.category == category;
    final matchesPriority = priority == 'Todas' || task.priority == priority;
    return task.dueDate != null &&
        matchesStatus &&
        matchesCategory &&
        matchesPriority;
  }).toList();

  filtered.sort((first, second) => first.dueDate!.compareTo(second.dueDate!));
  return filtered;
}

/// Calendario mensual y agenda con filtros y edición de tareas.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

/// Gestiona la fecha enfocada, selección diaria, filtros y acciones.
class _CalendarScreenState extends State<CalendarScreen> {
  // Opciones consistentes con los valores guardados y validados por Firestore.
  static const _categories = [
    'Todas',
    'Personal',
    'Estudio',
    'Trabajo',
    'Otras',
  ];
  static const _priorities = ['Todas', 'Alta', 'Media', 'Baja'];
  static const _statuses = ['Todas', 'Pendientes', 'Completadas', 'Vencidas'];

  final TaskService _taskService = TaskService();
  late final Stream<List<TaskModel>> _tasksStream;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  CalendarView _view = CalendarView.month;
  String _statusFilter = 'Todas';
  String _categoryFilter = 'Todas';
  String _priorityFilter = 'Todas';

  @override
  /// Inicia la suscripción que alimenta las vistas mensual y de agenda.
  void initState() {
    super.initState();
    _tasksStream = _taskService.getTasks();
  }

  /// Aplica filtros actuales y ordena las tareas cronológicamente.
  List<TaskModel> _filterTasks(Iterable<TaskModel> tasks) {
    return filterCalendarTasks(
      tasks: tasks,
      status: _statusFilter,
      category: _categoryFilter,
      priority: _priorityFilter,
    );
  }

  /// Devuelve un color accesible según prioridad, vencimiento y finalización.
  Color _priorityColor(TaskModel task, BuildContext context) {
    final theme = Theme.of(context);
    if (task.isCompleted) {
      return theme.brightness == Brightness.dark
          ? const Color(0xFF80CBC4)
          : const Color(0xFF006B5F);
    }
    if (isTaskOverdue(task)) return theme.colorScheme.error;
    switch (task.priority) {
      case 'Alta':
        return theme.brightness == Brightness.dark
            ? const Color(0xFFFF8A80)
            : const Color(0xFFB3261E);
      case 'Baja':
        return theme.brightness == Brightness.dark
            ? const Color(0xFF80CBC4)
            : const Color(0xFF006B5F);
      default:
        return theme.brightness == Brightness.dark
            ? const Color(0xFFFFCC80)
            : const Color(0xFF8A4F00);
    }
  }

  /// Devuelve el nombre localizado del mes que está enfocado.
  String _monthLabel() {
    final label = DateFormat.yMMMM('es_ES').format(_focusedDay);
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }

  /// Selecciona la fecha actual y centra el calendario en el día de hoy.
  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _focusedDay = today;
      _selectedDay = today;
    });
  }

  /// Cambia de mes conservando el día cuando existe en el mes de destino.
  void _changeMonth(int offset) {
    final month = DateTime(_focusedDay.year, _focusedDay.month + offset);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = (_selectedDay ?? _focusedDay).day.clamp(1, lastDay);
    setState(() {
      _focusedDay = month;
      _selectedDay = DateTime(month.year, month.month, day);
    });
  }

  /// Reutiliza el formulario común y actualiza la notificación tras guardar.
  Future<void> _editTask(TaskModel task) async {
    await showDialog<void>(
      context: context,
      builder: (_) => TaskFormDialog(
        task: task,
        onSave: (updatedTask) async {
          try {
            await _taskService.updateTask(updatedTask);
          } catch (error) {
            debugPrint('Error al editar una tarea desde el calendario: $error');
            return false;
          }

          try {
            final notificationId = NotificationService.notificationIdForTask(
              task.id,
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
              if (!scheduled && mounted) {
                _showMessage(
                  'La tarea se actualizó, pero no se pudo programar el recordatorio.',
                );
              }
            }
          } catch (error) {
            debugPrint('Error al actualizar el recordatorio: $error');
            if (mounted) {
              _showMessage(
                'La tarea se actualizó, pero no se pudo actualizar su recordatorio.',
              );
            }
          }
          return true;
        },
      ),
    );
  }

  /// Cambia el estado de finalización y ajusta el recordatorio local.
  Future<void> _toggleTask(TaskModel task, bool completed) async {
    try {
      await _taskService.toggleTask(task.id, completed);
      final notificationId = NotificationService.notificationIdForTask(task.id);
      if (completed || task.dueDate == null) {
        await NotificationService.instance.cancelarNotificacion(
          id: notificationId,
        );
      } else {
        final scheduled = await NotificationService.instance
            .programarNotificacion(
              id: notificationId,
              titulo: 'Recordatorio: ${task.title}',
              cuerpo: 'Tu tarea vence pronto.',
              fechaProgramada: task.dueDate!,
            );
        if (!scheduled) {
          _showMessage(
            'La tarea se actualizó, pero no se pudo programar el recordatorio.',
          );
        }
      }
    } catch (error) {
      debugPrint('Error al actualizar una tarea desde el calendario: $error');
      _showMessage('No se pudo actualizar la tarea. Inténtalo de nuevo.');
    }
  }

  /// Centraliza avisos breves originados por las acciones del calendario.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Mantiene accesibles las demás secciones desde la barra inferior.
  void _navigateToSection(int index) {
    if (index == 1) return;
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/profile', (route) => route.isFirst);
  }

  /// Construye un menú desplegable con el estilo común del calendario.
  Widget _buildFilter({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: onChanged,
    );
  }

  /// Presenta filtros combinables por estado, categoría y prioridad.
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 145,
            child: _buildFilter(
              label: 'Estado',
              value: _statusFilter,
              options: _statuses,
              onChanged: (value) {
                if (value != null) setState(() => _statusFilter = value);
              },
            ),
          ),
          SizedBox(
            width: 145,
            child: _buildFilter(
              label: 'Categoría',
              value: _categoryFilter,
              options: _categories,
              onChanged: (value) {
                if (value != null) setState(() => _categoryFilter = value);
              },
            ),
          ),
          SizedBox(
            width: 125,
            child: _buildFilter(
              label: 'Prioridad',
              value: _priorityFilter,
              options: _priorities,
              onChanged: (value) {
                if (value != null) setState(() => _priorityFilter = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra detalles resumidos y abre la edición al tocar una tarea.
  Widget _buildTaskTile(TaskModel task) {
    final priorityColor = _priorityColor(task, context);
    final dueDate = task.dueDate!;
    final dateText = DateFormat('EEEE d MMM, HH:mm', 'es_ES').format(dueDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        onTap: () => _editTask(task),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Checkbox(
          value: task.isCompleted,
          semanticLabel: task.isCompleted
              ? 'Marcar ${task.title} como pendiente'
              : 'Marcar ${task.title} como completada',
          onChanged: (value) {
            if (value != null) _toggleTask(task, value);
          },
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted
                ? Theme.of(context).disabledColor
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateText),
              const SizedBox(height: 2),
              Text(
                '${task.category}'
                '${isTaskOverdue(task) ? ' • Vencida' : ''}',
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: priorityColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            task.priority,
            style: TextStyle(
              color: priorityColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  /// Estado vacío reutilizable para agenda, fechas sin tareas y errores.
  Widget _buildEmptyState(String message, IconData icon) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 46,
              color: theme.colorScheme.primary.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  /// Agrupa cronológicamente las próximas tareas programadas.
  Widget _buildAgenda(List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return _buildEmptyState(
        'No hay tareas con esos filtros.',
        Icons.event_available_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final previousDate = index == 0 ? null : tasks[index - 1].dueDate;
        final showDateHeading =
            index == 0 || !isSameDay(previousDate, task.dueDate);
        final heading = DateFormat(
          'EEEE d MMMM',
          'es_ES',
        ).format(task.dueDate!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeading)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 3),
                child: Text(
                  '${heading[0].toUpperCase()}${heading.substring(1)}',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            _buildTaskTile(task),
          ],
        );
      },
    );
  }

  /// Dibuja el mes, marcadores de tareas y tareas del día seleccionado.
  Widget _buildMonth(List<TaskModel> tasks) {
    final theme = Theme.of(context);
    final selectedTasks = tasks
        .where((task) => isSameDay(task.dueDate, _selectedDay))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TableCalendar<TaskModel>(
            locale: 'es_ES',
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) =>
                tasks.where((task) => isSameDay(task.dueDate, day)).toList(),
            calendarFormat: CalendarFormat.month,
            rowHeight: 40,
            daysOfWeekHeight: 24,
            headerVisible: false,
            calendarBuilders: CalendarBuilders<TaskModel>(
              markerBuilder: (context, date, events) {
                final dayTasks = events.take(3).toList();
                if (dayTasks.isEmpty) return null;
                return Positioned(
                  bottom: 1,
                  child: Semantics(
                    label: '${events.length} tareas',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: dayTasks
                          .map(
                            (task) => Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: _priorityColor(task, context),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: theme.colorScheme.onSurface),
              weekendStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: theme.colorScheme.onSurface),
              weekendTextStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              outsideTextStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 5, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE d MMMM', 'es_ES').format(_selectedDay!),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${selectedTasks.length} ${selectedTasks.length == 1 ? 'tarea' : 'tareas'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: selectedTasks.isEmpty
              ? _buildEmptyState(
                  'No hay tareas programadas para este día.',
                  Icons.event_available_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: selectedTasks.length,
                  itemBuilder: (context, index) =>
                      _buildTaskTile(selectedTasks[index]),
                ),
        ),
      ],
    );
  }

  @override
  /// Alterna las vistas, renderiza filtros y conecta los datos de Firestore.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today),
            label: const Text('Hoy'),
          ),
        ],
      ),
      bottomNavigationBar: TaskFlowNavigationBar(
        currentIndex: 1,
        onDestinationSelected: _navigateToSection,
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _tasksStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildEmptyState(
              'No se pudieron cargar las tareas. Comprueba tu conexión e inténtalo de nuevo.',
              Icons.cloud_off_outlined,
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = _filterTasks(snapshot.data ?? []);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SegmentedButton<CalendarView>(
                  segments: const [
                    ButtonSegment(
                      value: CalendarView.month,
                      icon: Icon(Icons.calendar_month),
                      label: Text('Mes'),
                    ),
                    ButtonSegment(
                      value: CalendarView.agenda,
                      icon: Icon(Icons.view_agenda_outlined),
                      label: Text('Agenda'),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (selection) {
                    setState(() => _view = selection.first);
                  },
                ),
              ),
              if (_view == CalendarView.month)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Mes anterior',
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          _monthLabel(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mes siguiente',
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              _buildFilters(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _view == CalendarView.month
                      ? _buildMonth(tasks)
                      : _buildAgenda(tasks),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
