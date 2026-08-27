import '../entities/activity.dart';
import '../entities/whole_trip.dart';

abstract interface class IBudgetService {
  Future<WholeTrip?> topUpBudget({
    required String tripId,
    required String currentActivityId,
    required double topupAmount,
  });

  Future<bool> checkBudgetSufficiency({
    required WholeTrip trip,
    required String currentActivityId,
    required double topupAmount,
  });

  Future<List<Activity>> reallocateBudget(
    String tripId,
    Activity currentActivity,
    double overspendAmount,
  );

  Future<double> calculateSufficientDays(
    WholeTrip trip,
    String currentActivityId,
  );
}
