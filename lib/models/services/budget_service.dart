import 'package:flutter/cupertino.dart';

import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../repository/i_itinerary_repository.dart';
import '../repository/itinerary_repository.dart';
import 'i_profile_service.dart';
import 'i_itinerary_service.dart';

class BudgetService implements IBudgetService {
  final IItineraryRepository _itineraryRepository;
  final IProfileService _profileService;

  BudgetService({required IProfileService profileService})
    : _itineraryRepository = ItineraryRepository(),
      _profileService = profileService;

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

    final currentActivity = await _itineraryRepository.getCurrentActivity(
      currentActivityId,
    );

    final currentDay = await _itineraryRepository.getCurrentDay(
      currentActivity.dayTripId,
    );

    final oldRemaining = currentTrip.remainingBalance ?? 0.0;
    final oldTotal = currentTrip.totalBudget;
    final oldTopup = currentDay.topUpBudget ?? 0.00;

    double newRemaining = oldRemaining + topupAmount;
    double newTotal = oldTotal + topupAmount;
    double newTopUp = oldTopup + topupAmount;

    final updatedTrip = currentTrip.copyWith(
      remainingBalance: newRemaining,
      totalBudget: newTotal,
    );

    final updatedDay = currentDay.copyWith(topUpBudget: newTopUp);

    await _itineraryRepository.updateTripBudget(updatedTrip);
    await _itineraryRepository.updateDayTopUpBudget(updatedDay);

