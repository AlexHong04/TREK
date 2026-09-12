class MalaysiaState {
  final String name;
  final String category;

  const MalaysiaState({required this.name, this.category = 'State'});
}

/// States and Federal Territories of Malaysia.
const List<MalaysiaState> allMalaysiaDestinations = [
  MalaysiaState(name: 'Johor'),
  MalaysiaState(name: 'Kedah'),
  MalaysiaState(name: 'Kelantan'),
  MalaysiaState(name: 'Kuala Lumpur', category: 'Federal Territory'),
  MalaysiaState(name: 'Labuan', category: 'Federal Territory'),
  MalaysiaState(name: 'Melaka'),
  MalaysiaState(name: 'Negeri Sembilan'),
  MalaysiaState(name: 'Pahang'),
  MalaysiaState(name: 'Penang'),
  MalaysiaState(name: 'Perak'),
  MalaysiaState(name: 'Perlis'),
  MalaysiaState(name: 'Putrajaya', category: 'Federal Territory'),
  MalaysiaState(name: 'Sabah'),
  MalaysiaState(name: 'Sarawak'),
  MalaysiaState(name: 'Selangor'),
  MalaysiaState(name: 'Terengganu'),
];

/// List of state and federal territory names for quick lookup and autocomplete
const List<String> malaysiaStateNames = [
  'Johor',
  'Kedah',
  'Kelantan',
  'Kuala Lumpur',
  'Labuan',
  'Melaka',
  'Negeri Sembilan',
  'Pahang',
  'Penang',
  'Perak',
  'Perlis',
  'Putrajaya',
  'Sabah',
  'Sarawak',
  'Selangor',
  'Terengganu',
];

/// Major commercial airports organized by destination in Malaysia.
const Map<String, List<String>> destinationAirports = {
  'Johor': [
    'Senai International Airport (JHB)',
  ],
  'Kedah': [
    'Langkawi International Airport (LGK)',
    'Sultan Abdul Halim Airport, Alor Setar (AOR)',
  ],
  'Kelantan': [
    'Sultan Ismail Petra Airport, Kota Bharu (KBR)',
  ],
  'Kuala Lumpur': [
    'Kuala Lumpur International Airport (KLIA / KLIA2)',
    'Sultan Abdul Aziz Shah Airport (Subang Airport - SZB)',
  ],
  'Labuan': [
    'Labuan Airport (LBU)',
  ],
  'Melaka': [
    'Melaka International Airport (MKZ)',
  ],
  'Negeri Sembilan': [
    'Kuala Lumpur International Airport (KLIA / KLIA2)',
  ],
  'Pahang': [
    'Sultan Haji Ahmad Shah Airport, Kuantan (KUA)',
    'Tioman Airport (TOD)',
  ],
  'Penang': [
    'Penang International Airport (PEN)',
  ],
  'Perak': [
    'Sultan Azlan Shah Airport, Ipoh (IPH)',
    'Pangkor Island Airport (PKG)',
  ],
  'Perlis': [
    'Sultan Abdul Halim Airport, Alor Setar (AOR)',
    'Penang International Airport (PEN)',
  ],
  'Putrajaya': [
    'Kuala Lumpur International Airport (KLIA / KLIA2)',
  ],
  'Sabah': [
    'Kota Kinabalu International Airport (BKI)',
    'Tawau Airport (TWU)',
    'Sandakan Airport (SDK)',
    'Lahad Datu Airport (LDU)',
  ],
  'Sarawak': [
    'Kuching International Airport (KCH)',
    'Miri Airport (MYY)',
    'Sibu Airport (SBW)',
    'Bintulu Airport (BTU)',
    'Mulu Airport (MZV)',
  ],
  'Selangor': [
    'Kuala Lumpur International Airport (KLIA / KLIA2)',
    'Sultan Abdul Aziz Shah Airport (Subang Airport - SZB)',
  ],
  'Terengganu': [
    'Sultan Mahmud Airport, Kuala Terengganu (TGG)',
    'Redang Airport (RDN)',
  ],
};

/// Backward compatibility alias
const Map<String, List<String>> destinationTransitHubs = destinationAirports;

