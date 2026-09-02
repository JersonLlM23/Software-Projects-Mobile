import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/usuario_app.dart';

class SelectedUserNotifier extends Notifier<UsuarioApp?> {
  @override
  UsuarioApp? build() => null;

  void selectUser(UsuarioApp? usuario) {
    state = usuario;
  }
}

final selectedUserProvider = NotifierProvider<SelectedUserNotifier, UsuarioApp?>(
  SelectedUserNotifier.new,
);
