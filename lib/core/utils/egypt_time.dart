import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Centralized Egypt-local clock for all academic date/time decisions.
///
/// Academic schedules in EELU are wall-clock times in Egypt. Using the
/// IANA `Africa/Cairo` zone lets the timezone database handle any official
/// UTC-offset changes without hard-coding UTC+2/UTC+3.
class EgyptTime {
  EgyptTime._();

  static const String zoneName = 'Africa/Cairo';
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(zoneName));
    _initialized = true;
  }

  static tz.TZDateTime now() {
    initialize();
    return tz.TZDateTime.now(tz.local);
  }

  static tz.TZDateTime dateOnly(DateTime value) {
    initialize();
    return tz.TZDateTime(
      tz.local,
      value.year,
      value.month,
      value.day,
    );
  }

  static tz.TZDateTime at(
    DateTime date,
    String time,
  ) {
    initialize();
    final parts = time.trim().split(':');
    return tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
      parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    );
  }
}
