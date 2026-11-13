import 'package:firebase_auth/firebase_auth.dart';

/// Encapsula el acceso a Firebase Authentication para las pantallas de cuenta.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crea una cuenta y, si se proporciona, establece su nombre visible.
  Future<UserCredential> registrarUsuario({
    required String email,
    required String password,
    String? nombre,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (nombre != null && nombre.trim().isNotEmpty) {
      await credential.user?.updateDisplayName(nombre.trim());
      await credential.user?.reload();
    }

    return credential;
  }

  /// Valida las credenciales e inicia una sesión de Firebase.
  Future<UserCredential> iniciarSesion({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Cambia el nombre visible del usuario autenticado.
  Future<void> actualizarNombre(String nombre) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No hay una sesión activa');
    }

    await user.updateDisplayName(nombre.trim());
    await user.reload();
  }

  /// Envía un correo con el flujo de restablecimiento de contraseña.
  Future<void> recuperarPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Cierra la sesión actual en Firebase Authentication.
  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }

  /// Devuelve la cuenta activa o `null` si no hay sesión.
  User? get usuarioActual => _auth.currentUser;
}