/// Major railway stations organized by destination in Malaysia.
const Map<String, List<String>> destinationTrainStations = {
  'Johor': [
    'JB Sentral Railway Station (Johor Bahru)',
    'Kluang Railway Station',
    'Segamat Railway Station',
    'Kulai Railway Station',
    'Kempas Baru Station',
  ],
  'Kedah': [
    'Alor Setar Railway Station',
    'Sungai Petani Railway Station',
    'Gurun Railway Station',
    'Anak Bukit Railway Station',
  ],
  'Kelantan': [
    'Wakaf Bharu Railway Station (Kota Bharu)',
    'Tumpat Railway Station',
    'Dabong Railway Station',
    'Gua Musang Railway Station',
  ],
  'Kuala Lumpur': [
    'KL Sentral (Kuala Lumpur)',
    'Kuala Lumpur Railway Station (Old Station)',
    'Bandar Tasik Selatan (TBS / ERL / KTM)',
    'Kepong Sentral Station',
  ],
  'Melaka': [
    'Pulau Sebang / Tampin Railway Station (Gateway to Melaka)',
    'Batang Melaka Railway Station',
  ],
  'Negeri Sembilan': [
    'Seremban Railway Station',
    'Gemas Railway Station',
    'Nilai Railway Station',
    'Rembau Railway Station',
  ],
  'Pahang': [
    'Mentakab Railway Station',
    'Jerantut Railway Station (Taman Negara)',
    'Kuala Lipis Railway Station',
  ],
  'Penang': [
    'Butterworth Railway Station (Penang Sentral)',
    'Bukit Mertajam Railway Station',
    'Nibong Tebal Railway Station',
  ],
  'Perak': [
    'Ipoh Railway Station',
    'Taiping Railway Station',
    'Batu Gajah Railway Station',
    'Kampar Railway Station',
    'Tanjung Malim Railway Station',
    'Kuala Kangsar Railway Station',
    'Tapah Road Railway Station',
  ],
  'Perlis': [
    'Arau Railway Station (Gateway to Langkawi)',
    'Padang Besar Railway Station',
  ],
  'Putrajaya': [
    'Putrajaya Sentral (ERL / MRT)',
  ],
  'Sabah': [
    'Tanjung Aru Railway Station (Kota Kinabalu)',
    'Beaufort Railway Station',
    'Tenom Railway Station',
  ],
  'Selangor': [
    'KL Sentral (Main Hub)',
    'Subang Jaya Station',
    'Kajang Railway Station (MRT / KTM)',
    'Rawang Railway Station',
    'Klang Railway Station',
  ],
};

/// Major express bus terminals organized by destination in Malaysia.
const Map<String, List<String>> destinationBusTerminals = {
  'Johor': [
    'Larkin Sentral Bus Terminal (Johor Bahru)',
    'JB Sentral Bus Terminal',
    'Terminal Bas Kluang',
    'Batu Pahat Bus Terminal',
    'Muar Bus Terminal (Bentayan)',
  ],
  'Kedah': [
    'Shahab Perdana Bus Terminal (Alor Setar)',
    'Sungai Petani Bus Terminal',
    'Kuah Jetty Bus Terminal (Langkawi)',
    'Kuala Kedah Bus Terminal',
  ],
  'Kelantan': [
    'Terminal Bas Kota Bharu (Lembah Sireh)',
    'Gua Musang Bus Terminal',
  ],
  'Kuala Lumpur': [
    'Terminal Bersepadu Selatan (TBS - Kuala Lumpur)',
    'Hentian Duta Bus Terminal',
    'Pekeliling Bus Terminal',
  ],
  'Labuan': [
    'Labuan Ferry & Bus Terminal',
  ],
  'Melaka': [
    'Melaka Sentral Bus Terminal',
  ],
  'Negeri Sembilan': [
    'Terminal One Seremban',
    'Port Dickson Bus Terminal',
  ],
  'Pahang': [
    'Terminal Sentral Kuantan (TSK)',
    'Tanah Rata Bus Terminal (Cameron Highlands)',
    'Genting Highlands Awana Bus Terminal',
    'Temerloh Bus Terminal',
  ],
  'Penang': [
    'Penang Sentral Bus Terminal (Butterworth)',
    'Sungai Nibong Bus Terminal (Penang Island)',
    'Komtar Bus Terminal (George Town)',
  ],
  'Perak': [
    'Terminal Amanjaya (Ipoh)',
    'Taiping Bus Terminal (Kamunting)',
    'Terminal Bas Lumut (Pangkor Gateway)',
    'Teluk Intan Bus Terminal',
  ],
  'Perlis': [
    'Bukit Lagi Bus Terminal (Kangar)',
    'Kuala Perlis Bus Terminal',
  ],
  'Putrajaya': [
    'Putrajaya Sentral Bus Terminal',
  ],
  'Sabah': [
    'Inanam Bus Terminal (Kota Kinabalu - North)',
    'City Bus Terminal (South - Kota Kinabalu)',
    'Sandakan Express Bus Terminal',
    'Tawau Express Bus Terminal',
  ],
  'Sarawak': [
    'Kuching Sentral Bus Terminal',
    'Sibu Bus Terminal',
    'Miri Long Distance Bus Terminal',
    'Bintulu Bus Terminal',
  ],
  'Selangor': [
    'Terminal Shah Alam (Seksyen 17)',
    'Klang Sentral Bus Terminal',
    'Terminal Bas Kajang',
  ],
  'Terengganu': [
    'Terminal Bas MBKT (Kuala Terengganu)',
    'Dungun Bus Terminal',
    'Kemaman Bus Terminal',
  ],
};

const List<String> defaultMalaysiaAirports = [
  'Kuala Lumpur International Airport (KLIA / KLIA2)',
  'Penang International Airport (PEN)',
  'Kota Kinabalu International Airport (BKI)',
  'Kuching International Airport (KCH)',
  'Senai International Airport (JHB)',
  'Langkawi International Airport (LGK)',
  'Sultan Abdul Aziz Shah Airport (Subang Airport - SZB)',
];

