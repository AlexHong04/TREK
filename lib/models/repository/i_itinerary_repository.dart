import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../entities/day_trip.dart';

abstract interface class IItineraryRepository {
  Future<void> insertFullTrip({
    required String destination,
    required String datesText,
    required double totalBudget,
    required double remainingBalance,
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

  Future<bool> updateCriticalDetails(String tripId);

  Future<bool> updateActivities(List<Activity> activities);

  Future<WholeTrip> getTrip(String tripId);

  Future<WholeTrip> getTripByActivityId(String activityId);

  Future<List<DayTrip>> fetchDaysByTripId(String tripId);

  Future<WholeTrip?> getLatestTrip();

  Future<List<Activity>> fetchAllActivitiesByTrip(String tripId);

  Future<void> updateTripStatus(String tripId, String newStatus);

  Future<void> replaceTripActivities({required String tripId, required List<Activity> newActivities});

  Future<List<WholeTrip>> fetchAllTrip();
}
