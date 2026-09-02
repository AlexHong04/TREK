class TripSummaryCategoryUiState {
  final String name;
  final double expense;
  final String expenseText;
  final double percentage;

  const TripSummaryCategoryUiState({
    required this.name,
    required this.expense,
    required this.expenseText,
    required this.percentage,
  });
}

class CostSavingTipUiState {
  final String category;
  final String title;
  final String description;

  const CostSavingTipUiState({
    required this.category,
    required this.title,
    required this.description,
  });
}

enum FutureRecommendationAcceptResult { saved, invalidTotal, failed }

class FutureBudgetRecommendationUiState {
  final String category;
  final double aiPercentage;
  final double selectedPercentage;
  final double minimumPercentage;
  final double maximumPercentage;

  const FutureBudgetRecommendationUiState({
    required this.category,
    required this.aiPercentage,
    required this.selectedPercentage,
    required this.minimumPercentage,
    required this.maximumPercentage,
  });

  FutureBudgetRecommendationUiState copyWith({double? selectedPercentage}) {
    return FutureBudgetRecommendationUiState(
      category: category,
      aiPercentage: aiPercentage,
      selectedPercentage: selectedPercentage ?? this.selectedPercentage,
      minimumPercentage: minimumPercentage,
      maximumPercentage: maximumPercentage,
    );
  }
}

class TripSummaryUiState {
  final bool isLoading;
  final bool isLoadingCostSavingTips;
  final String? errorMessage;
  final String? costSavingTipsErrorMessage;
  final bool hasTrip;
  final String tripId;
  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final double allocatedBudget;
  final String allocatedBudgetText;
  final double topUpBudget;
  final String topUpBudgetText;
  final double totalExpense;
  final String totalExpenseText;
  final double remainingBudget;
  final String remainingBudgetText;
  final double spentPercentage;
  final String financialHealth;
  final List<TripSummaryCategoryUiState> categories;
  final List<CostSavingTipUiState> costSavingTips;
  final bool isFutureRecommendationsExpanded;
  final bool isLoadingFutureRecommendations;
  final bool isSavingFutureRecommendations;
  final bool hasAdjustedFutureRecommendations;
  final bool areFutureRecommendationsSaved;
  final String? futureRecommendationsErrorMessage;
  final List<FutureBudgetRecommendationUiState> futureRecommendations;

  const TripSummaryUiState({
    this.isLoading = false,
    this.isLoadingCostSavingTips = false,
    this.errorMessage,
    this.costSavingTipsErrorMessage,
    this.hasTrip = false,
    this.tripId = '',
    this.destination = '',
    this.startDate,
    this.endDate,
    this.allocatedBudget = 0,
    this.allocatedBudgetText = 'RM 0.00',
    this.topUpBudget = 0,
    this.topUpBudgetText = 'RM 0.00',
    this.totalExpense = 0,
    this.totalExpenseText = 'RM 0.00',
    this.remainingBudget = 0,
    this.remainingBudgetText = 'RM 0.00',
    this.spentPercentage = 0,
    this.financialHealth = 'Healthy',
    this.categories = const [],
    this.costSavingTips = const [],
    this.isFutureRecommendationsExpanded = false,
    this.isLoadingFutureRecommendations = false,
    this.isSavingFutureRecommendations = false,
    this.hasAdjustedFutureRecommendations = false,
    this.areFutureRecommendationsSaved = false,
    this.futureRecommendationsErrorMessage,
    this.futureRecommendations = const [],
  });

  TripSummaryUiState copyWith({
    bool? isLoading,
    bool? isLoadingCostSavingTips,
    String? errorMessage,
    bool clearError = false,
    String? costSavingTipsErrorMessage,
    bool clearCostSavingTipsError = false,
    bool? hasTrip,
    String? tripId,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    double? allocatedBudget,
    String? allocatedBudgetText,
    double? topUpBudget,
    String? topUpBudgetText,
    double? totalExpense,
    String? totalExpenseText,
    double? remainingBudget,
    String? remainingBudgetText,
    double? spentPercentage,
    String? financialHealth,
    List<TripSummaryCategoryUiState>? categories,
    List<CostSavingTipUiState>? costSavingTips,
    bool? isFutureRecommendationsExpanded,
    bool? isLoadingFutureRecommendations,
    bool? isSavingFutureRecommendations,
    bool? hasAdjustedFutureRecommendations,
    bool? areFutureRecommendationsSaved,
    String? futureRecommendationsErrorMessage,
    bool clearFutureRecommendationsError = false,
    List<FutureBudgetRecommendationUiState>? futureRecommendations,
  }) {
    return TripSummaryUiState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingCostSavingTips:
          isLoadingCostSavingTips ?? this.isLoadingCostSavingTips,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      costSavingTipsErrorMessage: clearCostSavingTipsError
          ? null
          : costSavingTipsErrorMessage ?? this.costSavingTipsErrorMessage,
      hasTrip: hasTrip ?? this.hasTrip,
      tripId: tripId ?? this.tripId,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      allocatedBudget: allocatedBudget ?? this.allocatedBudget,
      allocatedBudgetText: allocatedBudgetText ?? this.allocatedBudgetText,
      topUpBudget: topUpBudget ?? this.topUpBudget,
      topUpBudgetText: topUpBudgetText ?? this.topUpBudgetText,
      totalExpense: totalExpense ?? this.totalExpense,
      totalExpenseText: totalExpenseText ?? this.totalExpenseText,
      remainingBudget: remainingBudget ?? this.remainingBudget,
      remainingBudgetText: remainingBudgetText ?? this.remainingBudgetText,
      spentPercentage: spentPercentage ?? this.spentPercentage,
      financialHealth: financialHealth ?? this.financialHealth,
      categories: categories ?? this.categories,
      costSavingTips: costSavingTips ?? this.costSavingTips,
      isFutureRecommendationsExpanded:
          isFutureRecommendationsExpanded ??
          this.isFutureRecommendationsExpanded,
      isLoadingFutureRecommendations:
          isLoadingFutureRecommendations ?? this.isLoadingFutureRecommendations,
      isSavingFutureRecommendations:
          isSavingFutureRecommendations ?? this.isSavingFutureRecommendations,
      hasAdjustedFutureRecommendations:
          hasAdjustedFutureRecommendations ??
          this.hasAdjustedFutureRecommendations,
      areFutureRecommendationsSaved:
          areFutureRecommendationsSaved ?? this.areFutureRecommendationsSaved,
      futureRecommendationsErrorMessage: clearFutureRecommendationsError
          ? null
          : futureRecommendationsErrorMessage ??
                this.futureRecommendationsErrorMessage,
      futureRecommendations:
          futureRecommendations ?? this.futureRecommendations,
    );
  }
}
