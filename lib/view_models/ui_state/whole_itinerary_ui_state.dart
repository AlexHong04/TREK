import 'package:flutter/foundation.dart';

@immutable
class WholeItineraryUiState {
  final bool isLoading;
  final List<dynamic> activities;
  final List<dynamic> stashedActivities;
  final String? errorMessage;
  final String destinationTitle;
  final String datesText;
  final String budgetText;
  final double totalAllocatedBudget;
  final int wishlistItemsCoveredCount;
  final double estimatedExtraBudgetNeeded;

  const WholeItineraryUiState({
    this.isLoading = false,
    this.activities = const [],
    this.stashedActivities = const [],
    this.errorMessage,
    this.destinationTitle = '',
    this.datesText = '',
    this.budgetText = '',
    this.totalAllocatedBudget = 0.0,
    this.wishlistItemsCoveredCount = 0,
    this.estimatedExtraBudgetNeeded = 0.0,
  });

  WholeItineraryUiState copyWith({
    bool? isLoading,
    List<dynamic>? activities,
    List<dynamic>? stashedActivities,
    String? errorMessage,
    String? destinationTitle,
    String? datesText,
    String? budgetText,
    double? totalAllocatedBudget,
    int? wishlistItemsCoveredCount,
    double? estimatedExtraBudgetNeeded,
  }) {
    return WholeItineraryUiState(
      isLoading: isLoading ?? this.isLoading,
      activities: activities ?? this.activities,
      stashedActivities: stashedActivities ?? this.stashedActivities,
      errorMessage: errorMessage ?? this.errorMessage,
      destinationTitle: destinationTitle ?? this.destinationTitle,
      datesText: datesText ?? this.datesText,
      budgetText: budgetText ?? this.budgetText,
      totalAllocatedBudget: totalAllocatedBudget ?? this.totalAllocatedBudget,
      wishlistItemsCoveredCount:
          wishlistItemsCoveredCount ?? this.wishlistItemsCoveredCount,
      estimatedExtraBudgetNeeded:
          estimatedExtraBudgetNeeded ?? this.estimatedExtraBudgetNeeded,
    );
  }

  double get totalBudget => double.tryParse(budgetText) ?? 0.0;

  double get spentBudget =>
      activities.fold(0, (sum, a) => sum + (a.allocatedBudget as num));

  double get remainingBudget => totalBudget - spentBudget;

  double get overspentBudget => activities
      .where((a) => a.isOverspend == true)
      .fold(0, (sum, a) => sum + ((a.overspendAmount ?? 0) as num));

  String get usedPercentageString {
    if (totalBudget == 0) return '0% Used';
    return '${((spentBudget / totalBudget) * 100).toStringAsFixed(0)}% Used';
  }

  double get usedPercentageValue {
    if (totalBudget == 0) return 0.0;
    return spentBudget / totalBudget;
  }

  int get sufficientDays => 7;
}
