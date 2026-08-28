import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../entities/day_trip.dart';

abstract interface class IItineraryRepository {
  Future<void> insertFullTrip({
    required String destination,
    required String datesText,
    required double totalBudget,
    required List<Activity> activities,
  });

  Future<void> updateTripBudget(WholeTrip trip);

  Future<void> terminateTrip(String id, String status);

  Future<List<Activity>> fetchRemainingActivity(
    String tripId,
    String currentActivityId,
  );

  Future<Activity> getCurrentActivity(String id);

  Future<DayTrip> getCurrentDay(String dayId);

  Future<bool> updateOverspendDetails(DayTrip day, Activity activity);

  Future<bool> updateActivities(List<Activity> activities);

  Future<WholeTrip> getTrip(String tripId);

  Future<WholeTrip> getTripByActivityId(String activityId);

  Future<List<DayTrip>> fetchDaysByTripId(String tripId);

  Future<WholeTrip?> getLatestTrip();

  Future<List<Activity>> fetchAllActivitiesByTrip(String tripId);

  Future<void> updateTripStatus(String tripId, String newStatus);

  Future<Activity> generateAlternativeActivity({
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
}
