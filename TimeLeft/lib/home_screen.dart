import 'dart:async';
import 'package:flutter/material.dart';

/// HomeScreen es la pantalla principal del MVP de TimeLeft.
/// Permite al usuario seleccionar una hora objetivo y calcular el tiempo restante
/// en tiempo real mediante DateTime.now() y Duration.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TimeOfDay? _selectedTime;
  DateTime? _targetDateTime;
  Duration _remainingDuration = Duration.zero;
  Timer? _timer;

  bool _isRunning = false;
  bool _isFinished = false;
  String? _errorMessage;

  @override
  void dispose() {
    // Cancela el temporizador al destruir el widget para evitar memory leaks.
    _timer?.cancel();
    super.dispose();
  }

  /// Cancela el temporizador activo si existe.
  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  /// Muestra el seleccionador de hora nativo (showTimePicker).
  Future<void> _pickTime() async {
    final TimeOfDay nowTime = TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? nowTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;

    // Si había una cuenta en ejecución, la cancelamos antes de procesar la nueva hora
    _cancelTimer();

    final now = DateTime.now();
    final target = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );

    setState(() {
      _selectedTime = picked;
      _isFinished = false;

      // Verificación de hora pasada respecto a DateTime.now()
      if (target.isBefore(now)) {
        _targetDateTime = null;
        _remainingDuration = Duration.zero;
        _errorMessage =
            "La hora seleccionada (${picked.format(context)}) ya pasó el día de hoy. Por favor selecciona una hora futura.";
      } else {
        _targetDateTime = target;
        _remainingDuration = target.difference(now);
        _errorMessage = null;
      }
    });
  }

  /// Inicia la cuenta regresiva utilizando DateTime.now() como fuente de verdad.
  void _startCountdown() {
    if (_targetDateTime == null) return;

    _cancelTimer();

    final initialDiff = _targetDateTime!.difference(DateTime.now());
    if (initialDiff.isNegative || initialDiff.inSeconds <= 0) {
      setState(() {
        _remainingDuration = Duration.zero;
        _isFinished = true;
        _errorMessage = "La hora seleccionada ya transcurrió.";
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _isFinished = false;
      _errorMessage = null;
      _remainingDuration = initialDiff;
    });

    // Timer.periodic se utiliza únicamente para refrescar la UI cada segundo
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final difference = _targetDateTime!.difference(now);

      if (difference.isNegative || difference.inSeconds <= 0) {
        timer.cancel();
        setState(() {
          _timer = null;
          _isRunning = false;
          _isFinished = true;
          _remainingDuration = Duration.zero;
        });
      } else {
        setState(() {
          _remainingDuration = difference;
        });
      }
    });
  }

  /// Detiene y reinicia la cuenta regresiva.
  void _resetCountdown() {
    setState(() {
      _cancelTimer();
      _selectedTime = null;
      _targetDateTime = null;
      _remainingDuration = Duration.zero;
      _isFinished = false;
      _errorMessage = null;
    });
  }

  /// Formatea una instancia de Duration en una cadena con formato estricto HH:MM:SS.
  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00:00:00";
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TimeLeft',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Título y Subtítulo
                Text(
                  '¿Cuánto tiempo te queda?',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Sección de Selección de Hora Objetivo
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: colorScheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          'Hora objetivo:',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedTime != null
                              ? _selectedTime!.format(context)
                              : '--:--',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isRunning ? null : _pickTime,
                          icon: const Icon(Icons.access_time_rounded),
                          label: Text(
                            _selectedTime == null
                                ? 'Seleccionar hora'
                                : 'Cambiar hora',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Display Visual Principal: Cuenta Regresiva HH:MM:SS
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _isFinished
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _formatDuration(_remainingDuration),
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: _isFinished
                              ? colorScheme.onErrorContainer
                              : colorScheme.onPrimaryContainer,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      if (_isFinished) ...[
                        const SizedBox(height: 12),
                        Text(
                          '¡Es hora!',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Alerta/Mensaje de Error en caso de Hora Pasada
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Botones de Acción
                Row(
                  children: [
                    if (_isRunning || _selectedTime != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetCountdown,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: colorScheme.outline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Reiniciar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_selectedTime == null ||
                                    _targetDateTime == null ||
                                    _isRunning)
                                ? null
                                : _startCountdown,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text(
                          'Iniciar cuenta regresiva',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
