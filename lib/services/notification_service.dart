import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Contrato que desacopla la lógica de recordatorios del plugin de plataforma.
abstract interface class NotificationGateway {
  /// Prepara el plugin nativo antes de usar cualquiera de sus operaciones.
  Future<void> initialize();

  /// Devuelve si se concedió permiso para mostrar notificaciones.
  Future<bool> requestNotificationsPermission();

  /// Indica si el sistema permite alarmas de ejecución exacta.
  Future<bool> canScheduleExactNotifications();

  /// Solicita al usuario acceso a alarmas exactas cuando el sistema lo exige.
  Future<bool> requestExactAlarmsPermission();

  /// Programa una notificación en la fecha local ya convertida.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime date,
  });

  /// Quita el aviso identificado sin afectar los demás recordatorios.
  Future<void> cancel(int id);

  /// Quita todos los avisos locales asociados a la aplicación.
  Future<void> cancelAll();
}

/// Implementación del contrato mediante flutter_local_notifications.
class PluginNotificationGateway implements NotificationGateway {
  PluginNotificationGateway(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  /// Configura los canales y ajustes nativos iniciales del plugin.
  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
  }

  @override
  /// Solicita permiso de avisos según el sistema operativo actual.
  Future<bool> requestNotificationsPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final implementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await implementation?.requestNotificationsPermission() ?? true;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final implementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await implementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final implementation = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      return await implementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
    }
    return true;
  }

  @override
  /// Comprueba si Android permite programar alarmas exactas.
  Future<bool> canScheduleExactNotifications() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final implementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await implementation?.canScheduleExactNotifications() ?? false;
  }

  @override
  /// Abre la solicitud de permiso para alarmas exactas en Android.
  Future<bool> requestExactAlarmsPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final implementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await implementation?.requestExactAlarmsPermission() ?? false;
  }

  @override
  /// Programa una notificación en la zona horaria local del dispositivo.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime date,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: date,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'taskflow_reminders',
          'Recordatorios de Tareas',
          channelDescription: 'Recordatorios de tareas pendientes',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  /// Cancela un aviso usando el identificador asociado con una tarea.
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  /// Cancela todos los recordatorios locales de la aplicación.
  Future<void> cancelAll() => _plugin.cancelAll();
}

/// Programa recordatorios locales con IDs estables entre ejecuciones.
class NotificationService {
  /// Acepta un reloj inyectable para probar vencimientos sin depender del tiempo real.
  NotificationService({required this.gateway, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static final NotificationService instance = NotificationService(
    gateway: PluginNotificationGateway(FlutterLocalNotificationsPlugin()),
  );

  final NotificationGateway gateway;
  final DateTime Function() _clock;

  /// Carga las zonas horarias, selecciona la del equipo y prepara el plugin.
  Future<void> init() async {
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    await gateway.initialize();
  }

  /// Genera un ID positivo y determinista de Android a partir de una tarea.
  static int notificationIdForTask(String taskId) {
    var hash = 0x811c9dc5;
    for (final unit in taskId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  /// Solicita permisos de notificación y alarmas exactas antes de programar.
  Future<bool> requestPermissions() async {
    if (!await gateway.requestNotificationsPermission()) return false;
    if (!await gateway.canScheduleExactNotifications()) {
      return gateway.requestExactAlarmsPermission();
    }
    return true;
  }

  /// Programa el recordatorio; devuelve false si venció o falta permiso.
  Future<bool> programarNotificacion({
    required int id,
    required String titulo,
    required String cuerpo,
    required DateTime fechaProgramada,
  }) async {
    if (!fechaProgramada.isAfter(_clock())) return false;
    if (!await requestPermissions()) return false;

    await gateway.schedule(
      id: id,
      title: titulo,
      body: cuerpo,
      date: tz.TZDateTime.from(fechaProgramada, tz.local),
    );
    return true;
  }

  /// Cancela el recordatorio que corresponde a una tarea.
  Future<void> cancelarNotificacion({required int id}) => gateway.cancel(id);

  /// Cancela todos los recordatorios, por ejemplo, al vaciar la cuenta.
  Future<void> cancelarTodas() => gateway.cancelAll();
}
