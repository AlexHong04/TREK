import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../repository/activity_repository.dart';
import '../repository/itinerary_repository.dart';

class BudgetService {
  final ItineraryRepository _itineraryRepository = ItineraryRepository();
  final ActivityRepository _activityRepository = ActivityRepository();

  Future<WholeTrip> topUpBudget({
    required WholeTrip trip,
    required String currentActivityId,
    required double topupAmount,
  }) async {
    if (topupAmount <= 0) {
      throw ArgumentError('Top-up amount must be greater than zero.');
    }

    final updatedTrip = trip.copyWith(
      remainingBalance: (trip.remainingBalance ?? 0.0) + topupAmount,
      totalBudget: trip.totalBudget + topupAmount,
    );

    await _itineraryRepository.updateTripBudget(updatedTrip);

    bool sufficient = await checkBudgetSufficiency(trip: trip, currentActivityId: currentActivityId, topupAmount: topupAmount);

    if (sufficient == false) {
      throw Exception('Trigger Recommendation'); // trigger recommendation
    }
    return updatedTrip;
  }

  Future<bool> checkBudgetSufficiency({
    required WholeTrip trip,
    required String currentActivityId,
    required double topupAmount,
  }) async {
    List<Activity> remainingActivities = await _activityRepository.fetchRemainingActivity(trip.tripId!, currentActivityId);
    double totalRequired = 0.00;
    for (var activity in remainingActivities) {
      totalRequired += activity.allocatedBudget;
    }
    if (topupAmount < totalRequired) {
      return false;
    };

    return true;
  }

  Future<List<Activity>> reallocateBudget(
      String tripId,
      Activity currentActivity,
      double overspendAmount,
      ) async {
    // Fetch remaining activities occurring after currentActivity
    List<Activity> remainingActivities =
    await _activityRepository.fetchRemainingActivity(
      tripId,
      currentActivity.activitiesId,
    );

    // Filter remaining activities that belong to the 'restaurant' category
    final restaurantActivities = remainingActivities
        .where((activity) => activity.activityCategory == 'restaurant')
        .toList();

    // If no restaurants are remaining to absorb the overspend, trigger recommendation
    if (restaurantActivities.isEmpty) {
      throw Exception('Trigger Recommendation'); // trigger recommendation
    }

    // Divide overspend amount equally among remaining restaurants
    final double deductionPerRestaurant = overspendAmount / restaurantActivities.length;

    // Deduct divided amount
    final List<Activity> updatedRemainingActivities = remainingActivities.map((activity) {
      if (activity.activityCategory == 'restaurant') {
        final double newBudget = activity.allocatedBudget - deductionPerRestaurant;

        if (newBudget <= 0.00) {
          throw Exception('Trigger Recommendation'); // trigger recommendation
        }

        return activity.copyWith(
          allocatedBudget: newBudget,
        );
      }
      return activity;
    }).toList();

    return updatedRemainingActivities;
  }
}
