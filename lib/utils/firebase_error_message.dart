import 'package:firebase_auth/firebase_auth.dart';

/// Convierte errores técnicos de Firebase en mensajes seguros para el usuario.
class FirebaseErrorMessage {
  /// Traduce errores de autenticación sin exponer detalles del proveedor.
  static String fromAuth(FirebaseAuthException error) {
    return switch (error.code) {
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Correo o contraseña incorrectos.',
      'invalid-email' => 'El correo electrónico no es válido.',
      'email-already-in-use' => 'Este correo ya está registrado.',
      'weak-password' => 'La contraseña es demasiado débil.',
      'network-request-failed' =>
        'No hay conexión. Comprueba tu conexión e inténtalo de nuevo.',
      'too-many-requests' =>
        'Hubo demasiados intentos. Espera un momento y vuelve a intentarlo.',
      'user-disabled' => 'Esta cuenta está deshabilitada.',
      _ => 'No se pudo completar la autenticación. Inténtalo de nuevo.',
    };
  }

  /// Mapea fallos habituales de Firebase a mensajes accionables.
  static String fromFirebase(
    FirebaseException error, {
    required String fallback,
  }) {
    return switch (error.code) {
      'permission-denied' =>
        'No tienes permiso para realizar esta acción. Vuelve a iniciar sesión.',
      'unauthenticated' => 'Tu sesión expiró. Inicia sesión nuevamente.',
      'unavailable' || 'network-request-failed' =>
        'No hay conexión con el servicio. Inténtalo de nuevo.',
      'not-found' => 'El elemento solicitado ya no existe.',
      'resource-exhausted' =>
        'Se alcanzó un límite del servicio. Inténtalo más tarde.',
      _ => fallback,
    };
  }
}
