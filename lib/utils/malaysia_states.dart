class MalaysiaState {
  final String name;
  final String category;

  const MalaysiaState({required this.name, this.category = 'State'});
}

/// 13 States of Malaysia.
const List<MalaysiaState> allMalaysiaDestinations = [
  MalaysiaState(name: 'Johor'),
  MalaysiaState(name: 'Kedah'),
  MalaysiaState(name: 'Kelantan'),
  MalaysiaState(name: 'Melaka'),
  MalaysiaState(name: 'Negeri Sembilan'),
  MalaysiaState(name: 'Pahang'),
  MalaysiaState(name: 'Penang'),
  MalaysiaState(name: 'Perak'),
  MalaysiaState(name: 'Perlis'),
  MalaysiaState(name: 'Sabah'),
  MalaysiaState(name: 'Sarawak'),
  MalaysiaState(name: 'Selangor'),
  MalaysiaState(name: 'Terengganu'),
];

/// Simple list of 13 state names for quick lookup and autocomplete
const List<String> malaysiaStateNames = [
  'Johor',
  'Kedah',
  'Kelantan',
  'Melaka',
  'Negeri Sembilan',
  'Pahang',
  'Penang',
  'Perak',
  'Perlis',
  'Sabah',
  'Sarawak',
  'Selangor',
  'Terengganu',
];
