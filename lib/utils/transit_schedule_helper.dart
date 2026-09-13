/// Helper utility for realistic Malaysia transit journey schedules, travel durations,
/// and automatic departure/arrival date-time adjustments.
class TransitScheduleHelper {
  /// Extract a standardized region/state from a hub location string.
  static String extractRegion(String location) {
    final l = location.toLowerCase();
    if (l.contains('klia') ||
        l.contains('subang') ||
        l.contains('kuala lumpur') ||
        l.contains('kl ') ||
        l.contains('tbs') ||
        l.contains('duta') ||
        l.contains('putrajaya') ||
        l.contains('selangor') ||
        l.contains('shah alam') ||
        l.contains('kajang') ||
        l.contains('klang')) {
      return 'Kuala Lumpur';
    }
    if (l.contains('penang') ||
        l.contains('butterworth') ||
        l.contains('nibong') ||
        l.contains('george town')) {
      return 'Penang';
    }
    if (l.contains('ipoh') ||
        l.contains('amanjaya') ||
        l.contains('taiping') ||
        l.contains('perak')) {
      return 'Perak';
    }
    if (l.contains('melaka') || l.contains('malacca')) {
      return 'Melaka';
    }
    if (l.contains('johor') ||
        l.contains('larkin') ||
        l.contains('senai') ||
        l.contains('jb')) {
      return 'Johor';
    }
    if (l.contains('kuantan') ||
        l.contains('genting') ||
        l.contains('cameron') ||
        l.contains('pahang')) {
      return 'Pahang';
    }
    if (l.contains('langkawi') ||
        l.contains('alor setar') ||
        l.contains('kedah')) {
      return 'Kedah';
    }
    if (l.contains('perlis') ||
        l.contains('arau') ||
        l.contains('padang besar')) {
      return 'Perlis';
    }
    if (l.contains('terengganu') ||
        l.contains('redang') ||
        l.contains('dungun') ||
        l.contains('kemaman')) {
      return 'Terengganu';
    }
    if (l.contains('kelantan') || l.contains('kota bharu')) {
      return 'Kelantan';
    }
    if (l.contains('sabah') ||
        l.contains('kinabalu') ||
        l.contains('bki') ||
        l.contains('sandakan') ||
        l.contains('tawau') ||
        l.contains('inanam')) {
      return 'Sabah';
    }
    if (l.contains('sarawak') ||
        l.contains('kuching') ||
        l.contains('kch') ||
        l.contains('miri') ||
        l.contains('sibu') ||
        l.contains('bintulu')) {
      return 'Sarawak';
    }
    return '';
  }

  /// Calculates estimated travel duration in minutes based on transit mode and locations.
  static int getEstimatedDurationMinutes({
    required String transitType,
    String? fromLocation,
    String? toLocation,
    List<String>? selectedDestinations,
  }) {
    String fromRegion = extractRegion(fromLocation ?? '');
    String toRegion = extractRegion(toLocation ?? '');

    // Fallback inference if locations are still blank
    if (fromRegion.isEmpty) {
      fromRegion = 'Kuala Lumpur';
    }
    if (toRegion.isEmpty &&
        selectedDestinations != null &&
        selectedDestinations.isNotEmpty) {
      for (final dest in selectedDestinations) {
        final r = extractRegion(dest);
        if (r.isNotEmpty && r != fromRegion) {
          toRegion = r;
          break;
        }
      }
      if (toRegion.isEmpty) {
        toRegion = extractRegion(selectedDestinations.first);
      }
    }
    if (toRegion.isEmpty) {
      toRegion = 'Penang';
    }

    final mode = transitType.toLowerCase();

    // 1. FLIGHT
    if (mode == 'flight') {
      final isFromEast = fromRegion == 'Sabah' || fromRegion == 'Sarawak';
      final isToEast = toRegion == 'Sabah' || toRegion == 'Sarawak';

      if (isFromEast && isToEast) {
        return 85; // ~1h 25m within East Malaysia
      }
      if (isFromEast || isToEast) {
        final eastRegion = isFromEast ? fromRegion : toRegion;
        if (eastRegion == 'Sabah') {
          return 160; // ~2h 40m (KL <-> Kota Kinabalu)
        }
        return 110; // ~1h 50m (KL <-> Kuching)
      }
      // Peninsular domestic flights (KL to Penang, Langkawi, JB, Kota Bharu, etc.)
      return 65; // ~1h 05m
    }

    // 2. TRAIN (KTM ETS / Intercity / ERL)
    if (mode == 'train') {
      final pair = {fromRegion, toRegion};
      if (pair.contains('Kuala Lumpur') && pair.contains('Perak')) {
        return 160; // ~2h 40m (KL Sentral - Ipoh)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Penang')) {
        return 245; // ~4h 05m (KL Sentral - Butterworth)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Kedah')) {
        return 285; // ~4h 45m (KL - Alor Setar)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Perlis')) {
        return 310; // ~5h 10m (KL - Arau / Padang Besar)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Melaka')) {
        return 120; // ~2h 00m (KL - Batang Melaka / Tampin)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Johor')) {
        return 270; // ~4h 30m (KL - JB Sentral)
      }
      if (pair.contains('Perak') && pair.contains('Penang')) {
        return 100; // ~1h 40m (Ipoh - Butterworth)
      }
      return 210; // ~3h 30m default train duration
    }

    // 3. EXPRESS BUS
    final pair = {fromRegion, toRegion};
    if (pair.contains('Kuala Lumpur') && pair.contains('Penang')) {
      return 270; // ~4h 30m (TBS - Penang Sentral / Sungai Nibong)
    }
    if (pair.contains('Kuala Lumpur') && pair.contains('Melaka')) {
      return 135; // ~2h 15m (TBS - Melaka Sentral)
    }
    if (pair.contains('Kuala Lumpur') && pair.contains('Perak')) {
      return 195; // ~3h 15m (TBS - Terminal Amanjaya Ipoh)
    }
    if (pair.contains('Kuala Lumpur') && pair.contains('Johor')) {
      return 270; // ~4h 30m (TBS - Larkin Sentral JB)
    }
    if (pair.contains('Kuala Lumpur') && pair.contains('Pahang')) {
      if ((fromLocation ?? '').toLowerCase().contains('genting') ||
          (toLocation ?? '').toLowerCase().contains('genting')) {
        return 75; // ~1h 15m (KL - Genting)
      }
      return 225; // ~3h 45m (TBS - Kuantan / Cameron)
    }
    if (pair.contains('Kuala Lumpur') && pair.contains('Kedah')) {
      return 360; // ~6h 00m (TBS - Alor Setar)
    }
    if (pair.contains('Kuala Lumpur') && pair.contains('Terengganu')) {
      return 390; // ~6h 30m (TBS - MBKT Kuala Terengganu)
    }
    if (pair.contains('Kuala Lumpur') && pair.contains('Kelantan')) {
      return 480; // ~8h 00m (TBS - Kota Bharu)
    }
    if (pair.contains('Penang') && pair.contains('Perak')) {
      return 135; // ~2h 15m (Penang - Ipoh)
    }
    if (pair.contains('Penang') && pair.contains('Melaka')) {
      return 390; // ~6h 30m (Penang - Melaka)
    }
    if (pair.contains('Penang') && pair.contains('Johor')) {
      return 540; // ~9h 00m (Penang - JB)
    }

    return 240; // ~4h 00m default bus duration
  }

