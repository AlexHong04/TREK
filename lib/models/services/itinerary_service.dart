import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:Trek/models/entities/day_trip.dart';
import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../entities/future_suggestion.dart';
import '../../view_models/ui_state/travel_information_ui_state.dart';
import '../configurations/gemini_api_config.dart';
import '../configurations/google_places_api_config.dart';
import '../configurations/image_resolver_config.dart';
import '../repository/itinerary_repository.dart';
import '../repository/i_itinerary_repository.dart';
import '../../utils/id_generator.dart';
import 'i_itinerary_service.dart';

class ItineraryService implements IItineraryService {
  final IItineraryRepository _itineraryRepository = ItineraryRepository();

  static bool _isWishlistMatch(
    String wishlistName,
    String destinationName, [
    String description = '',
  ]) {
    final wLower = wishlistName.toLowerCase().trim();
    final dLower = destinationName.toLowerCase().trim();
    final descLower = description.toLowerCase().trim();

    if (wLower.isEmpty || (dLower.isEmpty && descLower.isEmpty)) return false;

    if (dLower.contains(wLower) || wLower.contains(dLower)) return true;
    if (descLower.contains(wLower)) return true;

    final cleanW = wLower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanD = dLower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanDesc = descLower.replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (cleanW.isNotEmpty) {
      if (cleanD.contains(cleanW) || cleanW.contains(cleanD)) return true;
      if (cleanDesc.contains(cleanW)) return true;
    }

    final tokens = wLower
        .split(RegExp(r'[\s,./\-_()]+'))
        .where((t) => t.length >= 2)
        .toList();
    if (tokens.isNotEmpty) {
      final matchedTokens = tokens
          .where((t) =>
              dLower.contains(t) ||
              cleanD.contains(t) ||
              descLower.contains(t))
          .length;
      if (tokens.length == 1) {
        if (matchedTokens == 1) return true;
      } else if (matchedTokens >= 2 || (matchedTokens * 2 >= tokens.length)) {
        return true;
      }
    }

    return false;
  }

  static bool _isAddressInDestination(String address, String destination) {
    final addrLower = address.toLowerCase();
    final destTokens = destination
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .where((t) => t.length >= 3)
        .toList();

    // Direct token check
    for (final token in destTokens) {
      if (addrLower.contains(token)) return true;
    }

    // Common Malaysian State & Territory Aliases
    final Map<String, List<String>> aliases = {
      'penang': [
        'pulau pinang',
        'pinang',
        'george town',
        'georgetown',
        'batu ferringhi',
        'butterworth',
        'bayan lepas',
        'bukit mertajam',
      ],
      'kuala lumpur': [
        'kl',
        'wilayah persekutuan kuala lumpur',
        'wp kuala lumpur',
        'cheras',
        'bukit bintang',
        'bangsar',
      ],
      'selangor': [
        'petaling jaya',
        'pj',
        'subang',
        'sunway',
        'shah alam',
        'klang',
        'cyberjaya',
        'sepang',
        'puchong',
        'seri kembangan',
      ],
      'malacca': ['melaka', 'ayer keroh', 'klebang'],
      'melaka': ['malacca', 'ayer keroh', 'klebang'],
      'johor': [
        'johor bahru',
        'jb',
        'muar',
        'batu pahat',
        'kluang',
        'iskandar puteri',
      ],
      'perak': ['ipoh', 'taiping', 'pangkor', 'lumut', 'teluk intan', 'kampar'],
      'kedah': ['alor setar', 'langkawi', 'sungai petani', 'kulim'],
      'langkawi': ['pantai cenang', 'kuah', 'kedah'],
      'pahang': [
        'kuantan',
        'cameron',
        'cameron highlands',
        'genting',
        'genting highlands',
        'tioman',
        'cherating',
        'bentong',
      ],
      'sabah': [
        'kota kinabalu',
        'sandakan',
        'tawau',
        'semporna',
        'kundasang',
        'ranau',
      ],
      'sarawak': ['kuching', 'miri', 'sibu', 'bintulu'],
      'terengganu': ['kuala terengganu', 'redang', 'perhentian', 'kapas'],
      'kelantan': ['kota bharu'],
      'negeri sembilan': ['seremban', 'port dickson', 'nilai'],
      'perlis': ['kangar', 'arau'],
      'putrajaya': ['wilayah persekutuan putrajaya'],
      'labuan': ['wilayah persekutuan labuan'],
    };

    for (final entry in aliases.entries) {
      final key = entry.key;
      if (destTokens.any((t) => t.contains(key) || key.contains(t))) {
        for (final alias in entry.value) {
          if (addrLower.contains(alias)) return true;
        }
      }
    }

    // If destination didn't match, verify whether the address belongs to a different major state
    final majorStates = [
      'kuala lumpur',
      'penang',
      'pulau pinang',
      'selangor',
      'melaka',
      'malacca',
      'johor',
      'perak',
      'kedah',
      'pahang',
      'sabah',
      'sarawak',
      'terengganu',
      'kelantan',
      'negeri sembilan',
      'perlis',
      'putrajaya',
      'labuan',
    ];
    for (final state in majorStates) {
      if (addrLower.contains(state)) {
        final destMatches =
            destTokens.any((t) => t.contains(state) || state.contains(t)) ||
            (aliases[state]?.any(
                  (a) => destTokens.any((t) => t.contains(a) || a.contains(t)),
                ) ??
                false);
        if (!destMatches) {
          return false;
        }
      }
    }

    return true;
  }

  static int _timeToMinutes(String? timeStr, int defaultMinutes) {
    if (timeStr == null || timeStr.trim().isEmpty) return defaultMinutes;
    try {
      final trimmed = timeStr.trim();
      final parts = trimmed.split(RegExp(r'[:\s]'));
      if (parts.length >= 2) {
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        final lower = trimmed.toLowerCase();
        final isPm = lower.contains('pm');
        final isAm = lower.contains('am');
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        return h * 60 + m;
      }
    } catch (_) {}
    return defaultMinutes;
  }

