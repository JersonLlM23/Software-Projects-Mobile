import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/mensaje.dart';
import '../../domain/models/usuario_app.dart';
import '../provider/auth_provider.dart';
import '../provider/conversation_provider.dart';
import '../provider/current_conversation_provider.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/chat_input.dart';
import '../../themes/app_colors.dart';

class PrivateChatView extends ConsumerStatefulWidget {
  final UsuarioApp usuarioDestino;
  final String conversationId;
  final String? miNombre;

  const PrivateChatView({
    super.key,
    required this.usuarioDestino,
    required this.conversationId,
    this.miNombre,
  });

  @override
  ConsumerState<PrivateChatView> createState() => _PrivateChatViewState();
}

class _PrivateChatViewState extends ConsumerState<PrivateChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _previousMessageCount = 0;
  String _nombreActual = '';

  @override
  void initState() {
    super.initState();
    _cargarNombreUsuarioActual();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(currentConversationProvider.notifier).setConversation(widget.conversationId);
      }
    });
  }

  Future<void> _cargarNombreUsuarioActual() async {
    if (widget.miNombre != null && widget.miNombre!.isNotEmpty) {
      setState(() {
        _nombreActual = widget.miNombre!;
      });
    } else {
      final authService = ref.read(authServiceProvider);
      final nombre = await authService.obtenerNombreUsuarioActual();
      if (mounted) {
        setState(() {
          _nombreActual = nombre ?? 'Yo';
        });
      }
    }
  }

  @override
  void dispose() {
    ref.read(currentConversationProvider.notifier).clearConversation();
    _controller.dispose();
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

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final mensaje = Mensaje(
      texto: text,
      autor: _nombreActual.isNotEmpty ? _nombreActual : 'Yo',
      autorUid: uid,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    ref.read(conversationServiceProvider).enviarMensajePrivado(
          conversationId: widget.conversationId,
          mensaje: mensaje,
        );

    _controller.clear();
    _scrollToBottom(force: true);
  }

  Future<void> _confirmarLimpiarChat() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Limpiar chat privado'),
          content: Text(
            '¿Deseas eliminar todos los mensajes de esta conversación con ${widget.usuarioDestino.nombre}?',
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
        await ref.read(conversationServiceProvider).limpiarConversacion(widget.conversationId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✔ Historial de chat eliminado'),
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
    final mensajesAsync = ref.watch(privateMensajesStreamProvider(widget.conversationId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final initial = widget.usuarioDestino.nombre.isNotEmpty
        ? widget.usuarioDestino.nombre[0].toUpperCase()
        : '?';
    final avatarColor = AppColors.getAvatarColor(widget.usuarioDestino.nombre);

    // Auto-scroll on message updates
    mensajesAsync.whenData((mensajes) {
      if (mensajes.length != _previousMessageCount) {
        final isInitialLoad = _previousMessageCount == 0;
        _previousMessageCount = mensajes.length;
        _scrollToBottom(force: isInitialLoad);
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarColor,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.usuarioDestino.nombre,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.usuarioDestino.correo,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
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
                _confirmarLimpiarChat();
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
          // Listado de mensajes
          Expanded(
            child: mensajesAsync.when(
              data: (mensajes) {
                if (mensajes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Inicia una conversación privada con\n${widget.usuarioDestino.nombre}',
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
                    final esMio = m.autor == _nombreActual;

                    return MessageBubble(
                      key: ValueKey('${m.key ?? m.timestamp}_$i'),
                      mensaje: m,
                      esMio: esMio,
                      onLongPress: () => _mostrarOpcionesMensaje(m, esMio),
                      onReactTap: (emoji) {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null && m.key != null) {
                          _reaccionar(m.key!, uid, emoji);
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
                  child: Text(
                    'Error al cargar la conversación: $e',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ),
            ),
          ),

          // Campo de entrada
          ChatInput(
            controller: _controller,
            onSend: _handleSend,
          ),
        ],
      ),
    );
  }

  void _mostrarOpcionesMensaje(Mensaje m, bool esMio) {
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
                        _reaccionar(m.key!, uid, emoji);
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
                      _mostrarDialogoEditar(m);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    title: const Text('Eliminar mensaje'),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _confirmarEliminarMensaje(m.key!);
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

  void _reaccionar(String mensajeKey, String uid, String emoji) {
    ref.read(conversationServiceProvider).agregarOActualizarReaccion(
          conversationId: widget.conversationId,
          mensajeKey: mensajeKey,
          uid: uid,
          emoji: emoji,
        );
  }

  void _mostrarDialogoEditar(Mensaje m) {
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
                  ref.read(conversationServiceProvider).editarMensaje(
                        conversationId: widget.conversationId,
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

  void _confirmarEliminarMensaje(String mensajeKey) {
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
                ref.read(conversationServiceProvider).eliminarMensaje(
                      conversationId: widget.conversationId,
                      mensajeKey: mensajeKey,
                    );
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
