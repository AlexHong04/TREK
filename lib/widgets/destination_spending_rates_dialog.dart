import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DestinationRateItem {
  final String destination;
  final double localMinRate;
  final double localMaxRate;
  final double touristMinRate;
  final double touristMaxRate;
  final String description;
  final List<String> keywords;

  const DestinationRateItem({
    required this.destination,
    required this.localMinRate,
    required this.localMaxRate,
    required this.touristMinRate,
    required this.touristMaxRate,
    required this.description,
    required this.keywords,
  });

  double getMinRate(bool isInternational) =>
      isInternational ? touristMinRate : localMinRate;

  double getMaxRate(bool isInternational) =>
      isInternational ? touristMaxRate : localMaxRate;

  String getRateRange(bool isInternational) {
    final min = getMinRate(isInternational).toStringAsFixed(0);
    final max = getMaxRate(isInternational).toStringAsFixed(0);
    return 'RM $min – RM $max / day';
  }

  /// Backward compatibility getters
  String get rateRange =>
      'RM ${localMinRate.toStringAsFixed(0)} – RM ${localMaxRate.toStringAsFixed(0)} / day';
  double get minRate => localMinRate;
}

const List<DestinationRateItem> malaysiaDestinationRates = [
  DestinationRateItem(
    destination: 'Kuala Lumpur',
    localMinRate: 80.0,
    localMaxRate: 150.0,
    touristMinRate: 195.0,
    touristMaxRate: 400.0,
    description:
        'Higher costs for premium dining, high-end shopping hubs, and nightlife.',
    keywords: ['kuala lumpur', 'kl', 'bukit bintang', 'klcc', 'cheras'],
  ),
  DestinationRateItem(
    destination: 'Selangor',
    localMinRate: 85.0,
    localMaxRate: 175.0,
    touristMinRate: 205.0,
    touristMaxRate: 445.0,
    description:
        'Driven by expansive urban theme parks, mega malls, and cafe culture.',
    keywords: [
      'selangor',
      'petaling jaya',
      'pj',
      'subang',
      'sunway',
      'shah alam',
      'klang',
    ],
  ),
  DestinationRateItem(
    destination: 'Penang',
    localMinRate: 65.0,
    localMaxRate: 140.0,
    touristMinRate: 160.0,
    touristMaxRate: 315.0,
    description:
        'Heritage boutique hotels and street food keep dining flexible, with higher resort and beach dining costs.',
    keywords: [
      'penang',
      'pulau pinang',
      'george town',
      'georgetown',
      'batu ferringhi',
      'butterworth',
    ],
  ),
  DestinationRateItem(
    destination: 'Sabah',
    localMinRate: 105.0,
    localMaxRate: 210.0,
    touristMinRate: 225.0,
    touristMaxRate: 490.0,
    description:
        'Island-hopping, dive permits, and wildlife park entry fees increase daily outlays significantly.',
    keywords: [
      'sabah',
      'kota kinabalu',
      'kk',
      'sandakan',
      'semporna',
      'sipadan',
      'kundasang',
      'tawau',
    ],
  ),
  DestinationRateItem(
    destination: 'Sarawak',
    localMinRate: 75.0,
    localMaxRate: 150.0,
    touristMinRate: 155.0,
    touristMaxRate: 320.0,
    description:
        'National park guides, nature reserves, and river boats for remote travel push costs slightly higher.',
    keywords: ['sarawak', 'kuching', 'miri', 'sibu', 'bintulu', 'mulu'],
  ),
  DestinationRateItem(
    destination: 'Pahang (Highlands)',
    localMinRate: 85.0,
    localMaxRate: 170.0,
    touristMinRate: 175.0,
    touristMaxRate: 360.0,
    description:
        'Dominated by pricing in Genting Highlands and localized resort fees in Cameron Highlands or Tioman Island.',
    keywords: [
      'pahang',
      'genting',
      'cameron',
      'cameron highlands',
      'tioman',
      'kuantan',
      'cherating',
    ],
  ),
  DestinationRateItem(
    destination: 'Johor',
    localMinRate: 80.0,
    localMaxRate: 170.0,
    touristMinRate: 185.0,
    touristMaxRate: 380.0,
    description:
        'Influenced heavily by family theme parks (like Legoland), coastal stays in Desaru, and premium outlet shopping.',
    keywords: [
      'johor',
      'johor bahru',
      'jb',
      'legoland',
      'desaru',
      'muar',
      'batu pahat',
    ],
  ),
  DestinationRateItem(
    destination: 'Melaka',
    localMinRate: 65.0,
    localMaxRate: 125.0,
    touristMinRate: 135.0,
    touristMaxRate: 270.0,
    description:
        'Highly affordable street food, though weekend boutique stays on Jonker Street spike the baseline.',
    keywords: ['melaka', 'malacca', 'jonker', 'ayer keroh'],
  ),
  DestinationRateItem(
    destination: 'Terengganu / Kelantan',
    localMinRate: 60.0,
    localMaxRate: 130.0,
    touristMinRate: 130.0,
    touristMaxRate: 280.0,
    description:
        'Known for cheap traditional local food and lower-cost cultural tours, though pristine islands (Redang, Perhentian) raise this average in peak season.',
    keywords: [
      'terengganu',
      'kuala terengganu',
      'redang',
      'perhentian',
      'kelantan',
      'kota bharu',
    ],
  ),
  DestinationRateItem(
    destination: 'Kedah (Langkawi)',
    localMinRate: 80.0,
    localMaxRate: 165.0,
    touristMinRate: 170.0,
    touristMaxRate: 355.0,
    description:
        'While duty-free goods are economical, beachside resorts, water activities, and rental vehicles raise the average.',
    keywords: ['langkawi', 'pantai cenang', 'kuah'],
  ),
  DestinationRateItem(
    destination: 'Perak',
    localMinRate: 55.0,
    localMaxRate: 125.0,
    touristMinRate: 135.0,
    touristMaxRate: 270.0,
    description:
        'Extremely economical local food scene in Ipoh and nature excursions in Taiping and Pangkor Island.',
    keywords: [
      'perak',
      'ipoh',
      'taiping',
      'pangkor',
      'kampar',
      'teluk intan',
    ],
  ),
  DestinationRateItem(
    destination: 'Negeri Sembilan',
    localMinRate: 50.0,
    localMaxRate: 110.0,
    touristMinRate: 115.0,
    touristMaxRate: 225.0,
    description:
        'Coastal stay options in Port Dickson vary, but mainland dining and basic transit expenses are minimal.',
    keywords: ['negeri sembilan', 'seremban', 'port dickson', 'nilai'],
  ),
  DestinationRateItem(
    destination: 'Kedah (Mainland) / Perlis',
    localMinRate: 40.0,
    localMaxRate: 85.0,
    touristMinRate: 90.0,
    touristMaxRate: 180.0,
    description:
        'The most budget-friendly states. Local economies keep traditional food, sightseeing, and basic amenities very affordable.',
    keywords: ['kedah', 'alor setar', 'perlis', 'kangar', 'arau'],
  ),
  DestinationRateItem(
    destination: 'Labuan',
    localMinRate: 55.0,
    localMaxRate: 105.0,
    touristMinRate: 110.0,
    touristMaxRate: 210.0,
    description:
        'Duty-free federal territory island with reasonable daily living and transit expenses.',
    keywords: ['labuan'],
  ),
  DestinationRateItem(
    destination: 'Putrajaya',
    localMinRate: 80.0,
    localMaxRate: 150.0,
    touristMinRate: 195.0,
    touristMaxRate: 400.0,
    description:
        'Federal administrative territory, governed by organized sightseeing, lake cruises, and modern urban hotels.',
    keywords: ['putrajaya', 'cyberjaya'],
  ),
];

