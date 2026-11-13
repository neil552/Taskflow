import 'package:flutter/material.dart';

import '../models/task_model.dart';

/// Formulario reutilizable para crear o editar una tarea.
class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({super.key, this.task, required this.onSave});

  final TaskModel? task;

  /// Persiste los datos y devuelve `true` solo si se guardaron correctamente.
  final Future<bool> Function(TaskModel task) onSave;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  // Las opciones coinciden con los valores aceptados por las reglas Firestore.
  static const _categories = ['Personal', 'Estudio', 'Trabajo', 'Otras'];
  static const _priorities = ['Alta', 'Media', 'Baja'];
  static const _recurrenceOptions = {
    'none': 'No se repite',
    'daily': 'Cada día',
    'weekly': 'Cada semana',
    'monthly': 'Cada mes',
  };

  // Controladores y valores temporales del formulario activo.
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _subtaskController;
  late String _category;
  late String _priority;
  late String _recurrence;
  late List<TaskSubtask> _subtasks;
  DateTime? _dueDate;
  bool _saving = false;
  String? _errorMessage;

  @override
  /// Carga valores existentes al editar o aplica las opciones iniciales al crear.
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _subtaskController = TextEditingController();
    _category = _categories.contains(task?.category)
        ? task!.category
        : _categories.first;
    _priority = _priorities.contains(task?.priority)
        ? task!.priority
        : _priorities[1];
    _recurrence = _recurrenceOptions.containsKey(task?.recurrence)
        ? task!.recurrence
        : 'none';
    _subtasks = List.of(task?.subtasks ?? const []);
    _dueDate = task?.dueDate;
  }

  @override
  /// Libera controladores cuando el diálogo termina su ciclo de vida.
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  /// Agrega una subtarea sin exceder el límite validado por las reglas.
  void _addSubtask() {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) return;
    if (_subtasks.length >= 20) {
      setState(() => _errorMessage = 'Una tarea admite hasta 20 subtareas.');
      return;
    }

    setState(() {
      _subtasks.add(TaskSubtask(title: title));
      _subtaskController.clear();
      _errorMessage = null;
    });
  }

  /// Valida, crea el modelo y delega la escritura al servicio anfitrión.
  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Escribe el nombre de la tarea.');
      return;
    }
    if (_recurrence != 'none' && _dueDate == null) {
      setState(
        () => _errorMessage =
            'Elige una fecha de vencimiento para repetir la tarea.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final previousTask = widget.task;
    final task = TaskModel(
      id: previousTask?.id ?? '',
      title: title,
      description: _descriptionController.text.trim(),
      category: _category,
      priority: _priority,
      dueDate: _dueDate,
      isCompleted: previousTask?.isCompleted ?? false,
      recurrence: _recurrence,
      recurrenceDay: previousTask != null && previousTask.dueDate == _dueDate
          ? previousTask.recurrenceDay
          : _dueDate?.day,
      subtasks: List.unmodifiable(_subtasks),
      createdAt: previousTask?.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      final saved = await widget.onSave(task);
      if (!mounted) return;
      if (saved) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _saving = false;
          _errorMessage = 'No se pudo guardar la tarea. Inténtalo de nuevo.';
        });
      }
    } catch (error) {
      debugPrint('Error al guardar la tarea: $error');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'No se pudo guardar la tarea. Inténtalo de nuevo.';
      });
    }
  }

  /// Permite elegir una fecha y una hora antes de actualizar el recordatorio.
  Future<void> _chooseDueDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || selectedDate == null) return;

    final currentTime = _dueDate == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay.fromDateTime(_dueDate!);
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    if (!mounted || selectedTime == null) return;

    setState(() {
      _dueDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  @override
  /// Dibuja campos, selectores, validaciones y acciones del formulario.
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dueDate = _dueDate;

    return AlertDialog(
      title: Text(widget.task == null ? 'Nueva tarea' : 'Editar tarea'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // El título es obligatorio y se limita a la longitud aceptada en Firestore.
            TextField(
              controller: _titleController,
              enabled: !_saving,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Nombre de la tarea',
                prefixIcon: Icon(Icons.task_alt),
              ),
            ),
            const SizedBox(height: 12),
            // La descripción es opcional, con un máximo compatible con las reglas.
            TextField(
              controller: _descriptionController,
              enabled: !_saving,
              maxLines: 2,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),
            // Categoría y prioridad usan los valores permitidos por el backend.
            DropdownButtonFormField<String>(
              initialValue: _category,
              dropdownColor: colors.surface,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _categories
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _category = value);
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              dropdownColor: colors.surface,
              decoration: const InputDecoration(labelText: 'Prioridad'),
              items: _priorities
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _priority = value);
                    },
            ),
            const SizedBox(height: 15),
            // Fecha y hora alimentan tanto el calendario como el recordatorio local.
            OutlinedButton.icon(
              onPressed: _saving ? null : _chooseDueDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                dueDate == null
                    ? 'Elegir fecha y hora'
                    : '${dueDate.day}/${dueDate.month}/${dueDate.year} '
                          '${dueDate.hour.toString().padLeft(2, '0')}:'
                          '${dueDate.minute.toString().padLeft(2, '0')}',
              ),
            ),
            if (dueDate != null)
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _dueDate = null;
                        _recurrence = 'none';
                      }),
                child: const Text('Quitar recordatorio'),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _recurrence,
              dropdownColor: colors.surface,
              decoration: const InputDecoration(
                labelText: 'Repetir tarea',
                prefixIcon: Icon(Icons.repeat),
              ),
              items: _recurrenceOptions.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _recurrence = value;
                          _errorMessage = null;
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'Subtareas (${_subtasks.length}/20)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskController,
                    enabled: !_saving && _subtasks.length < 20,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Agregar subtarea',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                IconButton(
                  tooltip: 'Agregar subtarea',
                  onPressed: _saving ? null : _addSubtask,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            ..._subtasks.indexed.map((entry) {
              final (index, subtask) = entry;
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: subtask.isCompleted,
                title: Text(subtask.title),
                onChanged: _saving
                    ? null
                    : (value) => setState(
                        () => _subtasks[index] = subtask.copyWith(
                          isCompleted: value ?? false,
                        ),
                      ),
                secondary: IconButton(
                  tooltip: 'Eliminar ${subtask.title}',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _subtasks.removeAt(index)),
                  icon: const Icon(Icons.close),
                ),
              );
            }),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
      actions: [
        // Durante el guardado se bloquea el cierre para evitar perder datos.
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
