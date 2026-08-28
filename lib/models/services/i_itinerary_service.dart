import 'package:Trek/models/entities/day_trip.dart';

import '../entities/activity.dart';
import '../entities/whole_trip.dart';

class ItineraryGenerationResult {
  final List<Activity> activities;
  final double totalAllocatedBudget;
  final int wishlistItemsCoveredCount;
  final double estimatedExtraBudgetNeeded;

  ItineraryGenerationResult({
    required this.activities,
    required this.totalAllocatedBudget,
    required this.wishlistItemsCoveredCount,
    required this.estimatedExtraBudgetNeeded,
  });
}

abstract interface class IItineraryService {
  Future<ItineraryGenerationResult> generateItinerary({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    String? emergencyFund,
    List<String>? wishlist,
  });

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
  });

  Activity createEmptyActivity({
    required String activitiesId,
    required String dayTripId,
    required DateTime date,
    required String? startTime,
    required String? endTime,
  });

  Future<bool> saveItinerary(
    List<dynamic> activities, {
    required String destination,
    required String datesText,
    required String budgetText,
  });

  Future<({WholeTrip trip, List<Activity> activities})?> fetchLatestTrip();

  Future<List<Activity>> fetchAllActivitiesByTrip(String tripId);

  Future<bool> endTrip(String id);

  Future<void> updateTripStatus(String tripId, String newStatus);

  Future<List<DayTrip>> getDaysByTripId(String tripId);
}