DestinationRateItem? findMatchingDestination(String? destinationName) {
  if (destinationName == null || destinationName.trim().isEmpty) return null;
  final normalized = destinationName.toLowerCase().trim();

  // Special case: Langkawi vs Kedah
  if (normalized.contains('langkawi')) {
    for (final d in malaysiaDestinationRates) {
      if (d.destination.toLowerCase().contains('langkawi')) return d;
    }
  }

  for (final d in malaysiaDestinationRates) {
    if (normalized.contains(d.destination.toLowerCase()) ||
        d.destination.toLowerCase().contains(normalized)) {
      return d;
    }
    for (final kw in d.keywords) {
      if (normalized.contains(kw) || kw.contains(normalized)) {
        return d;
      }
    }
  }
  return null;
}

List<DestinationRateItem> findMatchingDestinations(String? destinationName) {
  if (destinationName == null || destinationName.trim().isEmpty) return [];
  final rawList = destinationName.split(RegExp(r'[,;/]+'));
  final List<DestinationRateItem> matchedList = [];

  for (final raw in rawList) {
    final normalized = raw.toLowerCase().trim();
    if (normalized.isEmpty) continue;

    // Special case: Langkawi vs Kedah
    if (normalized.contains('langkawi')) {
      final langkawiItem = malaysiaDestinationRates.firstWhere(
        (d) => d.destination.toLowerCase().contains('langkawi'),
      );
      if (!matchedList.contains(langkawiItem)) matchedList.add(langkawiItem);
      continue;
    }

    DestinationRateItem? bestMatch;
    for (final d in malaysiaDestinationRates) {
      if (normalized.contains(d.destination.toLowerCase()) ||
          d.destination.toLowerCase().contains(normalized)) {
        bestMatch = d;
        break;
      }
      for (final kw in d.keywords) {
        if (normalized.contains(kw) || kw.contains(normalized)) {
          bestMatch = d;
          break;
        }
      }
      if (bestMatch != null) break;
    }

    if (bestMatch != null && !matchedList.contains(bestMatch)) {
      matchedList.add(bestMatch);
    }
  }

  if (matchedList.isEmpty) {
    final single = findMatchingDestination(destinationName);
    if (single != null) {
      matchedList.add(single);
    }
  }
  return matchedList;
}

