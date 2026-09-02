class Mensaje {
  final String? key;
  final String texto;
  final String autor;
  final String? autorUid;
  final int timestamp;
  final bool editado;
  final Map<String, String>? reacciones;

  Mensaje({
    this.key,
    required this.texto,
    required this.autor,
    this.autorUid,
    required this.timestamp,
    this.editado = false,
    this.reacciones,
  });

  factory Mensaje.fromJson(Map<dynamic, dynamic> json, {String? key}) {
    Map<String, String>? reaccs;
    if (json['reacciones'] != null && json['reacciones'] is Map) {
      reaccs = (json['reacciones'] as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }

    return Mensaje(
      key: key ?? json['key'] as String?,
      texto: json['texto'] as String? ?? '',
      autor: json['autor'] as String? ?? '',
      autorUid: json['autorUid'] as String?,
      timestamp: json['timestamp'] as int? ?? 0,
      editado: json['editado'] as bool? ?? false,
      reacciones: reaccs,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'texto': texto,
      'autor': autor,
      'timestamp': timestamp,
      'editado': editado,
    };
    if (autorUid != null) {
      map['autorUid'] = autorUid;
    }
    if (reacciones != null && reacciones!.isNotEmpty) {
      map['reacciones'] = reacciones;
    }
    return map;
  }

  Mensaje copyWith({
    String? key,
    String? texto,
    String? autor,
    String? autorUid,
    int? timestamp,
    bool? editado,
    Map<String, String>? reacciones,
  }) {
    return Mensaje(
      key: key ?? this.key,
      texto: texto ?? this.texto,
      autor: autor ?? this.autor,
      autorUid: autorUid ?? this.autorUid,
      timestamp: timestamp ?? this.timestamp,
      editado: editado ?? this.editado,
      reacciones: reacciones ?? this.reacciones,
    );
  }
}
