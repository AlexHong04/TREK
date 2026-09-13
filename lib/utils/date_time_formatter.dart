import 'package:intl/intl.dart';
import '../models/entities/activity.dart';

class DateTimeFormatter {
  /// Formats an activity's schedule as a time frame, e.g.
  /// "09:00 AM - 11:00 AM". Falls back to a single time when only one end of
  /// the frame is available.
  static String formatDisplayTime(Activity activity) {
    final start = _to12Hour(activity.startTime) ?? _dateTimeTo12Hour(activity.date);
    final end = _to12Hour(activity.endTime);

    if (start != null && end != null && start != end) {
      return '$start - $end';
    }
    if (start != null) return start;
    if (end != null) return end;
    return 'Scheduled';
  }

  /// Converts a stored time value ("HH:mm" or "hh:mm a") into "hh:mm a".
  /// Returns null when the value is missing or empty.
  static String? _to12Hour(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();

    // Return directly if already formatted as "09:00 AM" / "2:30 PM".
    final upper = value.toUpperCase();
    if (upper.contains('AM') || upper.contains('PM')) {
      return value;
    }

    // Convert 24-hour "HH:mm" to 12-hour format.
    try {
      final parts = value.split(':');
      if (parts.length < 2) return value;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1].split(' ').first);
      final timeDate = DateTime(2000, 1, 1, hour, minute);
      return DateFormat('hh:mm a').format(timeDate);
    } catch (_) {
      return value;
    }
  }

  /// Fallback: uses the DateTime's own hour/minute when it carries a time.
  static String? _dateTimeTo12Hour(DateTime date) {
    if (date.hour == 0 && date.minute == 0) return null;
    return DateFormat('hh:mm a').format(date);
  }
}
