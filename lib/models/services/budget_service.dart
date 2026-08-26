import 'package:flutter/cupertino.dart';

import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../repository/itinerary_repository.dart';

class BudgetService {
  final ItineraryRepository _itineraryRepository = ItineraryRepository();

  Future<WholeTrip?> topUpBudget({
    required String tripId,
    required String currentActivityId,
    required double topupAmount,
  }) async {
    final currentTrip = await _itineraryRepository.getTrip(tripId);

    final oldRemaining = currentTrip.remainingBalance ?? 0.0;
    final oldTotal = currentTrip.totalBudget;

    final updatedTrip = currentTrip.copyWith(
      remainingBalance: oldRemaining + topupAmount,
      totalBudget: oldTotal + topupAmount,
    );

    await _itineraryRepository.updateTripBudget(updatedTrip);

    final sufficient = await checkBudgetSufficiency(
      trip: updatedTrip,
      currentActivityId: currentActivityId,
      topupAmount: topupAmount,
    );

    if (!sufficient) {
      return null;
    }

    return updatedTrip;
  }

  Future<bool> checkBudgetSufficiency({
    required WholeTrip trip,
    required String currentActivityId,
    required double topupAmount,
  }) async {
    List<Activity> remainingActivities = await _itineraryRepository
        .fetchRemainingActivity(trip.tripId!, currentActivityId);
    double totalRequired = 0.00;
    for (var activity in remainingActivities) {
      totalRequired += activity.allocatedBudget;
    }
    if (topupAmount < totalRequired) {
      return false;
    }
    ;

    return true;
  }

  Future<List<Activity>> reallocateBudget(
    String tripId,
    Activity currentActivity,
    double overspendAmount,
  ) async {
    // Fetch remaining activities occurring after currentActivity
    List<Activity> remainingActivities = await _itineraryRepository
        .fetchRemainingActivity(tripId, currentActivity.activitiesId);
    debugPrint("current activity $currentActivity");
    debugPrint("trip id $tripId");
    debugPrint("remaining activities $remainingActivities");
    debugPrint("remaining overspend $overspendAmount");

    // Filter remaining activities that belong to the 'restaurant' category
    final restaurantActivities = remainingActivities
        .where((activity) => activity.activityCategory == 'Restaurant')
        .toList();

    debugPrint("restaurant activities $restaurantActivities");

    // If no restaurants are remaining to absorb the overspend, trigger recommendation
    if (restaurantActivities.isEmpty) {
      return [];
      throw Exception('Trigger Recommendation'); // trigger recommendation
    }

    // Divide overspend amount equally among remaining restaurants
    final double deductionPerRestaurant =
        overspendAmount / restaurantActivities.length;

    debugPrint("deduction $deductionPerRestaurant");

    // Deduct divided amount
    final List<Activity> updatedRemainingActivities = remainingActivities.map((
      activity,
    ) {
      if (activity.activityCategory == 'restaurant') {
        final double newBudget =
            activity.allocatedBudget - deductionPerRestaurant;

        if (newBudget <= 0.00) { // min price range
          throw Exception('Trigger Recommendation'); // trigger recommendation
        }

        return activity.copyWith(allocatedBudget: newBudget);
      }
      return activity;
    }).toList();

    return updatedRemainingActivities;
  }

  Future<double> calculateSufficientDays(
    WholeTrip trip,
    String currentActivityId,
  ) async {
    List<Activity> remainingActivities = await _itineraryRepository
        .fetchRemainingActivity(trip.tripId!, currentActivityId);
    double remainingCost = 0.00;
    for (var activity in remainingActivities) {
      remainingCost += activity.allocatedBudget;
    }
    return remainingCost / trip.remainingBalance!;
  }
}
