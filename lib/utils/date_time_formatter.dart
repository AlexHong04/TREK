import 'package:intl/intl.dart';
import '../models/entities/activity.dart';

class DateTimeFormatter {
  static String formatDisplayTime(Activity activity) {
    final startTime = activity.startTime;

    if (startTime != null && startTime.trim().isNotEmpty) {
      // Return directly if already formatted as "09:00 AM" / "2:30 PM"
      if (startTime.contains('AM') || startTime.contains('PM')) {
        return startTime;
      }

      // Convert 24-hour "HH:mm" to 12-hour format
      try {
        final parts = startTime.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          final timeDate = DateTime(
            activity.date.year,
            activity.date.month,
            activity.date.day,
            hour,
            minute,
          );
          return DateFormat('hh:mm a').format(timeDate);
        }
      } catch (_) {
        return startTime;
      }
    }

    // Fallback: If the DateTime object carries a specific hour/minute
    if (activity.date.hour != 0 || activity.date.minute != 0) {
      return DateFormat('hh:mm a').format(activity.date);
    }

    return 'Scheduled';
  }
}