    return updatedTrip;
  }

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

    final allRemainingActivities = await getRemainingActivities(
      tripId,
      DateTime.now(),
    );

    // Find restaurant activities
    final List<Activity> remainingRestaurantActivities = allRemainingActivities
        .where((activity) {
          final bool isRestaurant =
              activity.activityCategory.toLowerCase() == 'restaurant';
          final bool isCurrentActivity =
              activity.activitiesId == currentActivity.activitiesId;

          return isRestaurant && !isCurrentActivity;
        })
        .toList();

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

    if (remainingRestaurantActivities.isEmpty) {
      return [];
    }

    // Divide the overspent amount equally among the remaining restaurants.
    final int numberOfRemainingRestaurants =
        remainingRestaurantActivities.length;

    final double deductionPerRestaurant =
        overspentAmount / numberOfRemainingRestaurants;

    // Check whether all restaurants can absorb the deduction
    for (final restaurant in remainingRestaurantActivities) {
      final double oldBudget = restaurant.allocatedBudget;

      final double newAllocatedBudget = oldBudget - deductionPerRestaurant;

      final double minPrice = restaurant.minAllocatedBudget ?? 0.00;

      // If the new budget is <= minimum price, skip the reallocation
      if (newAllocatedBudget <= minPrice) {
        return [];
      }
    }

    // Perform Reallocation
    final List<Activity> modifiedActivities = [];

    for (final restaurant in remainingRestaurantActivities) {
      final double oldBudget = restaurant.allocatedBudget;

      final double newAllocatedBudget = oldBudget - deductionPerRestaurant;

      final updatedRestaurant = restaurant.copyWith(
        allocatedBudget: newAllocatedBudget,
      );

      modifiedActivities.add(updatedRestaurant);
    }

    return modifiedActivities;
  }

  Future<int> calculateSufficientDays(
    String tripId,
    String currentActivityId,
  ) async {
    final trip = await _itineraryRepository.getTrip(tripId);

    final List<Activity> remainingActivities = await getRemainingActivities(
      tripId,
      DateTime.now(),
    );

    double remainingCost = 0.0;

    for (final activity in remainingActivities) {
      remainingCost += activity.allocatedBudget;
    }

    final double remainingBalance = trip.remainingBalance ?? 0.0;

    if (remainingBalance <= 0) {
      return 0;
    }

    if (remainingCost <= 0) {
      return 0;
    }

    final double sufficientDays = remainingBalance / remainingCost;

    final today = DateTime.now();

    final todayDate = DateTime(today.year, today.month, today.day);
    final endDate = DateTime(
      trip.endDate.year,
      trip.endDate.month,
      trip.endDate.day,
    );

    // including today
    final daysUntilEnd = endDate.difference(todayDate).inDays + 1;

    if (sufficientDays > daysUntilEnd) {
      return daysUntilEnd;
    }

    return sufficientDays.floor();
  }

  // weisong
  // Reconciles EVERY activity/day against real spending and persists the
  // results, clearing stale per-day/per-activity overspend amounts left behind
  // by earlier submissions.
  //
  // Overspend is defined PER ACTIVITY as: how much an activity's recorded
  // spending exceeds ITS OWN allocation (max(0, spent - allocated)), counted
  // even when the allocated budget is 0. A day's / the trip's overspend is the
  // sum of those activity-level amounts. Returns the whole-trip total.
  @override
  Future<double> reconcileTripOverspend({required String tripId}) async {
    if (tripId.trim().isEmpty) return 0.0;

    final allActivities = await _itineraryRepository.fetchAllActivitiesByTrip(
      tripId,
    );
    final days = await _itineraryRepository.fetchDaysByTripId(tripId);

    // Total spent per activity for the whole trip in a single query.
    final spentSummary = await _itineraryRepository
        .fetchSpentSummaryByActivityIds(
          allActivities.map((a) => a.activitiesId).toList(),
        );
    final spentByActivity = Map<String, double>.from(
      (spentSummary['activitySpentMap'] as Map?) ?? const {},
    );

    final overspendByDay = <String, double>{};
    final activitiesToUpdate = <Activity>[];
    double totalTripOverspent = 0.0;

    for (final act in allActivities) {
      final double spent = spentByActivity[act.activitiesId] ?? 0.0;
      final double allocated = act.allocatedBudget;
      final double gross = spent > allocated ? spent - allocated : 0.0;
      final bool isOver = spent > allocated;

      if (gross > 0) {
        overspendByDay[act.dayTripId] =
            (overspendByDay[act.dayTripId] ?? 0.0) + gross;
        totalTripOverspent += gross;
      }

      // Only persist when the stored values are out of sync with reality.
      final double storedAmount = act.overspendAmount ?? 0.0;
      final bool storedFlag = act.isOverspend ?? false;
      if (storedFlag != isOver || (storedAmount - gross).abs() > 0.001) {
        activitiesToUpdate.add(
          act.copyWith(isOverspend: isOver, overspendAmount: gross),
        );
      }
    }

    if (activitiesToUpdate.isNotEmpty) {
      await _itineraryRepository.updateActivities(activitiesToUpdate);
    }

    for (final day in days) {
      final dayId = day.dayTripId;
      if (dayId == null) continue;

      final double dayOverspend = overspendByDay[dayId] ?? 0.0;
      final updatedDay = day.copyWith(
        overspendAmount: dayOverspend,
        isOverspend: dayOverspend > 0,
      );
      await _itineraryRepository.updateDayOverspend(updatedDay);
    }

    return totalTripOverspent;
  }

  // Recomputes the trip balance from the source of truth (the recorded
  // expenses) and repairs `remaining_balance` when it has drifted.
  //
  // `remaining_balance` was previously only ever adjusted incrementally -
  // `deductRemainingBudget` subtracts on each expense and `topUpBudget` adds -
  // so an expense that is later edited, removed, or regenerated leaves it
  // permanently wrong. Nothing recomputed it from the expense records, while the
  // overspend columns self-heal through reconcileTripOverspend(). This is the
  // missing symmetric half, and every remaining-budget decision in the app
  // (sufficient days, the critical check, the reallocation ceiling) reads it.
  @override
  Future<({double totalBudget, double totalSpent, double remainingBalance})>
  reconcileTripBalance({required String tripId}) async {
    if (tripId.trim().isEmpty) {
      return (totalBudget: 0.0, totalSpent: 0.0, remainingBalance: 0.0);
    }

    final trip = await _itineraryRepository.getTrip(tripId);
    final activities = await _itineraryRepository.fetchAllActivitiesByTrip(
      tripId,
    );

    final double storedBalance = trip.remainingBalance ?? 0.0;

    // Defensive: with no activities there is nothing to verify the balance
    // against, and summing an empty set would wrongly restore the full budget
    // even when orphaned expenses still exist. Leave the stored value alone.
    if (activities.isEmpty) {
      debugPrint(
        '[reconcileTripBalance] No activities for trip $tripId - '
        'leaving the stored balance untouched.',
      );
      return (
        totalBudget: trip.totalBudget,
        totalSpent: (trip.totalBudget - storedBalance).clamp(
          0.0,
          double.infinity,
        ),
        remainingBalance: storedBalance,
      );
    }

    // Total spent for the whole trip in a single query.
    final spentSummary = await _itineraryRepository
        .fetchSpentSummaryByActivityIds(
          activities.map((a) => a.activitiesId).toList(),
        );
    final double totalSpent =
        (spentSummary['totalSpent'] as num?)?.toDouble() ?? 0.0;

    final double authoritativeBalance = trip.totalBudget - totalSpent;
    final double drift = storedBalance - authoritativeBalance;

    debugPrint('========== TRIP BALANCE RECONCILIATION ==========');
    debugPrint('Trip: $tripId');
    debugPrint(
      'Total budget:          RM ${trip.totalBudget.toStringAsFixed(2)}',
    );
    debugPrint('Total spent:           RM ${totalSpent.toStringAsFixed(2)}');
    debugPrint('Stored balance:        RM ${storedBalance.toStringAsFixed(2)}');
    debugPrint(
      'Authoritative balance: RM ${authoritativeBalance.toStringAsFixed(2)}',
    );
    debugPrint('Drift: RM ${drift.toStringAsFixed(2)}');
    debugPrint('==================================================');

    // Only write when the stored value is actually out of sync.
    if (drift.abs() > 0.001) {
      await _itineraryRepository.updateTripBudget(
        trip.copyWith(remainingBalance: authoritativeBalance),
      );
      debugPrint(
        '[reconcileTripBalance] Repaired RM ${drift.toStringAsFixed(2)} '
        'of drift.',
      );
    }

    return (
      totalBudget: trip.totalBudget,
      totalSpent: totalSpent,
      remainingBalance: authoritativeBalance,
    );
  }
}
