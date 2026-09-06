import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Servicio singleton responsable de gestionar las notificaciones locales con flutter_local_notifications.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'timeleft_notifications';
  static const String channelName = 'TimeLeft Notificaciones';
  static const String channelDescription =
      'Canal para notificaciones y recordatorios de TimeLeft';
  static const String soundResourceName = 'reloj';

  bool _isInitialized = false;

  /// Inicializa la configuración de notificaciones y la base de datos de zonas horarias.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Inicializar Timezone
      tz.initializeTimeZones();
      _configureLocalTimeZone();

      // Configuración para Android
      const androidInitSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const initSettings = InitializationSettings(
        android: androidInitSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notificación interactuada: ${response.payload}');
        },
      );

      // Crear NotificationChannel de Android con el sonido nativo 'reloj'
      await _createAndroidNotificationChannel();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error en NotificationService.init: $e');
    }
  }

  /// Configura tz.local basado en el offset real del dispositivo para evitar asumir UTC.
  void _configureLocalTimeZone() {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final timeZoneName = now.timeZoneName;

      // Intentar coincidir por nombre de zona
      if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        return;
      }

      // Buscar una ubicación que coincida con el offset horario local
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == offset) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error al configurar zona horaria local: $e');
    }
  }

  /// Crea el canal de notificación nativo para Android.
  Future<void> _createAndroidNotificationChannel() async {
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        const channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound(soundResourceName),
        );

        await androidPlugin.createNotificationChannel(channel);
      }
    } catch (e) {
      debugPrint('Error al crear canal de notificaciones Android: $e');
    }
  }

  /// Solicita los permisos necesarios en Android (POST_NOTIFICATIONS y alarmas exactas).
  Future<bool> requestPermissions() async {
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final bool? notificationsGranted =
            await androidPlugin.requestNotificationsPermission();
        final bool? exactAlarmsGranted =
            await androidPlugin.requestExactAlarmsPermission();

        return (notificationsGranted ?? false) || (exactAlarmsGranted ?? false);
      }
    } catch (e) {
      debugPrint('Error al solicitar permisos: $e');
    }
    return true;
  }

  /// Programa una notificación para una fecha y hora local exacta.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      // Convertir DateTime a TZDateTime usando la zona horaria local configurada
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      final nowTz = tz.TZDateTime.now(tz.local);

      // Evitar programar si la fecha/hora ya transcurrió
      if (tzScheduledDate.isBefore(nowTz) ||
          tzScheduledDate.isAtSameMomentAs(nowTz)) {
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound(soundResourceName),
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Error al programar notificación (id: $id): $e');
    }
  }

  /// Cancela una notificación individual por su ID.
  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('Error al cancelar notificación (id: $id): $e');
    }
  }

  /// Cancela todas las notificaciones pendientes de la aplicación.
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error al cancelar todas las notificaciones: $e');
    }
  }

  /// Obtiene la lista de notificaciones pendientes actualmente programadas.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Error al obtener notificaciones pendientes: $e');
      return [];
    }
  }
}
