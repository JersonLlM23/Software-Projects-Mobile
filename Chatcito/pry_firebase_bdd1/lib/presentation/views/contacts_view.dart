import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/contacto.dart';
import '../../domain/models/usuario_app.dart';
import '../provider/contact_provider.dart';
import '../provider/user_provider.dart';
import '../provider/selected_user_provider.dart';
import '../provider/conversation_provider.dart';
import 'private_chat_view.dart';
import '../../themes/app_colors.dart';

class ContactsView extends ConsumerStatefulWidget {
  const ContactsView({super.key});

  @override
  ConsumerState<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends ConsumerState<ContactsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchFirebaseController = TextEditingController();
  final TextEditingController _searchLocalController = TextEditingController();

  String _searchFirebaseQuery = '';
  String _searchLocalQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Actualiza UI al cambiar de pestaña (ej. para ocultar/mostrar FAB)
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFirebaseController.dispose();
    _searchLocalController.dispose();
    super.dispose();
  }

  void _mostrarFormularioContacto({Contacto? contactoExistente}) {
    final isEditing = contactoExistente != null;
    final nombreController = TextEditingController(text: isEditing ? contactoExistente.nombre : '');
    final descripcionController = TextEditingController(text: isEditing ? contactoExistente.descripcion : '');
    String? errorNombre;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar contacto' : 'Nuevo contacto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreController,
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Nombre *',
                        hintText: 'Ej. Juan Pérez',
                        errorText: errorNombre,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      onChanged: (_) {
                        if (errorNombre != null) {
                          setDialogState(() {
                            errorNombre = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descripcionController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        hintText: 'Ej. Amigo de la universidad, Trabajo...',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final nombre = nombreController.text.trim();
                    if (nombre.isEmpty) {
                      setDialogState(() {
                        errorNombre = 'El nombre no puede estar vacío';
                      });
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    final errorColor = Theme.of(context).colorScheme.error;

                    Navigator.of(dialogContext).pop();

                    final nuevoContacto = Contacto(
                      id: isEditing ? contactoExistente.id : '',
                      nombre: nombre,
                      descripcion: descripcionController.text.trim(),
                    );

                    try {
                      await ref
                          .read(contactsProvider.notifier)
                          .guardarContacto(nuevoContacto);

                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditing
                                ? '✔ Contacto actualizado correctamente'
                                : '✔ Contacto agregado correctamente',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar el contacto: $e'),
                          backgroundColor: errorColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? 'Guardar' : 'Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmarEliminarContacto(Contacto contacto) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar contacto'),
          content: Text(
            '¿Deseas eliminar a "${contacto.nombre}" de tus contactos? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final errorColor = Theme.of(context).colorScheme.error;

      try {
        await ref
            .read(contactsProvider.notifier)
            .eliminarContacto(contacto.id);

        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✔ Contacto eliminado correctamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al eliminar el contacto: $e'),
            backgroundColor: errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onUsuarioFirebaseSeleccionado(UsuarioApp usuario) {
    // 1. Guardar usuario seleccionado en el provider
    ref.read(selectedUserProvider.notifier).selectUser(usuario);

    // 2. Obtener UID del usuario autenticado
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para abrir un chat privado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 3. Generar conversationId centralizado usando ConversationService
    final conversationService = ref.read(conversationServiceProvider);
    final conversationId = conversationService.generarConversationId(currentUid, usuario.uid);

    // 4. Navegar automáticamente a PrivateChatView
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateChatView(
          usuarioDestino: usuario,
          conversationId: conversationId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactos y Usuarios'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.people_alt_rounded),
              text: 'Usuarios Firebase',
            ),
            Tab(
              icon: Icon(Icons.contact_phone_rounded),
              text: 'Contactos Locales',
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _mostrarFormularioContacto(),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Nuevo contacto'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // PESTAÑA 1: Usuarios Registrados en Firebase
          _buildFirebaseUsersTab(theme, colorScheme),

          // PESTAÑA 2: Contactos Locales (SharedPreferences)
          _buildLocalContactsTab(theme, colorScheme),
        ],
      ),
    );
  }

  /// Construye la lista de usuarios registrados en Firebase
  Widget _buildFirebaseUsersTab(ThemeData theme, ColorScheme colorScheme) {
    final usuariosAsync = ref.watch(usuariosRegistradosStreamProvider);

    return Column(
      children: [
        // Búsqueda de usuarios Firebase
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchFirebaseController,
            onChanged: (value) {
              setState(() {
                _searchFirebaseQuery = value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o correo...',
              prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              suffixIcon: _searchFirebaseController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchFirebaseController.clear();
                        setState(() {
                          _searchFirebaseQuery = '';
                        });
                      },
                    )
                  : null,
              fillColor: colorScheme.surfaceContainerHigh,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            ),
          ),
        ),

        // Lista dinámica desde Firebase Realtime Database
        Expanded(
          child: usuariosAsync.when(
            data: (usuarios) {
              if (usuarios.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 72,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay otros usuarios registrados',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Los nuevos usuarios que se registren en la app aparecerán automáticamente aquí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Filtrar por término de búsqueda (nombre o correo)
              final filtrados = usuarios.where((u) {
                return u.nombre.toLowerCase().contains(_searchFirebaseQuery) ||
                    u.correo.toLowerCase().contains(_searchFirebaseQuery);
              }).toList();

              if (filtrados.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron usuarios',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Intenta buscar con otro nombre o correo.',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filtrados.length,
                separatorBuilder: (context, index) => Divider(
                  indent: 72,
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, index) {
                  final usuario = filtrados[index];
                  final initial = usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?';
                  final avatarColor = AppColors.getAvatarColor(usuario.nombre);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    onTap: () => _onUsuarioFirebaseSeleccionado(usuario),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: avatarColor,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    title: Text(
                      usuario.nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      usuario.correo,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Disponible',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error al cargar usuarios desde Firebase: $e',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Construye la lista de contactos locales guardados en SharedPreferences
  Widget _buildLocalContactsTab(ThemeData theme, ColorScheme colorScheme) {
    final contactsAsync = ref.watch(contactsProvider);

    return Column(
      children: [
        // Búsqueda de contactos locales
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchLocalController,
            onChanged: (value) {
              setState(() {
                _searchLocalQuery = value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar contacto local por nombre...',
              prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              suffixIcon: _searchLocalController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchLocalController.clear();
                        setState(() {
                          _searchLocalQuery = '';
                        });
                      },
                    )
                  : null,
              fillColor: colorScheme.surfaceContainerHigh,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            ),
          ),
        ),

        // Lista de contactos locales
        Expanded(
          child: contactsAsync.when(
            data: (contactos) {
              if (contactos.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.contacts_outlined,
                          size: 72,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tienes contactos locales aún',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Presiona el botón "+ Nuevo contacto" para agregar tu primer contacto.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Filtrar según término de búsqueda
              final filtrados = contactos.where((c) {
                return c.nombre.toLowerCase().contains(_searchLocalQuery) ||
                    c.descripcion.toLowerCase().contains(_searchLocalQuery);
              }).toList();

              if (filtrados.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron contactos',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Intenta buscar con otro nombre.',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filtrados.length,
                separatorBuilder: (context, index) => Divider(
                  indent: 72,
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, index) {
                  final contacto = filtrados[index];
                  final initial = contacto.nombre.isNotEmpty ? contacto.nombre[0].toUpperCase() : '?';
                  final avatarColor = AppColors.getAvatarColor(contacto.nombre);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: avatarColor,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    title: Text(
                      contacto.nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    subtitle: contacto.descripcion.isNotEmpty
                        ? Text(
                            contacto.descripcion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          color: colorScheme.primary,
                          onPressed: () => _mostrarFormularioContacto(contactoExistente: contacto),
                          tooltip: 'Editar',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: colorScheme.error,
                          onPressed: () => _confirmarEliminarContacto(contacto),
                          tooltip: 'Eliminar',
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error al cargar contactos locales: $e',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
