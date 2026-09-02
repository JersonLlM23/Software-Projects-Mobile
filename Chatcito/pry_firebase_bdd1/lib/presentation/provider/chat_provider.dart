import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/firebase_service.dart';
import '../../domain/models/mensaje.dart';

final firebaseServiceProvider = Provider<FirebaseService>(
  (ref) => FirebaseService(),
);

final mensajesProvider = StreamProvider<List<Mensaje>>((ref) {
  final service = ref.read(firebaseServiceProvider);
  return service.recibirMensajes();
});
