import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_controller.dart';
import 'widgets/taskflow_logo.dart';

/// Prepara servicios locales y Firebase antes de mostrar la interfaz.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // El plugin debe inicializarse antes de que las pantallas programen avisos.
  await NotificationService.instance.init();
  await AppThemeController.instance.load();
  runApp(const TaskFlowApp());
}

/// Raíz de la aplicación: conecta temas, rutas y control de sesión.
class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  /// Reconstruye los temas cuando el usuario cambia modo o color de acento.
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'TaskFlow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightThemeFor(
            AppThemeController.instance.accentColor,
          ),
          darkTheme: AppTheme.darkThemeFor(
            AppThemeController.instance.accentColor,
          ),
          themeMode: AppThemeController.instance.themeMode,
          home: const AppLaunchScreen(),
          routes: {
            '/calendar': (_) => const CalendarScreen(),
            '/profile': (_) => const ProfileScreen(),
          },
        );
      },
    );
  }
}

/// Muestra una introducción animada antes de abrir la aplicación.
class AppLaunchScreen extends StatefulWidget {
  const AppLaunchScreen({super.key});

  @override
  State<AppLaunchScreen> createState() => _AppLaunchScreenState();
}

class _AppLaunchScreenState extends State<AppLaunchScreen> {
  bool _showApp = false;

  @override
  /// Inicia la transición hacia la pantalla correspondiente a la sesión.
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _showApp = true);
    });
  }

  @override
  /// Alterna la introducción animada y el acceso según el temporizador.
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _showApp
          ? const AuthGate(key: ValueKey('app'))
          : _LaunchAnimation(
              key: const ValueKey('launch'),
              backgroundColor: theme.scaffoldBackgroundColor,
            ),
    );
  }
}

class _LaunchAnimation extends StatelessWidget {
  const _LaunchAnimation({super.key, required this.backgroundColor});

  final Color backgroundColor;

  @override
  /// Dibuja la marca de TaskFlow con escala animada.
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.72, end: 1),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TaskFlowLogo(size: 190),
              const SizedBox(height: 22),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dirige al usuario según el estado actual de su sesión de Firebase.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  /// Observa la sesión y dirige al inicio o a la pantalla de autenticación.
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
