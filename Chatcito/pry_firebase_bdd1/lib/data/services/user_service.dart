import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../domain/models/usuario_app.dart';

class UserService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Retorna un Stream con la lista de usuarios registrados en `users/`,
  /// excluyendo automáticamente al usuario actualmente autenticado.
  Stream<List<UsuarioApp>> obtenerUsuariosStream() {
    return _db.ref('users').onValue.map((event) {
      final currentUid = _auth.currentUser?.uid;
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) return [];

      final List<UsuarioApp> usuarios = [];
      data.forEach((key, value) {
        final uid = key.toString();
        if (uid != currentUid && value is Map) {
          final map = Map<String, dynamic>.from(value);
          usuarios.add(UsuarioApp.fromMap(map, uid));
        }
      });

      // Ordenar alfabéticamente por nombre
      usuarios.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return usuarios;
    });
  }

  /// Consulta la lista de usuarios una sola vez (Future), excluyendo al usuario actual.
  Future<List<UsuarioApp>> obtenerUsuarios() async {
    final currentUid = _auth.currentUser?.uid;
    final snapshot = await _db.ref('users').get();
    if (!snapshot.exists || snapshot.value == null) return [];

    final data = snapshot.value as Map<dynamic, dynamic>;
    final List<UsuarioApp> usuarios = [];
    data.forEach((key, value) {
      final uid = key.toString();
      if (uid != currentUid && value is Map) {
        final map = Map<String, dynamic>.from(value);
        usuarios.add(UsuarioApp.fromMap(map, uid));
      }
    });

    usuarios.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return usuarios;
  }

  /// Devuelve la información del usuario autenticado actualmente desde Realtime Database.
  Future<UsuarioApp?> obtenerUsuarioActual() async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return null;

    final snapshot = await _db.ref('users/$currentUid').get();
    if (snapshot.exists && snapshot.value is Map) {
      final map = Map<String, dynamic>.from(snapshot.value as Map);
      return UsuarioApp.fromMap(map, currentUid);
    }

    return null;
  }
}
