import 'package:flutter/foundation.dart';
import '../../models/entities/activity.dart';
export '../../models/entities/activity.dart';

@immutable
class WholeItineraryUiState {
  final bool isLoading;
  final String? regeneratingSlotId;
  final List<Activity> activities;
  final List<Activity> stashedActivities;
  final String? errorMessage;
  final String destinationTitle;
  final String datesText;
  final String budgetText;
  final double totalAllocatedBudget;
  final int wishlistItemsCoveredCount;
  final double estimatedExtraBudgetNeeded;

  const WholeItineraryUiState({
    this.isLoading = false,
    this.regeneratingSlotId,
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
    String? regeneratingSlotId,
    bool clearRegeneratingSlot = false,
    List<Activity>? activities,
    List<Activity>? stashedActivities,
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
      regeneratingSlotId: clearRegeneratingSlot
          ? null
          : (regeneratingSlotId ?? this.regeneratingSlotId),
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
      activities.fold(0.0, (sum, a) => sum + a.allocatedBudget);

  double get remainingBudget => totalBudget - spentBudget;

  double get overspentBudget => activities
      .where((a) => a.isOverspend == true)
      .fold(0.0, (sum, a) => sum + (a.overspendAmount ?? 0.0));

  String get usedPercentageString {
    if (totalBudget == 0) return '0% Used';
    return '${((spentBudget / totalBudget) * 100).toStringAsFixed(0)}% Used';
  }

  double get usedPercentageValue {
    if (totalBudget == 0) return 0.0;
    return (spentBudget / totalBudget).clamp(0.0, 1.0);
  }

  int get sufficientDays => 7;
}