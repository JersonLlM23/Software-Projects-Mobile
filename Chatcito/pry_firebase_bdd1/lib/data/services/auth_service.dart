import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Registra un nuevo usuario en Firebase Auth y guarda su perfil en Realtime Database (users/UID).
  Future<String> registrarse({
    required String nombre,
    required String correo,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw Exception('No se pudo obtener el ID del usuario creado.');
      }

      // Guardar perfil en Realtime Database: users/UID
      final userRef = _db.ref('users/$uid');
      await userRef.set({
        'nombre': nombre.trim(),
        'correo': correo.trim(),
      });

      return nombre.trim();
    } on FirebaseAuthException catch (e) {
      throw _mapearErrorAuth(e);
    } catch (e) {
      throw Exception('Ocurrió un error inesperado al registrarse: ${e.toString()}');
    }
  }

  /// Inicia sesión en Firebase Auth y recupera el nombre del usuario desde Realtime Database.
  Future<String> iniciarSesion({
    required String correo,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw Exception('No se pudo obtener el usuario autenticado.');
      }

      // Obtener el nombre registrado desde Realtime Database
      final nombre = await obtenerNombrePorUid(uid);
      return nombre.isNotEmpty ? nombre : (credential.user?.email?.split('@').first ?? 'Usuario');
    } on FirebaseAuthException catch (e) {
      throw _mapearErrorAuth(e);
    } catch (e) {
      throw Exception('Ocurrió un error inesperado al iniciar sesión: ${e.toString()}');
    }
  }

  /// Recupera el nombre guardado en Realtime Database para un UID dado.
  Future<String> obtenerNombrePorUid(String uid) async {
    try {
      final snapshot = await _db.ref('users/$uid/nombre').get();
      if (snapshot.exists && snapshot.value != null) {
        return snapshot.value.toString();
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// Obtener el nombre del usuario actualmente autenticado (si existe sesión activa)
  Future<String?> obtenerNombreUsuarioActual() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final nombre = await obtenerNombrePorUid(uid);
    if (nombre.isNotEmpty) return nombre;
    return _auth.currentUser?.displayName ?? _auth.currentUser?.email?.split('@').first;
  }

  /// Cierra la sesión en Firebase Auth
  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }

  /// Mapea los códigos de error de FirebaseAuthException a mensajes amigables en español.
  String _mapearErrorAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'user-not-found':
        return 'No existe ningún usuario registrado con este correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Contraseña incorrecta o credenciales inválidas.';
      case 'email-already-in-use':
        return 'Este correo electrónico ya se encuentra registrado.';
      case 'weak-password':
        return 'La contraseña es muy débil. Debe tener al menos 6 caracteres.';
      case 'network-request-failed':
        return 'Error de red. Por favor revisa tu conexión a internet.';
      default:
        return e.message ?? 'Ocurrió un error de autenticación.';
    }
  }
}
