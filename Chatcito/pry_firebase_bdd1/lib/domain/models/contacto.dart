class Contacto {
  final String id;
  final String nombre;
  final String descripcion;

  Contacto({
    required this.id,
    required this.nombre,
    this.descripcion = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
    };
  }

  factory Contacto.fromJson(Map<String, dynamic> json) {
    return Contacto(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
    );
  }

  Contacto copyWith({
    String? id,
    String? nombre,
    String? descripcion,
  }) {
    return Contacto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
    );
  }
}
