import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const TimeLeftApp());
}

/// TimeLeftApp es el widget raíz de la aplicación TimeLeft.
/// Configura el tema claro y oscuro utilizando Material Design 3.
class TimeLeftApp extends StatelessWidget {
  const TimeLeftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeLeft',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      // Tema Claro
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.light,
        ),
      ),
      // Tema Oscuro
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
