# Informe técnico del proyecto TaskFlow

**Fecha de revisión:** 9 de noviembre de 2026  
**Tipo de revisión:** análisis estático del código, configuración y pruebas locales  
**Estado general:** apto para pruebas Android; requiere trabajo antes de una publicación de producción.

## 1. Resumen ejecutivo

TaskFlow es una aplicación Flutter para gestionar tareas personales. Usa Firebase Authentication para las cuentas, Cloud Firestore para tareas y Firebase Storage para las fotos de perfil. Incluye recordatorios locales, calendario mensual y agenda, filtros, temas claro/oscuro y personalización de color.

La estructura separa pantallas, servicios, modelos, utilidades y tema, lo que facilita el mantenimiento. El análisis estático y las pruebas Flutter pasan. También se pudo construir el APK de depuración.

Antes de publicar una versión release, hay que configurar una firma propia y reemplazar el identificador Android de ejemplo. La configuración Firebase revisada solo contiene opciones Android. Las pruebas automatizadas de las reglas Firebase no pudieron ejecutarse porque Firebase CLI requiere JDK 21 y el entorno tiene JDK 17.

## 2. Alcance y límites

Se revisaron:

- Código Dart en `lib/`: inicialización, autenticación, tareas, calendario, perfil, notificaciones, temas y navegación.
- Pruebas Dart en `test/`.
- Reglas de Firestore y Storage y sus pruebas locales.
- Dependencias, documentación y configuración de Firebase.
- Configuración Android y disponibilidad de configuración Firebase en otras plataformas.

No se comprobó la configuración real de los proveedores de autenticación en la consola Firebase, no se desplegaron reglas, ni se hicieron pruebas de notificaciones en teléfonos físicos o de publicación en tiendas. Tampoco se verificaron builds de iOS, web o escritorio.

## 3. Arquitectura y funcionalidades

### Aplicación y navegación

- [main.dart](./lib/main.dart) inicializa Firebase, localización española y notificaciones, define temas y rutas y dirige al usuario según su sesión.
- [taskflow_navigation_bar.dart](./lib/widgets/taskflow_navigation_bar.dart) comparte la navegación inferior entre tareas, calendario y perfil.
- Las pantallas principales están separadas en `lib/screens/`.

### Datos y backend

- [task_model.dart](./lib/models/task_model.dart) representa las tareas y convierte datos a y desde Firestore.
- [task_service.dart](./lib/services/task_service.dart) administra tareas bajo la cuenta autenticada, paginación, actualizaciones y borrado en lotes.
- [auth_service.dart](./lib/services/auth_service.dart) concentra registro, inicio y cierre de sesión y recuperación de contraseña.
- [firestore.rules](./firestore.rules) restringe la colección de tareas al propietario y valida campos y valores.
- [storage.rules](./storage.rules) limita los avatares al UID autenticado y restringe tamaño y tipo MIME.

### Interfaz y experiencia

- [home_screen.dart](./lib/screens/home_screen.dart) presenta tareas, filtros, búsqueda, orden, resumen de las páginas cargadas y operaciones CRUD.
- [calendar_screen.dart](./lib/screens/calendar_screen.dart) permite alternar entre mes y agenda, navegar por meses, volver a hoy y filtrar por estado, categoría y prioridad.
- [task_form_dialog.dart](./lib/screens/task_form_dialog.dart) comparte el formulario de creación y edición.
- [profile_screen.dart](./lib/screens/profile_screen.dart) gestiona la foto, el tema, el color de acento y acciones de cuenta.
- [app_theme.dart](./lib/theme/app_theme.dart) y [app_theme_controller.dart](./lib/theme/app_theme_controller.dart) implementan temas y preferencias visuales persistentes.

### Recordatorios

- [notification_service.dart](./lib/services/notification_service.dart) encapsula `flutter_local_notifications`, permisos, alarmas exactas y zona horaria local.
- Android declara permisos y receptores de notificaciones en [AndroidManifest.xml](./android/app/src/main/AndroidManifest.xml).
- El recordatorio actual se programa para la fecha y hora de vencimiento; no incluye todavía reglas de repetición o anticipación configurable.

## 4. Hallazgos y prioridades

