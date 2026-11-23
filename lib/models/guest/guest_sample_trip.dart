/// Built-in demo trip shown in guest preview mode.
///
/// Guest mode has no account and no backend, so nothing here touches Supabase,
/// Gemini or the device. The numbers are fixed and self-consistent so the
/// preview always looks the same.
class GuestSampleActivity {
  final String time;
  final String title;
  final String note;
  final String category;
  final double allocated;

  /// What was "spent" so far. Null for activities still ahead in the demo.
  final double? spent;

  const GuestSampleActivity({
    required this.time,
    required this.title,
    required this.note,
    required this.category,
    required this.allocated,
    this.spent,
  });

  bool get isOverspent => spent != null && spent! > allocated;
}

class GuestSampleDay {
  final int dayNumber;
  final String heading;
  final List<GuestSampleActivity> activities;

  const GuestSampleDay({
    required this.dayNumber,
    required this.heading,
    required this.activities,
  });

  double get allocated => activities.fold(0.0, (s, a) => s + a.allocated);
  double get spent => activities.fold(0.0, (s, a) => s + (a.spent ?? 0.0));
}

class GuestSampleTrip {
  GuestSampleTrip._();

  static const String destination = 'George Town, Penang';
  static const String dates = '3 days';
  static const double totalBudget = 300.0;
  static const String currency = 'RM';

  static const List<GuestSampleDay> days = [
    GuestSampleDay(
      dayNumber: 1,
      heading: 'Heritage & street food',
      activities: [
        GuestSampleActivity(
          time: '09:00 AM',
          title: 'Nasi kandar breakfast',
          note: 'Classic Penang curry-and-rice breakfast at a local kopitiam.',
          category: 'Restaurant',
          allocated: 15,
          spent: 14.5,
        ),
        GuestSampleActivity(
          time: '10:30 AM',
          title: 'George Town street art walk',
          note: 'Self-guided walk past the famous wall murals and shophouses.',
          category: 'Attraction',
          allocated: 0,
          spent: 0,
        ),
        GuestSampleActivity(
          time: '01:00 PM',
          title: 'Cendol and char kway teow lunch',
          note: 'Hawker lunch near Lebuh Kimberley.',
          category: 'Restaurant',
          allocated: 20,
          spent: 24,
        ),
        GuestSampleActivity(
          time: '03:00 PM',
          title: 'Khoo Kongsi clan house',
          note: 'Ornate Hokkien clan temple and museum.',
          category: 'Attraction',
          allocated: 25,
          spent: 25,
        ),
      ],
    ),
    GuestSampleDay(
      dayNumber: 2,
      heading: 'Hills & temples',
      activities: [
        GuestSampleActivity(
          time: '08:30 AM',
          title: 'Penang Hill funicular',
          note: 'Ride the funicular to the summit for views over the island.',
          category: 'Attraction',
          allocated: 30,
        ),
        GuestSampleActivity(
          time: '12:30 PM',
          title: 'Lunch at Air Itam',
          note: 'Famous asam laksa near Kek Lok Si.',
          category: 'Restaurant',
          allocated: 18,
        ),
        GuestSampleActivity(
          time: '02:30 PM',
          title: 'Kek Lok Si Temple',
          note: 'The largest Buddhist temple in Malaysia.',
          category: 'Attraction',
          allocated: 10,
        ),
        GuestSampleActivity(
          time: '06:00 PM',
          title: 'Ride-hailing back to the hotel',
          note: 'Grab fare estimate from Air Itam.',
          category: 'Transportation',
          allocated: 22,
        ),
      ],
    ),
    GuestSampleDay(
      dayNumber: 3,
      heading: 'Beach & departure',
      activities: [
        GuestSampleActivity(
          time: '09:00 AM',
          title: 'Batu Ferringhi beach morning',
          note: 'Easy beach time before heading to the airport.',
          category: 'Attraction',
          allocated: 12,
        ),
        GuestSampleActivity(
          time: '12:00 PM',
          title: 'Seafood lunch',
          note: 'Fresh local seafood by the sea.',
          category: 'Restaurant',
          allocated: 45,
        ),
        GuestSampleActivity(
          time: '03:00 PM',
          title: 'Transfer to Penang International Airport',
          note: 'Arrive in time for the evening flight.',
          category: 'Transportation',
          allocated: 25,
        ),
      ],
    ),
  ];

  /// Sum of everything planned across all days.
  static double get plannedTotal =>
      days.fold(0.0, (sum, d) => sum + d.allocated);

  /// Sum of what the demo shows as already spent.
  static double get spentTotal => days.fold(0.0, (sum, d) => sum + d.spent);

  static double get remaining => totalBudget - spentTotal;

  /// Spending so far grouped by category (for the demo breakdown).
  static Map<String, double> get spentByCategory {
    final result = <String, double>{};
    for (final day in days) {
      for (final a in day.activities) {
        final spent = a.spent;
        if (spent == null || spent <= 0) continue;
        result[a.category] = (result[a.category] ?? 0) + spent;
      }
    }
    return result;
  }

  /// What each feature card on the preview shows.
  static const List<GuestFeature> features = [
    GuestFeature(
      icon: 'auto_awesome',
      title: 'AI trip planner',
      description:
          'Tell TREK where, when and your budget. It builds a day-by-day plan with real places and local food.',
    ),
    GuestFeature(
      icon: 'train',
      title: 'Smart transit times',
      description:
          'Real KTMB train departures plus flight and bus estimates, kept consistent across your trip.',
    ),
    GuestFeature(
      icon: 'receipt_long',
      title: 'Receipt scanning',
      description:
          'Snap a receipt and TREK reads the items and total for you, on your phone.',
    ),
    GuestFeature(
      icon: 'savings',
      title: 'Budget alerts',
      description:
          'Overspend on lunch? TREK rebalances the rest of your plan and warns you before the money runs out.',
    ),
  ];
}

class GuestFeature {
  /// Name of a Material icon; the screen maps it to an [IconData].
  final String icon;
  final String title;
  final String description;

  const GuestFeature({
    required this.icon,
    required this.title,
    required this.description,
  });
}
