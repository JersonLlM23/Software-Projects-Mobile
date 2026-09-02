class UsuarioApp {
  final String uid;
  final String nombre;
  final String correo;
  final String? fcmToken;

  const UsuarioApp({
    required this.uid,
    required this.nombre,
    required this.correo,
    this.fcmToken,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'nombre': nombre,
      'correo': correo,
    };
    if (fcmToken != null) {
      map['fcmToken'] = fcmToken;
    }
    return map;
  }

  factory UsuarioApp.fromMap(Map<String, dynamic> map, String uid) {
    return UsuarioApp(
      uid: uid,
      nombre: map['nombre'] as String? ?? '',
      correo: map['correo'] as String? ?? '',
      fcmToken: map['fcmToken'] as String?,
    );
  }
}
