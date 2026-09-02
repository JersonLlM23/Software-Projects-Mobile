import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurrentConversationNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setConversation(String? conversationId) {
    state = conversationId;
  }

  void clearConversation() {
    state = null;
  }
}

final currentConversationProvider =
    NotifierProvider<CurrentConversationNotifier, String?>(
  CurrentConversationNotifier.new,
);
