import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/contact_service.dart';
import '../../domain/models/contacto.dart';

final contactServiceProvider = Provider<ContactService>(
  (ref) => ContactService(),
);

final contactsProvider =
    AsyncNotifierProvider<ContactsNotifier, List<Contacto>>(
  ContactsNotifier.new,
);

class ContactsNotifier extends AsyncNotifier<List<Contacto>> {
  @override
  Future<List<Contacto>> build() async {
    final service = ref.watch(contactServiceProvider);
    return service.obtenerContactos();
  }

  Future<void> guardarContacto(Contacto contacto) async {
    final service = ref.read(contactServiceProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await service.guardarContacto(contacto);
      return service.obtenerContactos();
    });
  }

  Future<void> eliminarContacto(String id) async {
    final service = ref.read(contactServiceProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await service.eliminarContacto(id);
      return service.obtenerContactos();
    });
  }
}
