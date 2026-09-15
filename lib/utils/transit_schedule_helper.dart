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

  /// Returns estimated direct express bus travel duration in minutes
  /// for known Malaysian bus terminal pairs.
  ///
  /// IMPORTANT:
  /// - These are estimated road/bus travel durations based on typical highway/expressway speeds.
  /// - Includes standard rest-stop allowances on long journeys.
  /// - Returns null when no direct or specific terminal pair is recognized,
  ///   falling back to regional estimations or ORS dynamic routing.
  static int? _getBusStationPairDuration(String from, String to) {
    final f = from.toLowerCase().trim();
    final t = to.toLowerCase().trim();

    bool match(String k1, String k2) {
      return (f.contains(k1) && t.contains(k2)) ||
          (f.contains(k2) && t.contains(k1));
    }

    bool matchAny(List<String> list1, List<String> list2) {
      for (final a in list1) {
        for (final b in list2) {
          if (match(a, b)) return true;
        }
      }
      return false;
    }

    // Common aliases for Greater KL / Klang Valley bus hubs
    final klHubs = [
      'tbs',
      'duta',
      'pekeliling',
      'kl sentral',
      'kl central',
      'kuala lumpur',
      'shah alam',
      'klang',
      'kajang',
      'putrajaya',
    ];

    // ===========================================================================
    // KLANG VALLEY / KL <-> NEGERI SEMBILAN
    // ===========================================================================
    if (matchAny(klHubs, ['seremban', 'terminal one'])) {
      return 60; // ~1h 00m (TBS/KL <-> Terminal One Seremban)
    }
    if (matchAny(klHubs, ['port dickson'])) {
      return 90; // ~1h 30m (TBS/KL <-> Port Dickson)
    }

    // ===========================================================================
    // KLANG VALLEY / KL <-> MELAKA
    // ===========================================================================
    if (matchAny(klHubs, ['melaka', 'malacca'])) {
      return 135; // ~2h 15m (TBS/KL <-> Melaka Sentral)
    }

    // ===========================================================================
    // KLANG VALLEY / KL <-> PAHANG
    // ===========================================================================
    if (matchAny(klHubs, ['genting'])) {
      return 75; // ~1h 15m (TBS/KL <-> Awana / Genting Highlands)
    }
    if (matchAny(klHubs, ['cameron', 'tanah rata'])) {
      return 270; // ~4h 30m (TBS/KL <-> Cameron Highlands)
    }
    if (matchAny(klHubs, ['kuantan', 'tsk'])) {
      return 210; // ~3h 30m (TBS/KL <-> Terminal Sentral Kuantan)
    }
    if (matchAny(klHubs, ['temerloh'])) {
      return 120; // ~2h 00m (TBS/KL <-> Temerloh)
    }

    // ===========================================================================
    // KLANG VALLEY / KL <-> PERAK
    // ===========================================================================
    if (matchAny(klHubs, ['amanjaya', 'ipoh', 'meru raya'])) {
      return 195; // ~3h 15m (TBS/KL <-> Terminal Amanjaya Ipoh)
    }
    if (matchAny(klHubs, ['taiping', 'kamunting'])) {
      return 240; // ~4h 00m (TBS/KL <-> Taiping Kamunting)
    }
    if (matchAny(klHubs, ['lumut', 'pangkor'])) {
      return 255; // ~4h 15m (TBS/KL <-> Lumut Bus Terminal)
    }
    if (matchAny(klHubs, ['teluk intan'])) {
      return 150; // ~2h 30m (TBS/KL <-> Teluk Intan)
    }

    // ===========================================================================
    // KLANG VALLEY / KL <-> PENANG
    // ===========================================================================
    if (matchAny(klHubs, ['penang sentral', 'butterworth'])) {
      return 270; // ~4h 30m (TBS/KL <-> Penang Sentral Butterworth)
    }
    if (matchAny(klHubs, ['sungai nibong', 'komtar', 'george town'])) {
      return 300; // ~5h 00m (TBS/KL <-> Sungai Nibong Penang Island)
    }

    // ===========================================================================
    // KLANG VALLEY / KL <-> KEDAH & PERLIS
    // ===========================================================================
    if (matchAny(klHubs, ['sungai petani'])) {
      return 330; // ~5h 30m (TBS/KL <-> Sungai Petani)
    }
    if (matchAny(klHubs, ['alor setar', 'shahab perdana'])) {
      return 360; // ~6h 00m (TBS/KL <-> Shahab Perdana Alor Setar)
    }
    if (matchAny(klHubs, ['kuala kedah'])) {
      return 375; // ~6h 15m (TBS/KL <-> Kuala Kedah Jetty)
    }
    if (matchAny(klHubs, ['kangar', 'bukit lagi'])) {
      return 390; // ~6h 30m (TBS/KL <-> Kangar Bukit Lagi)
    }
    if (matchAny(klHubs, ['kuala perlis'])) {
      return 405; // ~6h 45m (TBS/KL <-> Kuala Perlis Jetty)
    }

    // ===========================================================================
    // KLANG VALLEY / KL <-> JOHOR & SINGAPORE
    // ===========================================================================
    if (matchAny(klHubs, ['muar', 'bentayan'])) {
      return 150; // ~2h 30m (TBS/KL <-> Muar)
    }
    if (matchAny(klHubs, ['batu pahat'])) {
      return 210; // ~3h 30m (TBS/KL <-> Batu Pahat)
    }
    if (matchAny(klHubs, ['kluang'])) {
      return 210; // ~3h 30m (TBS/KL <-> Kluang)
    }
    if (matchAny(klHubs, ['larkin', 'jb sentral', 'johor bahru'])) {
      return 270; // ~4h 30m (TBS/KL <-> Larkin Sentral JB)
    }
    if (matchAny(klHubs, ['woodlands', 'singapore'])) {
      return 330; // ~5h 30m (TBS/KL <-> Singapore via Larkin)
    }

    // ===========================================================================
    // KLANG VALLEY / KL <-> EAST COAST (TERENGGANU & KELANTAN)
    // ===========================================================================
    if (matchAny(klHubs, ['mbkt', 'kuala terengganu'])) {
      return 390; // ~6h 30m (TBS/KL <-> MBKT Kuala Terengganu)
    }
    if (matchAny(klHubs, ['dungun'])) {
      return 315; // ~5h 15m (TBS/KL <-> Dungun)
    }
    if (matchAny(klHubs, ['kemaman'])) {
      return 255; // ~4h 15m (TBS/KL <-> Kemaman)
    }
    if (matchAny(klHubs, ['kota bharu', 'lembah sireh'])) {
      return 480; // ~8h 00m (TBS/KL <-> Terminal Kota Bharu)
    }
    if (matchAny(klHubs, ['gua musang'])) {
      return 300; // ~5h 00m (TBS/KL <-> Gua Musang)
    }

    // ===========================================================================
    // MELAKA CONNECTIONS
    // ===========================================================================
    if (match('melaka', 'seremban')) {
      return 75; // ~1h 15m (Melaka Sentral <-> Seremban)
    }
    if (match('melaka', 'muar')) {
      return 50; // ~50m (Melaka Sentral <-> Muar)
    }
    if (match('melaka', 'batu pahat')) {
      return 90; // ~1h 30m (Melaka Sentral <-> Batu Pahat)
    }
    if (match('melaka', 'larkin') || match('melaka', 'jb sentral') || match('melaka', 'johor bahru')) {
      return 150; // ~2h 30m (Melaka Sentral <-> Larkin Sentral JB)
    }
    if (match('melaka', 'woodlands') || match('melaka', 'singapore')) {
      return 210; // ~3h 30m (Melaka Sentral <-> Singapore)
    }
    if (match('melaka', 'penang sentral') || match('melaka', 'sungai nibong') || match('melaka', 'butterworth')) {
      return 390; // ~6h 30m (Melaka Sentral <-> Penang)
    }
    if (match('melaka', 'amanjaya') || match('melaka', 'ipoh')) {
      return 285; // ~4h 45m (Melaka Sentral <-> Ipoh)
    }

    // ===========================================================================
    // NEGERI SEMBILAN CONNECTIONS
    // ===========================================================================
    if (match('seremban', 'larkin') || match('seremban', 'jb sentral') || match('seremban', 'johor bahru')) {
      return 210; // ~3h 30m (Seremban <-> Larkin JB)
    }
    if (match('seremban', 'batu pahat')) {
      return 165; // ~2h 45m (Seremban <-> Batu Pahat)
    }
    if (match('seremban', 'muar')) {
      return 120; // ~2h 00m (Seremban <-> Muar)
    }

    // ===========================================================================
    // PENANG CONNECTIONS
    // ===========================================================================
    final penangHubs = ['penang sentral', 'butterworth', 'sungai nibong', 'komtar'];
    if (matchAny(penangHubs, ['amanjaya', 'ipoh', 'meru raya'])) {
      return 135; // ~2h 15m (Penang <-> Terminal Amanjaya Ipoh)
    }
    if (matchAny(penangHubs, ['taiping', 'kamunting'])) {
      return 75; // ~1h 15m (Penang <-> Taiping)
    }
    if (matchAny(penangHubs, ['sungai petani'])) {
      return 50; // ~50m (Penang <-> Sungai Petani)
    }
    if (matchAny(penangHubs, ['alor setar', 'shahab perdana'])) {
      return 90; // ~1h 30m (Penang <-> Alor Setar)
    }
    if (matchAny(penangHubs, ['kangar', 'bukit lagi'])) {
      return 135; // ~2h 15m (Penang <-> Kangar)
    }
    if (matchAny(penangHubs, ['kuala perlis'])) {
      return 150; // ~2h 30m (Penang <-> Kuala Perlis)
    }
    if (matchAny(penangHubs, ['larkin', 'jb sentral', 'johor bahru'])) {
      return 540; // ~9h 00m (Penang <-> Larkin JB)
    }
    if (matchAny(penangHubs, ['kota bharu', 'lembah sireh'])) {
      return 390; // ~6h 30m (Penang <-> Kota Bharu via East-West Hwy)
    }
    if (matchAny(penangHubs, ['kuantan', 'tsk'])) {
      return 420; // ~7h 00m (Penang <-> Kuantan)
    }

    // ===========================================================================
    // PERAK CONNECTIONS
    // ===========================================================================
    if (match('ipoh', 'alor setar') || match('amanjaya', 'shahab perdana')) {
      return 180; // ~3h 00m (Ipoh <-> Alor Setar)
    }
    if (match('ipoh', 'kangar') || match('amanjaya', 'bukit lagi')) {
      return 210; // ~3h 30m (Ipoh <-> Kangar)
    }
    if (match('ipoh', 'cameron') || match('amanjaya', 'tanah rata')) {
      return 120; // ~2h 00m (Ipoh <-> Cameron Highlands)
    }
    if (match('ipoh', 'larkin') || match('amanjaya', 'larkin')) {
      return 420; // ~7h 00m (Ipoh <-> Larkin JB)
    }

    // ===========================================================================
    // KEDAH & PERLIS
    // ===========================================================================
    if (match('alor setar', 'kangar') || match('shahab perdana', 'bukit lagi')) {
      return 50; // ~50m (Alor Setar <-> Kangar)
    }
    if (match('alor setar', 'kuala perlis')) {
      return 60; // ~1h 00m (Alor Setar <-> Kuala Perlis)
    }
    if (match('sungai petani', 'alor setar')) {
      return 50; // ~50m (Sungai Petani <-> Alor Setar)
    }

    // ===========================================================================
    // JOHOR INTERNAL & SINGAPORE
    // ===========================================================================
    if (match('larkin', 'batu pahat')) {
      return 90; // ~1h 30m (Larkin <-> Batu Pahat)
    }
    if (match('larkin', 'muar')) {
      return 120; // ~2h 00m (Larkin <-> Muar)
    }
    if (match('larkin', 'kluang')) {
      return 75; // ~1h 15m (Larkin <-> Kluang)
    }
    if (match('larkin', 'kuantan') || match('johor bahru', 'kuantan')) {
      return 270; // ~4h 30m (Larkin <-> Kuantan)
    }
    if (match('larkin', 'woodlands') || match('larkin', 'singapore') || match('jb sentral', 'woodlands')) {
      return 45; // ~45m (Larkin/JB <-> Singapore border bus)
    }

    // ===========================================================================
    // EAST COAST INTERNAL
    // ===========================================================================
    if (match('kuala terengganu', 'kota bharu') || match('mbkt', 'lembah sireh')) {
      return 150; // ~2h 30m (Kuala Terengganu <-> Kota Bharu)
    }
    if (match('kuantan', 'kuala terengganu') || match('tsk', 'mbkt')) {
      return 180; // ~3h 00m (Kuantan <-> Kuala Terengganu)
    }

    // ===========================================================================
    // EAST MALAYSIA (SABAH & SARAWAK)
    // ===========================================================================
    if (match('inanam', 'sandakan') || (match('kinabalu', 'sandakan'))) {
      return 360; // ~6h 00m (KK Inanam <-> Sandakan)
    }
    if (match('inanam', 'tawau') || (match('kinabalu', 'tawau'))) {
      return 510; // ~8h 30m (KK Inanam <-> Tawau)
    }
    if (match('sandakan', 'tawau')) {
      return 300; // ~5h 00m (Sandakan <-> Tawau)
    }
    if (match('kuching', 'sibu')) {
      return 390; // ~6h 30m (Kuching Sentral <-> Sibu)
    }
    if (match('sibu', 'bintulu')) {
      return 210; // ~3h 30m (Sibu <-> Bintulu)
    }
    if (match('bintulu', 'miri')) {
      return 210; // ~3h 30m (Bintulu <-> Miri)
    }
    if (match('kuching', 'miri')) {
      return 780; // ~13h 00m (Kuching <-> Miri)
    }

    return null;
  }

  /// Resolves standard IATA-style 3-letter airport code from location name.
  static String? resolveAirportCode(String location) {
    final l = location.toLowerCase().trim();
    if (l.isEmpty) return null;
    if (l.contains('klia') ||
        l.contains('sepang') ||
        (l.contains('kuala lumpur') &&
            (l.contains('international') || l.contains('airport')))) {
      return 'KUL';
    }
    if (l.contains('subang') || l.contains('szb') || l.contains('abdul aziz')) {
      return 'SZB';
    }
    if (l.contains('penang') || l.contains('pen') || l.contains('bayan lepas')) {
      return 'PEN';
    }
    if (l.contains('langkawi') || l.contains('lgk')) {
      return 'LGK';
    }
    if (l.contains('senai') ||
        l.contains('jhb') ||
        (l.contains('johor') && l.contains('airport'))) {
      return 'JHB';
    }
    if (l.contains('kota bharu') ||
        l.contains('kbr') ||
        l.contains('ismail petra')) {
      return 'KBR';
    }
    if (l.contains('kuala terengganu') ||
        l.contains('tgg') ||
        l.contains('mahmud')) {
      return 'TGG';
    }
    if (l.contains('alor setar') ||
        l.contains('aor') ||
        l.contains('abdul halim')) {
      return 'AOR';
    }
    if (l.contains('kuantan') ||
        l.contains('kua') ||
        l.contains('ahmad shah')) {
      return 'KUA';
    }
    if (l.contains('ipoh') || l.contains('iph') || l.contains('azlan shah')) {
      return 'IPH';
    }
    if (l.contains('melaka') ||
        l.contains('mkz') ||
        l.contains('malacca airport')) {
      return 'MKZ';
    }
    if (l.contains('tioman') || l.contains('tod')) {
      return 'TOD';
    }
    if (l.contains('redang') || l.contains('rdn')) {
      return 'RDN';
    }
    if (l.contains('pangkor') || l.contains('pkg')) {
      return 'PKG';
    }
    if (l.contains('kinabalu') || l.contains('bki')) {
      return 'BKI';
    }
    if (l.contains('tawau') || l.contains('twu')) {
      return 'TWU';
    }
    if (l.contains('sandakan') || l.contains('sdk')) {
      return 'SDK';
    }
    if (l.contains('lahad datu') || l.contains('ldu')) {
      return 'LDU';
    }
    if (l.contains('labuan') || l.contains('lbu')) {
      return 'LBU';
    }
    if (l.contains('kuching') || l.contains('kch')) {
      return 'KCH';
    }
    if (l.contains('miri') || l.contains('myy')) {
      return 'MYY';
    }
    if (l.contains('sibu') || l.contains('sbw')) {
      return 'SBW';
    }
    if (l.contains('bintulu') || l.contains('btu')) {
      return 'BTU';
    }
    if (l.contains('mulu') || l.contains('mzv')) {
      return 'MZV';
    }
    return null;
  }

  /// Official scheduled airline block times (in minutes) for direct commercial domestic flights.
  /// Sourced from Malaysia Airlines (MH), AirAsia (AK), Batik Air (OD), Firefly (FY), and MASwings.
  static final Map<String, int> _flightPairDurations = {
    // Peninsular trunk & regional
    'KUL-PEN': 60,
    'SZB-PEN': 60,
    'KUL-LGK': 65,
    'SZB-LGK': 65,
    'KUL-AOR': 60,
    'SZB-AOR': 60,
    'KUL-JHB': 55,
    'SZB-JHB': 55,
    'KUL-KBR': 60,
    'SZB-KBR': 60,
    'KUL-TGG': 55,
    'SZB-TGG': 55,
    'KUL-KUA': 50,
    'SZB-KUA': 50,
    'SZB-IPH': 45,
    'SZB-PKG': 45,
    'SZB-TOD': 50,
    'SZB-RDN': 60,
    'PEN-LGK': 40,
    'PEN-KBR': 50,
    'PEN-JHB': 70,
    'JHB-AOR': 75,
    'JHB-LGK': 80,
    'JHB-IPH': 65,
    'LGK-KBR': 55,

    // Peninsular <-> East Malaysia
    'KUL-BKI': 155,
    'SZB-BKI': 160,
    'KUL-TWU': 175,
    'KUL-SDK': 170,
    'KUL-LBU': 145,
    'KUL-KCH': 105,
    'SZB-KCH': 110,
    'KUL-SBW': 115,
    'KUL-BTU': 125,
    'KUL-MYY': 135,
    'PEN-BKI': 175,
    'PEN-KCH': 120,
    'JHB-BKI': 145,
    'JHB-KCH': 85,
    'JHB-SBW': 95,
    'JHB-MYY': 115,
    'JHB-TWU': 160,

    // Intra-East Malaysia (Sabah / Sarawak / Labuan)
    'BKI-TWU': 50,
    'BKI-SDK': 45,
    'BKI-LDU': 55,
    'BKI-LBU': 35,
    'BKI-KCH': 85,
    'BKI-MYY': 50,
    'BKI-BTU': 60,
    'BKI-SBW': 70,
    'BKI-MZV': 55,
    'KCH-SBW': 45,
    'KCH-MYY': 65,
    'KCH-BTU': 55,
    'KCH-MZV': 85,
    'KCH-LBU': 70,
    'MYY-MZV': 30,
    'MYY-BTU': 35,
    'MYY-SBW': 45,
    'MYY-LBU': 40,
  };

  /// Looks up scheduled flight duration between two airports based on actual airline timetables.
  static int? _getFlightAirportPairDuration(String from, String to) {
    final code1 = resolveAirportCode(from);
    final code2 = resolveAirportCode(to);
    if (code1 == null || code2 == null || code1 == code2) return null;

    final key1 = '$code1-$code2';
    if (_flightPairDurations.containsKey(key1)) return _flightPairDurations[key1];
    final key2 = '$code2-$code1';
    if (_flightPairDurations.containsKey(key2)) return _flightPairDurations[key2];

    return null;
  }

  /// Checks whether a valid direct transit route exists between [fromLocation] and [toLocation]
  /// for the specified [transitType] (Bus, Train, Flight).
  /// Returns false if no direct route exists (e.g. bus/train across South China Sea,
  /// or airline pair with no commercial direct flights).
  static bool isRouteAvailable({
    required String transitType,
    required String fromLocation,
    required String toLocation,
  }) {
    final f = fromLocation.trim();
    final t = toLocation.trim();
    if (f.isEmpty || t.isEmpty) return false;
    if (f.toLowerCase() == t.toLowerCase()) return false;

    final mode = transitType.toLowerCase();

    // 1. FLIGHT
    if (mode == 'flight') {
      final code1 = resolveAirportCode(f);
      final code2 = resolveAirportCode(t);

      // If both airport codes are known, route must be in the commercial direct flight timetable
      if (code1 != null && code2 != null) {
        if (code1 == code2) return false;
        final key1 = '$code1-$code2';
        final key2 = '$code2-$code1';
        return _flightPairDurations.containsKey(key1) ||
            _flightPairDurations.containsKey(key2);
      }

      // If either location is custom/unresolved, check regional plausibility
      final fromReg = extractRegion(f);
      final toReg = extractRegion(t);
      if (fromReg == toReg && fromReg.isNotEmpty) {
        // No commercial domestic flights within the same Peninsular state
        if (fromReg != 'Sabah' && fromReg != 'Sarawak') return false;
      }
      return true;
    }

    // 2. TRAIN
    if (mode == 'train') {
      final fLower = f.toLowerCase();
      final tLower = t.toLowerCase();

      bool isSabahStation(String s) =>
          s.contains('tanjung aru') ||
          s.contains('beaufort') ||
          s.contains('tenom');

      final isFSabah = isSabahStation(fLower);
      final isTSabah = isSabahStation(tLower);

      // Sarawak and Labuan have no passenger railway system
      if (fLower.contains('sarawak') ||
          tLower.contains('sarawak') ||
          fLower.contains('kuching') ||
          tLower.contains('kuching') ||
          fLower.contains('sibu') ||
          tLower.contains('sibu') ||
          fLower.contains('miri') ||
          tLower.contains('miri') ||
          fLower.contains('bintulu') ||
          tLower.contains('bintulu') ||
          fLower.contains('labuan') ||
          tLower.contains('labuan')) {
        return false;
      }

      // Sabah State Railway operates only within Sabah
      if (isFSabah && isTSabah) return true;
      if (isFSabah != isTSabah) return false; // Cannot take train across the South China Sea

      // KTMB Peninsular network (West Coast + East Coast Line)
      final fromReg = extractRegion(f);
      final toReg = extractRegion(t);
      if (fromReg == 'Sabah' ||
          toReg == 'Sabah' ||
          fromReg == 'Sarawak' ||
          toReg == 'Sarawak') {
        return false;
      }
      return true;
    }

    // 3. BUS
    if (mode == 'bus') {
      final fromReg = extractRegion(f);
      final toReg = extractRegion(t);

      final isFromSabah = fromReg == 'Sabah';
      final isToSabah = toReg == 'Sabah';
      final isFromSarawak = fromReg == 'Sarawak';
      final isToSarawak = toReg == 'Sarawak';
      final isFromEast = isFromSabah || isFromSarawak;
      final isToEast = isToSabah || isToSarawak;

      // Cannot take bus across South China Sea (Peninsular <-> Borneo)
      if (isFromEast != isToEast) return false;

      // Sabah buses only connect within Sabah
      if (isFromSabah && !isToSabah) return false;
      if (isToSabah && !isFromSabah) return false;

      // Sarawak buses only connect within Sarawak
      if (isFromSarawak && !isToSarawak) return false;
      if (isToSarawak && !isFromSarawak) return false;

      return true;
    }

    return true;
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
      // 1a. Direct airport pair matching using real airline schedule block times
      final directFlightMin = _getFlightAirportPairDuration(
        fromLocation ?? '',
        toLocation ?? '',
      );
      if (directFlightMin != null) {
        return directFlightMin;
      }

      // 1b. Region-level fallback based on airline averages
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
      return 60; // ~1h 00m
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
    if (mode == 'bus') {
      // 3a. Direct terminal pair matching
      final stationDuration = _getBusStationPairDuration(
        fromLocation ?? '',
        toLocation ?? '',
      );
      if (stationDuration != null) {
        return stationDuration;
      }

      // 3b. Region-level fallback
      // Treat Selangor & Putrajaya as Greater Klang Valley (Kuala Lumpur) for express bus routes
      final normFrom = (fromRegion == 'Selangor' || fromRegion == 'Putrajaya')
          ? 'Kuala Lumpur'
          : fromRegion;
      final normTo = (toRegion == 'Selangor' || toRegion == 'Putrajaya')
          ? 'Kuala Lumpur'
          : toRegion;
      final pair = {normFrom, normTo};

      // Greater KL connections
      if (pair.contains('Kuala Lumpur') && pair.contains('Negeri Sembilan')) {
        return 60; // ~1h 00m (TBS <-> Seremban)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Melaka')) {
        return 135; // ~2h 15m (TBS <-> Melaka Sentral)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Pahang')) {
        final locStr = '${fromLocation ?? ''} ${toLocation ?? ''}'.toLowerCase();
        if (locStr.contains('genting')) {
          return 75; // ~1h 15m (KL <-> Genting)
        }
        if (locStr.contains('cameron') || locStr.contains('tanah rata')) {
          return 270; // ~4h 30m (TBS <-> Cameron Highlands)
        }
        if (locStr.contains('temerloh')) {
          return 120; // ~2h 00m (TBS <-> Temerloh)
        }
        return 210; // ~3h 30m (TBS <-> Kuantan)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Perak')) {
        return 195; // ~3h 15m (TBS <-> Terminal Amanjaya Ipoh)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Penang')) {
        return 270; // ~4h 30m (TBS <-> Penang Sentral / Sungai Nibong)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Johor')) {
        return 270; // ~4h 30m (TBS <-> Larkin Sentral JB)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Kedah')) {
        return 360; // ~6h 00m (TBS <-> Alor Setar)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Perlis')) {
        return 390; // ~6h 30m (TBS <-> Kangar / Kuala Perlis)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Terengganu')) {
        return 390; // ~6h 30m (TBS <-> MBKT Kuala Terengganu)
      }
      if (pair.contains('Kuala Lumpur') && pair.contains('Kelantan')) {
        return 480; // ~8h 00m (TBS <-> Kota Bharu)
      }

      // Melaka connections
      if (pair.contains('Melaka') && pair.contains('Johor')) {
        return 150; // ~2h 30m (Melaka Sentral <-> Larkin JB)
      }
      if (pair.contains('Melaka') && pair.contains('Negeri Sembilan')) {
        return 75; // ~1h 15m (Melaka Sentral <-> Seremban)
      }

      // Negeri Sembilan connections
      if (pair.contains('Negeri Sembilan') && pair.contains('Johor')) {
        return 210; // ~3h 30m (Seremban <-> Larkin JB)
      }

      // Penang & Northern Corridor connections
      if (pair.contains('Penang') && pair.contains('Perak')) {
        return 135; // ~2h 15m (Penang <-> Ipoh)
      }
      if (pair.contains('Penang') && pair.contains('Kedah')) {
        return 90; // ~1h 30m (Penang <-> Alor Setar)
      }
      if (pair.contains('Penang') && pair.contains('Perlis')) {
        return 135; // ~2h 15m (Penang <-> Kangar)
      }
      if (pair.contains('Penang') && pair.contains('Melaka')) {
        return 390; // ~6h 30m (Penang <-> Melaka)
      }
      if (pair.contains('Penang') && pair.contains('Johor')) {
        return 540; // ~9h 00m (Penang <-> JB)
      }
      if (pair.contains('Penang') && pair.contains('Kelantan')) {
        return 390; // ~6h 30m (Penang <-> Kota Bharu)
      }

      // Perak connections
      if (pair.contains('Perak') && pair.contains('Kedah')) {
        return 180; // ~3h 00m (Ipoh <-> Alor Setar)
      }
      if (pair.contains('Perak') && pair.contains('Perlis')) {
        return 210; // ~3h 30m (Ipoh <-> Kangar)
      }
      if (pair.contains('Perak') && pair.contains('Pahang')) {
        return 150; // ~2h 30m (Ipoh <-> Cameron Highlands)
      }

      // Kedah & Perlis
      if (pair.contains('Kedah') && pair.contains('Perlis')) {
        return 50; // ~50m (Alor Setar <-> Kangar)
      }

      // East Coast connections
      if (pair.contains('Terengganu') && pair.contains('Kelantan')) {
        return 150; // ~2h 30m (Kuala Terengganu <-> Kota Bharu)
      }
      if (pair.contains('Pahang') && pair.contains('Terengganu')) {
        return 180; // ~3h 00m (Kuantan <-> Kuala Terengganu)
      }
      if (pair.contains('Johor') && pair.contains('Pahang')) {
        return 270; // ~4h 30m (JB <-> Kuantan)
      }

      // East Malaysia internal
      if (pair.contains('Sabah')) {
        return 360; // ~6h 00m (e.g. KK <-> Sandakan)
      }
      if (pair.contains('Sarawak')) {
        return 360; // ~6h 00m (e.g. Kuching <-> Sibu)
      }

      return 240; // ~4h 00m default bus duration
    }

    return 240; // Default fallback for any other transit mode
  }

  /// Looks up geographical coordinates [lat, lng] for major Malaysian transit hubs.
  static List<double>? getHubCoordinates(String location) {
    final l = location.toLowerCase();

    // Commercial Airports
    if (l.contains('klia') || (l.contains('kuala lumpur') && l.contains('international'))) {
      return [2.7456, 101.7072]; // KLIA / KLIA2
    }
    if (l.contains('subang') || l.contains('szb')) {
      return [3.1306, 101.5489]; // Subang Airport (SZB)
    }
    if (l.contains('pen') || (l.contains('penang') && l.contains('airport'))) {
      return [5.2971, 100.2769]; // Penang Airport (PEN)
    }
    if (l.contains('lgk') || (l.contains('langkawi') && l.contains('airport'))) {
      return [6.3297, 99.7287]; // Langkawi Airport (LGK)
    }
    if (l.contains('jhb') || (l.contains('senai') && l.contains('airport'))) {
      return [1.6413, 103.6698]; // Senai Airport (JHB)
    }
    if (l.contains('bki') || (l.contains('kinabalu') && l.contains('airport'))) {
      return [5.9372, 116.0512]; // Kota Kinabalu Airport (BKI)
    }
    if (l.contains('kch') || (l.contains('kuching') && l.contains('airport'))) {
      return [1.4847, 110.3472]; // Kuching Airport (KCH)
    }
    if (l.contains('kbr') || (l.contains('ismail petra') && l.contains('airport'))) {
      return [6.1664, 102.2933]; // Kota Bharu Airport (KBR)
    }
    if (l.contains('tgg') || (l.contains('mahmud') && l.contains('airport'))) {
      return [5.3826, 103.1030]; // Kuala Terengganu Airport (TGG)
    }
    if (l.contains('aor') || (l.contains('abdul halim') && l.contains('airport'))) {
      return [6.1897, 100.3986]; // Alor Setar Airport (AOR)
    }
    if (l.contains('kua') || (l.contains('ahmad shah') && l.contains('airport'))) {
      return [3.7792, 103.2094]; // Kuantan Airport (KUA)
    }
    if (l.contains('iph') || (l.contains('azlan shah') && l.contains('airport'))) {
      return [4.5680, 101.0919]; // Ipoh Airport (IPH)
    }
    if (l.contains('twu') || (l.contains('tawau') && l.contains('airport'))) {
      return [4.3202, 118.1213]; // Tawau Airport (TWU)
    }
    if (l.contains('sdk') || (l.contains('sandakan') && l.contains('airport'))) {
      return [5.9008, 118.0594]; // Sandakan Airport (SDK)
    }
    if (l.contains('myy') || (l.contains('miri') && l.contains('airport'))) {
      return [4.3220, 113.9870]; // Miri Airport (MYY)
    }
    if (l.contains('sbw') || (l.contains('sibu') && l.contains('airport'))) {
      return [2.2612, 111.9856]; // Sibu Airport (SBW)
    }
    if (l.contains('btu') || (l.contains('bintulu') && l.contains('airport'))) {
      return [3.1239, 113.0205]; // Bintulu Airport (BTU)
    }
    if (l.contains('lbu') || (l.contains('labuan') && l.contains('airport'))) {
      return [5.3007, 115.2503]; // Labuan Airport (LBU)
    }
    if (l.contains('mzv') || (l.contains('mulu') && l.contains('airport'))) {
      return [4.0489, 114.8118]; // Mulu Airport (MZV)
    }
    if (l.contains('ldu') || (l.contains('lahad datu') && l.contains('airport'))) {
      return [5.0322, 118.3242]; // Lahad Datu Airport (LDU)
    }

    // Kuala Lumpur & Selangor
    if (l.contains('tbs') ||
        (l.contains('kuala lumpur') && (l.contains('bus') || l.contains('terminal')))) {
      return [3.0768, 101.7107]; // TBS KL
    }
    if (l.contains('duta')) {
      return [3.1818, 101.6748]; // Hentian Duta KL
    }
    if (l.contains('pekeliling')) {
      return [3.1736, 101.6986]; // Pekeliling Bus Terminal KL
    }
    if (l.contains('kl sentral') || l.contains('kuala lumpur')) {
      return [3.1342, 101.6865]; // KL Sentral
    }
    if (l.contains('shah alam')) {
      return [3.0565, 101.5126]; // Terminal Shah Alam Seksyen 17
    }
    if (l.contains('klang')) {
      return [3.0901, 101.4427]; // Klang Sentral
    }
    if (l.contains('kajang')) {
      return [2.9833, 101.7895]; // Terminal Bas Kajang
    }
    if (l.contains('putrajaya')) {
      return [2.9324, 101.6702]; // Putrajaya Sentral
    }

    // Penang
    if (l.contains('penang sentral') || l.contains('butterworth')) {
      return [5.3942, 100.3685]; // Penang Sentral
    }
    if (l.contains('sungai nibong') || l.contains('komtar') || l.contains('penang')) {
      return [5.3427, 100.2982]; // Sungai Nibong Penang
    }

    // Perak
    if (l.contains('amanjaya') || l.contains('ipoh') || l.contains('meru raya')) {
      return [4.6711, 101.0715]; // Terminal Amanjaya Ipoh
    }
    if (l.contains('taiping') || l.contains('kamunting')) {
      return [4.8872, 100.7303]; // Taiping Kamunting Bus Terminal
    }
    if (l.contains('lumut') || l.contains('pangkor')) {
      return [4.2325, 100.6315]; // Terminal Bas Lumut
    }
    if (l.contains('teluk intan')) {
      return [4.0258, 101.0208]; // Teluk Intan Bus Terminal
    }

    // Melaka
    if (l.contains('melaka') || l.contains('malacca')) {
      return [2.2201, 102.2476]; // Melaka Sentral
    }

    // Johor
    if (l.contains('larkin') || l.contains('jb sentral') || (l.contains('johor') && l.contains('bahru'))) {
      return [1.4957, 103.7431]; // Larkin Sentral JB
    }
    if (l.contains('muar') || l.contains('bentayan')) {
      return [2.0465, 102.5692]; // Muar Bus Terminal (Bentayan)
    }
    if (l.contains('batu pahat')) {
      return [1.8548, 102.9325]; // Batu Pahat Bus Terminal
    }
    if (l.contains('kluang')) {
      return [2.0298, 103.3218]; // Terminal Bas Kluang
    }

    // Negeri Sembilan
    if (l.contains('seremban') || l.contains('terminal one') || l.contains('negeri sembilan')) {
      return [2.7247, 101.9392]; // Terminal 1 Seremban
    }
    if (l.contains('port dickson')) {
      return [2.5226, 101.7972]; // Port Dickson Bus Terminal
    }

    // Pahang
    if (l.contains('genting')) {
      return [3.4243, 101.7942]; // Genting Highlands Awana
    }
    if (l.contains('cameron') || l.contains('tanah rata')) {
      return [4.4697, 101.3789]; // Cameron Highlands (Tanah Rata)
    }
    if (l.contains('kuantan') || l.contains('tsk')) {
      return [3.8291, 103.2758]; // Terminal Sentral Kuantan
    }
    if (l.contains('temerloh')) {
      return [3.4497, 102.4172]; // Temerloh Bus Terminal
    }

    // Kedah & Perlis
    if (l.contains('shahab perdana') || l.contains('alor setar') || l.contains('kedah')) {
      return [6.1362, 100.3732]; // Terminal Shahab Perdana
    }
    if (l.contains('sungai petani')) {
      return [5.6436, 100.4878]; // Sungai Petani Bus Terminal
    }
    if (l.contains('kuala kedah')) {
      return [6.1085, 100.2936]; // Kuala Kedah Bus Terminal
    }
    if (l.contains('kangar') || l.contains('bukit lagi') || l.contains('perlis')) {
      return [6.4385, 100.1982]; // Bukit Lagi Bus Terminal (Kangar)
    }
    if (l.contains('kuala perlis')) {
      return [6.3986, 100.1332]; // Kuala Perlis Bus Terminal
    }

    // East Coast (Terengganu & Kelantan)
    if (l.contains('mbkt') || l.contains('kuala terengganu') || l.contains('terengganu')) {
      return [5.3308, 103.1415]; // MBKT Kuala Terengganu
    }
    if (l.contains('dungun')) {
      return [4.7758, 103.4184]; // Dungun Bus Terminal
    }
    if (l.contains('kemaman')) {
      return [4.2319, 103.4214]; // Kemaman Bus Terminal
    }
    if (l.contains('kota bharu') || l.contains('lembah sireh') || l.contains('kelantan')) {
      return [6.1264, 102.2483]; // Terminal Kota Bharu
    }
    if (l.contains('gua musang')) {
      return [4.8789, 101.9682]; // Gua Musang Bus Terminal
    }

    // Sabah & Sarawak
    if (l.contains('inanam') || l.contains('kinabalu') || l.contains('sabah')) {
      return [5.9868, 116.1347]; // Inanam Bus Terminal
    }
    if (l.contains('sandakan')) {
      return [5.8402, 118.0645]; // Sandakan Express Bus Terminal
    }
    if (l.contains('tawau')) {
      return [4.2447, 117.8912]; // Tawau Express Bus Terminal
    }
    if (l.contains('kuching sentral') || l.contains('kuching') || l.contains('sarawak')) {
      return [1.4721, 110.3342]; // Kuching Sentral
    }
    if (l.contains('sibu')) {
      return [2.3168, 111.8488]; // Sibu Bus Terminal
    }
    if (l.contains('bintulu')) {
      return [3.1895, 113.0456]; // Bintulu Bus Terminal
    }
    if (l.contains('miri')) {
      return [4.3995, 113.9914]; // Miri Long Distance Bus Terminal
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
