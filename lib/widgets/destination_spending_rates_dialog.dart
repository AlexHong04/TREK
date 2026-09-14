import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DestinationRateItem {
  final String destination;
  final String rateRange;
  final String description;
  final List<String> keywords;

  const DestinationRateItem({
    required this.destination,
    required this.rateRange,
    required this.description,
    required this.keywords,
  });

  /// Extracts the lower bound of the daily rate range in MYR (e.g. 'RM350 – RM480 / day' -> 350.0).
  double get minRate {
    final match = RegExp(r'RM\s*(\d+)').firstMatch(rateRange);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 120.0;
    }
    return 120.0;
  }
}

const List<DestinationRateItem> malaysiaDestinationRates = [
  DestinationRateItem(
    destination: 'Kuala Lumpur',
    rateRange: 'RM350 – RM480 / day',
    description:
        'Higher costs for premium dining, high-end shopping hubs, and nightlife.',
    keywords: ['kuala lumpur', 'kl', 'bukit bintang', 'klcc', 'cheras'],
  ),
  DestinationRateItem(
    destination: 'Selangor',
    rateRange: 'RM300 – RM420 / day',
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
    rateRange: 'RM280 – RM400 / day',
    description:
        'Heritage boutique hotels and premium seafood add up, though hawker food keeps dining costs flexible.',
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
    destination: 'Putrajaya',
    rateRange: 'RM280 – RM380 / day',
    description:
        'Mostly upscale business hotels, governed by city transit and organized tours.',
    keywords: ['putrajaya', 'cyberjaya'],
  ),
  DestinationRateItem(
    destination: 'Sabah',
    rateRange: 'RM280 – RM400 / day',
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
    destination: 'Pahang',
    rateRange: 'RM250 – RM380 / day',
    description:
        'Dominated by premium pricing models in Genting Highlands and localized resort fees in Cameron Highlands or Tioman Island.',
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
    destination: 'Langkawi',
    rateRange: 'RM250 – RM380 / day',
    description:
        'While duty-free items are inexpensive, beachside stays, jet-skiing, and rental vehicles raise the average.',
    keywords: ['langkawi', 'pantai cenang', 'kuah'],
  ),
  DestinationRateItem(
    destination: 'Sarawak',
    rateRange: 'RM220 – RM320 / day',
    description:
        'National park guides and regional flights or river boats for remote travel push costs slightly higher.',
    keywords: ['sarawak', 'kuching', 'miri', 'sibu', 'bintulu', 'mulu'],
  ),
  DestinationRateItem(
    destination: 'Johor',
    rateRange: 'RM220 – RM320 / day',
    description:
        'Influenced heavily by family theme parks (like Legoland) and premium outlet shopping.',
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
    rateRange: 'RM180 – RM260 / day',
    description:
        'Highly affordable food, though weekend hotel rates on Jonker Street spike the baseline.',
    keywords: ['melaka', 'malacca', 'jonker', 'ayer keroh'],
  ),
  DestinationRateItem(
    destination: 'Perak',
    rateRange: 'RM160 – RM240 / day',
    description:
        'Extremely economical local food scene in Ipoh and nature excursions in Taiping.',
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
    rateRange: 'RM150 – RM220 / day',
    description:
        'Coastal stay options in Port Dickson vary, but mainland expenses are minor.',
    keywords: ['negeri sembilan', 'seremban', 'port dickson', 'nilai'],
  ),
  DestinationRateItem(
    destination: 'Terengganu & Kelantan',
    rateRange: 'RM140 – RM220 / day',
    description:
        'Known for cheap traditional local food and lower-cost cultural tours, though pristine islands like the Perhentians can double this average during peak seasons.',
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
    destination: 'Kedah (Mainland) & Perlis',
    rateRange: 'RM120 – RM180 / day',
    description:
        'The most budget-friendly states. Local economies are centered heavily around agriculture, keeping food and basic amenities very affordable.',
    keywords: ['kedah', 'alor setar', 'perlis', 'kangar', 'arau'],
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
  final normalized = destinationName.toLowerCase().trim();
  final List<DestinationRateItem> matchedList = [];

  for (final d in malaysiaDestinationRates) {
    bool isMatch = false;
    if (normalized.contains(d.destination.toLowerCase())) {
      isMatch = true;
    } else {
      for (final kw in d.keywords) {
        if (normalized.contains(kw) || kw.contains(normalized)) {
          isMatch = true;
          break;
        }
      }
    }
    if (isMatch && !matchedList.any((m) => m.destination == d.destination)) {
      matchedList.add(d);
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

/// Returns the lowest minimum daily spending rate (in MYR) among the provided destinations.
/// If multiple destinations are selected, selects the lowest minimum daily rate.
double getMinimumDailySpendingRate(List<String> destinations) {
  if (destinations.isEmpty) return 120.0;
  final matched = findMatchingDestinations(destinations.join(', '));
  if (matched.isEmpty) return 120.0;

  double minVal = double.infinity;
  for (final item in matched) {
    if (item.minRate > 0 && item.minRate < minVal) {
      minVal = item.minRate;
    }
  }
  return minVal.isFinite ? minVal : 120.0;
}

Future<void> showDestinationSpendingRatesDialog(
  BuildContext context, {
  String? currentDestination,
}) {
  final matchedList = findMatchingDestinations(currentDestination);

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
                          const SizedBox(height: 2),
                          Text(
                            matchedList.isNotEmpty
                                ? 'Average daily reference for ${matchedList.map((m) => m.destination).join(', ')}'
                                : 'Average daily reference by destination',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: appTheme.blue_gray_300,
                              fontWeight: FontWeight.w500,
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

              // Content: Only show user's selected destination(s)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (matchedList.isNotEmpty) ...[
                        ...matchedList.map(
                          (item) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: appTheme.teal_50.withValues(alpha: 0.5),
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
                                                fontSize: 16,
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
                                        item.rateRange,
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
                      ] else ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: appTheme.blue_gray_300,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    currentDestination != null &&
                                            currentDestination.trim().isNotEmpty
                                        ? currentDestination
                                        : 'No Destination Selected',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: appTheme.gray_900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Estimated average daily travel budget in Malaysia is RM180 – RM350 / day. Select a specific destination (e.g., Kuala Lumpur, Penang, Sabah) to see tailored rates.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: appTheme.blue_gray_700,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

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
                                'Data reference: DOSM Domestic Tourism Survey (2024) & Malaysia Travel Budget Guides. Actual costs may vary by travel style and season.',
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
