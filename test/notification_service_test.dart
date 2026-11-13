import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // El gateway falso permite verificar permisos y programación sin plugins.
  late _FakeNotificationGateway gateway;
  late NotificationService service;
  final now = DateTime(2026, 11, 9, 12);

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Etc/UTC'));
  });

  setUp(() {
    gateway = _FakeNotificationGateway();
    service = NotificationService(gateway: gateway, clock: () => now);
  });

  /// Un aviso vencido no debe pedir permisos ni llegar al sistema operativo.
  test('does not request permissions or schedule past reminders', () async {
    final result = await service.programarNotificacion(
      id: 1,
      titulo: 'Vencida',
      cuerpo: 'No debe avisar',
      fechaProgramada: now,
    );

    expect(result, isFalse);
    expect(gateway.permissionRequests, 0);
    expect(gateway.scheduledIds, isEmpty);
  });

  /// Sin permiso de avisos el servicio informa que no pudo programar.
  test('does not schedule when notification permission is denied', () async {
    gateway.notificationsGranted = false;

    final result = await service.programarNotificacion(
      id: 2,
      titulo: 'Tarea',
      cuerpo: 'Recordatorio',
      fechaProgramada: now.add(const Duration(hours: 1)),
    );

    expect(result, isFalse);
    expect(gateway.scheduledIds, isEmpty);
  });

  test(
    // Android solicita permiso de alarma exacta antes de programar.
    'requests exact-alarm permission and schedules future reminders',
    () async {
      gateway.canScheduleExactly = false;
      gateway.exactAlarmsGranted = true;

      final result = await service.programarNotificacion(
        id: 3,
        titulo: 'Tarea',
        cuerpo: 'Recordatorio',
        fechaProgramada: now.add(const Duration(hours: 1)),
      );

      expect(result, isTrue);
      expect(gateway.exactAlarmRequests, 1);
      expect(gateway.scheduledIds, [3]);
    },
  );

  /// Rechazar alarmas exactas impide crear un aviso que podría no ser preciso.
  test('does not schedule when exact-alarm permission is denied', () async {
    gateway.canScheduleExactly = false;
    gateway.exactAlarmsGranted = false;

    final result = await service.programarNotificacion(
      id: 4,
      titulo: 'Tarea',
      cuerpo: 'Recordatorio',
      fechaProgramada: now.add(const Duration(hours: 1)),
    );

    expect(result, isFalse);
    expect(gateway.scheduledIds, isEmpty);
  });
}

/// Simula respuestas de plataforma y registra los avisos solicitados.
class _FakeNotificationGateway implements NotificationGateway {
  bool notificationsGranted = true;
  bool canScheduleExactly = true;
  bool exactAlarmsGranted = true;
  int permissionRequests = 0;
  int exactAlarmRequests = 0;
  final List<int> scheduledIds = [];

  @override
  Future<bool> requestNotificationsPermission() async {
    permissionRequests++;
    return notificationsGranted;
  }

  @override
  Future<bool> canScheduleExactNotifications() async => canScheduleExactly;

  @override
  Future<bool> requestExactAlarmsPermission() async {
    exactAlarmRequests++;
    return exactAlarmsGranted;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime date,
  }) async {
    scheduledIds.add(id);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}
