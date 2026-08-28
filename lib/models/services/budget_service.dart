import 'package:flutter/cupertino.dart';

import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../repository/i_itinerary_repository.dart';
import '../repository/itinerary_repository.dart';
import 'i_budget_service.dart';

class BudgetService implements IBudgetService {
  final IItineraryRepository _itineraryRepository = ItineraryRepository();

  @override
  Future<WholeTrip> deductRemainingBudget({
    required String tripId,
    required double expenseAmount,
  }) async {
    if (tripId.trim().isEmpty) {
      throw ArgumentError('A trip must be selected before recording an expense.');
    }
    if (expenseAmount <= 0) {
      throw ArgumentError('Expense amount must be greater than zero.');
    }

    final currentTrip = await _itineraryRepository.getTrip(tripId);
    final updatedTrip = currentTrip.copyWith(
      remainingBalance: (currentTrip.remainingBalance ?? 0.0) - expenseAmount,
    );

    await _itineraryRepository.updateTripBudget(updatedTrip);
    return updatedTrip;
  }

  @override
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
    final List<Activity> remainingActivities = await _itineraryRepository
        .fetchRemainingActivity(tripId, currentActivity.activitiesId);

    debugPrint("current activity: $currentActivity");
    debugPrint("trip id: $tripId");
    debugPrint("remaining activities: $remainingActivities");
    debugPrint("remaining overspend: $overspendAmount");

    // Get remaining restaurant activities
    final restaurantActivities = remainingActivities
        .where(
          (activity) => activity.activityCategory.toLowerCase() == 'restaurant',
        )
        .toList();

    debugPrint("restaurant activities: $restaurantActivities");

    // No restaurants available for reallocation
    if (restaurantActivities.isEmpty) {
      return [];
    }

    // Divide overspend equally among remaining restaurants
    final double deductionPerRestaurant =
        overspendAmount / restaurantActivities.length;

    debugPrint("deduction per restaurant: $deductionPerRestaurant");

    // Check all restaurants before making any changes
    for (final activity in restaurantActivities) {
      final double newBudget =
          activity.allocatedBudget - deductionPerRestaurant;

      debugPrint(
        "${activity.activitiesId}: "
        "current=${activity.allocatedBudget}, "
        "min=${activity.minPrice}, "
        "new=$newBudget",
      );

      if (activity.minPrice != null && newBudget < activity.minPrice!) {
        debugPrint(
          "Cannot reallocate: activity "
          "${activity.activitiesId} would fall below minimum price.",
        );

        return [];
      }
    }

    // All restaurants can accept the deduction
    final List<Activity> updatedRemainingActivities = remainingActivities.map((
      activity,
    ) {
      if (activity.activityCategory.toLowerCase() == 'restaurant') {
        final double newBudget =
            activity.allocatedBudget - deductionPerRestaurant;

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
