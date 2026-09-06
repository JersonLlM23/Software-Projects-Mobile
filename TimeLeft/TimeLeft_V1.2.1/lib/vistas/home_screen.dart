import 'package:flutter/material.dart';
import '../themes/theme_controller.dart';
import '../viewModel/countdown_view_model.dart';

/// Pantalla principal de TimeLeft que implementa la interfaz de usuario
/// consumiendo el CountdownViewModel bajo el patrón MVVM.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CountdownViewModel _viewModel;
  late final TextEditingController _eventController;

  @override
  void initState() {
    super.initState();
    _viewModel = CountdownViewModel();
    _eventController = TextEditingController(text: _viewModel.eventTitle);
  }

  @override
  void dispose() {
    _eventController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// Muestra el seleccionador de hora nativo (showTimePicker).
  /// Se utiliza únicamente initialTime y initialEntryMode dialOnly para evitar ingreso manual por teclado.
  Future<void> _pickTime() async {
    final TimeOfDay nowTime = TimeOfDay.now();

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _viewModel.selectedTime ?? nowTime,
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );

    if (picked != null) {
      _viewModel.selectTime(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'TimeLeft',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            elevation: 0,
            actions: [
              ListenableBuilder(
                listenable: ThemeController.instance,
                builder: (context, _) {
                  final isDark = ThemeController.instance.isDarkMode;
                  return IconButton(
                    tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                      color: isDark ? Colors.amber : colorScheme.onSurface,
                    ),
                    onPressed: () {
                      ThemeController.instance.toggleTheme();
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Título principal
                  Text(
                    '¿Cuánto tiempo te queda?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Campo opcional para el nombre del evento / meta
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _eventController,
                        enabled: !_viewModel.isRunning,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Nombre del evento / meta',
                          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                          hintText: 'Ej. Ir a clases, Examen, Reunión',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.label_important_outline_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                        onChanged: (val) {
                          _viewModel.setEventTitle(val);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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
                          const SizedBox(height: 6),
                          Text(
                            _viewModel.selectedTime != null
                                ? _viewModel.selectedTime!.format(context)
                                : '--:--',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _viewModel.isRunning ? null : _pickTime,
                            icon: const Icon(Icons.access_time_rounded),
                            label: Text(
                              _viewModel.selectedTime == null
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

                  const SizedBox(height: 20),

                  // Display Visual Principal: Cuenta Regresiva HH:MM:SS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _viewModel.isFinished
                          ? colorScheme.errorContainer
                          : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          _viewModel.formatDuration(_viewModel.remainingDuration),
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: _viewModel.isFinished
                                ? colorScheme.onErrorContainer
                                : colorScheme.onPrimaryContainer,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        if (_viewModel.isFinished) ...[
                          const SizedBox(height: 10),
                          Text(
                            '¡Es hora! ${_viewModel.eventTitle.trim().isNotEmpty ? "\"${_viewModel.eventTitle.trim()}\"" : ""}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Alerta de Error si la hora ya pasó
                  if (_viewModel.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(alpha: 0.6),
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
                              _viewModel.errorMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sección de Configuración de Notificaciones
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                color: colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Avisos y Notificaciones',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Selecciona cuándo deseas recibir alertas sonoras con "reloj.mp3":',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Divider(
                            height: 20,
                            color: colorScheme.outlineVariant,
                          ),
                          // Lista de switches/checkboxes para las opciones
                          ..._viewModel.reminderOptions.map((option) {
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: colorScheme.primary,
                              checkColor: colorScheme.onPrimary,
                              title: Text(
                                option.label,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: option.isEnabled
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              value: option.isEnabled,
                              onChanged: _viewModel.isRunning
                                  ? null
                                  : (bool? val) {
                                      if (val != null) {
                                        _viewModel.toggleReminderOption(
                                          option.id,
                                          val,
                                        );
                                      }
                                    },
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Botones de Acción
                  Row(
                    children: [
                      if (_viewModel.isRunning || _viewModel.selectedTime != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _viewModel.resetCountdown();
                            },
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
                          onPressed: (_viewModel.selectedTime == null ||
                                  _viewModel.targetDateTime == null ||
                                  _viewModel.isRunning)
                              ? null
                              : () {
                                  _viewModel.startCountdown();
                                },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text(
                            'Iniciar cuenta regresiva',
                            style: TextStyle(
                              fontSize: 15,
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

                  const SizedBox(height: 24),

                  // Versión de la aplicación
                  Center(
                    child: Text(
                      'TimeLeft versión 1.2.1',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
