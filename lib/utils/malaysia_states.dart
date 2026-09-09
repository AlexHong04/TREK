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
const Map<String, List<String>> destinationTransitHubs = {
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

const List<String> defaultMalaysiaTransitHubs = [
  'Kuala Lumpur International Airport (KLIA / KLIA2)',
  'Penang International Airport (PEN)',
  'Kota Kinabalu International Airport (BKI)',
  'Kuching International Airport (KCH)',
  'Senai International Airport (JHB)',
  'Langkawi International Airport (LGK)',
  'Sultan Abdul Aziz Shah Airport (Subang Airport - SZB)',
];

/// Returns transit hubs tailored to the user's selected destinations and optional query.
List<String> getTransitHubSuggestions(List<String> destinations, {String query = ''}) {
  final cleanQuery = query.trim().toLowerCase();
  final Set<String> results = {};

  // 1. Gather destination-specific hubs
  for (final dest in destinations) {
    final trimmedDest = dest.trim();
    if (trimmedDest.isEmpty) continue;
    final lowerDest = trimmedDest.toLowerCase();

    for (final entry in destinationTransitHubs.entries) {
      final entryLower = entry.key.toLowerCase();
      if (entryLower == lowerDest ||
          lowerDest.contains(entryLower) ||
          entryLower.contains(lowerDest) ||
          (lowerDest.contains('kuala lumpur') && (entry.key == 'Kuala Lumpur' || entry.key == 'Selangor')) ||
          (lowerDest.contains('kl') && (entry.key == 'Kuala Lumpur' || entry.key == 'Selangor')) ||
          (lowerDest.contains('putrajaya') && (entry.key == 'Putrajaya' || entry.key == 'Selangor')) ||
          (lowerDest.contains('langkawi') && entry.key == 'Kedah') ||
          (lowerDest.contains('cameron') && entry.key == 'Pahang') ||
          (lowerDest.contains('genting') && entry.key == 'Pahang')) {
        results.addAll(entry.value);
      }
    }
  }

  // 2. If no destination matched, supply default major hubs
  if (results.isEmpty) {
    results.addAll(defaultMalaysiaTransitHubs);
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

/// Returns all unique commercial airports across Malaysia in alphabetical order.
List<String> getAllMalaysiaAirports() {
  final Set<String> all = {};
  for (final list in destinationTransitHubs.values) {
    all.addAll(list);
  }
  for (final hub in defaultMalaysiaTransitHubs) {
    all.add(hub);
  }
  final sorted = all.toList()..sort();
  return sorted;
}

