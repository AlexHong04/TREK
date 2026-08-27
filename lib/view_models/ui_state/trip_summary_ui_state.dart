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
  final double totalExpense;
  final String totalExpenseText;
  final double remainingBudget;
  final String remainingBudgetText;
  final double spentPercentage;
  final String financialHealth;
  final List<TripSummaryCategoryUiState> categories;
  final List<CostSavingTipUiState> costSavingTips;

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
    this.totalExpense = 0,
    this.totalExpenseText = 'RM 0.00',
    this.remainingBudget = 0,
    this.remainingBudgetText = 'RM 0.00',
    this.spentPercentage = 0,
    this.financialHealth = 'Healthy',
    this.categories = const [],
    this.costSavingTips = const [],
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
    double? totalExpense,
    String? totalExpenseText,
    double? remainingBudget,
    String? remainingBudgetText,
    double? spentPercentage,
    String? financialHealth,
    List<TripSummaryCategoryUiState>? categories,
    List<CostSavingTipUiState>? costSavingTips,
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
      totalExpense: totalExpense ?? this.totalExpense,
      totalExpenseText: totalExpenseText ?? this.totalExpenseText,
      remainingBudget: remainingBudget ?? this.remainingBudget,
      remainingBudgetText: remainingBudgetText ?? this.remainingBudgetText,
      spentPercentage: spentPercentage ?? this.spentPercentage,
      financialHealth: financialHealth ?? this.financialHealth,
      categories: categories ?? this.categories,
      costSavingTips: costSavingTips ?? this.costSavingTips,
    );
  }
}