| Prioridad | Hallazgo | Evidencia e impacto | Recomendación |
|---|---|---|---|
| **Alta antes de publicar** | La variante release usa la firma debug. | En [build.gradle.kts](./android/app/build.gradle.kts), `release.signingConfig` apunta a `signingConfigs.debug`. No es una configuración adecuada para distribuir una versión de producción. | Crear una clave de firma release, protegerla fuera del código fuente y configurar la firma con secretos de entorno o CI. Verificar el APK/AAB firmado antes de distribuirlo. |
| **Media** | El identificador Android sigue siendo `com.example.taskflow`. | [build.gradle.kts](./android/app/build.gradle.kts) conserva el identificador de ejemplo. Aunque coincide con el cliente registrado en la configuración Firebase actual, no es un identificador apropiado para publicar una aplicación propia. | Elegir un identificador de paquete definitivo, actualizar Firebase con ese identificador y regenerar la configuración Android antes de publicar. |
| **Media, si se busca soporte multiplataforma** | Firebase solo está configurado para Android. | [firebase_options.dart](./lib/firebase_options.dart) devuelve opciones Android y lanza `UnsupportedError` para web, iOS, macOS, Windows y Linux. No se encontró un `GoogleService-Info.plist` de iOS. | Si la aplicación será solo Android, documentar ese alcance. Si se desea otra plataforma, registrar cada app en Firebase y generar sus opciones con FlutterFire antes de ejecutar allí. |
| **Media** | No fue posible ejecutar las pruebas de reglas con el emulador. | `npm run test:rules` se detuvo porque Firebase CLI requiere JDK 21 o superior; el entorno inspeccionado usa JDK 17. Por lo tanto, las reglas se revisaron en código, pero no se verificaron con el emulador en esta ejecución. | Ejecutar las pruebas con JDK 21 o superior en el `JAVA_HOME` efectivo y corregir cualquier fallo antes de desplegar reglas. |
| **Media a medida que crezcan los datos** | El calendario observa todas las tareas sin paginación. | [task_service.dart](./lib/services/task_service.dart) implementa `getTasks()` sin límite, y [calendar_screen.dart](./lib/screens/calendar_screen.dart) lo usa para alimentar ambas vistas. Esto puede aumentar lecturas, memoria y tiempo de carga con cuentas grandes. | Considerar consultas por intervalo de `dueDate` para el mes o rango visible y paginación para la agenda. Añadir índices si las consultas combinadas los necesitan. |
| **Baja / reproducibilidad** | Las dependencias de las pruebas de reglas no tienen lockfile. | No se encontró `tests/firebase/package-lock.json`; `package.json` usa rangos de versión. Las instalaciones futuras pueden resolver versiones distintas. | Generar y conservar el lockfile de npm para que las pruebas de reglas sean reproducibles en desarrollo y CI. |
| **Baja / mantenimiento** | La compilación muestra una advertencia de compatibilidad Kotlin de plugins. | `flutter build apk --debug` terminó correctamente, pero Flutter advirtió que algunos plugins aplican Kotlin Gradle Plugin y que futuras versiones podrían dejar de admitir esa integración. | Mantener actualizados Flutter y los plugins afectados; revisar sus notas de compatibilidad al actualizar el toolchain. |

### Comportamiento que conviene documentar

- La búsqueda, los filtros y el resumen de la pantalla principal operan sobre tareas cargadas en memoria; la propia interfaz ofrece **Cargar más**. Esto limita el alcance de la búsqueda hasta cargar otras páginas.
- La agenda filtra tareas con fecha de vencimiento; las tareas sin fecha no aparecen en el calendario, lo cual es coherente con su uso como planificador de vencimientos.

## 5. Aspectos positivos observados

- El código separa modelos, pantallas y servicios y permite inyectar un gateway falso para probar notificaciones.
- Los errores de Firebase se convierten en mensajes de usuario mediante [firebase_error_message.dart](./lib/utils/firebase_error_message.dart).
- Las reglas de Firestore limitan acceso al propietario, comprueban campos permitidos y preservan la fecha de creación durante actualizaciones.
- Las reglas de Storage limitan los avatares por UID, tipo de contenido y tamaño.
- El borrado masivo de tareas usa lotes menores al límite de escrituras de Firestore.
- Los controladores de texto y estados de carga se manejan en el ciclo de vida de sus widgets.
- La app tiene tema persistente, colores de acento, navegación compartida y accesibilidad básica mediante tooltips y etiquetas semánticas.
- Las pruebas unitarias cubren modelo, filtros, calendario, temas, navegación, mensajes y permisos de notificación.

## 6. Verificaciones ejecutadas

| Verificación | Resultado |
|---|---|
| `flutter analyze` | Correcto, sin problemas reportados. |
| `flutter test` | Correcto: 19 pruebas pasaron. |
| `flutter build apk --debug` | Correcto; se generó `build/app/outputs/flutter-apk/app-debug.apk`. |
| `npm run test:rules` en `tests/firebase` | No ejecutado: Firebase CLI requiere JDK 21 o superior; el entorno tiene JDK 17. |
| Coincidencia entre `applicationId` y el cliente Firebase Android actual | Coinciden. Esto no sustituye la actualización del identificador antes de una publicación propia. |
| Build release firmado | No verificado; la configuración actual usa firma debug. |

## 7. Plan de acción recomendado

1. Definir el identificador final de la aplicación y registrarlo en Firebase.
2. Configurar y probar la firma release sin incluir el keystore ni contraseñas en el repositorio.
3. Ejecutar las pruebas de reglas Firestore y Storage en un entorno con JDK 21.
4. Añadir el lockfile de `tests/firebase` y documentar el JDK requerido para las pruebas.
5. Si se prevé crecimiento, cambiar la consulta completa del calendario por consultas por rango y paginación.
6. Probar registro, permisos, alarmas y notificaciones en dispositivos Android reales con permisos concedidos y denegados.
7. Configurar Firebase por separado antes de habilitar iOS, web o escritorio.

## 8. Conclusión

El proyecto está en buen estado para continuar el desarrollo y compartir un APK de depuración para pruebas. Las verificaciones Flutter pasan y el build debug se generó correctamente. No debe considerarse listo para una publicación de producción hasta usar firma release propia, definir un identificador de aplicación definitivo y verificar las reglas mediante el emulador Firebase.
