import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'data/services/notification_service.dart';
import 'data/services/conversation_listener_service.dart';
import 'data/services/auth_service.dart';
import 'data/services/user_service.dart';
import 'domain/models/usuario_app.dart';
import 'presentation/provider/auth_provider.dart';
import 'presentation/provider/current_conversation_provider.dart';
import 'presentation/provider/theme_provider.dart';
import 'presentation/views/login_view.dart';
import 'presentation/views/main_navigation_view.dart';
import 'presentation/views/private_chat_view.dart';
import 'themes/app_theme.dart';

/// GlobalKey para permitir navegación desde notificaciones push sin contexto.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Initialize FCM push notification service
  await NotificationService.initialize();

  // 3. Register notification tap handler for navigating to PrivateChatView
  NotificationService.onNotificationTap = (String conversationId) async {
    await _navigateToPrivateChat(conversationId);
  };

  // 3. Start the app
  runApp(const ProviderScope(child: MyApp()));
}

/// Navega automáticamente a la conversación privada correcta cuando el usuario
/// toca una notificación push, usando el [navigatorKey] global.
Future<void> _navigateToPrivateChat(String conversationId) async {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  // Obtener nombre del usuario actual y datos del receptor
  final authService = AuthService();
  final userService = UserService();

  final miNombre = await authService.obtenerNombreUsuarioActual() ?? 'Yo';

  // Extraer el UID del receptor desde el conversationId (uid1_uid2)
  final idx = conversationId.indexOf('_');
  if (idx == -1) return;
  final uid1 = conversationId.substring(0, idx);
  final uid2 = conversationId.substring(idx + 1);
  final receptorUid = currentUser.uid == uid1 ? uid2 : uid1;

  // Buscar en la lista de usuarios registrados para obtener los datos del receptor
  final usuarios = await userService.obtenerUsuarios();
  UsuarioApp? usuarioDestino;
  try {
    usuarioDestino = usuarios.firstWhere((u) => u.uid == receptorUid);
  } catch (err) {
    // Si no se encuentra en la lista (excluida del stream), buscar directamente
    usuarioDestino = UsuarioApp(
      uid: receptorUid,
      nombre: receptorUid,
      correo: '',
    );
  }

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => PrivateChatView(
        usuarioDestino: usuarioDestino!,
        conversationId: conversationId,
        miNombre: miNombre,
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Chatcito',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AuthWrapper(),
    );
  }
}

/// Widget que evalúa si existe una sesión de Firebase Auth activa.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return FutureBuilder<String?>(
            future: ref.read(authServiceProvider).obtenerNombreUsuarioActual(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final nombre = snapshot.data;
              if (nombre != null && nombre.isNotEmpty) {
                // Guardar token FCM al reanudar sesión
                NotificationService.saveTokenForCurrentUser();
                // Iniciar escucha en tiempo real de notificaciones de conversaciones privadas
                ConversationListenerService.iniciarEscucha(
                  currentUid: user.uid,
                  currentNombre: nombre,
                  getCurrentConversationId: () => ref.read(currentConversationProvider),
                );
                return MainNavigationView(usuario: nombre);
              }
              return const LoginView();
            },
          );
        }
        ConversationListenerService.detenerEscucha();
        return const LoginView();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => const LoginView(),
    );
  }
}