  static String _minutesToTimeString(int totalMinutes) {
    if (totalMinutes < 0) totalMinutes = 0;
    if (totalMinutes >= 24 * 60) totalMinutes = 23 * 60 + 59;
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static Map<String, dynamic>? _tryParseOrRepairJson(String raw) {
    if (raw.trim().isEmpty) return null;

    // 1. Try standard parse directly
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    // 2. Try parsing after extracting outer object
    try {
      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(raw);
      if (match != null) {
        final decoded = jsonDecode(match.group(0)!);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}

    // 3. Attempt repair for truncated JSON
    try {
      int firstBrace = raw.indexOf('{');
      if (firstBrace == -1) return null;
      var trimmed = raw.substring(firstBrace).trim();

      // If it ends inside an incomplete item, trim to last valid '}'
      final lastBrace = trimmed.lastIndexOf('}');
      if (lastBrace != -1 && lastBrace < trimmed.length - 1) {
        trimmed = trimmed.substring(0, lastBrace + 1);
      }

      int openBraces = 0;
      int openBrackets = 0;
      bool inString = false;
      bool escape = false;

      for (int i = 0; i < trimmed.length; i++) {
        final char = trimmed[i];
        if (escape) {
          escape = false;
          continue;
        }
        if (char == '\\') {
          escape = true;
          continue;
        }
        if (char == '"') {
          inString = !inString;
          continue;
        }
        if (!inString) {
          if (char == '{') openBraces++;
          if (char == '}') openBraces--;
          if (char == '[') openBrackets++;
          if (char == ']') openBrackets--;
        }
      }

      var repaired = trimmed.trim();
      while (repaired.endsWith(',')) {
        repaired = repaired.substring(0, repaired.length - 1).trim();
      }

      final buffer = StringBuffer(repaired);
      while (openBrackets > 0) {
        buffer.write('\n]');
        openBrackets--;
      }
      while (openBraces > 0) {
        buffer.write('\n}');
        openBraces--;
      }

      final decoded = jsonDecode(buffer.toString());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      debugPrint('JSON repair attempt failed: $e');
    }

    return null;
  }

  // kokhong - Gemini API + Google Places validation + image resolution
  @override
  Future<ItineraryGenerationResult> generateItinerary({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    List<String>? wishlist,
    List<String>? constraints,
    List<FutureSuggestion>? futureSuggestions,
    bool strictBudget = false,
    List<TransitPoint>? arrivals,
    List<TransitPoint>? departures,
    List<HotelStay>? hotels,
    bool isForeign = false,
    String? arrivalLocation,
    String? arrivalTime,
    String? departureLocation,
    String? departureTime,
    String? hotelLocation,
    String? hotelCheckInTime,
    String? hotelCheckOutTime,
  }) async {
    try {
      int retries = 3;
      List<String> failedDestinations = [];
      List<dynamic> validatedList = [];
      Map<String, Map<String, dynamic>?> searchCache = {};
      List<dynamic> lastJsonList = [];
      Map<String, dynamic>? lastParsedObj;

      double responseTotalAllocatedBudget = 0.0;
      double responseEstimatedExtraBudgetNeeded = 0.0;

      while (retries > 0) {
        final responseText = await GeminiApiConfig.askGeminiForItinerary(
          destination: destination,
          dates: dates,
          budget: budget,
          preference: preference,
          avoidPlaces: failedDestinations,
          wishlist: wishlist,
          constraints: constraints,
          futureSuggestions: futureSuggestions,
          strictBudget: strictBudget,
          arrivals: arrivals,
          departures: departures,
          hotels: hotels,
          isForeign: isForeign,
          arrivalLocation: arrivalLocation,
          arrivalTime: arrivalTime,
          departureLocation: departureLocation,
          departureTime: departureTime,
          hotelLocation: hotelLocation,
          hotelCheckInTime: hotelCheckInTime,
          hotelCheckOutTime: hotelCheckOutTime,
        );

        // Extract and parse JSON object safely (with truncation repair)
        final parsedObj = _tryParseOrRepairJson(responseText);

        if (parsedObj == null) {
          retries--;
          if (retries == 0) {
            throw Exception('Invalid JSON returned by Gemini: $responseText');
          }
          continue;
        }

        final jsonList = parsedObj['activities'] as List? ?? [];
        lastJsonList = jsonList;
        lastParsedObj = parsedObj;

        if (!GooglePlacesApiConfig.isConfigured) {
          validatedList = jsonList;
          responseTotalAllocatedBudget =
              (parsedObj['totalAllocatedBudget'] as num?)?.toDouble() ?? 0.0;
          responseEstimatedExtraBudgetNeeded =
              (parsedObj['estimatedExtraBudgetNeeded'] as num?)?.toDouble() ??
              0.0;
          break;
        }

        bool allValid = true;
        bool apiDenied = false;
        List<String> currentFailed = [];
        final Set<String> seenNonTransportDestinations = <String>{};

        for (var item in jsonList) {
          final destName = item['destination'] as String? ?? '';
          if (destName.isEmpty) continue;
          final category = (item['activityCategory'] as String? ?? '')
              .toLowerCase();

          // Deduplication check: Non-transportation activities MUST be unique
          if (category != 'transportation') {
            final normalizedDest = destName.trim().toLowerCase();
            if (seenNonTransportDestinations.contains(normalizedDest)) {
              developer.log('Duplicate destination detected: $destName');
              allValid = false;
              currentFailed.add(destName);
            } else {
              seenNonTransportDestinations.add(normalizedDest);
            }
          }

          if (!searchCache.containsKey(destName)) {
            try {
              final place = await GooglePlacesApiConfig.searchPlace(destName);
              searchCache[destName] = place;
            } on PlacesApiDeniedException catch (e) {
              developer.log(
                'Google Places API denied ($e). Skipping validation and using Gemini results directly.',
              );
              apiDenied = true;
              break;
            } catch (e) {
              developer.log(
                'Validation searchPlace threw error for $destName: $e',
              );
              searchCache[destName] = null;
            }
          }

          final place = searchCache[destName];
          if (place == null) {
            if (category != 'transportation') {
              allValid = false;
              currentFailed.add(destName);
            }
          } else if (category != 'transportation') {
            final address = (place['address'] as String? ?? '').trim();
            if (address.isNotEmpty &&
                !_isAddressInDestination(address, destination)) {
              developer.log(
                'Destination "$destName" is outside "$destination" (Google Places address: $address). Rejecting.',
              );
              allValid = false;
              currentFailed.add(destName);
            }
          }
        }

        if (apiDenied) {
          validatedList = jsonList;
          responseTotalAllocatedBudget =
              (parsedObj['totalAllocatedBudget'] as num?)?.toDouble() ?? 0.0;
          responseEstimatedExtraBudgetNeeded =
              (parsedObj['estimatedExtraBudgetNeeded'] as num?)?.toDouble() ??
              0.0;
          break;
        }

        if (allValid && wishlist != null && wishlist.isNotEmpty) {
          final allWishlistIncluded = wishlist.every((w) {
            return jsonList.any(
              (item) => _isWishlistMatch(
                w,
                item['destination'] as String? ?? '',
                item['description'] as String? ?? '',
              ),
            );
          });
          if (!allWishlistIncluded && strictBudget && retries > 1) {
            developer.log(
              'Strict budget plan did not include all wishlist items, retrying...',
            );
            allValid = false;
          }
        }

        if (allValid) {
          final currentCost = jsonList.fold(
            0.0,
            (sum, item) =>
                sum + ((item['allocatedBudget'] as num?)?.toDouble() ?? 0.0),
          );
          final parsedBudget = double.tryParse(budget) ?? 0.0;
          if (parsedBudget > 0 && currentCost > parsedBudget && retries > 1) {
            developer.log(
              'Generated plan cost ($currentCost) exceeds target budget ($parsedBudget), retrying...',
            );
            allValid = false;
          }
        }

        if (allValid) {
          validatedList = jsonList;
          responseTotalAllocatedBudget =
              (parsedObj['totalAllocatedBudget'] as num?)?.toDouble() ?? 0.0;
          responseEstimatedExtraBudgetNeeded =
              (parsedObj['estimatedExtraBudgetNeeded'] as num?)?.toDouble() ??
              0.0;
          break;
        } else {
          developer.log(
            'Google Places validation failed. The following places are not searchable: $currentFailed',
          );
          failedDestinations.addAll(currentFailed);
          failedDestinations = failedDestinations.toSet().toList();
          retries--;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (validatedList.isEmpty) {
        if (lastJsonList.isNotEmpty) {
          developer.log(
            'Google Places validation could not resolve all places; falling back to Gemini generated plan.',
          );
          validatedList = lastJsonList;
          if (lastParsedObj != null) {
            responseTotalAllocatedBudget =
                (lastParsedObj['totalAllocatedBudget'] as num?)?.toDouble() ??
                0.0;
            responseEstimatedExtraBudgetNeeded =
                (lastParsedObj['estimatedExtraBudgetNeeded'] as num?)
                    ?.toDouble() ??
                0.0;
          }
        } else {
          throw Exception(
            'Failed to generate a valid itinerary with searchable Google Places locations.',
          );
        }
      }

      // Ensure Day 1 start time and Last Day end time strictly follow arrival/departure flow.
      final String rawArrivalTime = (arrivals != null &&
              arrivals.isNotEmpty &&
              arrivals.first.time.trim().isNotEmpty)
          ? arrivals.first.time
          : (arrivalTime != null && arrivalTime.trim().isNotEmpty
              ? arrivalTime
              : '09:00 AM');

      final String rawStartTime = rawArrivalTime;
      final int expectedDay1StartMinutes =
          _timeToMinutes(rawStartTime, 9 * 60);

      final String rawDepartureTime = (departures != null &&
              departures.isNotEmpty &&
              departures.last.time.trim().isNotEmpty)
          ? departures.last.time
          : (departureTime != null && departureTime.trim().isNotEmpty
              ? departureTime
              : '09:00 PM');

      final String rawEndTime = rawDepartureTime;
      final int expectedLastDayEndMinutes =
          _timeToMinutes(rawEndTime, 21 * 60);

      int maxDay = 1;
      for (final item in validatedList) {
        final d = int.tryParse(item['dayNumber']?.toString() ?? '1') ?? 1;
        if (d > maxDay) maxDay = d;
      }

      final day1Indices = <int>[];
      final lastDayIndices = <int>[];
      for (int i = 0; i < validatedList.length; i++) {
        final dNum =
            int.tryParse(validatedList[i]['dayNumber']?.toString() ?? '1') ?? 1;
        if (dNum == 1) {
          day1Indices.add(i);
        }
        if (dNum == maxDay) {
          lastDayIndices.add(i);
        }
      }

      // 1. Day 1 start time based on arrival time for first activity
      if (day1Indices.isNotEmpty) {
        int minStartM = 24 * 60;
        for (final idx in day1Indices) {
          final sM = _timeToMinutes(
              validatedList[idx]['startTime']?.toString(), 9 * 60);
          if (sM < minStartM) minStartM = sM;
        }

        if (minStartM != expectedDay1StartMinutes) {
          final shift = expectedDay1StartMinutes - minStartM;
          for (final idx in day1Indices) {
            final it = Map<String, dynamic>.from(validatedList[idx] as Map);
            final sM = _timeToMinutes(it['startTime']?.toString(), 9 * 60);
            final eM = _timeToMinutes(it['endTime']?.toString(), sM + 60);
            it['startTime'] = _minutesToTimeString(sM + shift);
            it['endTime'] = _minutesToTimeString(eM + shift);
            validatedList[idx] = it;
          }
        }
      }

      // 2. Last day end time based on departure time for last activity
      if (lastDayIndices.isNotEmpty) {
        int maxEndM = -1;
        int lastIdx = lastDayIndices.last;
        for (final idx in lastDayIndices) {
          final sM = _timeToMinutes(
              validatedList[idx]['startTime']?.toString(), 20 * 60);
          final eM =
              _timeToMinutes(validatedList[idx]['endTime']?.toString(), sM + 60);
          if (eM > maxEndM) {
            maxEndM = eM;
            lastIdx = idx;
          }
        }

        if (maxEndM != expectedLastDayEndMinutes) {
          final lastIt = Map<String, dynamic>.from(validatedList[lastIdx] as Map);
          final oldStartM =
              _timeToMinutes(lastIt['startTime']?.toString(), 20 * 60);
          final oldEndM =
              _timeToMinutes(lastIt['endTime']?.toString(), oldStartM + 60);
          int durationM = oldEndM - oldStartM;
          if (durationM <= 0 || durationM > 180) durationM = 60;

          int newStartM = expectedLastDayEndMinutes - durationM;
          if (newStartM < 0) newStartM = 0;

          if (maxDay == 1 && day1Indices.length == 1) {
            newStartM = expectedDay1StartMinutes;
          }

          lastIt['startTime'] = _minutesToTimeString(newStartM);
          lastIt['endTime'] = _minutesToTimeString(expectedLastDayEndMinutes);
          validatedList[lastIdx] = lastIt;
        }
      }

      List<Activity> newActivities = [];
      int index = 1;
      String currentActId = 'AC0000';
      String currentDayTripId = IdGenerator.generateNextFormattedId('DT', null);

      for (var item in validatedList) {
        currentActId = IdGenerator.generateNextFormattedId('AC', currentActId);
        final rawAllocated =
            (item['allocatedBudget'] as num?)?.toDouble() ?? 0.0;
        final rawCategory =
            (item['activityCategory'] as String? ?? 'General').trim();
        final isRestaurant = rawCategory.toLowerCase() == 'restaurant';

        final rawMinPrice = item['minPrice'] != null
            ? (item['minPrice'] as num).toDouble()
            : null;

        // Defensive realism: Food in Malaysia is never free
        final double allocatedBudget = (isRestaurant && rawAllocated <= 0.0)
            ? (rawMinPrice != null && rawMinPrice > 0 ? rawMinPrice : 8.0)
            : rawAllocated;

        double? minPriceLocal =
            isRestaurant && (rawMinPrice == null || rawMinPrice <= 0.0)
                ? 5.0
                : rawMinPrice;

        // Ensure minimum floor price never exceeds allocated budget
        if (minPriceLocal != null && minPriceLocal > allocatedBudget && allocatedBudget > 0) {
          minPriceLocal = allocatedBudget;
        }

        final destName = item['destination'] as String? ?? 'Activity';
        final imageKeyword = item['imageKeyword'] as String? ?? destName;

        String imgUrl = '';
        String finalDestinationTitle = destName;
        bool resolvedByGooglePlaces = false;

        // Google Places API
        if (GooglePlacesApiConfig.isConfigured) {
          try {
            final place = searchCache[destName];
            if (place != null) {
              resolvedByGooglePlaces = true;
              if (place['name'] != null &&
                  place['name'].toString().isNotEmpty) {
                finalDestinationTitle = place['name'];
              }
              final photos = place['photos'] as List?;
              if (photos != null && photos.isNotEmpty) {
                final firstPhoto = photos.first as Map<String, dynamic>;
                final photoReference = firstPhoto['photo_reference'] as String?;
                if (photoReference != null && photoReference.isNotEmpty) {
                  imgUrl = GooglePlacesApiConfig.getPhotoUrl(photoReference);
                }
              }
            }
          } catch (e) {
            developer.log('Google Places resolution error for $destName: $e');
          }
        }

        // Wikipedia + Wikimedia Commons + LoremFlickr fallback
        if (imgUrl.isEmpty && !resolvedByGooglePlaces) {
          final resolved = await ImageResolverConfig.resolveImage(
            keyword: imageKeyword,
            fallbackTitle: finalDestinationTitle,
            lockIndex: index,
          );
          imgUrl = resolved.imageUrl;
          finalDestinationTitle = resolved.correctedTitle;
        }

        int dayNumber = (item['dayNumber'] as num?)?.toInt() ?? 1;
        String startTimeStr = item['startTime'] as String? ?? '09:00';

        DateTime tripStartDate = DateTime.now();
        try {
          final parts = dates.split(' - ');
          if (parts.isNotEmpty) {
            tripStartDate = DateTime.parse(parts[0].trim());
          }
        } catch (_) {}

        DateTime baseDate = tripStartDate.add(Duration(days: dayNumber - 1));
        DateTime parsedDate = baseDate;

        try {
          final parts = startTimeStr.split(':');
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          parsedDate = DateTime(
            baseDate.year,
            baseDate.month,
            baseDate.day,
            h,
            m,
          );
        } catch (_) {}

        newActivities.add(
          Activity(
            activitiesId: currentActId,
            dayTripId: currentDayTripId,
            destination: finalDestinationTitle,
            description: item['description'] as String? ?? '',
            activityImgUrl: imgUrl,
            date: parsedDate,
            allocatedBudget: allocatedBudget,
            overspendAmount: allocatedBudget > 0 ? 0 : null,
            status: 'pending',
            startTime: startTimeStr,
            endTime: item['endTime'] as String? ?? '10:00',
            duration: item['duration'] as String? ?? '60 min',
            activityCategory: item['activityCategory'] as String? ?? 'General',
            isOverspend: false,
            minAllocatedBudget: minPriceLocal,
          ),
        );
        index++;

        // Throttle requests to avoid Wikipedia/Wikimedia 429 rate limiting
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Sort chronologically. Activity.date already embeds the slot's start
      // time, so this orders by day and then by time, keeping the timeline (and
      // the UI's day grouping) correct even when Gemini returns the slots out
      // of sequence - e.g. an arrival listed after a restaurant.
      newActivities.sort((a, b) => a.date.compareTo(b.date));

      // Ensure departure is covered if user specified departure points
      final resolvedDepList = (departures != null && departures.isNotEmpty)
          ? departures.where((d) => d.location.trim().isNotEmpty).toList()
          : (departureLocation != null && departureLocation.trim().isNotEmpty)
              ? [TransitPoint(id: 'dep_0', location: departureLocation, time: departureTime ?? '21:00')]
              : <TransitPoint>[];

      if (resolvedDepList.isNotEmpty && newActivities.isNotEmpty) {
        final lastDep = resolvedDepList.last;
        final depLocLower = lastDep.location.toLowerCase().trim();
        final bool departureCovered = newActivities.any((a) {
          final dest = a.destination.toLowerCase();
          final desc = a.description.toLowerCase();
          return dest.contains(depLocLower) ||
              desc.contains(depLocLower) ||
              depLocLower.contains(dest);
        });

        if (!departureCovered) {
          final lastActivity = newActivities.last;
          DateTime lastDate = lastActivity.date;
          String depTimeStr = lastDep.time;
          String formattedEndTime = '21:00';
          try {
            final tParts = depTimeStr.trim().split(RegExp(r'[:\s]'));
            if (tParts.length >= 2) {
              int h = int.parse(tParts[0]);
              int m = int.parse(tParts[1]);
              final isPm = depTimeStr.toLowerCase().contains('pm');
              final isAm = depTimeStr.toLowerCase().contains('am');
              if (isPm && h < 12) h += 12;
              if (isAm && h == 12) h = 0;
              formattedEndTime = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
            }
          } catch (_) {
            formattedEndTime = depTimeStr;
          }

          String formattedStartTime = '20:00';
          try {
            final parts = formattedEndTime.split(':');
            int h = int.parse(parts[0]);
            int m = int.parse(parts[1]);
            int totalM = h * 60 + m - 60;
            if (totalM < 0) totalM = 0;
            formattedStartTime = '${(totalM ~/ 60).toString().padLeft(2, '0')}:${(totalM % 60).toString().padLeft(2, '0')}';
          } catch (_) {}

          final depActId = 'AC${index.toString().padLeft(4, '0')}';
          newActivities.add(
            Activity(
              activitiesId: depActId,
              dayTripId: lastActivity.dayTripId,
              destination: lastDep.location,
              description: 'Travel to ${lastDep.location} for departure (${lastDep.type})',
              activityImgUrl: 'assets/logo.png',
              date: DateTime(
                lastDate.year,
                lastDate.month,
                lastDate.day,
                int.tryParse(formattedStartTime.split(':')[0]) ?? 20,
                int.tryParse(formattedStartTime.split(':')[1]) ?? 0,
              ),
              allocatedBudget: 0.0,
              overspendAmount: null,
              status: 'pending',
              startTime: formattedStartTime,
              endTime: formattedEndTime,
              duration: '60 min',
              activityCategory: 'Transportation',
              isOverspend: false,
              minAllocatedBudget: 0.0,
            ),
          );
          index++;
        }
      }

      if (newActivities.isNotEmpty) {
        // Guarantee first activity of Day 1 starts at arrival time
        final firstAct = newActivities.first;
        final expectedStartStr = _minutesToTimeString(expectedDay1StartMinutes);
        if (firstAct.startTime != expectedStartStr) {
          final sM = _timeToMinutes(firstAct.startTime, expectedDay1StartMinutes);
          final eM = _timeToMinutes(firstAct.endTime, sM + 60);
          final dur = eM - sM;
          final newEndStr = _minutesToTimeString(
              expectedDay1StartMinutes + (dur > 0 ? dur : 60));
          newActivities[0] = firstAct.copyWith(
            startTime: expectedStartStr,
            endTime: newEndStr,
          );
        }

        // Guarantee last activity of the trip ends at departure time
        final lastAct = newActivities.last;
        final expectedEndStr = _minutesToTimeString(expectedLastDayEndMinutes);
        if (lastAct.endTime != expectedEndStr) {
          final sM =
              _timeToMinutes(lastAct.startTime, expectedLastDayEndMinutes - 60);
          final eM = _timeToMinutes(lastAct.endTime, sM + 60);
          final dur = eM - sM;
          final newStartStr = _minutesToTimeString(
              expectedLastDayEndMinutes - (dur > 0 ? dur : 60));
          newActivities[newActivities.length - 1] = lastAct.copyWith(
            startTime: newStartStr,
            endTime: expectedEndStr,
          );
        }
      }

      final double parsedBudget = double.tryParse(budget) ?? 0.0;
      final double initialExcess = (responseTotalAllocatedBudget - parsedBudget).clamp(0.0, double.infinity);

      if (parsedBudget > 0) {
        double currentTotal =
            newActivities.fold(0.0, (sum, a) => sum + a.allocatedBudget);
        if (currentTotal > parsedBudget) {
          double excess = currentTotal - parsedBudget;

          // Pass 1: Trim restaurant costs down towards minimum allowed
          for (int i = 0; i < newActivities.length; i++) {
            if (excess <= 0.001) break;
            final a = newActivities[i];
            if (a.activityCategory.toLowerCase() == 'restaurant') {
              final minAllowed =
                  (a.minAllocatedBudget != null && a.minAllocatedBudget! > 0)
                      ? a.minAllocatedBudget!
                      : (parsedBudget < 20.0 ? (parsedBudget / newActivities.length).clamp(1.0, 4.0) : 4.0);
              final reducible = a.allocatedBudget - minAllowed;
              if (reducible > 0) {
                final reduction = reducible > excess ? excess : reducible;
                final newBudget = double.parse(
                  (a.allocatedBudget - reduction).toStringAsFixed(2),
                );
                newActivities[i] = a.copyWith(allocatedBudget: newBudget);
                excess -= reduction;
              }
            }
          }

          // Pass 2: Trim non-wishlist paid activities and transportation
          if (excess > 0.001) {
            for (int i = 0; i < newActivities.length; i++) {
              if (excess <= 0.001) break;
              final a = newActivities[i];
              final bool isWishlistItem =
                  wishlist != null &&
                  wishlist.any(
                    (w) => _isWishlistMatch(w, a.destination, a.description),
                  );
              if (!isWishlistItem && a.allocatedBudget > 0) {
                final reduction =
                    a.allocatedBudget > excess ? excess : a.allocatedBudget;
                final newBudget = double.parse(
                  (a.allocatedBudget - reduction).toStringAsFixed(2),
                );
                newActivities[i] = a.copyWith(allocatedBudget: newBudget);
                excess -= reduction;
              }
            }
          }

          // Pass 3: If STILL exceeding budget, scale down non-wishlist activities further:
          if (excess > 0.001) {
            for (int i = 0; i < newActivities.length; i++) {
              if (excess <= 0.001) break;
              final a = newActivities[i];
              final bool isWishlistItem =
                  wishlist != null &&
                  wishlist.any(
                    (w) => _isWishlistMatch(w, a.destination, a.description),
                  );
              if (!isWishlistItem && a.allocatedBudget > 0) {
                final reduction =
                    a.allocatedBudget > excess ? excess : a.allocatedBudget;
                final newBudget = double.parse(
                  (a.allocatedBudget - reduction).toStringAsFixed(2),
                );
                newActivities[i] = a.copyWith(allocatedBudget: newBudget);
                excess -= reduction;
              }
            }
          }

          // Pass 4: Last resort ONLY if non-wishlist costs are completely zeroed and budget STILL exceeds:
          // In non-strict mode, replace only the single most expensive wishlist item if necessary,
          // rather than discarding all wishlist items.
          if (excess > 0.001 && !strictBudget && wishlist != null && wishlist.isNotEmpty) {
            int? maxIdx;
            double maxBudget = 0.0;
            for (int i = 0; i < newActivities.length; i++) {
              final a = newActivities[i];
              final bool isWishlistItem = wishlist.any(
                (w) => _isWishlistMatch(w, a.destination, a.description),
              );
              if (isWishlistItem && a.allocatedBudget > maxBudget) {
                maxBudget = a.allocatedBudget;
                maxIdx = i;
              }
            }
            if (maxIdx != null) {
              final a = newActivities[maxIdx];
              final savedBudget = a.allocatedBudget;
              newActivities[maxIdx] = a.copyWith(
                destination: '$destination Heritage & Scenic Spot',
                description: 'Explore scenic and historical attractions around $destination.',
                activityCategory: 'Attraction',
                allocatedBudget: 0.0,
              );
              excess -= savedBudget;
            }
          }
        }
      }

      // Calculate actual total cost from activities
      final double calculatedTotalCost = newActivities.fold(
        0.0,
        (sum, a) => sum + a.allocatedBudget,
      );
      final double resolvedTotalAllocatedBudget = (parsedBudget > 0 && calculatedTotalCost > parsedBudget)
          ? parsedBudget
          : (calculatedTotalCost > 0 ? calculatedTotalCost : responseTotalAllocatedBudget);

      // Resolve wishlist coverage and enforce budget consistency
      int resolvedWishlistCovered = 0;
      double resolvedExtraBudget = 0.0;

      if (wishlist != null && wishlist.isNotEmpty) {
        if (strictBudget) {
          // Top-up mode: 100% of wishlist items are covered and fit within budget
          resolvedWishlistCovered = wishlist.length;
          resolvedExtraBudget = 0.0;
        } else {
          // Identify covered and uncovered wishlist items in newActivities
          final List<String> coveredWishlist = [];
          final List<String> uncoveredWishlist = [];
          for (final item in wishlist) {
            final isMatched = newActivities.any(
              (a) => _isWishlistMatch(item, a.destination, a.description),
            );
            if (isMatched) {
              coveredWishlist.add(item);
            } else {
              uncoveredWishlist.add(item);
            }
          }

          // Case A: If Gemini reported extra budget is needed (budget cannot afford all items),
          // but still scheduled all wishlist items in activities:
          // Prune the excess wishlist item(s) so that only the items the budget CAN afford are covered!
          if (responseEstimatedExtraBudgetNeeded > 0 && uncoveredWishlist.isEmpty && coveredWishlist.length > 1) {
            int itemsToPrune = 1;
            if (responseEstimatedExtraBudgetNeeded > 60.0 && coveredWishlist.length > 2) {
              itemsToPrune = (responseEstimatedExtraBudgetNeeded / 40.0)
                  .clamp(1, coveredWishlist.length - 1)
                  .toInt();
            }

            for (int p = 0; p < itemsToPrune; p++) {
              for (int i = newActivities.length - 1; i >= 0; i--) {
                final a = newActivities[i];
                final matchedItem = coveredWishlist.reversed.firstWhere(
                  (w) => _isWishlistMatch(w, a.destination, a.description),
                  orElse: () => '',
                );
                if (matchedItem.isNotEmpty) {
                  newActivities[i] = a.copyWith(
                    destination: '$destination Heritage & Scenic Spot',
                    description: 'Explore scenic and historical attractions around $destination.',
                    activityCategory: 'Attraction',
                    allocatedBudget: 0.0,
                  );
                  coveredWishlist.remove(matchedItem);
                  uncoveredWishlist.add(matchedItem);
                  break;
                }
              }
            }
          }

          // Resolved covered count
          resolvedWishlistCovered = coveredWishlist.length;

          // Case B: ALL wishlist items are covered and total plan cost is within user budget:
          // In this case, 100% of wishlist items fit within budget -> extra budget needed MUST be 0.0!
          if (uncoveredWishlist.isEmpty && calculatedTotalCost <= (parsedBudget > 0 ? parsedBudget : double.infinity)) {
            resolvedWishlistCovered = wishlist.length;
            resolvedExtraBudget = 0.0;
          } else {
            // Case C: Some wishlist items are uncovered because user's budget is insufficient:
            // Calculate extra budget needed strictly for the uncovered items.
            if (responseEstimatedExtraBudgetNeeded > 0) {
              resolvedExtraBudget = responseEstimatedExtraBudgetNeeded;
            } else {
              // Default estimate: RM 35.00 per uncovered wishlist item
              resolvedExtraBudget = uncoveredWishlist.length * 35.0;
            }

            // Offset any unallocated budget from the user's target budget
            if (parsedBudget > 0 && resolvedExtraBudget > 0.0) {
              final double remainingBudget =
                  (parsedBudget - resolvedTotalAllocatedBudget).clamp(0.0, double.infinity);
              resolvedExtraBudget =
                  (resolvedExtraBudget - remainingBudget).clamp(0.0, double.infinity);
            }

            // Mathematical shortfall if plan exceeded budget
            if (initialExcess > resolvedExtraBudget) {
              resolvedExtraBudget = initialExcess;
            }
          }
        }
      } else {
        // No wishlist provided
        resolvedWishlistCovered = 0;
        if (!strictBudget) {
          if (responseEstimatedExtraBudgetNeeded > 0) {
            resolvedExtraBudget = responseEstimatedExtraBudgetNeeded;
          } else if (initialExcess > 0) {
            resolvedExtraBudget = initialExcess;
          }
        }
      }

      return ItineraryGenerationResult(
        activities: newActivities,
        totalAllocatedBudget: resolvedTotalAllocatedBudget,
        wishlistItemsCoveredCount: resolvedWishlistCovered,
        estimatedExtraBudgetNeeded: resolvedExtraBudget,
      );
    } catch (e) {
      debugPrint('Service Error generating itinerary: $e');
      return ItineraryGenerationResult(
        activities: [
          Activity(
            activitiesId: 'AC9999',
            dayTripId: 'DT9999',
            destination: 'Error Occurred',
            description: e.toString(),
            activityImgUrl: 'assets/logo.png',
            date: DateTime.now(),
            allocatedBudget: 0,
            overspendAmount: null,
            status: 'error',
            startTime: '00:00',
            endTime: '00:00',
            duration: '',
            activityCategory: 'Error',
            isOverspend: false,
          ),
        ],
        totalAllocatedBudget: 0.0,
        wishlistItemsCoveredCount: 0,
        estimatedExtraBudgetNeeded: 0.0,
      );
    }
  }

  /// Returns the existing place name that [candidate] duplicates, or null when
  /// the candidate is a genuinely different venue.
  ///
  /// Matching is deliberately conservative so real alternatives are never
  /// rejected by mistake. Two names are only treated as the same venue when:
  ///   1. they are identical (ignoring case/punctuation), or
  ///   2. one is a *distinctive* multi-word part of the other
  ///      (e.g. "KLCC Park" vs "KLCC Park Fountain"), or
  ///   3. they are near-identical (>= 80% shared words with >= 2 in common),
  ///      e.g. "Petronas Twin Towers" vs "Petronas Towers".
  static String? _findDuplicateMatch(
    String candidate,
    List<String> existing,
  ) {
    final candidateKey = _normalizePlaceName(candidate);
    if (candidateKey.isEmpty) return null;

    final candidateTokens = candidateKey
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toSet();

    for (final name in existing) {
      final key = _normalizePlaceName(name);
      if (key.isEmpty) continue;

      // 1. Identical name.
      if (key == candidateKey) return name;

      // 2. Whole-word containment, but only for a distinctive contained name
      //    (multi-word, or a single word of >= 8 chars). This prevents a short
      //    generic entry (e.g. a city name or "KLCC") from blocking every
      //    nearby venue.
      final shorter = key.length <= candidateKey.length ? key : candidateKey;
      final longer = key.length <= candidateKey.length ? candidateKey : key;
      final shorterTokenCount =
          shorter.split(' ').where((t) => t.isNotEmpty).length;
      if (' $longer '.contains(' $shorter ') &&
          (shorterTokenCount >= 2 || shorter.length >= 8)) {
        return name;
      }

      // 3. Near-identical names: high token overlap.
      final existingTokens = key
          .split(' ')
          .where((t) => t.isNotEmpty)
          .toSet();
      final shared = candidateTokens.intersection(existingTokens);
      if (shared.length >= 2) {
        final union = candidateTokens.union(existingTokens).length;
        if (union > 0 && shared.length / union >= 0.8) return name;
      }
    }
    return null;
  }

  /// Normalises a place name for duplicate comparison: lower-cased, with all
  /// punctuation collapsed to single spaces.
  static String _normalizePlaceName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Deterministic small index derived from a place name, used to vary the
  /// LoremFlickr placeholder so different activities don't share one image.
  static int _stableImageLockIndex(String value) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % 1000;
  }

  // weisong
  @override
  Future<Activity> generateAlternativeItinerary({
    required String destination,
    required DateTime slotDate,
    required String startTime,
    required String endTime,
    required String category,
    required List<String> excludedActivity,
    required String existingActivityId,
    required String dayTripId,
    double budgetLimit = 0.0,
    int dayNumber = 1,
    String? preference,
    List<String>? constraints,
    String? previousActivityDestination,
    String? nextActivityDestination,
    bool isFirstDay = false,
    bool isLastDay = false,
    int totalDays = 1,
  }) async {
    int retries = 4;
    final List<String> localExcluded = List.from(excludedActivity);
    Map<String, dynamic>? item;
    String destTitle = '';
    String imgUrl = '';
    Map<String, dynamic>? place;

    // Derive target area from surrounding activities for better geographic context
    final targetArea = previousActivityDestination ?? nextActivityDestination ?? destination;

    // Tracks whether the loop ran out of retries while rejecting duplicates, so
    // a duplicate is never accidentally accepted as the final result.
    bool blockedByDuplicate = false;

    while (retries > 0) {
      blockedByDuplicate = false;
      final rawJson = await GeminiApiConfig.askGeminiForAlternative(
        destinationCity: destination,
        targetAreaOrNeighborhood: targetArea,
        category: category,
        startTime: startTime,
        endTime: endTime,
        budgetLimit: budgetLimit,
        dayNumber: dayNumber,
        existingOrExcludedPlaces: localExcluded,
        preference: preference,
        constraints: constraints,
        previousActivityDestination: previousActivityDestination,
        nextActivityDestination: nextActivityDestination,
        isFirstDay: isFirstDay,
        isLastDay: isLastDay,
        totalDays: totalDays,
      );
      try {
        item = jsonDecode(rawJson);
        destTitle = item?['destination'] as String? ?? '';
      } catch (e) {
        developer.log('Error decoding alternative itinerary JSON: $e');
        retries--;
        continue;
      }
      if (destTitle.isEmpty) {
        retries--;
        continue;
      }

      // Hard duplicate guard: never accept a place that is already part of the
      // generated trip plan (or one already rejected during this run). Gemini
      // can ignore the exclusion list, so it is enforced here in code.
      final rawDuplicate = _findDuplicateMatch(destTitle, localExcluded);
      if (rawDuplicate != null) {
        developer.log(
          'Alternative destination "$destTitle" duplicates "$rawDuplicate" already in the itinerary. Exclude and retry...',
        );
        localExcluded.add(destTitle);
        blockedByDuplicate = true;
        retries--;
        continue;
      }

      if (GooglePlacesApiConfig.isConfigured) {
        try {
          place = await GooglePlacesApiConfig.searchPlace(destTitle);
          if (place == null) {
            developer.log(
              'Alternative destination "$destTitle" not found in Google Places. Exclude and retry...',
            );
            localExcluded.add(destTitle);
            retries--;
            continue;
          }

          // Google Places canonicalises aliases, so also compare the resolved
          // name (e.g. Gemini's "Petronas Towers" -> "Petronas Twin Towers").
          final String resolvedName = place['name']?.toString() ?? '';
          final resolvedDuplicate = resolvedName.isEmpty
              ? null
              : _findDuplicateMatch(resolvedName, localExcluded);
          if (resolvedDuplicate != null) {
            developer.log(
              'Alternative destination resolved to "$resolvedName" which duplicates "$resolvedDuplicate" already in the itinerary. Exclude and retry...',
            );
            localExcluded.add(resolvedName);
            localExcluded.add(destTitle);
            place = null;
            blockedByDuplicate = true;
            retries--;
            continue;
          }
        } on PlacesApiDeniedException catch (e) {
          developer.log(
            'Google Places API denied ($e). Skipping validation for alternative activity.',
          );
          place = null;
        }
      }
      break;
    }

    if (blockedByDuplicate) {
      throw Exception(
        'Could not find a new activity for this slot — every suggestion was '
        'already in your itinerary. Please try again.',
      );
    }

    if (item == null || destTitle.isEmpty) {
      throw Exception(
        'Failed to generate a valid alternative activity searchable on Google Places.',
      );
    }

    String finalDestinationTitle = destTitle;

    // 1. Preferred source: the Google Places photo for this exact venue.
    if (place != null) {
      if (place['name'] != null && place['name'].toString().isNotEmpty) {
        finalDestinationTitle = place['name'];
      }
      final photos = place['photos'] as List?;
      if (photos != null && photos.isNotEmpty) {
        final firstPhoto = photos.first as Map<String, dynamic>;
        final photoReference = firstPhoto['photo_reference'] as String?;
        if (photoReference != null && photoReference.isNotEmpty) {
          final placesPhotoUrl = GooglePlacesApiConfig.getPhotoUrl(
            photoReference,
          );
          if (placesPhotoUrl.isNotEmpty) {
            imgUrl = placesPhotoUrl;
          }
        }
      }
    }

    // 2. Fallback chain (Wikipedia -> Wikimedia Commons -> LoremFlickr).
    // This MUST also run when Google Places found the venue but had no photo,
    // otherwise the activity would be left with no image at all.
    if (imgUrl.isEmpty) {
      final rawKeyword =
          (item['imageKeyword'] ?? item['image_keyword'])?.toString() ?? '';
      final imageKeyword = rawKeyword.trim().isNotEmpty
          ? rawKeyword.trim()
          : finalDestinationTitle;
      final resolved = await ImageResolverConfig.resolveImage(
        keyword: imageKeyword,
        fallbackTitle: finalDestinationTitle,
        lockIndex: _stableImageLockIndex(imageKeyword),
      );
      imgUrl = resolved.imageUrl;
      // Only adopt Wikipedia's corrected title when Google Places did not
      // already give us a canonical business name.
      if (place == null && resolved.correctedTitle.isNotEmpty) {
        finalDestinationTitle = resolved.correctedTitle;
      }
    }

    final double rawAllocatedBudget =
        (item['allocatedBudget'] as num?)?.toDouble() ?? 0.0;

    final String resolvedCategory =
        item['activityCategory'] as String? ?? category;
    final bool isRestaurant = resolvedCategory.toLowerCase() == 'restaurant';

    final rawMinPrice = item['minPrice'] != null
        ? (item['minPrice'] as num).toDouble()
        : null;

    // The alternative prompt asks Gemini for "minPrice" but it used to be
    // dropped here, which left minAllocatedBudget null - so the budget
    // reallocation treated this venue's minimum cost as MYR 0 and could trim it
    // down to nothing. These are the same realism rules askGeminiForItinerary
    // uses: food in Malaysia is never free, and a restaurant always has a floor.
    final double allocatedBudget =
        (isRestaurant && rawAllocatedBudget <= 0.0)
            ? (rawMinPrice != null && rawMinPrice > 0 ? rawMinPrice : 8.0)
            : rawAllocatedBudget;

    final double? minPriceLocal =
        isRestaurant && (rawMinPrice == null || rawMinPrice <= 0.0)
            ? 5.0
            : rawMinPrice;

    return Activity(
      activitiesId: existingActivityId,
      dayTripId: dayTripId,
      destination: finalDestinationTitle,
      description: item['description'] as String? ?? '',
      activityImgUrl: imgUrl,
      date: slotDate,
      allocatedBudget: allocatedBudget,
      minAllocatedBudget: minPriceLocal,
      overspendAmount: allocatedBudget > 0 ? 0 : null,
      status: 'pending',
      startTime: startTime,
      endTime: endTime,
      duration: item['duration'] as String? ?? '60 min',
      activityCategory: resolvedCategory,
      isOverspend: false,
    );
  }

  @override
  Future<Activity> regenerateTransportation({
    required String originPlace,
    required String destinationPlace,
    required String city,
    required String existingActivityId,
    required String dayTripId,
    required DateTime date,
    String? startTime,
    String? endTime,
  }) async {
    final rawJson = await GeminiApiConfig.askGeminiForTransportation(
      originPlace: originPlace,
      destinationPlace: destinationPlace,
      city: city,
    );

    Map<String, dynamic> item;
    try {
      item = jsonDecode(rawJson);
    } catch (e) {
      developer.log('Error decoding transportation JSON: $e');
      // Fallback: simple walking transport
      item = {
        'destination': 'Walk to $destinationPlace',
        'description': 'Commute to the next activity',
        'duration': '15 min',
        'allocatedBudget': 0.0,
      };
    }

    final destName =
        item['destination'] as String? ?? 'Walk to $destinationPlace';
    final imageKeyword =
        (item['imageKeyword'] ?? item['image_keyword'] ?? destName) as String;

    String imgUrl = '';
    String finalDestinationTitle = destName;
    bool resolvedByGooglePlaces = false;

    // Google Places API image resolution
    if (GooglePlacesApiConfig.isConfigured) {
      try {
        final place = await GooglePlacesApiConfig.searchPlace(destName);
        if (place != null) {
          resolvedByGooglePlaces = true;
          if (place['name'] != null &&
              place['name'].toString().isNotEmpty) {
            finalDestinationTitle = place['name'];
          }
          final photos = place['photos'] as List?;
          if (photos != null && photos.isNotEmpty) {
            final firstPhoto = photos.first as Map<String, dynamic>;
            final photoReference =
                firstPhoto['photo_reference'] as String?;
            if (photoReference != null && photoReference.isNotEmpty) {
              imgUrl = GooglePlacesApiConfig.getPhotoUrl(photoReference);
            }
          }
        }
      } catch (e) {
        developer.log(
          'Google Places resolution error for transport $destName: $e',
        );
      }
    }

    // Fallback image resolvers (Wikipedia -> Wikimedia Commons -> LoremFlickr)
    if (imgUrl.isEmpty && !resolvedByGooglePlaces) {
      try {
        final resolved = await ImageResolverConfig.resolveImage(
          keyword: imageKeyword,
          fallbackTitle: finalDestinationTitle,
          lockIndex: 0,
        );
        imgUrl = resolved.imageUrl;
        finalDestinationTitle = resolved.correctedTitle;
      } catch (_) {}
    }

    final double allocatedBudget =
        (item['allocatedBudget'] as num?)?.toDouble() ?? 0.0;

    return Activity(
      activitiesId: existingActivityId,
      dayTripId: dayTripId,
      date: date,
      destination: finalDestinationTitle,
      description:
          item['description'] as String? ?? 'Commute between activities',
      activityImgUrl: imgUrl,
      allocatedBudget: allocatedBudget,
      overspendAmount: allocatedBudget > 0 ? 0 : null,
      status: 'pending',
      startTime: startTime,
      endTime: endTime,
      duration: item['duration'] as String? ?? '15 min',
      activityCategory: 'Transportation',
      isOverspend: false,
    );
  }

  @override
  Future<List<Activity>> regenerateEmptySlotsFromRemainingPlan({
    required String destination,
    required double remainingBudget,
    required List<Activity> remainingActivities,
    required List<Activity> emptySlots,
    required List<String> excludedPlaces,
    List<String>? uncoveredWishlist,
    String? preference,
    List<String>? constraints,
  }) async {
    if (emptySlots.isEmpty) return [];

    // Map remaining activities to lightweight maps for route/schedule context
    final mappedRemaining = remainingActivities.map((a) {
      return {
        'date': a.date.toIso8601String().split('T').first,
        'startTime': a.startTime ?? '',
        'endTime': a.endTime ?? '',
        'destination': a.destination,
        'activityCategory': a.activityCategory,
        'allocatedBudget': a.allocatedBudget,
      };
    }).toList();

    // Map empty slots to lightweight maps
    final mappedEmpty = emptySlots.map((s) {
      return {
        'activitiesId': s.activitiesId,
        'date': s.date.toIso8601String().split('T').first,
        'startTime': s.startTime ?? '',
        'endTime': s.endTime ?? '',
        'category': s.activityCategory,
      };
    }).toList();

    final rawJson = await GeminiApiConfig.askGeminiToRegenerateEmptySlots(
      destinationCity: destination,
      remainingBudget: remainingBudget,
      remainingActivities: mappedRemaining,
      emptySlots: mappedEmpty,
      excludedPlaces: excludedPlaces,
      uncoveredWishlist: uncoveredWishlist,
      preference: preference,
      constraints: constraints,
    );

    List<dynamic> parsedList = [];
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        parsedList = decoded;
      }
    } catch (e) {
      developer.log('Error decoding regenerated empty slots: $e');
    }

    // Create a map of regenerated data by activitiesId
    final Map<String, Map<String, dynamic>> itemsBySlotId = {};
    for (int i = 0; i < parsedList.length; i++) {
      final item = parsedList[i];
      if (item is Map<String, dynamic>) {
        final id = item['activitiesId']?.toString();
        if (id != null && id.isNotEmpty) {
          itemsBySlotId[id] = item;
        } else if (i < emptySlots.length) {
          itemsBySlotId[emptySlots[i].activitiesId] = item;
        }
      }
    }

    final List<Activity> resultActivities = [];

    for (final slot in emptySlots) {
      final item = itemsBySlotId[slot.activitiesId];
      final destTitle = item?['destination'] as String? ?? '';

      if (destTitle.isEmpty) {
        // If Gemini failed for this slot, fallback to single alternative generator
        try {
          final singleFallback = await generateAlternativeItinerary(
            destination: destination,
            slotDate: slot.date,
            startTime: slot.startTime ?? '09:00',
            endTime: slot.endTime ?? '11:00',
            category: slot.activityCategory.isNotEmpty
                ? slot.activityCategory
                : 'Attraction',
            excludedActivity: excludedPlaces,
            existingActivityId: slot.activitiesId,
            dayTripId: slot.dayTripId,
            budgetLimit: remainingBudget > 0
                ? (remainingBudget / emptySlots.length)
                : 30.0,
          );
          resultActivities.add(singleFallback);
          continue;
        } catch (_) {
          resultActivities.add(slot);
          continue;
        }
      }

      String finalTitle = destTitle;
      String imgUrl = '';
      bool resolvedByGooglePlaces = false;

      if (GooglePlacesApiConfig.isConfigured) {
        try {
          final place = await GooglePlacesApiConfig.searchPlace(destTitle);
          if (place != null) {
            resolvedByGooglePlaces = true;
            if (place['name'] != null && place['name'].toString().isNotEmpty) {
              finalTitle = place['name'];
            }
            final photos = place['photos'] as List?;
            if (photos != null && photos.isNotEmpty) {
              final firstPhoto = photos.first as Map<String, dynamic>;
              final photoRef = firstPhoto['photo_reference'] as String?;
              if (photoRef != null && photoRef.isNotEmpty) {
                imgUrl = GooglePlacesApiConfig.getPhotoUrl(photoRef);
              }
            }
          }
        } catch (e) {
          developer.log('Google Places search error for "$destTitle": $e');
        }
      }

      if (imgUrl.isEmpty && !resolvedByGooglePlaces) {
        final imageKeyword =
            (item?['imageKeyword'] ?? item?['image_keyword'] ?? destTitle)
                as String;
        try {
          final resolved = await ImageResolverConfig.resolveImage(
            keyword: imageKeyword,
            fallbackTitle: finalTitle,
            lockIndex: 0,
          );
          imgUrl = resolved.imageUrl;
          finalTitle = resolved.correctedTitle;
        } catch (_) {}
      }

      final rawAllocated =
          (item?['allocatedBudget'] as num?)?.toDouble() ?? 0.0;
      final category =
          (item?['activityCategory'] as String?) ??
          (slot.activityCategory.isNotEmpty
              ? slot.activityCategory
              : 'Attraction');
      final isRestaurant = category.toLowerCase() == 'restaurant';

      final rawMinPrice = item?['minPrice'] != null
          ? (item?['minPrice'] as num).toDouble()
          : null;

      final double allocatedBudget = (isRestaurant && rawAllocated <= 0.0)
          ? (rawMinPrice != null && rawMinPrice > 0 ? rawMinPrice : 8.0)
          : rawAllocated;

      double? minPriceLocal =
          isRestaurant && (rawMinPrice == null || rawMinPrice <= 0.0)
              ? 5.0
              : rawMinPrice;

      // Ensure minimum floor price never exceeds allocated budget
      if (minPriceLocal != null && minPriceLocal > allocatedBudget && allocatedBudget > 0) {
        minPriceLocal = allocatedBudget;
      }

      resultActivities.add(
        Activity(
          activitiesId: slot.activitiesId,
          dayTripId: slot.dayTripId,
          destination: finalTitle,
          description: (item?['description'] as String?) ?? '',
          activityImgUrl: imgUrl,
          date: slot.date,
          allocatedBudget: allocatedBudget,
          minAllocatedBudget: minPriceLocal,
          overspendAmount: allocatedBudget > 0 ? 0 : null,
          status: 'pending',
          startTime:
              (item?['startTime'] as String?) ?? slot.startTime ?? '09:00',
          endTime: (item?['endTime'] as String?) ?? slot.endTime ?? '11:00',
          duration: (item?['duration'] as String?) ?? slot.duration ?? '60 min',
          activityCategory: category,
          isOverspend: false,
        ),
      );
    }

    return resultActivities;
  }

  // kokhong
  @override
  Future<bool> saveItinerary(
    List<dynamic> activities, {
    required String destination,
    required String datesText,
    required String budgetText,
  }) async {
    final activityList = activities.cast<Activity>();
    if (activityList.isEmpty) return false;

    double budget = 0;
    try {
      budget = double.parse(budgetText.replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (_) {}

    try {
      await _itineraryRepository.insertFullTrip(
        destination: destination,
        datesText: datesText,
        totalBudget: budget,
        remainingBalance: budget,
        activities: activityList,
      );
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // weisong
  @override
  Future<({WholeTrip trip, List<Activity> activities})?>
  fetchLatestTrip() async {
    final latestTrip = await _itineraryRepository.fetchLatestTrip();
    if (latestTrip == null || latestTrip.tripId == null) {
      return null;
    }
    final activities = await _itineraryRepository.fetchAllActivitiesByTrip(
      latestTrip.tripId!,
    );
    return (trip: latestTrip, activities: activities);
  }

  @override
  Future<List<Activity>> fetchAllActivitiesByTrip(String tripId) async {
    return await _itineraryRepository.fetchAllActivitiesByTrip(tripId);
  }

  // zhiqin
  @override
  Future<bool> endTrip(String id) async {
    try {
      await _itineraryRepository.terminateTrip(id, 'terminated');
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // zhiqin
  @override
  Future<List<DayTrip>> getDaysByTripId(String id) async {
    try {
      return await _itineraryRepository.fetchDaysByTripId(id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Activity>> getRemainingActivities(
    String tripId,
    DateTime currentDateTime,
  ) async {
    try {
      final activities = await _itineraryRepository.fetchAllActivitiesByTrip(
        tripId,
      );

      activities.sort((a, b) {
        final aDateTime = _getActivityStartDateTime(a);
        final bDateTime = _getActivityStartDateTime(b);

        return aDateTime.compareTo(bDateTime);
      });

      return activities.where((activity) {
        final activityStart = _getActivityStartDateTime(activity);

        return activityStart.isAfter(currentDateTime);
      }).toList();
    } catch (e) {
      debugPrint('Calculating Remaining Activities Error: $e');
      rethrow;
    }
  }

  DateTime _getActivityStartDateTime(Activity activity) {
    final date = activity.date;

    final timeParts = activity.startTime?.split(':');

    final hour = int.parse(timeParts![0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  @override
  Future<void> updateTripStatus(String tripId, String newStatus) async {
    final allowedStatus = ['Pending', 'Ongoing', 'Completed'];
    if (!allowedStatus.contains(newStatus)) {
      throw ArgumentError(
        'Invalid trip status. Allowed values are: $allowedStatus',
      );
    }
    await _itineraryRepository.updateTripStatus(tripId, newStatus);
  }

  // kokhong
  @override
  Future<List<String>> getAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  }) async {
    return await GooglePlacesApiConfig.getAutocompleteSuggestions(
      query,
      destinations: destinations,
    );
  }

  @override
  Future<List<String>> getAirportAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  }) async {
    return await GooglePlacesApiConfig.getAirportAutocompleteSuggestions(
      query,
      destinations: destinations,
    );
  }

  @override
  Future<List<String>> getHotelAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  }) async {
    return await GooglePlacesApiConfig.getHotelAutocompleteSuggestions(
      query,
      destinations: destinations,
    );
  }

  // weisong
  @override
  Future<List<Activity>> generateBudgetRecoveryItinerary({
    required String tripId,
    required double effectiveRemainingBudget,
    required double currentSpentBudget,
    required double topUpAmount,
    required List<Activity> remainingActivities,
    required String tripDestination,
    String? userCoordinates,
    DateTime? currentDate,
    DateTime? tripEndDate,
  }) async {
    // 1. Create lookup map for preserving IDs and metadata
    final Map<String, Activity> activityLookup = {
      for (final act in remainingActivities) act.activitiesId: act,
    };

    final rawActivitiesPayload = remainingActivities
        .map(
          (act) => {
            'activitiesId': act.activitiesId,
            'dayTripId': act.dayTripId,
            'destination': act.destination,
            'description': act.description,
            'date': act.date.toIso8601String(),
            'startTime': act.startTime,
            'endTime': act.endTime,
            'allocatedBudget': act.allocatedBudget,
            'activityCategory': act.activityCategory,
          },
        )
        .toList();

    // 2. Call Gemini API endpoint
    final List<Map<String, dynamic>> rawResponseList =
        await GeminiApiConfig.generateRecoveryItinerary(
          effectiveRemainingBudget: effectiveRemainingBudget,
          currentSpentBudget: currentSpentBudget,
          topUpAmount: topUpAmount,
          remainingActivities: rawActivitiesPayload,
          tripDestination: tripDestination,
          userCoordinates: userCoordinates,
          currentDate: currentDate,
          tripEndDate: tripEndDate,
        );

    final defaultDayTripId = remainingActivities.isNotEmpty
        ? remainingActivities.first.dayTripId
        : '';

    // 3. Map returned JSON array back to domain entities
    final revisedActivities = rawResponseList.map((item) {
      final actId = item['activitiesId']?.toString() ?? '';
      final originalActivity = activityLookup[actId];
      final rawAllocatedBudget =
          (item['allocatedBudget'] as num?)?.toDouble() ?? 0.0;

      final String resolvedCategory =
          item['activityCategory']?.toString() ??
              originalActivity?.activityCategory ??
              'General';
      final bool isRestaurant = resolvedCategory.toLowerCase() == 'restaurant';

      final rawMinPrice = item['minPrice'] != null
          ? (item['minPrice'] as num).toDouble()
          : null;

      // Same realism rules as askGeminiForItinerary: food in Malaysia is never
      // free, and every restaurant carries a minimum cost floor so the budget
      // reallocation can never trim it below a plausible price.
      final double allocatedBudget =
          (isRestaurant && rawAllocatedBudget <= 0.0)
              ? (rawMinPrice != null && rawMinPrice > 0 ? rawMinPrice : 8.0)
              : rawAllocatedBudget;

      final double? minPriceLocal =
          isRestaurant && (rawMinPrice == null || rawMinPrice <= 0.0)
              ? 5.0
              : rawMinPrice;

      return Activity(
        activitiesId: actId.isNotEmpty
            ? actId
            : IdGenerator.generateNextFormattedId('AC', null),
        dayTripId:
            item['dayTripId']?.toString() ??
            originalActivity?.dayTripId ??
            defaultDayTripId,
        destination: item['destination']?.toString() ?? '',
        description: item['description']?.toString() ?? '',
        activityImgUrl: item['activityImgUrl']?.toString().isNotEmpty == true
            ? item['activityImgUrl'].toString()
            : (originalActivity?.activityImgUrl ?? 'assets/logo.png'),
        date: originalActivity?.date ?? DateTime.now(),
        allocatedBudget: allocatedBudget,
        minAllocatedBudget: minPriceLocal,
        overspendAmount: allocatedBudget > 0 ? 0 : null,
        status: item['status']?.toString() ?? 'pending',
        startTime:
            item['startTime']?.toString() ??
            originalActivity?.startTime ??
            '09:00',
        endTime:
            item['endTime']?.toString() ?? originalActivity?.endTime ?? '10:00',
        duration:
            item['duration']?.toString() ??
            originalActivity?.duration ??
            '60 min',
        activityCategory: resolvedCategory,
        isOverspend: false,
      );
    }).toList();
    final oldIdsToReplace = remainingActivities
        .map((a) => a.activitiesId)
        .toList();

    // 4. Update the database through the repository
    if (revisedActivities.isNotEmpty) {
      await _itineraryRepository.replaceRemainingActivities(
        dayTripId: defaultDayTripId,
        oldRemainingActivityIds: oldIdsToReplace,
        newActivities: revisedActivities,
      );
    }
    return revisedActivities;
  }

  @override
  Future<void> saveRevisedItineraryActivities(List<Activity> activities) async {
    if (activities.isEmpty) return;

    final tripId = activities.first.dayTripId; // or target trip identifier

    try {
      await _itineraryRepository.replaceTripActivities(
        tripId: tripId,
        newActivities: activities,
      );
    } catch (e) {
      debugPrint('Error saving revised itinerary activities: $e');
      rethrow;
    }
  }

  @override
  Future<List<WholeTrip>> fetchAllTrip() {
    return _itineraryRepository.fetchAllTrip();
  }

  @override
  Future<WholeTrip?> fetchLatestTripWithCurrentUserId() {
    return _itineraryRepository.fetchLatestTrip();
  }

  @override
  Future<Map<String, dynamic>> getTripSpentSummary(
    List<String> activityIds,
  ) async {
    try {
      return await _itineraryRepository.fetchSpentSummaryByActivityIds(
        activityIds,
      );
    } catch (e) {
      debugPrint('Error in getTripSpentSummary service: $e');
      rethrow;
    }
  }

  // call the delete trip method from repository
  @override
  Future<void> deleteWholeTrip(String tripId) async {
    try {
      await _itineraryRepository.deleteWholeTrip(tripId);
    } catch (e) {
      debugPrint('Error deleting whole trip: $e');
      rethrow;
    }
  }
}

class GetCachedActivities implements ICachedActivity {
  final ISharedPreferencesRepo _itineraryRepository = ActivityLocalCache();

  @override
  Future<List<Activity>> getActivitiesForTrip(
    String tripId, {
    bool forceRefresh = false,
  }) async {
    // Service delegates entirely to repository
    return await _itineraryRepository.getActivities(
      tripId,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<void> saveActivitiesLocally(
    String tripId,
    List<Activity> activities,
  ) async {
    await _itineraryRepository.saveActivitiesLocally(tripId, activities);
  }

  @override
  Future<void> clearLocalActivities(String tripId) async {
    await _itineraryRepository.clearLocalActivities(tripId);
  }
}
