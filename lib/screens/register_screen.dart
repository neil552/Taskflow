import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../utils/firebase_error_message.dart';
import '../widgets/taskflow_logo.dart';

/// Formulario de alta de usuario con validación de datos básicos.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Los controladores preservan el texto mientras se envía el alta.
  final _formKey = GlobalKey<FormState>();

  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  final AuthService _auth = AuthService();

  bool _cargando = false;
  bool _mostrarPassword = false;

  /// Valida el formulario, registra al usuario y comunica el resultado.
  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      await _auth.registrarUsuario(
        nombre: _nombre.text,
        email: _email.text,
        password: _password.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada correctamente!'),
          backgroundColor: Colors.green,
        ),
      );

      // AuthGate detectará automáticamente la sesión
      // y abrirá HomeScreen.
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirebaseErrorMessage.fromAuth(error))),
      );
    } catch (e) {
      if (!mounted) return;

      debugPrint('Error inesperado durante el registro: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la cuenta.')),
      );
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  /// Libera los recursos asociados a los campos de entrada.
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  /// Construye los campos de perfil, correo y contraseña de registro.
  Widget build(BuildContext context) {
    final morado = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado del flujo de registro de TaskFlow.
                const Center(child: TaskFlowLogo(size: 150)),
                const SizedBox(height: 20),
                const Text(
                  'Únete a TaskFlow',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // Nombre que se mostrará en el perfil y saludo principal.
                TextFormField(
                  controller: _nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa tu nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Correo usado como identificador de acceso de Firebase.
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        !RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                            .hasMatch(value.trim())) {
                      return 'Ingresa un correo válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Firebase Authentication exige al menos seis caracteres.
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
                    if (value == null || value.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 25),

                // Envía el alta y bloquea reintentos mientras la operación continúa.
                FilledButton(
                  onPressed: _cargando ? null : _registrar,
                  style: FilledButton.styleFrom(
                    backgroundColor: morado,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  child: _cargando
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
