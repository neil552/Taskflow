import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../utils/firebase_error_message.dart';
import '../widgets/taskflow_logo.dart';
import 'register_screen.dart';

/// Formulario para iniciar sesión o solicitar recuperación de contraseña.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // El formulario valida los campos antes de contactar con Firebase.
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  final AuthService _auth = AuthService();

  // Controla el indicador de carga y la visibilidad de la contraseña.
  bool _cargando = false;
  bool _mostrarPassword = false;

  /// Valida las credenciales e informa errores de autenticación al usuario.
  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      await _auth.iniciarSesion(email: _email.text, password: _password.text);

      // AuthGate abrirá HomeScreen automáticamente.
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirebaseErrorMessage.fromAuth(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  /// Solicita a Firebase el envío del correo de restablecimiento.
  Future<void> _recuperarPassword() async {
    final correo = _email.text.trim();

    if (correo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero escribe tu correo electrónico.')),
      );
      return;
    }

    try {
      await _auth.recuperarPassword(correo);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa tu correo para restablecer tu contraseña.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirebaseErrorMessage.fromAuth(error))),
      );
    } catch (error) {
      if (!mounted) return;
      debugPrint('Error al enviar recuperación de contraseña: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar el correo. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  @override
  /// Libera los controladores de texto al retirar el formulario.
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  /// Presenta los campos de acceso y enlaces para registrar o recuperar.
  Widget build(BuildContext context) {
    final morado = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Marca de la aplicación e indicación de su propósito.
                  const Center(child: TaskFlowLogo(size: 170)),
                  const SizedBox(height: 20),
                  Text(
                    'TaskFlow',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Organiza tus tareas. Alcanza tus objetivos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Credenciales con validación local antes de llamar a Firebase.
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  TextFormField(
                    controller: _password,
                    obscureText: !_mostrarPassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _mostrarPassword = !_mostrarPassword;
                          });
                        },
                        icon: Icon(
                          _mostrarPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      return null;
                    },
                  ),

                  // Recuperación usa el correo ya escrito en el formulario.
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _recuperarPassword,
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // El indicador evita envíos repetidos mientras Firebase responde.
                  FilledButton(
                    onPressed: _cargando ? null : _iniciarSesion,
                    style: FilledButton.styleFrom(
                      backgroundColor: morado,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                    ),
                    child: _cargando
                        ? CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                          )
                        : const Text('Iniciar sesión'),
                  ),

                  const SizedBox(height: 20),

                  // Permite cambiar al flujo de creación de cuenta.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('¿No tienes cuenta?'),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Regístrate',
                          style: TextStyle(color: morado),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