/// Structured calculation for recommended budget across single or multiple destinations.
class BudgetRecommendation {
  final double minDailyMyr;
  final double maxDailyMyr;
  final double minTotalMyr;
  final double maxTotalMyr;
  final int days;
  final bool isInternational;
  final List<String> matchedDestinations;

  const BudgetRecommendation({
    required this.minDailyMyr,
    required this.maxDailyMyr,
    required this.minTotalMyr,
    required this.maxTotalMyr,
    required this.days,
    required this.isInternational,
    required this.matchedDestinations,
  });

  /// Recommended mid/moderate budget in MYR
  double get midTotalMyr => (minTotalMyr + maxTotalMyr) / 2;

  /// Formatted daily rate range text (e.g. 'RM 65 – RM 140 / day')
  String get dailyRangeText =>
      'RM ${minDailyMyr.toStringAsFixed(0)} – RM ${maxDailyMyr.toStringAsFixed(0)} / day';

  /// Formatted total range text in MYR (e.g. 'RM 260 – RM 560')
  String get totalRangeTextMyr =>
      'RM ${minTotalMyr.toStringAsFixed(0)} – RM ${maxTotalMyr.toStringAsFixed(0)}';
}

/// Calculates budget recommendation based on destinations, duration, and traveler type.
/// Aggregates across multiple destinations to produce an overall total range.
BudgetRecommendation getBudgetRecommendation({
  required List<String> destinations,
  required int numberOfDays,
  required bool isInternational,
}) {
  final days = numberOfDays > 0 ? numberOfDays : 1;
  final matched = findMatchingDestinations(destinations.join(', '));

  if (matched.isEmpty) {
    final minDaily = isInternational ? 160.0 : 65.0;
    final maxDaily = isInternational ? 315.0 : 140.0;
    return BudgetRecommendation(
      minDailyMyr: minDaily,
      maxDailyMyr: maxDaily,
      minTotalMyr: minDaily * days,
      maxTotalMyr: maxDaily * days,
      days: days,
      isInternational: isInternational,
      matchedDestinations: const [],
    );
  }

  // Across selected destinations:
  // For multiple destinations, combine by calculating the average daily rate across destinations
  // (allocating equal duration to each visited region over the trip days).
  double sumMinDaily = 0.0;
  double sumMaxDaily = 0.0;

  for (final item in matched) {
    sumMinDaily += item.getMinRate(isInternational);
    sumMaxDaily += item.getMaxRate(isInternational);
  }

  final double combinedMinDaily = sumMinDaily / matched.length;
  final double combinedMaxDaily = sumMaxDaily / matched.length;

  return BudgetRecommendation(
    minDailyMyr: combinedMinDaily,
    maxDailyMyr: combinedMaxDaily,
    minTotalMyr: combinedMinDaily * days,
    maxTotalMyr: combinedMaxDaily * days,
    days: days,
    isInternational: isInternational,
    matchedDestinations: matched.map((m) => m.destination).toList(),
  );
}

/// Returns the lowest minimum daily spending rate (in MYR) among the provided destinations.
/// If multiple destinations are selected, selects the lowest minimum daily rate.
double getMinimumDailySpendingRate(
  List<String> destinations, {
  bool isInternational = false,
}) {
  final rec = getBudgetRecommendation(
    destinations: destinations,
    numberOfDays: 1,
    isInternational: isInternational,
  );
  return rec.minDailyMyr;
}

