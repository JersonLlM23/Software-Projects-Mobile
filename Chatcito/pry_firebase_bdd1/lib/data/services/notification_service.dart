import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../domain/models/mensaje.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
// Integra Firebase Cloud Messaging (FCM) para notificaciones push reales y
// mantiene el listener de notificaciones locales del chat general.
// ─────────────────────────────────────────────────────────────────────────────

/// Handler de mensajes FCM en background/terminated (top-level, fuera de clase)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Las notificaciones en background son manejadas automáticamente por FCM.
  // Si se necesita lógica adicional en background se puede agregar aquí.
}

class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  // ─── Internal references ───────────────────────────────────────────────────
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  final DatabaseReference _messagesRef =
      FirebaseDatabase.instance.ref('chats/general');

  /// Stores current logged-in user's name to avoid self-notifications.
  String _currentUser = '';

  /// Timestamp recorded when service initializes to ignore historical messages.
  int _initTimestamp = 0;

  /// Ensures onChildAdded listener is registered ONLY ONCE per app execution.
  bool _isListening = false;
  StreamSubscription<DatabaseEvent>? _subscription;

  /// Callback invocado cuando el usuario toca una notificación push
  /// Entrega el conversationId para navegar a PrivateChatView.
  static void Function(String conversationId)? onNotificationTap;

  /// The Android notification channel used for all chat messages.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chatcito_messages',
    'Mensajes de Chatcito',
    description: 'Notificaciones de nuevos mensajes en Chatcito',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// The Android notification channel used for private chat messages.
  static const AndroidNotificationChannel _privateChannel = AndroidNotificationChannel(
    'private_messages',
    'Mensajes privados',
    description: 'Notificaciones de mensajes privados',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Call once after Firebase.initializeApp() and before runApp().
  static Future<void> initialize() async {
    // Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await instance._setup();
  }

  /// Muestra una notificación local para un nuevo mensaje privado.
  static Future<void> showPrivateMessageNotification({
    required String conversationId,
    required String autor,
    required String mensaje,
  }) async {
    await instance._showPrivateLocalNotification(
      conversationId: conversationId,
      autor: autor,
      mensaje: mensaje,
    );
  }

  /// Register current user's name so the service can skip
  /// notifying when the sender is ourselves.
  static void setCurrentUser(String username) {
    instance._currentUser = username;
  }

  /// Obtiene y guarda el token FCM del usuario autenticado en Realtime Database.
  static Future<void> saveTokenForCurrentUser() async {
    await instance._saveFcmToken();
  }

  /// Stops listening for Realtime Database events and resets listener status.
  static Future<void> stopListening() async {
    await instance._subscription?.cancel();
    instance._subscription = null;
    instance._isListening = false;
  }

  // ─── Private setup ─────────────────────────────────────────────────────────

  Future<void> _setup() async {
    _initTimestamp = DateTime.now().millisecondsSinceEpoch;
    await _setupLocalNotifications();
    await _setupFCM();
    _listenDatabaseMessages();
  }

  Future<void> _setupLocalNotifications() async {
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(_channel);
      await androidImplementation.createNotificationChannel(_privateChannel);
      await androidImplementation.requestNotificationsPermission();
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Manejar toque en notificación local (foreground)
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );
  }

  Future<void> _setupFCM() async {
    // 1. Solicitar permisos
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Guardar token al iniciar
    await _saveFcmToken();

    // 3. Actualizar token si cambia
    _fcm.onTokenRefresh.listen((newToken) async {
      await _updateFcmToken(newToken);
    });

    // 4. Mensajes en Foreground → mostrar notificación local
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showFcmLocalNotification(message);
    });

    // 5. App abierta desde background al tocar notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationNavigation(message);
    });

    // 6. App terminada al tocar notificación (opened from terminated state)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      // Pequeña demora para que el navigator esté montado
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleNotificationNavigation(initialMessage);
      });
    }
  }

  Future<void> _saveFcmToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final token = await _fcm.getToken();
      if (token != null) {
        await _updateFcmToken(token);
      }
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[NotificationService] Error al obtener token FCM: $e');
        return true;
      }());
    }
  }

  Future<void> _updateFcmToken(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseDatabase.instance.ref('users/$uid/fcmToken').set(token);
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[NotificationService] Error al guardar token FCM: $e');
        return true;
      }());
    }
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    final conversationId = message.data['conversationId'];
    if (conversationId != null && conversationId.isNotEmpty) {
      onNotificationTap?.call(conversationId as String);
    }
  }

  /// Muestra una notificación local cuando el mensaje FCM llega en foreground.
  Future<void> _showFcmLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final conversationId = message.data['conversationId'] as String? ?? '';

    final androidDetails = AndroidNotificationDetails(
      'chatcito_messages',
      'Mensajes de Chatcito',
      channelDescription: 'Notificaciones de nuevos mensajes en Chatcito',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      notification?.title ?? '💬 Nuevo mensaje',
      notification?.body ?? '',
      notificationDetails,
      payload: conversationId,
    );
  }

  /// Listens for new messages in the general chat (chats/general).
  /// Guaranteed to execute registration only once.
  void _listenDatabaseMessages() {
    if (_isListening) return;
    _isListening = true;

    _subscription = _messagesRef.onChildAdded.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data == null) return;

      try {
        final Map<dynamic, dynamic> map =
            Map<dynamic, dynamic>.from(data as Map);
        final mensaje = Mensaje.fromJson(map);

        // 1. Ignore historical messages prior to service initialization
        if (mensaje.timestamp < _initTimestamp) return;

        // 2. Ignore messages sent by the logged-in user
        if (_currentUser.isNotEmpty && mensaje.autor == _currentUser) return;

        // 3. Display local notification for general chat
        _showLocalNotification(
          title: '🔔 Nuevo mensaje de ${mensaje.autor}',
          body: mensaje.texto,
        );
      } catch (e) {
        assert(() {
          // ignore: avoid_print
          print('[NotificationService] Error al procesar mensaje en notificación: $e');
          return true;
        }());
      }
    });
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chatcito_messages',
      'Mensajes de Chatcito',
      channelDescription: 'Notificaciones de nuevos mensajes en Chatcito',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> _showPrivateLocalNotification({
    required String conversationId,
    required String autor,
    required String mensaje,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'private_messages',
      'Mensajes privados',
      channelDescription: 'Notificaciones de mensajes privados',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '💬 Nuevo mensaje de $autor',
      mensaje,
      notificationDetails,
      payload: conversationId,
    );
  }
}
