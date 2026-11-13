import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/taskflow_navigation_bar.dart';
import '../widgets/user_avatar.dart';

/// Muestra información de cuenta, preferencias y acciones del usuario.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Servicios que aplican cambios de perfil, tareas y recordatorios.
  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  final User? _user = FirebaseAuth.instance.currentUser;

  // Evita iniciar operaciones de borrado duplicadas.
  bool _eliminandoTareas = false;

  /// Cambia el tema guardado y presenta errores si falla la persistencia.
  Future<void> _cambiarTema(bool usarTemaClaro) async {
    try {
      await AppThemeController.instance.setThemeMode(
        usarTemaClaro ? ThemeMode.light : ThemeMode.dark,
      );
    } catch (error) {
      _mostrarError('No se pudo guardar el tema seleccionado.', error);
    }
  }

  /// Guarda el color de acento elegido y permite que MaterialApp se actualice.
  Future<void> _cambiarColorAcento(Color color) async {
    try {
      await AppThemeController.instance.setAccentColor(color);
    } catch (error) {
      _mostrarError('No se pudo guardar el color seleccionado.', error);
    }
  }

  /// Presenta errores de las acciones del perfil sin ocultar el detalle técnico.
  void _mostrarError(String mensaje, Object error) {
    debugPrint('$mensaje: $error');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Confirma la operación y elimina las tareas y avisos asociados a la cuenta.
  Future<void> _eliminarTodasLasTareas() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar todas las tareas'),
        content: const Text(
          'Esta acción eliminará permanentemente todas tus tareas. '
          'No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _eliminandoTareas = true);
    try {
      await _taskService.deleteAllTasks();
      try {
        await NotificationService.instance.cancelarTodas();
      } catch (error) {
        _mostrarError(
          'Se eliminaron las tareas, pero no se pudieron cancelar todos los recordatorios.',
          error,
        );
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se eliminaron todas las tareas.')),
        );
      }
    } catch (error) {
      _mostrarError('No se pudieron eliminar todas las tareas.', error);
    } finally {
      if (mounted) setState(() => _eliminandoTareas = false);
    }
  }

  /// Cierra la sesión; AuthGate se encarga de volver a la pantalla de acceso.
  Future<void> _cerrarSesion() async {
    try {
      await _authService.cerrarSesion();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _mostrarError('No se pudo cerrar la sesión.', error);
    }
  }

  /// Mantiene la navegación principal accesible desde la pantalla de perfil.
  void _navigateToSection(int index) {
    if (index == 2) return;
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/calendar', (route) => route.isFirst);
  }

  @override
  /// Organiza los datos del perfil, preferencias y acciones de cuenta.
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final morado = theme.colorScheme.primary;
    final tarjeta = theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil y Configuración')),
      bottomNavigationBar: TaskFlowNavigationBar(
        currentIndex: 2,
        onDestinationSelected: _navigateToSection,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar con iniciales, sin depender de un servicio de almacenamiento.
            Center(
              child: UserAvatar(
                displayName: _user?.displayName,
                email: _user?.email,
                radius: 55,
                backgroundColor: morado,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _user?.displayName ?? 'Usuario',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              _user?.email ?? '',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 30),
            // Preferencias visuales persistentes para el dispositivo actual.
            Card(
              color: tarjeta,
              child: SwitchListTile(
                secondary: Icon(
                  AppThemeController.instance.themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  color: morado,
                ),
                title: const Text('Modo claro'),
                subtitle: Text(
                  AppThemeController.instance.themeMode == ThemeMode.light
                      ? 'Activado'
                      : 'Desactivado',
                ),
                value: AppThemeController.instance.themeMode == ThemeMode.light,
                onChanged: _cambiarTema,
              ),
            ),
            const SizedBox(height: 12),
            // La operación destructiva permanece separada de las preferencias.
            Card(
              color: tarjeta,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Color de acento',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personaliza botones e indicadores de la aplicación.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: AppThemeController.accentColors.map((color) {
                        final selected =
                            AppThemeController.instance.accentColor == color;
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: 'Color de acento ${_nombreColor(color)}',
                          child: Tooltip(
                            message: _nombreColor(color),
                            child: InkWell(
                              onTap: () => _cambiarColorAcento(color),
                              customBorder: const CircleBorder(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? theme.colorScheme.onSurface
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: selected
                                    ? Icon(
                                        Icons.check,
                                        color: color.computeLuminance() > 0.45
                                            ? Colors.black
                                            : Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: tarjeta,
              child: ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                ),
                title: const Text('Eliminar todas las tareas'),
                subtitle: const Text('Esta acción no se puede deshacer.'),
                trailing: _eliminandoTareas
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                enabled: !_eliminandoTareas,
                onTap: _eliminandoTareas ? null : _eliminarTodasLasTareas,
              ),
            ),
            const SizedBox(height: 30),
            // Cerrar sesión deja que AuthGate redirija según el estado de Firebase.
            FilledButton.icon(
              onPressed: _cerrarSesion,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar Sesión'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Proporciona nombres accesibles para los colores de la paleta.
  String _nombreColor(Color color) {
    final index = AppThemeController.accentColors.indexOf(color);
    return const ['Morado', 'Verde', 'Azul', 'Rojo', 'Naranja', 'Rosa'][index];
  }
}
