import '../models/configurations/openrouteservice_api_config.dart';

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
    if (l.contains('singapore') || l.contains('woodlands')) {
      return 'Singapore';
    }
    if (l.contains('seremban') ||
        l.contains('negeri sembilan') ||
        l.contains('gemas') ||
        l.contains('nilai')) {
      return 'Negeri Sembilan';
    }
    if (l.contains('penang') ||
        l.contains('butterworth') ||
        l.contains('bukit mertajam') ||
        l.contains('nibong') ||
        l.contains('george town')) {
      return 'Penang';
    }
    if (l.contains('ipoh') ||
        l.contains('amanjaya') ||
        l.contains('taiping') ||
        l.contains('kampar') ||
        l.contains('tanjung malim') ||
        l.contains('batu gajah') ||
        l.contains('perak')) {
      return 'Perak';
    }
    if (l.contains('melaka') || l.contains('malacca')) {
      return 'Melaka';
    }
    if (l.contains('johor') ||
        l.contains('larkin') ||
        l.contains('senai') ||
        l.contains('jb') ||
        l.contains('kluang') ||
        l.contains('segamat') ||
        l.contains('kulai')) {
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
        l.contains('sungai petani') ||
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

  /// Returns estimated direct rail travel duration in minutes
  /// for known Malaysian railway station pairs.
  ///
  /// IMPORTANT:
  /// - These are estimated in-train travel durations.
  /// - They do not include waiting time, transfer time, walking time,
  ///   or delays.
  /// - Returns null when there is no known direct/common rail connection.
  /// - Station matching is intentionally name-based so it works with
  ///   the station names used in destinationTrainStations.
  static int? _getGtfsStationPairDuration(String from, String to) {
    final f = from.toLowerCase().trim();
    final t = to.toLowerCase().trim();

    // ---------------------------------------------------------------------------
    // Helper
    // ---------------------------------------------------------------------------

    bool match(String k1, String k2) {
      return (f.contains(k1) && t.contains(k2)) ||
          (f.contains(k2) && t.contains(k1));
    }

    // ===========================================================================
    // KLANG VALLEY / KUALA LUMPUR
    // ===========================================================================

    // KL Sentral <-> Kuala Lumpur Railway Station
    if (match('kl sentral', 'kuala lumpur railway station')) {
      return 5;
    }

    // KL Sentral <-> Kepong Sentral
    if (match('kl sentral', 'kepong')) {
      return 25;
    }

    // KL Sentral <-> Bandar Tasik Selatan
    if (match('kl sentral', 'bandar tasik selatan')) {
      return 15;
    }

    // KL Sentral <-> Subang Jaya
    if (match('kl sentral', 'subang jaya')) {
      return 25;
    }

    // KL Sentral <-> Kajang
    if (match('kl sentral', 'kajang')) {
      return 40;
    }

    // KL Sentral <-> Rawang
    if (match('kl sentral', 'rawang')) {
      return 45;
    }

    // KL Sentral <-> Klang
    if (match('kl sentral', 'klang')) {
      return 55;
    }

    // KL Sentral <-> Tanjung Malim
    if (match('kl sentral', 'tanjung malim')) {
      return 80;
    }

    // ---------------------------------------------------------------------------
    // Other Klang Valley combinations
    // ---------------------------------------------------------------------------

    // Kepong <-> Rawang
    if (match('kepong', 'rawang')) {
      return 25;
    }

    // Kepong <-> Kajang
    if (match('kepong', 'kajang')) {
      return 55;
    }

    // Kepong <-> Subang Jaya
    if (match('kepong', 'subang jaya')) {
      return 40;
    }

    // Kepong <-> Klang
    if (match('kepong', 'klang')) {
      return 50;
    }

    // Kepong <-> Bandar Tasik Selatan
    if (match('kepong', 'bandar tasik selatan')) {
      return 40;
    }

    // Kajang <-> Bandar Tasik Selatan
    if (match('kajang', 'bandar tasik selatan')) {
      return 25;
    }

    // Kajang <-> Seremban
    if (match('kajang', 'seremban')) {
      return 40;
    }

    // Kajang <-> Nilai
    if (match('kajang', 'nilai')) {
      return 25;
    }

    // Rawang <-> Tanjung Malim
    if (match('rawang', 'tanjung malim')) {
      return 40;
    }

    // Rawang <-> Subang Jaya
    if (match('rawang', 'subang jaya')) {
      return 55;
    }

    // Klang <-> Subang Jaya
    if (match('klang', 'subang jaya')) {
      return 25;
    }

    // ===========================================================================
    // KUALA LUMPUR -> PERAK
    // ===========================================================================

    if (match('kl sentral', 'tanjung malim')) {
      return 80;
    }

    if (match('kl sentral', 'kampar')) {
      return 125;
    }

    if (match('kl sentral', 'batu gajah')) {
      return 135;
    }

    if (match('kl sentral', 'ipoh')) {
      return 145;
    }

    if (match('kl sentral', 'kuala kangsar')) {
      return 165;
    }

    if (match('kl sentral', 'taiping')) {
      return 180;
    }

    if (match('kl sentral', 'tapah road')) {
      return 120;
    }

    // ===========================================================================
    // PERAK INTERNAL
    // ===========================================================================

    if (match('tanjung malim', 'tapah road')) {
      return 40;
    }

    if (match('tapah road', 'kampar')) {
      return 20;
    }

    if (match('kampar', 'batu gajah')) {
      return 20;
    }

    if (match('kampar', 'ipoh')) {
      return 26;
    }

    if (match('batu gajah', 'ipoh')) {
      return 20;
    }

    if (match('ipoh', 'kuala kangsar')) {
      return 30;
    }

    if (match('ipoh', 'taiping')) {
      return 50;
    }

    if (match('kuala kangsar', 'taiping')) {
      return 25;
    }

    // ===========================================================================
    // KUALA LUMPUR -> PENANG
    // ===========================================================================

    if (match('kl sentral', 'butterworth')) {
      return 255;
    }

    if (match('kl sentral', 'bukit mertajam')) {
      return 205;
    }

    if (match('kl sentral', 'nibong tebal')) {
      return 190;
    }

    // ===========================================================================
    // PENANG INTERNAL
    // ===========================================================================

    if (match('butterworth', 'bukit mertajam')) {
      return 20;
    }

    if (match('butterworth', 'nibong tebal')) {
      return 40;
    }

    if (match('bukit mertajam', 'nibong tebal')) {
      return 25;
    }

    // ===========================================================================
    // PENANG -> KEDAH
    // ===========================================================================

    if (match('butterworth', 'sungai petani')) {
      return 30;
    }

    if (match('bukit mertajam', 'sungai petani')) {
      return 25;
    }

    if (match('nibong tebal', 'sungai petani')) {
      return 20;
    }

    if (match('butterworth', 'alor setar')) {
      return 65;
    }

    if (match('bukit mertajam', 'alor setar')) {
      return 60;
    }

    if (match('nibong tebal', 'alor setar')) {
      return 80;
    }

    if (match('sungai petani', 'alor setar')) {
      return 35;
    }

    // ===========================================================================
    // PENANG -> PERLIS
    // ===========================================================================

    if (match('butterworth', 'arau')) {
      return 95;
    }

    if (match('bukit mertajam', 'arau')) {
      return 90;
    }

    if (match('nibong tebal', 'arau')) {
      return 110;
    }

    if (match('butterworth', 'padang besar')) {
      return 105;
    }

    if (match('bukit mertajam', 'padang besar')) {
      return 100;
    }

    if (match('nibong tebal', 'padang besar')) {
      return 120;
    }

    // ===========================================================================
    // KEDAH INTERNAL
    // ===========================================================================

    if (match('sungai petani', 'alor setar')) {
      return 35;
    }

    if (match('sungai petani', 'arau')) {
      return 60;
    }

    if (match('sungai petani', 'padang besar')) {
      return 75;
    }

    if (match('alor setar', 'arau')) {
      return 20;
    }

    if (match('alor setar', 'padang besar')) {
      return 40;
    }

    // ===========================================================================
    // PERLIS INTERNAL
    // ===========================================================================

    if (match('arau', 'padang besar')) {
      return 20;
    }

    // ===========================================================================
    // KUALA LUMPUR -> KEDAH
    // ===========================================================================

    if (match('kl sentral', 'sungai petani')) {
      return 220;
    }

    if (match('kl sentral', 'alor setar')) {
      return 220;
    }

    if (match('kl sentral', 'arau')) {
      return 260;
    }

    if (match('kl sentral', 'padang besar')) {
      return 270;
    }

    // ===========================================================================
    // KUALA LUMPUR -> NEGERI SEMBILAN
    // ===========================================================================

    if (match('kl sentral', 'nilai')) {
      return 50;
    }

    if (match('kl sentral', 'seremban')) {
      return 85;
    }

    if (match('kl sentral', 'rembau')) {
      return 105;
    }

    if (match('kl sentral', 'gemas')) {
      return 140;
    }

    // ===========================================================================
    // NEGERI SEMBILAN INTERNAL
    // ===========================================================================

    if (match('nilai', 'seremban')) {
      return 25;
    }

    if (match('nilai', 'rembau')) {
      return 50;
    }

    if (match('nilai', 'gemas')) {
      return 100;
    }

    if (match('seremban', 'rembau')) {
      return 30;
    }

    if (match('seremban', 'gemas')) {
      return 60;
    }

    if (match('rembau', 'gemas')) {
      return 40;
    }

    // ===========================================================================
    // KUALA LUMPUR -> MELAKA
    // ===========================================================================

    if (match('kl sentral', 'pulau sebang')) {
      return 120;
    }

    if (match('kl sentral', 'tampin')) {
      return 120;
    }

    if (match('kl sentral', 'batang melaka')) {
      return 120;
    }

    // ===========================================================================
    // NEGERI SEMBILAN -> MELAKA
    // ===========================================================================

    if (match('seremban', 'pulau sebang')) {
      return 50;
    }

    if (match('seremban', 'tampin')) {
      return 50;
    }

    if (match('seremban', 'batang melaka')) {
      return 60;
    }

    if (match('gemas', 'pulau sebang')) {
      return 50;
    }

    if (match('gemas', 'tampin')) {
      return 50;
    }

    if (match('gemas', 'batang melaka')) {
      return 60;
    }

    // ===========================================================================
    // KUALA LUMPUR -> JOHOR
    // ===========================================================================

    if (match('kl sentral', 'gemas')) {
      return 140;
    }

    if (match('kl sentral', 'segamat')) {
      return 180;
    }

    if (match('kl sentral', 'kluang')) {
      return 220;
    }

    if (match('kl sentral', 'kulai')) {
      return 245;
    }

    if (match('kl sentral', 'kempas baru')) {
      return 255;
    }

    if (match('kl sentral', 'jb sentral')) {
      return 260;
    }

    // ===========================================================================
    // JOHOR INTERNAL
    // ===========================================================================

    if (match('gemas', 'segamat')) {
      return 45;
    }

    if (match('gemas', 'kluang')) {
      return 90;
    }

    if (match('gemas', 'kulai')) {
      return 120;
    }

    if (match('gemas', 'kempas baru')) {
      return 135;
    }

    if (match('gemas', 'jb sentral')) {
      return 150;
    }

    if (match('segamat', 'kluang')) {
      return 55;
    }

    if (match('segamat', 'kulai')) {
      return 90;
    }

    if (match('segamat', 'kempas baru')) {
      return 105;
    }

    if (match('segamat', 'jb sentral')) {
      return 120;
    }

    if (match('kluang', 'kulai')) {
      return 50;
    }

    if (match('kluang', 'kempas baru')) {
      return 65;
    }

    if (match('kluang', 'jb sentral')) {
      return 80;
    }

    if (match('kulai', 'kempas baru')) {
      return 25;
    }

    if (match('kulai', 'jb sentral')) {
      return 35;
    }

    if (match('kempas baru', 'jb sentral')) {
      return 15;
    }

    // ===========================================================================
    // JOHOR <-> SINGAPORE
    // ===========================================================================

    if (match('jb sentral', 'woodlands') ||
        match('jb sentral', 'singapore')) {
      return 5;
    }

    // ===========================================================================
    // NO KNOWN DIRECT ROUTE
    // ===========================================================================

    return null;
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

    // 2. TRAIN (KTMB ETS / Intercity / Komuter / Shuttle Tebrau)
    if (mode == 'train') {
      // 2a. Direct station pair matching using KTMB GTFS timetables
      final stationDuration = _getGtfsStationPairDuration(
        fromLocation ?? '',
        toLocation ?? '',
      );
      if (stationDuration != null) {
        return stationDuration;
      }

      // 2b. Region-level fallback using KTMB GTFS timetables
      final pair = {fromRegion, toRegion};
      if (pair.contains('Kuala Lumpur') && pair.contains('Perak')) {
        return 145; // ~2h 25m (KTMB GTFS ETS: KL Sentral <-> Ipoh)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Penang')) {
        return 255; // ~4h 15m (KTMB GTFS ETS: KL Sentral <-> Butterworth)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Kedah')) {
        return 220; // ~3h 40m (KTMB GTFS ETS: KL Sentral <-> Alor Setar)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Perlis')) {
        return 265; // ~4h 25m (KTMB GTFS ETS: KL Sentral <-> Arau / Padang Besar)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Negeri Sembilan')) {
        return 85; // ~1h 25m (KTMB GTFS ETS/Komuter: KL Sentral <-> Seremban)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Melaka')) {
        return 120; // ~2h 00m (KL <-> Batang Melaka / Tampin)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Johor')) {
        return 260; // ~4h 20m (KTMB GTFS ETS/Intercity: KL Sentral <-> JB Sentral)
      }
      if (pair.contains('Perak') && pair.contains('Penang')) {
        return 105; // ~1h 45m (KTMB GTFS: Ipoh <-> Butterworth)
      }
      if (pair.contains('Perak') && pair.contains('Kedah')) {
        return 80; // ~1h 20m (KTMB GTFS ETS: Ipoh <-> Alor Setar)
      }
      if (pair.contains('Perak') && pair.contains('Perlis')) {
        return 115; // ~1h 55m (KTMB GTFS ETS: Ipoh <-> Padang Besar)
      }
      if (pair.contains('Penang') && pair.contains('Kedah')) {
        return 65; // ~1h 05m (KTMB GTFS Komuter Utara: Butterworth <-> Alor Setar)
      }
      if (pair.contains('Penang') && pair.contains('Perlis')) {
        return 105; // ~1h 45m (KTMB GTFS Komuter Utara: Butterworth <-> Padang Besar)
      }
      if (pair.contains('Kedah') && pair.contains('Perlis')) {
        return 40; // ~40m (KTMB GTFS Komuter Utara: Alor Setar <-> Padang Besar)
      }
      if (pair.contains('Negeri Sembilan') && pair.contains('Johor')) {
        return 150; // ~2h 30m (KTMB GTFS: Seremban/Gemas <-> JB Sentral)
      }
      if (pair.contains('Johor') && pair.contains('Singapore')) {
        return 5; // 5m (KTMB GTFS Shuttle Tebrau: JB Sentral <-> Woodlands)
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

  /// Looks up geographical coordinates [lat, lng] for major Malaysian transit hubs.
  static List<double>? getHubCoordinates(String location) {
    final l = location.toLowerCase();
    if (l.contains('tbs') ||
        (l.contains('kuala lumpur') && (l.contains('bus') || l.contains('terminal')))) {
      return [3.0768, 101.7107]; // TBS KL
    }
    if (l.contains('duta')) {
      return [3.1818, 101.6748]; // Hentian Duta KL
    }
    if (l.contains('kl sentral') || l.contains('kuala lumpur')) {
      return [3.1342, 101.6865]; // KL Sentral
    }
    if (l.contains('penang sentral') || l.contains('butterworth')) {
      return [5.3942, 100.3685]; // Penang Sentral
    }
    if (l.contains('sungai nibong') || l.contains('penang')) {
      return [5.3427, 100.2982]; // Sungai Nibong Penang
    }
    if (l.contains('amanjaya') || l.contains('ipoh') || l.contains('meru raya')) {
      return [4.6711, 101.0715]; // Terminal Amanjaya Ipoh
    }
    if (l.contains('melaka') || l.contains('malacca')) {
      return [2.2201, 102.2476]; // Melaka Sentral
    }
    if (l.contains('larkin') || l.contains('johor') || l.contains('jb')) {
      return [1.4957, 103.7431]; // Larkin Sentral JB
    }
    if (l.contains('kuantan') || l.contains('tsk')) {
      return [3.8291, 103.2758]; // Terminal Sentral Kuantan
    }
    if (l.contains('shahab perdana') || l.contains('alor setar') || l.contains('kedah')) {
      return [6.1362, 100.3732]; // Terminal Shahab Perdana
    }
    if (l.contains('mbkt') || l.contains('terengganu')) {
      return [5.3308, 103.1415]; // MBKT Kuala Terengganu
    }
    if (l.contains('kota bharu') || l.contains('kelantan')) {
      return [6.1264, 102.2483]; // Terminal Kota Bharu
    }
    if (l.contains('genting')) {
      return [3.4243, 101.7942]; // Genting Highlands
    }
    if (l.contains('cameron') || l.contains('tanah rata')) {
      return [4.4697, 101.3789]; // Cameron Highlands
    }
    if (l.contains('seremban') || l.contains('negeri sembilan')) {
      return [2.7247, 101.9392]; // Terminal 1 Seremban
    }
    if (l.contains('inanam') || l.contains('kinabalu') || l.contains('sabah')) {
      return [5.9868, 116.1347]; // Inanam Bus Terminal
    }
    if (l.contains('kuching sentral') || l.contains('kuching') || l.contains('sarawak')) {
      return [1.4721, 110.3342]; // Kuching Sentral
    }
    return null;
  }

  /// Calculates estimated travel duration in minutes asynchronously.
  /// For Bus travel, tries OpenRouteService (ORS) dynamic road routing first;
  /// seamlessly falls back to standard heuristic if API key is not configured or offline.
  static Future<int> getEstimatedDurationMinutesAsync({
    required String transitType,
    String? fromLocation,
    String? toLocation,
    List<String>? selectedDestinations,
  }) async {
    if (transitType.toLowerCase() == 'bus') {
      try {
        final startCoords = getHubCoordinates(fromLocation ?? '');
        final endCoords = getHubCoordinates(toLocation ?? '');
        if (startCoords != null && endCoords != null) {
          final res = await OpenRouteServiceApiConfig.calculateDrivingRoute(
            startLat: startCoords[0],
            startLng: startCoords[1],
            endLat: endCoords[0],
            endLng: endCoords[1],
            isBus: true,
          );
          final int minutes = res['durationMinutes'] as int;
          if (minutes > 0) {
            return minutes;
          }
        }
      } catch (_) {
        // Fall back seamlessly to local heuristic on any network/API issue
      }
    }

    return getEstimatedDurationMinutes(
      transitType: transitType,
      fromLocation: fromLocation,
      toLocation: toLocation,
      selectedDestinations: selectedDestinations,
    );
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
    return const [];
  }
}
