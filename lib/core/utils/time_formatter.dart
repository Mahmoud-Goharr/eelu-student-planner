class TimeFormatter {
  const TimeFormatter._();

  /// Converts database times such as 13:00 or 13:00:00 to 12-hour format.
  /// The database value itself is never changed.
  static String format(String value, {bool arabic = false}) {
    final text = value.trim();
    final parts = text.split(':');
    if (parts.length < 2) return text;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23) {
      return text;
    }

    final suffix = arabic
        ? (hour >= 12 ? 'م' : 'ص')
        : (hour >= 12 ? 'PM' : 'AM');
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }
}
