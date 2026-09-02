import 'package:flutter/material.dart';
import '../domain/models/mensaje.dart';
import '../themes/app_colors.dart';
import '../themes/app_styles.dart';

class MessageBubble extends StatelessWidget {
  final Mensaje mensaje;
  final bool esMio;
  final String? avatarUrl;
  final String? displayName;
  final VoidCallback? onLongPress;
  final void Function(String emoji)? onReactTap;

  const MessageBubble({
    super.key,
    required this.mensaje,
    required this.esMio,
    this.avatarUrl,
    this.displayName,
    this.onLongPress,
    this.onReactTap,
  });

  String _formatTimestamp(int timestamp) {
    if (timestamp <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(messageDay).inDays;

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (diffDays == 0) {
      return '$hour:$minute';
    } else if (diffDays == 1) {
      return 'Ayer';
    } else {
      const meses = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      final mes = meses[date.month - 1];
      if (date.year == now.year) {
        return '${date.day} $mes';
      } else {
        return '${date.day} $mes ${date.year}';
      }
    }
  }

  String _getInitial(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return '?';
    return cleanName[0].toUpperCase();
  }

  Map<String, int> _getReactionCounts() {
    final Map<String, int> counts = {};
    if (mensaje.reacciones != null) {
      for (final emoji in mensaje.reacciones!.values) {
        counts[emoji] = (counts[emoji] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final authorName = displayName ?? (mensaje.autor.isNotEmpty ? mensaje.autor : 'Usuario');
    final formattedTime = _formatTimestamp(mensaje.timestamp);

    final bubbleColor = esMio
        ? colorScheme.primary
        : colorScheme.surfaceContainerHigh;

    final textColor = esMio
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    final subtitleColor = esMio
        ? colorScheme.onPrimary.withValues(alpha: 0.75)
        : colorScheme.onSurfaceVariant;

    final avatarBg = esMio
        ? colorScheme.primaryContainer
        : AppColors.getAvatarColor(authorName);

    final avatarTextColor = esMio
        ? colorScheme.onPrimaryContainer
        : Colors.white;

    final reactionCounts = _getReactionCounts();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Received Avatar (Left side)
          if (!esMio) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: avatarBg,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? Text(
                      _getInitial(authorName),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: avatarTextColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],

          // Message Container Box
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Column(
                crossAxisAlignment:
                    esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(esMio ? 20 : 4),
                        bottomRight: Radius.circular(esMio ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment:
                          esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Author Name
                        if (!esMio)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              authorName,
                              style: AppStyles.messageAuthor.copyWith(
                                color: AppColors.getAvatarColor(authorName),
                              ),
                            ),
                          ),

                        // Message Body
                        Text(
                          mensaje.texto,
                          style: AppStyles.messageBody.copyWith(
                            color: textColor,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Timestamp Row & Edited Label
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment:
                              esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (mensaje.editado) ...[
                              Text(
                                '(editado)',
                                style: AppStyles.messageTime.copyWith(
                                  color: subtitleColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (formattedTime.isNotEmpty)
                              Text(
                                formattedTime,
                                style: AppStyles.messageTime.copyWith(
                                  color: subtitleColor,
                                ),
                              ),
                            if (esMio) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done_all,
                                size: 14,
                                color: subtitleColor,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Reacciones acumuladas
                  if (reactionCounts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: esMio ? WrapAlignment.end : WrapAlignment.start,
                      children: reactionCounts.entries.map((entry) {
                        final emoji = entry.key;
                        final count = entry.value;
                        final textLabel = count > 1 ? '$emoji $count' : emoji;

                        return GestureDetector(
                          onTap: () => onReactTap?.call(emoji),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              textLabel,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Sent Avatar
          if (esMio) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: avatarBg,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? Text(
                      _getInitial(authorName),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: avatarTextColor,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
