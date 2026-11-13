import 'package:flutter/material.dart';

import '../models/task_model.dart';

/// Tarjeta de tarea con contenido visible y acciones accesibles.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.priorityColor,
    required this.onToggle,
    required this.onToggleSubtask,
    required this.onEdit,
    required this.onDelete,
  });

  final TaskModel task;
  final Color priorityColor;
  final ValueChanged<bool> onToggle;
  final void Function(int index, bool completed) onToggleSubtask;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueDate = task.dueDate;
    final dueDateText = dueDate == null
        ? null
        : '${dueDate.day}/${dueDate.month}/${dueDate.year} '
              '${dueDate.hour.toString().padLeft(2, '0')}:'
              '${dueDate.minute.toString().padLeft(2, '0')}';
    final recurrenceLabel = switch (task.recurrence) {
      'daily' => 'Diaria',
      'weekly' => 'Semanal',
      'monthly' => 'Mensual',
      _ => null,
    };

    return Card(
      color: task.isCompleted
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: priorityColor.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(8, 8, 4, 8),
        leading: Checkbox(
          value: task.isCompleted,
          activeColor: theme.colorScheme.primary,
          semanticLabel: task.isCompleted
              ? 'Marcar ${task.title} como pendiente'
              : 'Marcar ${task.title} como completada',
          onChanged: (value) {
            if (value != null) onToggle(value);
          },
        ),
        title: Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted
                ? theme.disabledColor
                : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.description.isNotEmpty) ...[
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    task.category,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.priority,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: priorityColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (dueDateText != null)
                    Text(
                      '${isOverdue ? 'Vencida' : 'Vence'}: $dueDateText',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isOverdue
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        fontWeight: isOverdue ? FontWeight.w700 : null,
                      ),
                    ),
                  if (recurrenceLabel != null)
                    Text(
                      'Repite: $recurrenceLabel',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              if (task.subtasks.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Subtareas: ${task.subtasks.where((item) => item.isCompleted).length}/${task.subtasks.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                ...task.subtasks.indexed.map((entry) {
                  final (index, subtask) = entry;
                  return InkWell(
                    onTap: () => onToggleSubtask(index, !subtask.isCompleted),
                    child: Row(
                      children: [
                        Checkbox(
                          value: subtask.isCompleted,
                          visualDensity: VisualDensity.compact,
                          onChanged: (value) {
                            if (value != null) {
                              onToggleSubtask(index, value);
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            subtask.title,
                            style: theme.textTheme.bodySmall?.copyWith(
                              decoration: subtask.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Opciones para ${task.title}',
          onSelected: (value) {
            if (value == 'editar') onEdit();
            if (value == 'eliminar') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'editar', child: Text('Editar')),
            PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }

  bool get isOverdue =>
      !task.isCompleted &&
      task.dueDate != null &&
      task.dueDate!.isBefore(DateTime.now());
}
