import 'dart:convert';

import '../entities/activity.dart';
import '../entities/expense_item.dart';
import '../entities/future_suggestion.dart';
import '../entities/whole_trip.dart';
import '../repository/dashboard_repository.dart';
import '../repository/i_dashboard_repository.dart';
import 'i_financial_dashboard_service.dart';

class FinancialDashboardService implements IFinancialDashboardService {
  static const _dashboardCategories = ['Restaurant', 'Transport', 'Attraction'];
  static const _tripSummaryCategories = ['Attraction', 'Food', 'Transport'];
  static const _futureRecommendationCategories = [
    'Attraction',
    'Transport',
    'Food',
  ];

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
          expenseId: expense.expenseId ?? '',
          activityName: activity.destination,
          activityImageUrl: activity.activityImgUrl,
          activityStartTime: activity.startTime,
          amount: expense.totalAmount,
          currency: expense.currency.trim().isEmpty
              ? 'MYR'
              : expense.currency.trim().toUpperCase(),
          paymentMethod: expense.paymentMethod,
          receiptImageUrl: expense.receiptImageUrl,
          recordedAt: expense.createdAt,
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
  Future<List<ExpenseItem>> getExpenseItems(String expenseId) {
    return _repository.getExpenseItems(expenseId);
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
      totalTopUpBudget: dayTrips.fold(
        0,
        (total, dayTrip) => total + (dayTrip.topUpBudget ?? 0),
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
    const maxAttempts = 3;
    FormatException? lastFormatError;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final String rawResponse;
      try {
        rawResponse = await _repository.requestGeminiCostSavingTips(
          destination: destination,
          allocatedBudget: allocatedBudget,
          totalExpense: totalExpense,
          remainingBudget: remainingBudget,
          categoryExpenses: categoryExpenses,
        );
      } on DashboardRecommendationRateLimitException {
        throw const CostSavingTipsRateLimitException();
      }

      try {
        final cleanedResponse = rawResponse
            .trim()
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '');
        final decoded = jsonDecode(cleanedResponse);
        if (decoded is! Map<String, dynamic> || decoded['tips'] is! List) {
          throw const FormatException(
            'Gemini returned an invalid tips response.',
          );
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
        if (tips.length != 3) {
          throw const FormatException(
            'Gemini did not return exactly three usable tips.',
          );
        }
        return tips;
      } on FormatException catch (error) {
        lastFormatError = error;
      }
    }

    throw lastFormatError ??
        const FormatException('Gemini returned no usable tips.');
  }

  @override
  Future<List<FutureBudgetRecommendation>> getFutureBudgetRecommendations({
    required String destination,
    required double allocatedBudget,
    required double totalExpense,
    required Map<String, double> categoryExpenses,
  }) async {
    const maxAttempts = 3;
    FormatException? lastFormatError;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final String rawResponse;
      try {
        rawResponse = await _repository
            .requestGeminiFutureBudgetRecommendations(
              destination: destination,
              allocatedBudget: allocatedBudget,
              totalExpense: totalExpense,
              categoryExpenses: categoryExpenses,
            );
      } on DashboardRecommendationRateLimitException {
        throw const FutureBudgetRecommendationsRateLimitException();
      }

      try {
        final recommendations = _parseFutureBudgetRecommendations(rawResponse);
        if (!hasValidFutureRecommendationTotal({
          for (final recommendation in recommendations)
            recommendation.category: recommendation.percentage,
        })) {
          throw const FormatException(
            'Gemini recommendation percentages must total 100.',
          );
        }
        return recommendations;
      } on FormatException catch (error) {
        lastFormatError = error;
      }
    }

    throw lastFormatError ??
        const FormatException(
          'Gemini returned no usable future budget recommendations.',
        );
  }

  @override
  Future<List<FutureBudgetRecommendation>> getSavedFutureBudgetRecommendations(
    String tripId,
  ) async {
    final suggestions = await _repository.getFutureSuggestions(tripId);
    if (suggestions.isEmpty) return const [];

    final recommendationsByCategory = <String, FutureBudgetRecommendation>{};
    for (final suggestion in suggestions) {
      final category = _validFutureRecommendationCategory(
        suggestion.activityCategory,
      );
      if (category == null) continue;
      recommendationsByCategory[category] = FutureBudgetRecommendation(
        category: category,
        percentage: suggestion.suggestedAmount,
      );
    }

    if (recommendationsByCategory.length !=
        _futureRecommendationCategories.length) {
      return const [];
    }
    final recommendations = _futureRecommendationCategories
        .map((category) => recommendationsByCategory[category]!)
        .toList();
    if (!hasValidFutureRecommendationTotal({
      for (final recommendation in recommendations)
        recommendation.category: recommendation.percentage,
    })) {
      return const [];
    }
    return recommendations;
  }

  @override
  bool hasValidFutureRecommendationTotal(Map<String, double> percentages) {
    if (percentages.length != _futureRecommendationCategories.length ||
        !_futureRecommendationCategories.every(percentages.containsKey)) {
      return false;
    }
    if (percentages.values.any((value) => value < 0 || value > 100)) {
      return false;
    }
    final total = percentages.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    return (total - 100).abs() < 0.001;
  }

  @override
  Future<void> saveFutureBudgetRecommendations({
    required String tripId,
    required Map<String, double> percentages,
  }) async {
    if (!hasValidFutureRecommendationTotal(percentages)) {
      throw ArgumentError('Future budget recommendation total must be 100%.');
    }

    await _repository.saveFutureSuggestions(
      _futureRecommendationCategories
          .map(
            (category) => FutureSuggestion(
              suggestedAmount: percentages[category]!,
              activityCategory: category,
              tripId: tripId,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<List<DateTime>> getAvailableDates() async {
    final dates = await _repository.getAvailableDates();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return dates.where((date) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      return !dateOnly.isAfter(today);
    }).toList();
  }

  @override
  Future<List<WholeTrip>> getCompletedTrips() async {
    final trips = await _repository.getTripsForCurrentUser();
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

  List<FutureBudgetRecommendation> _parseFutureBudgetRecommendations(
    String rawResponse,
  ) {
    final cleanedResponse = rawResponse
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    final decoded = jsonDecode(cleanedResponse);
    if (decoded is! Map<String, dynamic> ||
        decoded['recommendations'] is! List) {
      throw const FormatException(
        'Gemini returned an invalid recommendations response.',
      );
    }

    final recommendationsByCategory = <String, FutureBudgetRecommendation>{};
    for (final value in decoded['recommendations'] as List) {
      if (value is! Map) continue;
      final category = _validFutureRecommendationCategory(
        value['category']?.toString() ?? '',
      );
      final percentage = value['percentage'];
      if (category == null || percentage is! num) continue;
      final percentageValue = percentage.toDouble();
      if (percentageValue < 0 ||
          percentageValue > 100 ||
          percentageValue != percentageValue.roundToDouble()) {
        continue;
      }
      recommendationsByCategory[category] = FutureBudgetRecommendation(
        category: category,
        percentage: percentageValue,
      );
    }

    if (recommendationsByCategory.length !=
        _futureRecommendationCategories.length) {
      throw const FormatException(
        'Gemini did not return all three recommendation categories.',
      );
    }
    return _futureRecommendationCategories
        .map((category) => recommendationsByCategory[category]!)
        .toList();
  }

  String? _validFutureRecommendationCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'attraction':
        return 'Attraction';
      case 'food':
      case 'restaurant':
        return 'Food';
      case 'transport':
      case 'transportation':
        return 'Transport';
      default:
        return null;
    }
  }
}
