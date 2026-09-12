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
      int responseWishlistItemsCoveredCount = 0;
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
          arrivalLocation: arrivalLocation,
          arrivalTime: arrivalTime,
          departureLocation: departureLocation,
          departureTime: departureTime,
          hotelLocation: hotelLocation,
          hotelCheckInTime: hotelCheckInTime,
          hotelCheckOutTime: hotelCheckOutTime,
        );

        // Extract JSON object
        final jsonMatch = RegExp(
          r'\{.*\}',
          dotAll: true,
        ).firstMatch(responseText);

        if (jsonMatch == null) {
          retries--;
          if (retries == 0) {
            throw Exception(
              'No JSON found in response after multiple attempts: $responseText',
            );
          }
          continue;
        }

        final jsonString = jsonMatch.group(0)!;
        Map<String, dynamic> parsedObj;
        try {
          parsedObj = jsonDecode(jsonString) as Map<String, dynamic>;
        } catch (e) {
          retries--;
          if (retries == 0) {
            throw Exception('Invalid JSON returned by Gemini: $jsonString');
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
          responseWishlistItemsCoveredCount =
              (parsedObj['wishlistItemsCoveredCount'] as num?)?.toInt() ?? 0;
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
          }
        }

        if (apiDenied) {
          validatedList = jsonList;
          responseTotalAllocatedBudget =
              (parsedObj['totalAllocatedBudget'] as num?)?.toDouble() ?? 0.0;
          responseWishlistItemsCoveredCount =
              (parsedObj['wishlistItemsCoveredCount'] as num?)?.toInt() ?? 0;
          responseEstimatedExtraBudgetNeeded =
              (parsedObj['estimatedExtraBudgetNeeded'] as num?)?.toDouble() ??
              0.0;
          break;
        }

        if (allValid &&
            strictBudget &&
            wishlist != null &&
            wishlist.isNotEmpty) {
          final destNames = jsonList
              .map(
                (item) => (item['destination'] as String? ?? '').toLowerCase(),
              )
              .toList();
          final allWishlistIncluded = wishlist.every((w) {
            final lowerW = w.toLowerCase().trim();
            return destNames.any(
              (d) => d.contains(lowerW) || lowerW.contains(d),
            );
          });
          if (!allWishlistIncluded && retries > 1) {
            developer.log(
              'Strict budget plan did not include all wishlist items, retrying...',
            );
            allValid = false;
          }
        }

        if (allValid) {
          validatedList = jsonList;
          responseTotalAllocatedBudget =
              (parsedObj['totalAllocatedBudget'] as num?)?.toDouble() ?? 0.0;
          responseWishlistItemsCoveredCount =
              (parsedObj['wishlistItemsCoveredCount'] as num?)?.toInt() ?? 0;
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
            responseWishlistItemsCoveredCount =
                (lastParsedObj['wishlistItemsCoveredCount'] as num?)?.toInt() ??
                0;
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

      List<Activity> newActivities = [];
      int index = 1;
      String currentActId = 'AC0000';
      String currentDayTripId = IdGenerator.generateNextFormattedId('DT', null);

      for (var item in validatedList) {
        currentActId = IdGenerator.generateNextFormattedId('AC', currentActId);
        final allocatedBudget =
            (item['allocatedBudget'] as num?)?.toDouble() ?? 0.0;
        final minPriceLocal = item['minPrice'] != null
            ? (item['minPrice'] as num).toDouble()
            : null;

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

      // Calculate actual total cost from activities
      final double calculatedTotalCost = newActivities.fold(
        0.0,
        (sum, a) => sum + a.allocatedBudget,
      );
      final double resolvedTotalAllocatedBudget = calculatedTotalCost > 0
          ? calculatedTotalCost
          : responseTotalAllocatedBudget;

      // Calculate mathematical budget shortfall
      final double parsedBudget = double.tryParse(budget) ?? 0.0;
      final double mathShortfall = (resolvedTotalAllocatedBudget - parsedBudget)
          .clamp(0.0, double.infinity);

      double resolvedExtraBudget = responseEstimatedExtraBudgetNeeded;
      if (mathShortfall > resolvedExtraBudget) {
        resolvedExtraBudget = mathShortfall;
      }

      // Resolve wishlist coverage from activities and Gemini estimation
      int resolvedWishlistCovered = 0;
      if (wishlist != null && wishlist.isNotEmpty) {
        resolvedWishlistCovered = responseWishlistItemsCoveredCount;
        final activityDestinations = newActivities
            .map((a) => a.destination.toLowerCase())
            .toSet();
        int matchedCount = 0;
        for (final item in wishlist) {
          final lowerItem = item.toLowerCase().trim();
          if (activityDestinations.any(
            (dest) => dest.contains(lowerItem) || lowerItem.contains(dest),
          )) {
            matchedCount++;
          }
        }

        if (strictBudget) {
          resolvedWishlistCovered = wishlist.length;
          resolvedExtraBudget = 0.0;
        } else {
          // If Gemini returned 0 or didn't set coverage, but items matched in activities
          if (resolvedWishlistCovered == 0 && matchedCount > 0) {
            resolvedWishlistCovered = matchedCount.clamp(
              0,
              wishlist.length - 1,
            );
          } else if (resolvedWishlistCovered > wishlist.length) {
            resolvedWishlistCovered = wishlist.length;
          }
        }

        // When wishlist is incomplete, ensure there is a realistic estimated shortfall for missing items
        final bool wishlistIncomplete =
            resolvedWishlistCovered < wishlist.length;
        if (!strictBudget && wishlistIncomplete && resolvedExtraBudget <= 0.0) {
          final uncoveredCount = wishlist.length - resolvedWishlistCovered;
          resolvedExtraBudget = uncoveredCount * 30.0;
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
    int retries = 3;
    final List<String> localExcluded = List.from(excludedActivity);
    Map<String, dynamic>? item;
    String destTitle = '';
    String imgUrl = '';
    Map<String, dynamic>? place;

    // Derive target area from surrounding activities for better geographic context
    final targetArea = previousActivityDestination ?? nextActivityDestination ?? destination;

    while (retries > 0) {
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
        } on PlacesApiDeniedException catch (e) {
          developer.log(
            'Google Places API denied ($e). Skipping validation for alternative activity.',
          );
          place = null;
        }
      }
      break;
    }

    if (item == null || destTitle.isEmpty) {
      throw Exception(
        'Failed to generate a valid alternative activity searchable on Google Places.',
      );
    }

    String finalDestinationTitle = destTitle;
    bool resolvedByGooglePlaces = false;

    if (place != null) {
      resolvedByGooglePlaces = true;
      if (place['name'] != null && place['name'].toString().isNotEmpty) {
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

    // Fallback image resolvers (Wikipedia -> Wikimedia Commons -> LoremFlickr)
    if (imgUrl.isEmpty && !resolvedByGooglePlaces) {
      final imageKeyword =
          (item['imageKeyword'] ?? item['image_keyword'] ?? destTitle)
              as String;
      final resolved = await ImageResolverConfig.resolveImage(
        keyword: imageKeyword,
        fallbackTitle: finalDestinationTitle,
        lockIndex: 0,
      );
      imgUrl = resolved.imageUrl;
      finalDestinationTitle = resolved.correctedTitle;
    }

    final double allocatedBudget =
        (item['allocatedBudget'] as num?)?.toDouble() ?? 0.0;

    return Activity(
      activitiesId: existingActivityId,
      dayTripId: dayTripId,
      destination: finalDestinationTitle,
      description: item['description'] as String? ?? '',
      activityImgUrl: imgUrl,
      date: slotDate,
      allocatedBudget: allocatedBudget,
      overspendAmount: allocatedBudget > 0 ? 0 : null,
      status: 'pending',
      startTime: startTime,
      endTime: endTime,
      duration: item['duration'] as String? ?? '60 min',
      activityCategory: item['activityCategory'] as String? ?? category,
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

      final double allocatedBudget =
          (item?['allocatedBudget'] as num?)?.toDouble() ?? 0.0;
      final category =
          (item?['activityCategory'] as String?) ??
          (slot.activityCategory.isNotEmpty
              ? slot.activityCategory
              : 'Attraction');

      resultActivities.add(
        Activity(
          activitiesId: slot.activitiesId,
          dayTripId: slot.dayTripId,
          destination: finalTitle,
          description: (item?['description'] as String?) ?? '',
          activityImgUrl: imgUrl,
          date: slot.date,
          allocatedBudget: allocatedBudget,
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
      final allocatedBudget =
          (item['allocatedBudget'] as num?)?.toDouble() ?? 0.0;

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
        activityCategory:
            item['activityCategory']?.toString() ??
            (originalActivity?.activityCategory ?? 'General'),
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
