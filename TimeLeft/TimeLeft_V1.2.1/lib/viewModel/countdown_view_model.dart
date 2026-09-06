import 'dart:async';
import 'package:flutter/material.dart';
import '../modelo/reminder_option.dart';
import 'notification_service.dart';

/// ViewModel que maneja la lógica de la cuenta regresiva y la programación de notificaciones.
class CountdownViewModel extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService.instance;

  TimeOfDay? _selectedTime;
  DateTime? _targetDateTime;
  String _eventTitle = 'Ir a clases';
  Duration _remainingDuration = Duration.zero;
  Timer? _timer;

  bool _isRunning = false;
  bool _isFinished = false;
  String? _errorMessage;

  List<ReminderOption> _reminderOptions = ReminderOption.defaultOptions();

  // Getters
  TimeOfDay? get selectedTime => _selectedTime;
  DateTime? get targetDateTime => _targetDateTime;
  String get eventTitle => _eventTitle;
  Duration get remainingDuration => _remainingDuration;
  bool get isRunning => _isRunning;
  bool get isFinished => _isFinished;
  String? get errorMessage => _errorMessage;
  List<ReminderOption> get reminderOptions => _reminderOptions;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Cancela el temporizador activo de la UI.
  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  /// Actualiza el título o nombre del evento.
  void setEventTitle(String title) {
    _eventTitle = title;
    notifyListeners();
  }

  /// Alterna el estado de activación de una opción de recordatorio por su ID.
  void toggleReminderOption(int id, bool isEnabled) {
    _reminderOptions = _reminderOptions.map((option) {
      if (option.id == id) {
        return option.copyWith(isEnabled: isEnabled);
      }
      return option;
    }).toList();
    notifyListeners();
  }

  /// Procesa la selección de una nueva hora objetivo mediante showTimePicker.
  void selectTime(TimeOfDay picked) {
    _cancelTimer();

    final now = DateTime.now();
    final target = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );

    _selectedTime = picked;
    _isFinished = false;

    // Verificación de hora pasada respecto al DateTime.now() actual
    if (target.isBefore(now)) {
      _targetDateTime = null;
      _remainingDuration = Duration.zero;
      final formattedTime = _formatTimeOfDay(picked);
      _errorMessage =
          'La hora seleccionada ($formattedTime) ya pasó el día de hoy. Por favor selecciona una hora futura.';
    } else {
      _targetDateTime = target;
      _remainingDuration = target.difference(now);
      _errorMessage = null;
    }

    notifyListeners();
  }

  /// Inicia la cuenta regresiva visual y programa las notificaciones locales correspondientes.
  Future<void> startCountdown() async {
    if (_targetDateTime == null) return;

    _cancelTimer();

    final now = DateTime.now();
    final initialDiff = _targetDateTime!.difference(now);

    if (initialDiff.isNegative || initialDiff.inSeconds <= 0) {
      _remainingDuration = Duration.zero;
      _isFinished = true;
      _errorMessage = 'La hora seleccionada ya transcurrió.';
      notifyListeners();
      return;
    }

    // Solicitar permisos de notificación si es necesario (Android 13+)
    await _notificationService.requestPermissions();

    // 1. Cancelar cualquier notificación programada previamente para evitar duplicados
    await _notificationService.cancelAll();

    // 2. Programar las nuevas notificaciones válidas
    await _scheduleValidNotifications();

    _isRunning = true;
    _isFinished = false;
    _errorMessage = null;
    _remainingDuration = initialDiff;
    notifyListeners();

    // Timer.periodic se utiliza exclusivamente para refrescar la interfaz visual
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentNow = DateTime.now();
      final difference = _targetDateTime!.difference(currentNow);

      if (difference.isNegative || difference.inSeconds <= 0) {
        timer.cancel();
        _timer = null;
        _isRunning = false;
        _isFinished = true;
        _remainingDuration = Duration.zero;
        notifyListeners();
      } else {
        _remainingDuration = difference;
        notifyListeners();
      }
    });
  }

  /// Calcula y programa únicamente las notificaciones habilitadas cuyo momento aún esté en el futuro.
  Future<void> _scheduleValidNotifications() async {
    if (_targetDateTime == null) return;

    final now = DateTime.now();
    final title = 'TimeLeft';
    final trimmedEventName = _eventTitle.trim();

    for (final option in _reminderOptions) {
      if (!option.isEnabled) continue;

      // Calcular el momento exacto en que debe sonar la notificación
      final scheduledDate =
          _targetDateTime!.subtract(Duration(minutes: option.minutesBefore));

      // Solo programar si el momento de disparo es posterior a ahora
      if (scheduledDate.isAfter(now)) {
        String body;
        if (option.minutesBefore == 0) {
          body = trimmedEventName.isNotEmpty
              ? '¡Es hora! "$trimmedEventName"'
              : '¡Es hora!';
        } else if (option.minutesBefore == 60) {
          body = trimmedEventName.isNotEmpty
              ? 'Falta 1 hora para "$trimmedEventName"'
              : 'Falta 1 hora';
        } else if (option.minutesBefore == 1) {
          body = trimmedEventName.isNotEmpty
              ? 'Falta 1 minuto para "$trimmedEventName"'
              : 'Falta 1 minuto';
        } else {
          body = trimmedEventName.isNotEmpty
              ? 'Faltan ${option.minutesBefore} minutos para "$trimmedEventName"'
              : 'Faltan ${option.minutesBefore} minutos';
        }

        await _notificationService.scheduleNotification(
          id: option.id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
        );
      }
    }
  }

  /// Detiene la cuenta regresiva, cancela las notificaciones y reinicia el estado.
  Future<void> resetCountdown() async {
    _cancelTimer();
    await _notificationService.cancelAll();

    _selectedTime = null;
    _targetDateTime = null;
    _remainingDuration = Duration.zero;
    _isRunning = false;
    _isFinished = false;
    _errorMessage = null;

    notifyListeners();
  }

  /// Formatea la duración restante en formato HH:MM:SS con ceros a la izquierda.
  String formatDuration(Duration duration) {
    if (duration.isNegative) return '00:00:00';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Formatea TimeOfDay a cadena legible de 12 horas con AM/PM.
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
