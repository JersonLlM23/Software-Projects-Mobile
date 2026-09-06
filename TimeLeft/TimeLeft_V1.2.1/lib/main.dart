import 'package:flutter/material.dart';
import 'themes/app_theme.dart';
import 'themes/theme_controller.dart';
import 'viewModel/notification_service.dart';
import 'vistas/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const TimeLeftApp());
}

/// TimeLeftApp es el widget raíz de la aplicación TimeLeft.
/// Configura el tema claro (por defecto) y oscuro utilizando AppTheme.
class TimeLeftApp extends StatelessWidget {
  const TimeLeftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'TimeLeft',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController.instance.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const SplashScreen(),
        );
      },
    );
  }
}
