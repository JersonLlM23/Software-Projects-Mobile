import 'package:firebase_database/firebase_database.dart';
import '../../domain/models/mensaje.dart';

class FirebaseService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref('chats/general');

  // Enviar mensaje
  Future<void> enviarMensaje(Mensaje mensaje) async {
    await _ref.push().set(mensaje.toJson());
  }

  // Stream de mensajes en tiempo real
  Stream<List<Mensaje>> recibirMensajes() {
    return _ref.onValue.map((event) {
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

  /// Registra o actualiza una reacción para un mensaje en el chat general.
  /// Si ya tenía exactamente la misma reacción, la remueve.
  Future<void> agregarOActualizarReaccion({
    required String mensajeKey,
    required String uid,
    required String emoji,
  }) async {
    final ref = _ref.child('$mensajeKey/reacciones/$uid');
    final snapshot = await ref.get();
    if (snapshot.exists && snapshot.value == emoji) {
      await ref.remove();
    } else {
      await ref.set(emoji);
    }
  }

  /// Edita el texto de un mensaje enviado por el propio usuario y establece editado = true.
  Future<void> editarMensaje({
    required String mensajeKey,
    required String nuevoTexto,
  }) async {
    final ref = _ref.child(mensajeKey);
    await ref.update({
      'texto': nuevoTexto,
      'editado': true,
    });
  }

  /// Elimina físicamente el nodo correspondiente al mensaje en chat general.
  Future<void> eliminarMensaje({
    required String mensajeKey,
  }) async {
    await _ref.child(mensajeKey).remove();
  }

  // Limpiar todos los mensajes del chat
  Future<void> limpiarChat() async {
    await _ref.remove();
  }
}
