import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/chat_provider.dart';
import '../../domain/models/mensaje.dart';
import '../../data/services/notification_service.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/chat_input.dart';
import '../../themes/app_styles.dart';

class ChatView extends ConsumerStatefulWidget {
  final String usuario;

  const ChatView({
    super.key,
    required this.usuario,
  });

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Register current user so NotificationService can filter out self-notifications.
    NotificationService.setCurrentUser(widget.usuario);
  }

  @override
  void dispose() {
    controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final isNearBottom = (maxScroll - currentScroll) < 120;

    if (force || isNearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  void _handleSend(dynamic service) {
    if (controller.text.trim().isEmpty) return;

    service.enviarMensaje(
      Mensaje(
        texto: controller.text.trim(),
        autor: widget.usuario,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    controller.clear();
    _scrollToBottom(force: true);
  }

  Future<void> _confirmarLimpiarChat(dynamic service) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Limpiar chat'),
          content: const Text(
            '¿Deseas eliminar todos los mensajes del chat? Esta acción no se puede deshacer.',
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
      try {
        await service.limpiarChat();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✔ Chat eliminado correctamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No fue posible eliminar el chat: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mensajesAsync = ref.watch(mensajesProvider);
    final service = ref.read(firebaseServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Trigger auto-scroll on new messages if near bottom
    mensajesAsync.whenData((mensajes) {
      if (mensajes.length != _previousMessageCount) {
        final isInitialLoad = _previousMessageCount == 0;
        _previousMessageCount = mensajes.length;
        _scrollToBottom(force: isInitialLoad);
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.groups_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chat en Tiempo Real',
                    style: AppStyles.appBarTitle.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'En línea',
                    style: AppStyles.appBarSubtitle.copyWith(
                      color: const Color(0xFF22C55E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface),
            onSelected: (value) {
              if (value == 'limpiar') {
                _confirmarLimpiarChat(service);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'limpiar',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Limpiar chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // MENSAJES
          Expanded(
            child: mensajesAsync.when(
              data: (mensajes) {
                if (mensajes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No hay mensajes aún.\n¡Sé el primero en escribir!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  itemCount: mensajes.length,
                  itemBuilder: (_, i) {
                    final m = mensajes[i];
                    final esMio = m.autor == widget.usuario;

                    return MessageBubble(
                      key: ValueKey('${m.key ?? m.timestamp}_$i'),
                      mensaje: m,
                      esMio: esMio,
                      onLongPress: () => _mostrarOpcionesMensaje(m, esMio, service),
                      onReactTap: (emoji) {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null && m.key != null) {
                          _reaccionar(service, m.key!, uid, emoji);
                        }
                      },
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: colorScheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error al cargar mensajes: $e',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // INPUT DE MENSAJE
          ChatInput(
            controller: controller,
            onSend: () => _handleSend(service),
          ),
        ],
      ),
    );
  }

  void _mostrarOpcionesMensaje(Mensaje m, bool esMio, dynamic service) {
    if (m.key == null || m.key!.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    const allowedEmojis = ['👍', '❤️', '😂', '😮', '😬', '👺'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selector Horizontal de Reacciones
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: allowedEmojis.map((emoji) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        _reaccionar(service, m.key!, uid, emoji);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (esMio) ...[
                  const Divider(height: 24),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                    title: const Text('Editar mensaje'),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _mostrarDialogoEditar(service, m);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    title: const Text('Eliminar mensaje'),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _confirmarEliminarMensaje(service, m.key!);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _reaccionar(dynamic service, String mensajeKey, String uid, String emoji) {
    service.agregarOActualizarReaccion(
      mensajeKey: mensajeKey,
      uid: uid,
      emoji: emoji,
    );
  }

  void _mostrarDialogoEditar(dynamic service, Mensaje m) {
    final editController = TextEditingController(text: m.texto);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar mensaje'),
          content: TextField(
            controller: editController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Escribe el nuevo texto...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final nuevoTexto = editController.text.trim();
                if (nuevoTexto.isNotEmpty && m.key != null) {
                  service.editarMensaje(
                    mensajeKey: m.key!,
                    nuevoTexto: nuevoTexto,
                  );
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmarEliminarMensaje(dynamic service, String mensajeKey) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar mensaje'),
          content: const Text('¿Deseas eliminar este mensaje?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                service.eliminarMensaje(mensajeKey: mensajeKey);
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
