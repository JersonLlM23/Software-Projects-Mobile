import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/user_service.dart';
import '../../domain/models/usuario_app.dart';

final userServiceProvider = Provider<UserService>(
  (ref) => UserService(),
);

final usuariosRegistradosStreamProvider = StreamProvider<List<UsuarioApp>>((ref) {
  final service = ref.watch(userServiceProvider);
  return service.obtenerUsuariosStream();
});
