import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/contacto.dart';

class ContactService {
  static const String _key = 'local_contacts_v1';

  /// Obtiene todos los contactos guardados localmente en SharedPreferences,
  /// ordenados alfabéticamente por nombre.
  Future<List<Contacto>> obtenerContactos() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
      final contactos = list
          .map((item) => Contacto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      contactos.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );

      return contactos;
    } catch (e) {
      return [];
    }
  }

  /// Inserta un nuevo contacto o actualiza uno existente según su `id`.
  /// Si el `id` viene vacío, le asigna uno único automáticamente.
  Future<void> guardarContacto(Contacto contacto) async {
    final contactos = await obtenerContactos();

    final String id = contacto.id.isNotEmpty
        ? contacto.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    final contactoFinal = contacto.copyWith(id: id);

    final index = contactos.indexWhere((c) => c.id == id);
    if (index >= 0) {
      contactos[index] = contactoFinal;
    } else {
      contactos.add(contactoFinal);
    }

    contactos.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );

    await _guardarLista(contactos);
  }

  /// Elimina un contacto de SharedPreferences según su `id`.
  Future<void> eliminarContacto(String id) async {
    final contactos = await obtenerContactos();
    contactos.removeWhere((c) => c.id == id);
    await _guardarLista(contactos);
  }

  Future<void> _guardarLista(List<Contacto> contactos) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(contactos.map((c) => c.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}
