import 'package:Trek/models/entities/day_trip.dart';

import '../entities/activity.dart';
import '../entities/whole_trip.dart';

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

  Future<List<Activity>> getRemainingActivities(
    String tripId,
    DateTime currentDateTime,
  );

  Future<List<String>> getAutocompleteSuggestions(String query);

  Future<List<Activity>> generateBudgetRecoveryItinerary({
    required String tripId,
    required double newTotalBudget,
    required double currentSpentBudget,
    required double topUpAmount,
    required List<Activity> remainingActivities,
    required String tripDestination,
    DateTime? currentDate,
  });

  Future<void> saveRevisedItineraryActivities(List<Activity> activities);
}
