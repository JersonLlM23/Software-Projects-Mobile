import 'package:firebase_database/firebase_database.dart';
import '../../domain/models/mensaje.dart';

class ConversationService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Genera un ID de conversación único y determinista ordenando alfabéticamente los UIDs.
  String generarConversationId(String uid1, String uid2) {
    if (uid1.compareTo(uid2) < 0) {
      return '${uid1}_$uid2';
    } else {
      return '${uid2}_$uid1';
    }
  }

  /// Envía un mensaje privado al nodo conversations/conversationId/mensajes
  Future<void> enviarMensajePrivado({
    required String conversationId,
    required Mensaje mensaje,
  }) async {
    final ref = _db.ref('conversations/$conversationId/mensajes');
    await ref.push().set(mensaje.toJson());
  }

  /// Stream en tiempo real de los mensajes de una conversación privada ordenados por timestamp
  Stream<List<Mensaje>> obtenerMensajesPrivadosStream(String conversationId) {
    final ref = _db.ref('conversations/$conversationId/mensajes');
    return ref.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) return [];

      final mensajes = data.entries.map((entry) {
        final map = Map<dynamic, dynamic>.from(entry.value as Map);
        return Mensaje.fromJson(map, key: entry.key as String);
      }).toList();

      mensajes.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return mensajes;
    });
  }

  /// Registra o actualiza una reacción para un mensaje privado.
  /// Si ya tenía exactamente la misma reacción, la remueve.
  Future<void> agregarOActualizarReaccion({
    required String conversationId,
    required String mensajeKey,
    required String uid,
    required String emoji,
  }) async {
    final ref = _db
        .ref('conversations/$conversationId/mensajes/$mensajeKey/reacciones/$uid');
    final snapshot = await ref.get();
    if (snapshot.exists && snapshot.value == emoji) {
      await ref.remove();
    } else {
      await ref.set(emoji);
    }
  }

  /// Edita el texto de un mensaje enviado por el propio usuario y establece editado = true.
  Future<void> editarMensaje({
    required String conversationId,
    required String mensajeKey,
    required String nuevoTexto,
  }) async {
    final ref = _db.ref('conversations/$conversationId/mensajes/$mensajeKey');
    await ref.update({
      'texto': nuevoTexto,
      'editado': true,
    });
  }

  /// Elimina físicamente el nodo correspondiente al mensaje.
  Future<void> eliminarMensaje({
    required String conversationId,
    required String mensajeKey,
  }) async {
    await _db.ref('conversations/$conversationId/mensajes/$mensajeKey').remove();
  }

  /// Limpia los mensajes del historial de una conversación privada
  Future<void> limpiarConversacion(String conversationId) async {
    await _db.ref('conversations/$conversationId/mensajes').remove();
  }
}