Future<void> showDestinationSpendingRatesDialog(
  BuildContext context, {
  String? currentDestination,
  String? currency,
  int numberOfDays = 1,
  double? rateToMyr,
}) {
  final bool isTourist = (currency != null && currency != 'MYR');
  final String effectiveCurrency = currency ?? 'MYR';
  final int days = numberOfDays > 0 ? numberOfDays : 1;
  final double rate = (rateToMyr != null && rateToMyr > 0) ? rateToMyr : 1.0;

  final matchedList = findMatchingDestinations(currentDestination);
  final effectiveList = matchedList.isNotEmpty
      ? matchedList
      : malaysiaDestinationRates;

  BudgetRecommendation? recommendation;
  if (matchedList.isNotEmpty) {
    recommendation = getBudgetRecommendation(
      destinations: matchedList.map((m) => m.destination).toList(),
      numberOfDays: days,
      isInternational: isTourist,
    );
  }

  return showDialog(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: appTheme.teal_50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        color: appTheme.teal_A700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Spending Rates',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: appTheme.gray_900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isTourist
                                  ? const Color(0xFFEFF6FF)
                                  : appTheme.teal_50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isTourist
                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                                    : appTheme.teal_A700.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              isTourist
                                  ? '🌐 International Tourist ($effectiveCurrency)'
                                  : '🇲🇾 Local Malaysian (MYR)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isTourist
                                    ? const Color(0xFF1D4ED8)
                                    : appTheme.teal_800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: appTheme.blue_gray_300,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Content: recommendation summary + list of destination rate cards
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Budget Recommendation Banner (when destinations are selected)
                      if (recommendation != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                appTheme.teal_50.withValues(alpha: 0.8),
                                const Color(0xFFF0FDF4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: appTheme.teal_A700.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: appTheme.teal_700,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      matchedList.length > 1
                                          ? 'Combined Budget Recommendation'
                                          : 'Trip Budget Recommendation',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Inter',
                                        color: appTheme.teal_800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: appTheme.white_A700,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: appTheme.teal_A700.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      '$days ${days == 1 ? 'day' : 'days'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Inter',
                                        color: appTheme.teal_800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Selected: ${matchedList.map((m) => m.destination).join(', ')}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                  color: appTheme.blue_gray_700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: appTheme.white_A700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Daily Benchmark',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'Inter',
                                              color: appTheme.blue_gray_300,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'RM ${recommendation.minDailyMyr.toStringAsFixed(0)} – ${recommendation.maxDailyMyr.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'Inter',
                                              color: appTheme.gray_900,
                                            ),
                                          ),
                                          if (isTourist && rate > 0) ...[
                                            Text(
                                              '$effectiveCurrency ${(recommendation.minDailyMyr / rate).toStringAsFixed(0)} – ${(recommendation.maxDailyMyr / rate).toStringAsFixed(0)} / day',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w600,
                                                color: appTheme.teal_700,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: const Color(0xFFE2E8F0),
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total Range ($days days)',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Inter',
                                              color: appTheme.teal_700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isTourist && rate > 0
                                                ? '$effectiveCurrency ${(recommendation.minTotalMyr / rate).toStringAsFixed(0)} – ${(recommendation.maxTotalMyr / rate).toStringAsFixed(0)}'
                                                : 'RM ${recommendation.minTotalMyr.toStringAsFixed(0)} – ${recommendation.maxTotalMyr.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: 'Inter',
                                              color: appTheme.teal_800,
                                            ),
                                          ),
                                          if (isTourist && rate > 0) ...[
                                            Text(
                                              '≈ RM ${recommendation.minTotalMyr.toStringAsFixed(0)} – ${recommendation.maxTotalMyr.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w500,
                                                color: appTheme.blue_gray_300,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (matchedList.length > 1) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '💡 Total range combines lowest daily segment (RM ${recommendation.minDailyMyr.toStringAsFixed(0)}) to highest daily peak (RM ${recommendation.maxDailyMyr.toStringAsFixed(0)}) across your $days days.',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontFamily: 'Inter',
                                    color: appTheme.teal_800.withValues(alpha: 0.85),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Destination list
                      ...effectiveList.map(
                        (item) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: appTheme.teal_50.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: appTheme.teal_A700.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.place_rounded,
                                          size: 18,
                                          color: appTheme.teal_A700,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            item.destination,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: appTheme.teal_800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: appTheme.teal_A700,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      item.getRateRange(isTourist),
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: appTheme.white_A700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item.description,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: appTheme.blue_gray_700,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Reference note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: appTheme.blue_gray_300,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Reference: Segment daily benchmarks for ${isTourist ? "International Tourists ($effectiveCurrency)" : "Local Malaysians (MYR)"} based on current currency setting.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: appTheme.blue_gray_300,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
