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
      throw ArgumentError(
        'A trip must be selected before recording an expense.',
      );
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
      double overspentAmount,
      ) async {
    debugPrint('========== START BUDGET REALLOCATION ==========');
    debugPrint('Trip ID: $tripId');
    debugPrint('Current Activity ID: ${currentActivity.activitiesId}');
    debugPrint('Current Activity: ${currentActivity.destination}');
    debugPrint('Overspent Amount: RM ${overspentAmount.toStringAsFixed(2)}');

    final allRemainingActivities =
    await _itineraryRepository.fetchRemainingActivity(
      tripId,
      currentActivity.activitiesId,
    );

    debugPrint(
      'Total remaining activities: ${allRemainingActivities.length}',
    );

    for (final activity in allRemainingActivities) {
      debugPrint(
        'Remaining Activity: '
            '${activity.activitiesId} | '
            '${activity.destination} | '
            'Category: ${activity.activityCategory} | '
            'Date: ${activity.date} | '
            'Start: ${activity.startTime} | '
            'Budget: RM ${activity.allocatedBudget.toStringAsFixed(2)}',
      );
    }

    final DateTime currentDateTime = DateTime.now();

    debugPrint('Current DateTime: $currentDateTime');

    // Find restaurants that have not started yet.
    final remainingRestaurantActivities =
    allRemainingActivities.where((activity) {
      final timeParts = activity.startTime?.split(':');

      if (timeParts == null || timeParts.length < 2) {
        debugPrint(
          '[SKIP] ${activity.activitiesId} - '
              'Invalid start time: ${activity.startTime}',
        );
        return false;
      }

      final int? hour = int.tryParse(timeParts[0]);
      final int? minute = int.tryParse(timeParts[1]);

      if (hour == null || minute == null) {
        debugPrint(
          '[SKIP] ${activity.activitiesId} - '
              'Cannot parse start time: ${activity.startTime}',
        );
        return false;
      }

      // Combine activity date + start time
      final DateTime activityStartDateTime = DateTime(
        activity.date.year,
        activity.date.month,
        activity.date.day,
        hour,
        minute,
      );

      final bool isRestaurant =
          activity.activityCategory.toLowerCase() == 'restaurant';

      final bool hasNotStarted =
      activityStartDateTime.isAfter(currentDateTime);

      debugPrint(
        '[CHECK] ${activity.activitiesId} | '
            '${activity.destination} | '
            'Restaurant: $isRestaurant | '
            'Start: $activityStartDateTime | '
            'Future: $hasNotStarted',
      );

      return isRestaurant && hasNotStarted;
    }).toList();

    // Sort restaurants according to start time.
    remainingRestaurantActivities.sort((a, b) {
      final aParts = a.startTime!.split(':');
      final bParts = b.startTime!.split(':');

      final DateTime aDateTime = DateTime(
        a.date.year,
        a.date.month,
        a.date.day,
        int.parse(aParts[0]),
        int.parse(aParts[1]),
      );

      final DateTime bDateTime = DateTime(
        b.date.year,
        b.date.month,
        b.date.day,
        int.parse(bParts[0]),
        int.parse(bParts[1]),
      );

      return aDateTime.compareTo(bDateTime);
    });

    debugPrint(
      'Remaining restaurants: '
          '${remainingRestaurantActivities.length}',
    );

    if (remainingRestaurantActivities.isEmpty) {
      debugPrint(
        '[REALLOCATION FAILED] No remaining restaurant activities.',
      );
      debugPrint('========== END BUDGET REALLOCATION ==========');
      return [];
    }

    // Divide the overspent amount equally
    // among the remaining restaurants.
    final int numberOfRemainingRestaurants =
        remainingRestaurantActivities.length;

    final double deductionPerRestaurant =
        overspentAmount / numberOfRemainingRestaurants;

    debugPrint(
      'Number of restaurants: $numberOfRemainingRestaurants',
    );

    debugPrint(
      'Total overspent: RM ${overspentAmount.toStringAsFixed(2)}',
    );

    debugPrint(
      'Deduction per restaurant: '
          'RM ${deductionPerRestaurant.toStringAsFixed(2)}',
    );

    final List<Activity> modifiedActivities = [];

    for (final restaurant in remainingRestaurantActivities) {
      final double oldBudget = restaurant.allocatedBudget;

      final double newAllocatedBudget =
          oldBudget - deductionPerRestaurant;

      final double finalAllocatedBudget =
      newAllocatedBudget < 0 ? 0.0 : newAllocatedBudget;

      final updatedRestaurant = restaurant.copyWith(
        allocatedBudget: finalAllocatedBudget,
      );

      modifiedActivities.add(updatedRestaurant);

      debugPrint(
        '[REALLOCATE] ${restaurant.activitiesId} | '
            '${restaurant.destination}',
      );

      debugPrint(
        '    Old Budget: RM ${oldBudget.toStringAsFixed(2)}',
      );

      debugPrint(
        '    Deduction: RM ${deductionPerRestaurant.toStringAsFixed(2)}',
      );

      debugPrint(
        '    New Budget: RM ${finalAllocatedBudget.toStringAsFixed(2)}',
      );
    }

    debugPrint('========== REALLOCATION RESULT ==========');

    for (final activity in modifiedActivities) {
      debugPrint(
        '${activity.activitiesId} | '
            '${activity.destination} | '
            'New Budget: RM ${activity.allocatedBudget.toStringAsFixed(2)}',
      );
    }

    debugPrint('========== END BUDGET REALLOCATION ==========');

    return modifiedActivities;
  }

  Future<int> calculateSufficientDays(
      String tripId,
      String currentActivityId,
      ) async {
    final trip = await _itineraryRepository.getTrip(tripId);

    final List<Activity> remainingActivities =
    await _itineraryRepository.fetchRemainingActivity(
      tripId,
      currentActivityId,
    );

    double remainingCost = 0.0;

    for (final activity in remainingActivities) {
      remainingCost += activity.allocatedBudget;
    }

    final double remainingBalance = trip.remainingBalance ?? 0.0;

    if (remainingBalance <= 0) {
      debugPrint('Remaining balance is RM0 or below.');
      return 0;
    }

    final double sufficientDays =
        remainingCost / remainingBalance;

    debugPrint('Remaining cost: RM $remainingCost');
    debugPrint('Remaining balance: RM $remainingBalance');
    debugPrint('Sufficient days: $sufficientDays');
    debugPrint('Returned days: ${sufficientDays.floor()}');

    return sufficientDays.floor();
  }
}
