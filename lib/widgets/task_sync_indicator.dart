import 'package:flutter/material.dart';

/// Indica si las tareas están en caché, pendientes de subir o sincronizadas.
class TaskSyncIndicator extends StatelessWidget {
  const TaskSyncIndicator({
    required this.isFromCache,
    required this.hasPendingWrites,
    super.key,
  });

  final bool isFromCache;
  final bool hasPendingWrites;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label, color) = switch ((hasPendingWrites, isFromCache)) {
      (true, true) => (
        Icons.cloud_upload_outlined,
        'Sin conexión · cambios pendientes',
        theme.colorScheme.tertiary,
      ),
      (true, false) => (
        Icons.cloud_upload_outlined,
        'Sincronizando cambios…',
        theme.colorScheme.tertiary,
      ),
      (false, true) => (
        Icons.cloud_off_outlined,
        'Sin conexión · datos guardados',
        theme.colorScheme.onSurfaceVariant,
      ),
      (false, false) => (
        Icons.cloud_done_outlined,
        'Sincronizado',
        theme.colorScheme.primary,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
