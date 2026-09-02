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
    debugPrint('current trip ${currentTrip}');

    final currentActivity = await _itineraryRepository.getCurrentActivity(currentActivityId);
    debugPrint('current activity ${currentActivity}');

    final currentDay = await _itineraryRepository.getCurrentDay(currentActivity.dayTripId);

    final oldRemaining = currentTrip.remainingBalance ?? 0.0;
    final oldTotal = currentTrip.totalBudget;

    final oldTopup = currentDay.topUpBudget ?? 0.00;

    final updatedTrip = currentTrip.copyWith(
      remainingBalance: oldRemaining + topupAmount,
      totalBudget: oldTotal + topupAmount,
    );

    final updatedDay = currentDay.copyWith(
      topUpBudget: oldTopup + topupAmount,
    );

    debugPrint('updatedTrip ${updatedTrip}');
    debugPrint('updatedDay ${updatedDay}');

    await _itineraryRepository.updateTripBudget(updatedTrip);
    await _itineraryRepository.updateDayTopUpBudget(updatedDay);

    return updatedTrip;
  }

  // Future<bool> checkBudgetSufficiency({
  //   required WholeTrip trip,
  //   required String currentActivityId,
  //   required double topupAmount,
  // }) async {
  //   List<Activity> remainingActivities = await _itineraryRepository
  //       .fetchRemainingActivity(trip.tripId!, currentActivityId);
  //   double totalRequired = 0.00;
  //   for (var activity in remainingActivities) {
  //     totalRequired += activity.allocatedBudget;
  //   }
  //   if (topupAmount < totalRequired) {
  //     return false;
  //   }
  //   ;
  //
  //   return true;
  // }

  Future<List<Activity>> getRemainingActivities(
    String tripId,
    DateTime currentDateTime,
  ) async {
    try {
      final activities = await _itineraryRepository.fetchAllActivitiesByTrip(
        tripId,
      );

      activities.sort((a, b) {
        final aDateTime = _getActivityStartDateTime(a);
        final bDateTime = _getActivityStartDateTime(b);

        return aDateTime.compareTo(bDateTime);
      });

      return activities.where((activity) {
        final activityStart = _getActivityStartDateTime(activity);

        return activityStart.isAfter(currentDateTime);
      }).toList();
    } catch (e) {
      print('Calculating Remaining Activities Error: $e');
      rethrow;
    }
  }

  DateTime _getActivityStartDateTime(Activity activity) {
    final date = activity.date;

    final timeParts = activity.startTime?.split(':');

    final hour = int.parse(timeParts![0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(date.year, date.month, date.day, hour, minute);
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

    final allRemainingActivities = await getRemainingActivities(
      tripId,
      DateTime.now(),
    );

    debugPrint('Total remaining activities: ${allRemainingActivities.length}');

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

    // Find restaurant activities here.
    final List<Activity> remainingRestaurantActivities =
    allRemainingActivities.where((activity) {
      final bool isRestaurant =
          activity.activityCategory.toLowerCase() == 'restaurant';

      debugPrint(
        '[CHECK] ${activity.activitiesId} | '
            '${activity.destination} | '
            'Restaurant: $isRestaurant',
      );

      return isRestaurant;
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
        '[REALLOCATION FAILED] '
            'No remaining restaurant activities.',
      );
      debugPrint('========== END BUDGET REALLOCATION ==========');
      return [];
    }

    // Divide the overspent amount equally among the remaining restaurants.
    final int numberOfRemainingRestaurants =
        remainingRestaurantActivities.length;

    final double deductionPerRestaurant =
        overspentAmount / numberOfRemainingRestaurants;

    debugPrint('Number of restaurants: $numberOfRemainingRestaurants');

    debugPrint(
      'Total overspent: RM ${overspentAmount.toStringAsFixed(2)}',
    );

    debugPrint(
      'Deduction per restaurant: '
          'RM ${deductionPerRestaurant.toStringAsFixed(2)}',
    );

    // Check whether all restaurants can absorb the deduction
    for (final restaurant in remainingRestaurantActivities) {
      final double oldBudget = restaurant.allocatedBudget;

      final double newAllocatedBudget =
          oldBudget - deductionPerRestaurant;

      final double minPrice = restaurant.minAllocatedBudget ?? 0.00;

      debugPrint(
        '[MIN PRICE CHECK] ${restaurant.activitiesId} | '
            '${restaurant.destination}',
      );

      debugPrint(
        'Old Budget: RM ${oldBudget.toStringAsFixed(2)}',
      );

      debugPrint(
        'Deduction: RM ${deductionPerRestaurant.toStringAsFixed(2)}',
      );

      debugPrint(
        'New Budget: RM ${newAllocatedBudget.toStringAsFixed(2)}',
      );

      debugPrint(
        'Min Price: RM ${minPrice.toStringAsFixed(2)}',
      );

      // If the new budget is <= minimum price, skip the reallocation
      if (newAllocatedBudget <= minPrice) {
        debugPrint(
          '[REALLOCATION FAILED] ${restaurant.destination} '
              'would fall to or below minimum price.',
        );

        debugPrint(
          'New Budget: RM '
              '${newAllocatedBudget.toStringAsFixed(2)}',
        );

        debugPrint(
          'Min Price: RM '
              '${minPrice.toStringAsFixed(2)}',
        );

        debugPrint('========== END BUDGET REALLOCATION ==========');

        return [];
      }
    }

    // ----------------------------------------------------------
    // PERFORM REALLOCATION
    // ----------------------------------------------------------

    final List<Activity> modifiedActivities = [];

    for (final restaurant in remainingRestaurantActivities) {
      final double oldBudget = restaurant.allocatedBudget;

      final double newAllocatedBudget =
          oldBudget - deductionPerRestaurant;

      final updatedRestaurant = restaurant.copyWith(
        allocatedBudget: newAllocatedBudget,
      );

      modifiedActivities.add(updatedRestaurant);

      debugPrint(
        '[REALLOCATE] ${restaurant.activitiesId} | '
            '${restaurant.destination}',
      );

      debugPrint(
        'Old Budget: RM ${oldBudget.toStringAsFixed(2)}',
      );

      debugPrint(
        'Deduction: RM ${deductionPerRestaurant.toStringAsFixed(2)}',
      );

      debugPrint(
        'New Budget: RM ${newAllocatedBudget.toStringAsFixed(2)}',
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

  // Future<List<Activity>> reallocateBudget(
  //   String tripId,
  //   Activity currentActivity,
  //   double overspentAmount,
  // ) async {
  //   debugPrint('========== START BUDGET REALLOCATION ==========');
  //   debugPrint('Trip ID: $tripId');
  //   debugPrint('Current Activity ID: ${currentActivity.activitiesId}');
  //   debugPrint('Current Activity: ${currentActivity.destination}');
  //   debugPrint('Overspent Amount: RM ${overspentAmount.toStringAsFixed(2)}');
  //
  //   final allRemainingActivities = await getRemainingActivities(
  //     tripId,
  //     DateTime.now(),
  //   );
  //
  //   debugPrint('Total remaining activities: ${allRemainingActivities.length}');
  //
  //   for (final activity in allRemainingActivities) {
  //     debugPrint(
  //       'Remaining Activity: '
  //       '${activity.activitiesId} | '
  //       '${activity.destination} | '
  //       'Category: ${activity.activityCategory} | '
  //       'Date: ${activity.date} | '
  //       'Start: ${activity.startTime} | '
  //       'Budget: RM ${activity.allocatedBudget.toStringAsFixed(2)}',
  //     );
  //   }
  //
  //   final DateTime currentDateTime = DateTime.now();
  //
  //   debugPrint('Current DateTime: $currentDateTime');
  //
  //   // Find restaurants that have not started yet.
  //   final remainingRestaurantActivities = allRemainingActivities.where((
  //     activity,
  //   ) {
  //     final timeParts = activity.startTime?.split(':');
  //
  //     if (timeParts == null || timeParts.length < 2) {
  //       debugPrint(
  //         '[SKIP] ${activity.activitiesId} - '
  //         'Invalid start time: ${activity.startTime}',
  //       );
  //       return false;
  //     }
  //
  //     final int? hour = int.tryParse(timeParts[0]);
  //     final int? minute = int.tryParse(timeParts[1]);
  //
  //     if (hour == null || minute == null) {
  //       debugPrint(
  //         '[SKIP] ${activity.activitiesId} - '
  //         'Cannot parse start time: ${activity.startTime}',
  //       );
  //       return false;
  //     }
  //
  //     // Combine activity date + start time
  //     final DateTime activityStartDateTime = DateTime(
  //       activity.date.year,
  //       activity.date.month,
  //       activity.date.day,
  //       hour,
  //       minute,
  //     );
  //
  //     final bool isRestaurant =
  //         activity.activityCategory.toLowerCase() == 'restaurant';
  //
  //     final bool hasNotStarted = activityStartDateTime.isAfter(currentDateTime);
  //     // remove those comparing date
  //
  //     debugPrint(
  //       '[CHECK] ${activity.activitiesId} | '
  //       '${activity.destination} | '
  //       'Restaurant: $isRestaurant | '
  //       'Start: $activityStartDateTime | '
  //       'Future: $hasNotStarted',
  //     );
  //
  //     return isRestaurant && hasNotStarted;
  //   }).toList();
  //
  //   // Sort restaurants according to start time.
  //   remainingRestaurantActivities.sort((a, b) {
  //     final aParts = a.startTime!.split(':');
  //     final bParts = b.startTime!.split(':');
  //
  //     final DateTime aDateTime = DateTime(
  //       a.date.year,
  //       a.date.month,
  //       a.date.day,
  //       int.parse(aParts[0]),
  //       int.parse(aParts[1]),
  //     );
  //
  //     final DateTime bDateTime = DateTime(
  //       b.date.year,
  //       b.date.month,
  //       b.date.day,
  //       int.parse(bParts[0]),
  //       int.parse(bParts[1]),
  //     );
  //
  //     return aDateTime.compareTo(bDateTime);
  //   });
  //
  //   debugPrint(
  //     'Remaining restaurants: '
  //     '${remainingRestaurantActivities.length}',
  //   );
  //
  //   if (remainingRestaurantActivities.isEmpty) {
  //     debugPrint('[REALLOCATION FAILED] No remaining restaurant activities.');
  //     debugPrint('========== END BUDGET REALLOCATION ==========');
  //     return [];
  //   }
  //
  //   // Divide the overspent amount equally
  //   // among the remaining restaurants.
  //   final int numberOfRemainingRestaurants =
  //       remainingRestaurantActivities.length;
  //
  //   final double deductionPerRestaurant =
  //       overspentAmount / numberOfRemainingRestaurants;
  //
  //   debugPrint('Number of restaurants: $numberOfRemainingRestaurants');
  //
  //   debugPrint('Total overspent: RM ${overspentAmount.toStringAsFixed(2)}');
  //
  //   debugPrint(
  //     'Deduction per restaurant: '
  //     'RM ${deductionPerRestaurant.toStringAsFixed(2)}',
  //   );
  //
  //   final List<Activity> modifiedActivities = [];
  //
  //   for (final restaurant in remainingRestaurantActivities) {
  //     final double oldBudget = restaurant.allocatedBudget;
  //
  //     final double newAllocatedBudget = oldBudget - deductionPerRestaurant;
  //
  //     final double finalAllocatedBudget = newAllocatedBudget < 0
  //         ? 0.0
  //         : newAllocatedBudget;
  //
  //     final updatedRestaurant = restaurant.copyWith(
  //       allocatedBudget: finalAllocatedBudget,
  //     );
  //
  //     // add if newAllocatedBudget < 0 or newAllocatedBudget < min price, skip the reallocation
  //
  //     modifiedActivities.add(updatedRestaurant);
  //
  //     debugPrint(
  //       '[REALLOCATE] ${restaurant.activitiesId} | '
  //       '${restaurant.destination}',
  //     );
  //
  //     debugPrint('    Old Budget: RM ${oldBudget.toStringAsFixed(2)}');
  //
  //     debugPrint(
  //       '    Deduction: RM ${deductionPerRestaurant.toStringAsFixed(2)}',
  //     );
  //
  //     debugPrint(
  //       '    New Budget: RM ${finalAllocatedBudget.toStringAsFixed(2)}',
  //     );
  //   }
  //
  //   debugPrint('========== REALLOCATION RESULT ==========');
  //
  //   for (final activity in modifiedActivities) {
  //     debugPrint(
  //       '${activity.activitiesId} | '
  //       '${activity.destination} | '
  //       'New Budget: RM ${activity.allocatedBudget.toStringAsFixed(2)}',
  //     );
  //   }
  //
  //   debugPrint('========== END BUDGET REALLOCATION ==========');
  //
  //   return modifiedActivities;
  // }

  Future<int> calculateSufficientDays(
    String tripId,
    String currentActivityId,
  ) async {
    final trip = await _itineraryRepository.getTrip(tripId);
    debugPrint("trip ${trip.tripId}, ${trip.remainingBalance}, ${trip.totalBudget}");

    final List<Activity> remainingActivities = await getRemainingActivities(
      tripId,
      DateTime.now(),
    );

    double remainingCost = 0.0;

    for (final activity in remainingActivities) {
      debugPrint('activity id ${activity.activitiesId}');
      debugPrint("activity allocated budget ${activity.allocatedBudget}");
      remainingCost += activity.allocatedBudget;
    }

    final double remainingBalance = trip.remainingBalance ?? 0.0;

    if (remainingBalance <= 0) {
      debugPrint('Remaining balance is RM0 or below.');
      return 0;
    }

    final double sufficientDays = remainingBalance / remainingCost;

    debugPrint('Remaining cost: RM $remainingCost');
    debugPrint('Remaining balance: RM $remainingBalance');
    debugPrint('Sufficient days: $sufficientDays');
    debugPrint('Returned days: ${sufficientDays.floor()}');

    return sufficientDays.floor();
  }
}
