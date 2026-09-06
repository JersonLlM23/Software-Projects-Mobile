/// Modelo que representa una regla de recordatorio / notificación previa.
class ReminderOption {
  final int id;
  final int minutesBefore;
  final String label;
  bool isEnabled;

  ReminderOption({
    required this.id,
    required this.minutesBefore,
    required this.label,
    this.isEnabled = true,
  });

  /// Crea una copia del objeto con valores actualizados si es necesario.
  ReminderOption copyWith({
    int? id,
    int? minutesBefore,
    String? label,
    bool? isEnabled,
  }) {
    return ReminderOption(
      id: id ?? this.id,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      label: label ?? this.label,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// Lista predeterminada de avisos para TimeLeft Fase 2.
  static List<ReminderOption> defaultOptions() {
    return [
      ReminderOption(id: 1001, minutesBefore: 60, label: '1 hora antes'),
      ReminderOption(id: 1002, minutesBefore: 30, label: '30 minutos antes'),
      ReminderOption(id: 1003, minutesBefore: 15, label: '15 minutos antes'),
      ReminderOption(id: 1004, minutesBefore: 5, label: '5 minutos antes'),
      ReminderOption(id: 1005, minutesBefore: 1, label: '1 minuto antes'),
      ReminderOption(id: 1006, minutesBefore: 0, label: 'Al finalizar'),
    ];
  }
}