  /// Formats minutes into human-readable string, e.g. "4h 30m", "1h 15m".
  static String formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Parses a 12-hour formatted time (e.g. "09:00 PM") into minutes from midnight (0..1439).
  static int parseTimeToMinutes(String timeStr) {
    try {
      final trimmed = timeStr.trim();
      if (trimmed.isEmpty) return 540; // 09:00 AM default
      final parts = trimmed.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
        hour += 12;
      } else if (parts.length > 1 &&
          parts[1].toUpperCase() == 'AM' &&
          hour == 12) {
        hour = 0;
      }
      return hour * 60 + minute;
    } catch (_) {
      return 540;
    }
  }

  /// Formats minutes from midnight into 12-hour format string, e.g. "09:00 PM".
  static String minutesToTimeString(int totalMinutes) {
    final normalized = (totalMinutes % 1440 + 1440) % 1440;
    final h24 = normalized ~/ 60;
    final m = normalized % 60;
    final period = h24 >= 12 ? 'PM' : 'AM';
    int h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  /// Adds [minutesToAdd] to a given [departureDate] and [departureTimeStr].
  /// Returns a map with calculated {'date': newDateStr, 'time': newTimeStr, 'crossesMidnight': bool}.
  static Map<String, dynamic> calculateArrivalDateTime({
    required String departureDate,
    required String departureTimeStr,
    required int minutesToAdd,
  }) {
    final depMinutes = parseTimeToMinutes(departureTimeStr);
    final totalArrivalMinutes = depMinutes + minutesToAdd;
    final daysAdded = totalArrivalMinutes ~/ 1440;
    final arrivalMinutesInDay = totalArrivalMinutes % 1440;
    final newTime = minutesToTimeString(arrivalMinutesInDay);

    String newDate = departureDate;
    if (daysAdded > 0 && departureDate.isNotEmpty) {
      final parsed = DateTime.tryParse(departureDate);
      if (parsed != null) {
        final adjustedDate = parsed.add(Duration(days: daysAdded));
        newDate = adjustedDate.toLocal().toString().split(' ')[0];
      }
    }

    return {
      'date': newDate,
      'time': newTime,
      'daysAdded': daysAdded,
      'crossesMidnight': daysAdded > 0,
    };
  }

  /// Recommended realistic departure schedules based on typical Malaysia timetables.
  static List<String> getPopularScheduleDepartureTimes(String transitType) {
    final mode = transitType.toLowerCase();
    if (mode == 'flight') {
      return [
        '08:00 AM',
        '10:30 AM',
        '01:15 PM',
        '04:30 PM',
        '07:00 PM',
        '09:30 PM',
      ];
    }
    if (mode == 'train') {
      return [
        '07:08 AM',
        '08:47 AM',
        '11:45 AM',
        '03:30 PM',
        '07:15 PM',
        '09:10 PM',
      ];
    }
    // Express Bus
    return [
      '08:00 AM',
      '10:30 AM',
      '02:00 PM',
      '05:30 PM',
      '08:30 PM',
      '11:00 PM',
    ];
  }
}