/// Backward compatibility alias
const List<String> defaultMalaysiaTransitHubs = defaultMalaysiaAirports;

const List<String> defaultMalaysiaTrainStations = [
  'KL Sentral (Kuala Lumpur)',
  'Butterworth Railway Station (Penang Sentral)',
  'Ipoh Railway Station',
  'JB Sentral Railway Station (Johor Bahru)',
  'Arau Railway Station (Gateway to Langkawi)',
  'Seremban Railway Station',
  'Gemas Railway Station',
  'Putrajaya Sentral (ERL / MRT)',
];

const List<String> defaultMalaysiaBusTerminals = [
  'Terminal Bersepadu Selatan (TBS - Kuala Lumpur)',
  'Penang Sentral Bus Terminal (Butterworth)',
  'Larkin Sentral Bus Terminal (Johor Bahru)',
  'Terminal Amanjaya (Ipoh)',
  'Melaka Sentral Bus Terminal',
  'Terminal Sentral Kuantan (TSK)',
  'Sungai Nibong Bus Terminal (Penang Island)',
  'Hentian Duta Bus Terminal',
];

/// Returns transit hubs tailored to the user's selected destinations, transport mode, and optional query.
List<String> getTransitHubSuggestions(
  List<String> destinations, {
  String transitType = 'Flight',
  String query = '',
}) {
  final cleanQuery = query.trim().toLowerCase();
  final Set<String> results = {};

  final isTrain = transitType.toLowerCase() == 'train';
  final isBus = transitType.toLowerCase() == 'bus';

  final Map<String, List<String>> targetMap = isTrain
      ? destinationTrainStations
      : (isBus ? destinationBusTerminals : destinationAirports);

  final List<String> defaultList = isTrain
      ? defaultMalaysiaTrainStations
      : (isBus ? defaultMalaysiaBusTerminals : defaultMalaysiaAirports);

  // 1. Gather destination-specific hubs
  for (final dest in destinations) {
    final trimmedDest = dest.trim();
    if (trimmedDest.isEmpty) continue;
    final lowerDest = trimmedDest.toLowerCase();

    for (final entry in targetMap.entries) {
      final entryLower = entry.key.toLowerCase();
      if (entryLower == lowerDest ||
          lowerDest.contains(entryLower) ||
          entryLower.contains(lowerDest) ||
          (lowerDest.contains('kuala lumpur') &&
              (entry.key == 'Kuala Lumpur' || entry.key == 'Selangor')) ||
          (lowerDest.contains('kl') &&
              (entry.key == 'Kuala Lumpur' || entry.key == 'Selangor')) ||
          (lowerDest.contains('putrajaya') &&
              (entry.key == 'Putrajaya' || entry.key == 'Selangor')) ||
          (lowerDest.contains('langkawi') &&
              (entry.key == 'Kedah' || entry.key == 'Perlis')) ||
          (lowerDest.contains('cameron') && entry.key == 'Pahang') ||
          (lowerDest.contains('genting') && entry.key == 'Pahang')) {
        results.addAll(entry.value);
      }
    }
  }

  // 2. If no destination matched, supply default major hubs
  if (results.isEmpty) {
    results.addAll(defaultList);
  }

  // 3. If query is provided, filter by query
  if (cleanQuery.isNotEmpty) {
    final filtered = results
        .where((hub) => hub.toLowerCase().contains(cleanQuery))
        .toList();
    return filtered;
  }

  return results.toList();
}

/// Returns all transit hubs for a given transit mode.
List<String> getAllTransitHubs({String transitType = 'Flight'}) {
  final isTrain = transitType.toLowerCase() == 'train';
  final isBus = transitType.toLowerCase() == 'bus';

  if (isTrain) {
    return getAllMalaysiaTrainStations();
  } else if (isBus) {
    return getAllMalaysiaBusTerminals();
  } else {
    return getAllMalaysiaAirports();
  }
}

/// Returns all unique commercial airports across Malaysia in alphabetical order.
List<String> getAllMalaysiaAirports() {
  final Set<String> all = {};
  for (final list in destinationAirports.values) {
    all.addAll(list);
  }
  for (final hub in defaultMalaysiaAirports) {
    all.add(hub);
  }
  final sorted = all.toList()..sort();
  return sorted;
}

/// Returns all unique railway stations across Malaysia in alphabetical order.
List<String> getAllMalaysiaTrainStations() {
  final Set<String> all = {};
  for (final list in destinationTrainStations.values) {
    all.addAll(list);
  }
  for (final hub in defaultMalaysiaTrainStations) {
    all.add(hub);
  }
  final sorted = all.toList()..sort();
  return sorted;
}

/// Returns all unique express bus terminals across Malaysia in alphabetical order.
List<String> getAllMalaysiaBusTerminals() {
  final Set<String> all = {};
  for (final list in destinationBusTerminals.values) {
    all.addAll(list);
  }
  for (final hub in defaultMalaysiaBusTerminals) {
    all.add(hub);
  }
  final sorted = all.toList()..sort();
  return sorted;
}
