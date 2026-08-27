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

  Future<bool> updateDayOverspendDetails(DayTrip current);

  Future<bool> updateOverspendDetails(Activity current);

  Future<bool> updateActivities(List<Activity> activities);

  Future<WholeTrip> getTrip(String tripId);

  Future<WholeTrip> getTripByActivityId(String activityId);

  Future<WholeTrip?> getLatestTrip();

  Future<List<Activity>> fetchAllActivitiesByTrip(String tripId);

  Future<void> updateTripStatus(String tripId, String newStatus);
}
