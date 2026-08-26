import '../entities/activity.dart';
import '../entities/day_trip.dart';
import '../entities/whole_trip.dart';
import '../repository/dashboard_repository.dart';

class FinancialCategorySummary {
  final String category;
  final double allocatedBudget;
  final double expense;

  const FinancialCategorySummary({
    required this.category,
    required this.allocatedBudget,
    required this.expense,
  });
}

class CurrentDayFinancialSummary {
  final WholeTrip trip;
  final DayTrip dayTrip;
  final List<FinancialCategorySummary> categories;

  const CurrentDayFinancialSummary({
    required this.trip,
    required this.dayTrip,
    required this.categories,
  });
}

abstract class IFinancialDashboardService {
  Future<CurrentDayFinancialSummary?> getCurrentDaySummary(DateTime date);
}

class FinancialDashboardService implements IFinancialDashboardService {
  static const _dashboardCategories = ['Restaurant', 'Transport', 'Attraction'];

  final IDashboardRepository _repository;

  FinancialDashboardService({IDashboardRepository? repository})
    : _repository = repository ?? DashboardRepository();

  @override
  Future<CurrentDayFinancialSummary?> getCurrentDaySummary(
    DateTime date,
  ) async {
    final trip = await _repository.getCurrentTrip(date);
    if (trip?.tripId == null) return null;

    final dayTrip = await _repository.getDayTrip(trip!.tripId!, date);
    if (dayTrip?.dayTripId == null) return null;

    final activities = await _repository.getActivities(dayTrip!.dayTripId!);
    final expenses = await _repository.getExpenses(
      activities.map((activity) => activity.activitiesId).toList(),
    );

    final expenseByActivity = <String, double>{};
    for (final expense in expenses) {
      expenseByActivity.update(
        expense.activitiesId,
        (total) => total + expense.totalAmount,
        ifAbsent: () => expense.totalAmount,
      );
    }

    final categoryTotals = <String, ({double budget, double expense})>{
      for (final category in _dashboardCategories)
        category: (budget: 0, expense: 0),
    };
    for (final activity in activities) {
      final category = _normalizedCategory(activity);
      if (category == null) continue;
      final current = categoryTotals[category];
      categoryTotals[category] = (
        budget: (current?.budget ?? 0) + activity.allocatedBudget,
        expense:
            (current?.expense ?? 0) +
            (expenseByActivity[activity.activitiesId] ?? 0),
      );
    }

    final categories = categoryTotals.entries
        .map(
          (entry) => FinancialCategorySummary(
            category: entry.key,
            allocatedBudget: entry.value.budget,
            expense: entry.value.expense,
          ),
        )
        .toList();
    categories.sort((a, b) => b.expense.compareTo(a.expense));

    return CurrentDayFinancialSummary(
      trip: trip,
      dayTrip: dayTrip,
      categories: categories,
    );
  }

  String? _normalizedCategory(Activity activity) {
    switch (activity.activityCategory.trim().toLowerCase()) {
      case 'restaurant':
      case 'food':
      case 'dining':
        return 'Restaurant';
      case 'transport':
      case 'transportation':
        return 'Transport';
      case 'attraction':
      case 'entertainment':
      case 'sightseeing':
        return 'Attraction';
      default:
        return null;
    }
  }
}
