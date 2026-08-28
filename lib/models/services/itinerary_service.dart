import 'dart:convert';
import 'dart:developer' as developer;
import 'package:Trek/models/entities/day_trip.dart';
import 'package:http/http.dart' as http;

import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../configurations/gemini_api_config.dart';
import '../configurations/google_places_api_config.dart';
import '../repository/itinerary_repository.dart';
import '../repository/i_itinerary_repository.dart';
import '../../utils/id_generator.dart';
import 'i_itinerary_service.dart';

class ItineraryService implements IItineraryService {
  final IItineraryRepository _itineraryRepository = ItineraryRepository();

  // kokhong
  Future<ItineraryGenerationResult> generateItinerary({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    String? emergencyFund,
    List<String>? wishlist,
  }) async {
    try {
      int retries = 3;
      List<String> failedDestinations = [];
      List<dynamic> validatedList = [];
      Map<String, Map<String, dynamic>?> searchCache = {};

      double responseTotalAllocatedBudget = 0.0;
      int responseWishlistItemsCoveredCount = 0;
      double responseEstimatedExtraBudgetNeeded = 0.0;

      while (retries > 0) {
        final responseText = await GeminiApiConfig.askGeminiForItinerary(
          destination: destination,
          dates: dates,
          budget: budget,
          preference: preference,
          emergencyFund: emergencyFund,
          avoidPlaces: failedDestinations,
          wishlist: wishlist,
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

        if (!GooglePlacesApiConfig.isConfigured) {
          // If Google Places API is not configured, we cannot verify, so just break and use the results
          validatedList = jsonList;
          responseTotalAllocatedBudget =
              (parsedObj['totalAllocatedBudget'] as num?)?.toDouble() ?? 0.0;
          responseWishlistItemsCoveredCount =
              parsedObj['wishlistItemsCoveredCount'] as int? ?? 0;
          responseEstimatedExtraBudgetNeeded =
              (parsedObj['estimatedExtraBudgetNeeded'] as num?)?.toDouble() ??
              0.0;
          break;
        }

        bool allValid = true;
        bool apiDenied = false;
        List<String> currentFailed = [];

        for (var item in jsonList) {
          final destName = item['destination'] as String? ?? '';
          if (destName.isEmpty) continue;

          if (!searchCache.containsKey(destName)) {
            try {
              final place = await GooglePlacesApiConfig.searchPlace(destName);
              searchCache[destName] = place;
            } on PlacesApiDeniedException catch (e) {
              // API key is not valid / Places API not enabled — skip all validation
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
            allValid = false;
            currentFailed.add(destName);
          }
        }

        if (apiDenied) {
          // API is not usable, accept Gemini results without verification
          validatedList = jsonList;
          responseTotalAllocatedBudget =
              (parsedObj['totalAllocatedBudget'] as num?)?.toDouble() ?? 0.0;
          responseWishlistItemsCoveredCount =
              parsedObj['wishlistItemsCoveredCount'] as int? ?? 0;
          responseEstimatedExtraBudgetNeeded =
              (parsedObj['estimatedExtraBudgetNeeded'] as num?)?.toDouble() ??
              0.0;
          break;
        }

        if (allValid) {
          validatedList = jsonList;
          responseTotalAllocatedBudget =
              (parsedObj['totalAllocatedBudget'] as num?)?.toDouble() ?? 0.0;
          responseWishlistItemsCoveredCount =
              parsedObj['wishlistItemsCoveredCount'] as int? ?? 0;
          responseEstimatedExtraBudgetNeeded =
              (parsedObj['estimatedExtraBudgetNeeded'] as num?)?.toDouble() ??
              0.0;
          break;
        } else {
          developer.log(
            'Google Places validation failed. The following places are not searchable: $currentFailed',
          );
          failedDestinations.addAll(currentFailed);
          // remove duplicates
          failedDestinations = failedDestinations.toSet().toList();
          retries--;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (validatedList.isEmpty) {
        throw Exception(
          'Failed to generate a valid itinerary with searchable Google Places locations.',
        );
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
        final maxPriceLocal = item['maxPrice'] != null
            ? (item['maxPrice'] as num).toDouble()
            : null;

        final destName = item['destination'] as String? ?? 'Activity';
        final imageKeyword = item['imageKeyword'] as String? ?? destName;

        String imgUrl = '';
        String finalDestinationTitle = destName;
        bool resolvedByGooglePlaces = false;

        // ──────────────────────────────────────────────────
        // Google Places API
        // Provides official name correction + high-quality photos
        // ──────────────────────────────────────────────────
        if (GooglePlacesApiConfig.isConfigured) {
          try {
            final place = searchCache[destName];
            if (place != null) {
              resolvedByGooglePlaces = true;
              // Correct name to official Google Places name
              if (place['name'] != null &&
                  place['name'].toString().isNotEmpty) {
                finalDestinationTitle = place['name'];
              }
              // Fetch official high-resolution photo
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

        // ──────────────────────────────────────────────────
        // Wikipedia + Wikimedia Commons
        // Only used when Google Places is NOT configured or
        // did NOT find the place at all. Skipped if Google
        // Places found the place (even without a photo),
        // because Wikipedia returns irrelevant results for
        // specific Malaysian restaurants/cafes.
        // ──────────────────────────────────────────────────
        if (imgUrl.isEmpty && !resolvedByGooglePlaces) {
          final query = Uri.encodeComponent(imageKeyword);
          const wikiHeaders = {
            'User-Agent': 'TrekApp/1.0 (Flutter; travel itinerary generator)',
          };

          // English Wikipedia
          try {
            final wikiUrl = Uri.parse(
              'https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=$query&gsrlimit=1&prop=pageimages&format=json&pithumbsize=600&origin=*',
            );
            final wikiRes = await http.get(wikiUrl, headers: wikiHeaders);
            if (wikiRes.statusCode == 200) {
              final data = jsonDecode(wikiRes.body);
              final pages = data['query']?['pages'] as Map<String, dynamic>?;
              if (pages != null && pages.isNotEmpty) {
                final page = pages.values.first;
                if (page['title'] != null &&
                    !page['title'].toString().startsWith('File:')) {
                  finalDestinationTitle = page['title'];
                }
                if (page.containsKey('thumbnail')) {
                  imgUrl = page['thumbnail']['source'] as String? ?? '';
                }
              }
            }
          } catch (_) {}

          // Wikimedia Commons (if Wikipedia had no image)
          if (imgUrl.isEmpty) {
            try {
              final commonsQuery = Uri.encodeComponent(finalDestinationTitle);
              final commonsUrl = Uri.parse(
                'https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=$commonsQuery&gsrnamespace=6&gsrlimit=1&prop=imageinfo&iiprop=url&iiurlwidth=600&format=json&origin=*',
              );
              final commonsRes = await http.get(
                commonsUrl,
                headers: wikiHeaders,
              );
              if (commonsRes.statusCode == 200) {
                final data = jsonDecode(commonsRes.body);
                final pages = data['query']?['pages'] as Map<String, dynamic>?;
                if (pages != null && pages.isNotEmpty) {
                  final page = pages.values.first;
                  if (page.containsKey('imageinfo')) {
                    final imageInfo = page['imageinfo'] as List;
                    if (imageInfo.isNotEmpty &&
                        imageInfo[0]['thumburl'] != null) {
                      imgUrl = imageInfo[0]['thumburl'] as String;
                    }
                  }
                }
              }
            } catch (_) {}
          }
        }

        // ──────────────────────────────────────────────────
        // LoremFlickr placeholder
        // ──────────────────────────────────────────────────
        if (imgUrl.isEmpty) {
          final keywordQuery = Uri.encodeComponent(
            imageKeyword.replaceAll(RegExp(r'\s+'), ','),
          );
          imgUrl = 'https://loremflickr.com/600/400/$keywordQuery?lock=$index';
        }

        int dayNumber = item['dayNumber'] as int? ?? 1;
        String startTimeStr = item['startTime'] as String? ?? '09:00';

        DateTime baseDate = DateTime.now().add(Duration(days: dayNumber - 1));
        DateTime parsedDate = baseDate;

        try {
          // Try parsing "09:00" assuming it's HH:mm
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
        } catch (_) {
          // keep baseDate if fail
        }

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
            minPrice: minPriceLocal,
            maxPrice: maxPriceLocal,
          ),
        );
        index++;

        // Throttle requests to avoid Wikipedia/Wikimedia 429 rate limiting
        await Future.delayed(const Duration(milliseconds: 300));
      }
      return ItineraryGenerationResult(
        activities: newActivities,
        totalAllocatedBudget: responseTotalAllocatedBudget,
        wishlistItemsCoveredCount: responseWishlistItemsCoveredCount,
        estimatedExtraBudgetNeeded: responseEstimatedExtraBudgetNeeded,
      );
    } catch (e) {
      developer.log('Service Error generating itinerary: $e');
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
  }) async {
    return await _itineraryRepository.generateAlternativeActivity(
      destination: destination,
      slotDate: slotDate,
      startTime: startTime,
      endTime: endTime,
      category: category,
      excludedActivity: excludedActivity,
      existingActivityId: existingActivityId,
      dayTripId: dayTripId,
      budgetLimit: budgetLimit,
      dayNumber: dayNumber,
    );
  }

  Activity createEmptyActivity({
    required String activitiesId,
    required String dayTripId,
    required DateTime date,
    required String? startTime,
    required String? endTime,
  }) {
    return Activity(
      activitiesId: activitiesId,
      dayTripId: dayTripId,
      destination: '',
      description: '',
      activityImgUrl: '',
      date: date,
      allocatedBudget: 0.0,
      overspendAmount: null,
      status: 'empty',
      startTime: startTime,
      endTime: endTime,
      duration: '',
      activityCategory: '',
      isOverspend: false,
    );
  }

  // kokhong
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
        activities: activityList,
      );
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // weisong
  Future<({WholeTrip trip, List<Activity> activities})?>
  fetchLatestTrip() async {
    final latestTrip = await _itineraryRepository.getLatestTrip();
    if (latestTrip == null || latestTrip.tripId == null) {
      return null;
    }
    final activities = await _itineraryRepository.fetchAllActivitiesByTrip(
      latestTrip.tripId!,
    );
    return (trip: latestTrip, activities: activities);
  }

  Future<List<Activity>> fetchAllActivitiesByTrip(String tripId) async {
    return await _itineraryRepository.fetchAllActivitiesByTrip(tripId);
  }

  // zhiqin
  Future<bool> endTrip(String id) async {
    try {
      await _itineraryRepository.terminateTrip(id, 'terminated');
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // zhiqin
  Future<List<DayTrip>> getDaysByTripId(String id) async {
    try {
      return await _itineraryRepository.fetchDaysByTripId(id);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTripStatus(String tripId, String newStatus) async {
    final allowedStatus = ['Pending', 'Ongoing', 'Completed'];
    if (!allowedStatus.contains(newStatus)) {
      throw ArgumentError(
        'Invalid trip status. Allowed values are: $allowedStatus',
      );
    }
    await _itineraryRepository.updateTripStatus(tripId, newStatus);
  }
}
