import 'dart:convert';

import '../entities/activity.dart';
import '../entities/day_trip.dart';
import '../entities/whole_trip.dart';
import '../repository/dashboard_repository.dart';

class FinancialCategorySummary {
  final String category;
  final double allocatedBudget;
  final double expense;
  final List<FinancialExpenseDetail> expenseDetails;

  const FinancialCategorySummary({
    required this.category,
    required this.allocatedBudget,
    required this.expense,
    this.expenseDetails = const [],
  });
}

class FinancialExpenseDetail {
  final String activityName;
  final String activityImageUrl;
  final String? activityStartTime;
  final double amount;
  final String? paymentMethod;

  const FinancialExpenseDetail({
    required this.activityName,
    required this.activityImageUrl,
    required this.activityStartTime,
    required this.amount,
    required this.paymentMethod,
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

class TripCategorySummary {
  final String category;
  final double expense;

  const TripCategorySummary({required this.category, required this.expense});
}

class WholeTripFinancialSummary {
  final WholeTrip trip;
  final double totalExpense;
  final List<TripCategorySummary> categories;

  const WholeTripFinancialSummary({
    required this.trip,
    required this.totalExpense,
    required this.categories,
  });
}

class CostSavingTip {
  final String category;
  final String title;
  final String description;

  const CostSavingTip({
    required this.category,
    required this.title,
    required this.description,
  });
}

class CostSavingTipsRateLimitException implements Exception {
  const CostSavingTipsRateLimitException();
}

abstract class IFinancialDashboardService {
  Future<CurrentDayFinancialSummary?> getCurrentDaySummary(DateTime date);

  Future<WholeTripFinancialSummary?> getTripSummary(String tripId);

  Future<List<CostSavingTip>> getCostSavingTips({
    required String destination,
    required double allocatedBudget,
    required double totalExpense,
    required double remainingBudget,
    required Map<String, double> categoryExpenses,
  });

  Future<List<DateTime>> getAvailableDates(String userId);

  Future<List<WholeTrip>> getCompletedTrips(String userId);
}

class FinancialDashboardService implements IFinancialDashboardService {
  static const _dashboardCategories = ['Restaurant', 'Transport', 'Attraction'];
  static const _tripSummaryCategories = ['Attraction', 'Food', 'Transport'];

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
    final activityById = {
      for (final activity in activities) activity.activitiesId: activity,
    };
    final detailsByCategory = <String, List<FinancialExpenseDetail>>{
      for (final category in _dashboardCategories) category: [],
    };
    for (final expense in expenses) {
      expenseByActivity.update(
        expense.activitiesId,
        (total) => total + expense.totalAmount,
        ifAbsent: () => expense.totalAmount,
      );

      final activity = activityById[expense.activitiesId];
      if (activity == null) continue;
      final category = _normalizedCategory(activity);
      if (category == null) continue;
      detailsByCategory[category]!.add(
        FinancialExpenseDetail(
          activityName: activity.destination,
          activityImageUrl: activity.activityImgUrl,
          activityStartTime: activity.startTime,
          amount: expense.totalAmount,
          paymentMethod: expense.paymentMethod,
        ),
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
            expenseDetails: List.unmodifiable(detailsByCategory[entry.key]!),
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

  @override
  Future<WholeTripFinancialSummary?> getTripSummary(String tripId) async {
    final trip = await _repository.getWholeTrip(tripId);
    if (trip == null) return null;

    final dayTrips = await _repository.getDayTrips(tripId);
    final activities = await _repository.getActivitiesForDayTrips(
      dayTrips
          .map((dayTrip) => dayTrip.dayTripId ?? '')
          .where((id) => id.isNotEmpty)
          .toList(),
    );
    final expenses = await _repository.getExpenses(
      activities.map((activity) => activity.activitiesId).toList(),
    );

    final activityById = {
      for (final activity in activities) activity.activitiesId: activity,
    };
    final totals = {
      for (final category in _tripSummaryCategories) category: 0.0,
    };

    for (final expense in expenses) {
      final activity = activityById[expense.activitiesId];
      if (activity == null) continue;
      final dashboardCategory = _normalizedCategory(activity);
      if (dashboardCategory == null) continue;
      final tripCategory = dashboardCategory == 'Restaurant'
          ? 'Food'
          : dashboardCategory;
      totals[tripCategory] = totals[tripCategory]! + expense.totalAmount;
    }

    return WholeTripFinancialSummary(
      trip: trip,
      totalExpense: expenses.fold(
        0,
        (total, expense) => total + expense.totalAmount,
      ),
      categories: _tripSummaryCategories
          .map(
            (category) => TripCategorySummary(
              category: category,
              expense: totals[category]!,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<List<CostSavingTip>> getCostSavingTips({
    required String destination,
    required double allocatedBudget,
    required double totalExpense,
    required double remainingBudget,
    required Map<String, double> categoryExpenses,
  }) async {
    final categoryText = categoryExpenses.entries
        .map((entry) => '- ${entry.key}: RM ${entry.value.toStringAsFixed(2)}')
        .join('\n');
    final prompt =
        '''
You are a practical travel budget assistant. Generate exactly 3 concise cost-saving tips for this completed trip.

Trip financial data:
- Destination: $destination
- Total allocated budget: RM ${allocatedBudget.toStringAsFixed(2)}
- Total expense: RM ${totalExpense.toStringAsFixed(2)}
- Remaining budget: RM ${remainingBudget.toStringAsFixed(2)}
- Expenses by category:
$categoryText

Rules:
- Base every tip only on the supplied financial data.
- Focus first on the highest-expense categories.
- Do not invent venue names, discount percentages, passes, prices, or facts.
- Keep each title at 6 words or fewer.
- Keep each description at 12 words or fewer.
- category must be exactly Attraction, Food, Transport, or General.

Return only this JSON structure with no markdown:
{"tips":[{"category":"Transport","title":"Short action title","description":"Short practical explanation"}]}
''';

    final String rawResponse;
    try {
      rawResponse = await _repository.requestGeminiRecommendation(prompt);
    } on DashboardRecommendationRateLimitException {
      throw const CostSavingTipsRateLimitException();
    }
    final cleanedResponse = rawResponse
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    final decoded = jsonDecode(cleanedResponse);
    if (decoded is! Map<String, dynamic> || decoded['tips'] is! List) {
      throw const FormatException('Gemini returned an invalid tips response.');
    }

    final tips = <CostSavingTip>[];
    for (final value in decoded['tips'] as List) {
      if (value is! Map) continue;
      final category = value['category']?.toString().trim() ?? '';
      final title = value['title']?.toString().trim() ?? '';
      final description = value['description']?.toString().trim() ?? '';
      if (title.isEmpty || description.isEmpty) continue;
      tips.add(
        CostSavingTip(
          category: _validTipCategory(category),
          title: title,
          description: description,
        ),
      );
      if (tips.length == 3) break;
    }
    if (tips.isEmpty) {
      throw const FormatException('Gemini returned no usable tips.');
    }
    return tips;
  }

  @override
  Future<List<DateTime>> getAvailableDates(String userId) async {
    final dates = await _repository.getAvailableDates(userId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return dates.where((date) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      return !dateOnly.isAfter(today);
    }).toList();
  }

  @override
  Future<List<WholeTrip>> getCompletedTrips(String userId) async {
    final trips = await _repository.getTripsForUser(userId);
    return trips.where((trip) {
      return trip.status.toLowerCase() != 'terminated' &&
          trip.computedStatus == 'completed';
    }).toList();
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

  String _validTipCategory(String category) {
    switch (category.toLowerCase()) {
      case 'attraction':
        return 'Attraction';
      case 'food':
      case 'restaurant':
        return 'Food';
      case 'transport':
      case 'transportation':
        return 'Transport';
      default:
        return 'General';
    }
  }
}
