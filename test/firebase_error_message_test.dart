import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/utils/firebase_error_message.dart';

void main() {
  /// Los mensajes de acceso no deben revelar la respuesta técnica de Firebase.
  test('maps sign-in errors without exposing backend details', () {
    final message = FirebaseErrorMessage.fromAuth(
      FirebaseAuthException(code: 'invalid-credential', message: 'raw detail'),
    );

    expect(message, 'Correo o contraseña incorrectos.');
    expect(message, isNot(contains('raw detail')));
  });

  /// Los errores de reglas se convierten en instrucciones comprensibles.
  test('maps Firebase access errors to actionable user messages', () {
    final message = FirebaseErrorMessage.fromFirebase(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      fallback: 'Error genérico',
    );

    expect(message, contains('No tienes permiso'));
  });
}
