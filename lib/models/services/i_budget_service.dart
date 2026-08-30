import '../entities/activity.dart';
import '../entities/whole_trip.dart';

abstract interface class IBudgetService {
  Future<WholeTrip> deductRemainingBudget({
    required String tripId,
    required double expenseAmount,
  });

  Future<WholeTrip?> topUpBudget({
    required String tripId,
    required String currentActivityId,
    required double topupAmount,
  });

  // Future<bool> checkBudgetSufficiency({
  //   required WholeTrip trip,
  //   required String currentActivityId,
  //   required double topupAmount,
  // });

  Future<List<Activity>> reallocateBudget(
    String tripId,
    Activity currentActivity,
    double overspendAmount,
  );

  Future<int> calculateSufficientDays(
    String tripId,
    String currentActivityId,
  );
}
