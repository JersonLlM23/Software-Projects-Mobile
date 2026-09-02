import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/conversation_service.dart';
import '../../domain/models/mensaje.dart';

final conversationServiceProvider = Provider<ConversationService>(
  (ref) => ConversationService(),
);

final privateMensajesStreamProvider = StreamProvider.family<List<Mensaje>, String>((ref, conversationId) {
  final service = ref.watch(conversationServiceProvider);
  return service.obtenerMensajesPrivadosStream(conversationId);
});
