import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart';

/// SplashScreen muestra el logo durante 2 segundos al inicio de la aplicación
/// y redirige a HomeScreen reemplazando la ruta en el stack de navegación.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Temporizador de 2 segundos para la transición automática a HomeScreen
    _timer = Timer(const Duration(seconds: 2), _navigateToHome);
  }

  /// Navega a HomeScreen reemplazando la SplashScreen para evitar volver con el botón atrás
  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  @override
  void dispose() {
    // Cancela el temporizador para evitar memory leaks si el widget es destruido
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Image.asset(
            'assets/images/Logo_JelyProductions.png',
            width: 220,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
