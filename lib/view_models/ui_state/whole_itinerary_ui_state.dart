import '../../models/entities/activity.dart';
export '../../models/entities/activity.dart';

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
  final bool showWishlistWarning;

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
    this.showWishlistWarning = false,
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
    bool? showWishlistWarning,
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
      showWishlistWarning: showWishlistWarning ?? this.showWishlistWarning,
    );
  }
}
