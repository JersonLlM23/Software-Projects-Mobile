import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../../domain/models/mensaje.dart';
import 'notification_service.dart';

/// Servicio encargado de escuchar en tiempo real todas las conversaciones del usuario autenticado
/// en Realtime Database y emitir notificaciones locales cuando reciba nuevos mensajes privados.
class ConversationListenerService {
  static final ConversationListenerService _instance =
      ConversationListenerService._internal();
  factory ConversationListenerService() => _instance;
  ConversationListenerService._internal();

  static ConversationListenerService get instance => _instance;

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final List<StreamSubscription<DatabaseEvent>> _subscriptions = [];
  StreamSubscription<DatabaseEvent>? _conversationsSubscription;

  int _initTimestamp = 0;
  bool _isListening = false;
  String _currentUid = '';
  String _currentNombre = '';
  String? Function()? _getCurrentConversationId;

  /// Inicia la escucha activa de notificaciones de conversaciones privadas.
  static void iniciarEscucha({
    required String currentUid,
    String currentNombre = '',
    required String? Function() getCurrentConversationId,
  }) {
    instance._start(
      currentUid: currentUid,
      currentNombre: currentNombre,
      getCurrentConversationId: getCurrentConversationId,
    );
  }

  /// Detiene la escucha de conversaciones privadas y limpia las suscripciones.
  static Future<void> detenerEscucha() async {
    await instance._stop();
  }

  void _start({
    required String currentUid,
    required String currentNombre,
    required String? Function() getCurrentConversationId,
  }) {
    if (_isListening) {
      if (_currentUid == currentUid) return;
      _stop();
    }

    _isListening = true;
    _currentUid = currentUid;
    _currentNombre = currentNombre;
    _getCurrentConversationId = getCurrentConversationId;
    _initTimestamp = DateTime.now().millisecondsSinceEpoch;

    final conversationsRef = _db.ref('conversations');

    _conversationsSubscription =
        conversationsRef.onChildAdded.listen((event) {
      final conversationId = event.snapshot.key;
      if (conversationId == null) return;

      // Verificar si el usuario autenticado participa en esta conversación (uid1_uid2)
      if (_isUserParticipant(conversationId, _currentUid)) {
        _listenToConversation(conversationId);
      }
    });
  }

  bool _isUserParticipant(String conversationId, String uid) {
    if (uid.isEmpty) return false;
    final parts = conversationId.split('_');
    return parts.contains(uid);
  }

  void _listenToConversation(String conversationId) {
    final mensajesRef = _db.ref('conversations/$conversationId/mensajes');

    final sub = mensajesRef.onChildAdded.listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;

      try {
        final Map<dynamic, dynamic> map =
            Map<dynamic, dynamic>.from(data as Map);
        final mensaje = Mensaje.fromJson(map);

        // 1. Ignorar mensajes históricos anteriores al inicio del servicio
        if (mensaje.timestamp < _initTimestamp) return;

        // 2. Ignorar mensajes enviados por el propio usuario autenticado
        if (mensaje.autorUid == _currentUid ||
            (_currentNombre.isNotEmpty && mensaje.autor == _currentNombre)) {
          return;
        }

        // 3. Consultar conversación actualmente abierta
        final conversationActual = _getCurrentConversationId?.call();

        // 4. Si el usuario ya está dentro de esa conversación, NO notificar
        if (conversationActual == conversationId) return;

        // 5. Mostrar notificación local si no la tiene abierta
        NotificationService.showPrivateMessageNotification(
          conversationId: conversationId,
          autor: mensaje.autor,
          mensaje: mensaje.texto,
        );
      } catch (e) {
        assert(() {
          // ignore: avoid_print
          print('[ConversationListenerService] Error al procesar mensaje: $e');
          return true;
        }());
      }
    });

    _subscriptions.add(sub);
  }

  Future<void> _stop() async {
    await _conversationsSubscription?.cancel();
    _conversationsSubscription = null;

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _isListening = false;
    _currentUid = '';
    _currentNombre = '';
    _getCurrentConversationId = null;
  }
}
