import 'package:flutter/material.dart';

/// Barra inferior compartida por las pantallas principales autenticadas.
class TaskFlowNavigationBar extends StatelessWidget {
  const TaskFlowNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Resalta la sección actual y delega el cambio de destino a su pantalla.
  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.checklist_outlined),
          selectedIcon: Icon(Icons.checklist_rounded),
          label: 'Tareas',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Calendario',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }
}
