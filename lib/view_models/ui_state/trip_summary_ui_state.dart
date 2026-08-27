class TripSummaryCategoryUiState {
  final String name;
  final double expense;
  final double percentage;

  const TripSummaryCategoryUiState({
    required this.name,
    required this.expense,
    required this.percentage,
  });
}

class TripSummaryUiState {
  final bool isLoading;
  final String? errorMessage;
  final bool hasTrip;
  final String tripId;
  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final double allocatedBudget;
  final double totalExpense;
  final double remainingBudget;
  final double spentPercentage;
  final String financialHealth;
  final List<TripSummaryCategoryUiState> categories;

  const TripSummaryUiState({
    this.isLoading = false,
    this.errorMessage,
    this.hasTrip = false,
    this.tripId = '',
    this.destination = '',
    this.startDate,
    this.endDate,
    this.allocatedBudget = 0,
    this.totalExpense = 0,
    this.remainingBudget = 0,
    this.spentPercentage = 0,
    this.financialHealth = 'Healthy',
    this.categories = const [],
  });

  TripSummaryUiState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? hasTrip,
    String? tripId,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    double? allocatedBudget,
    double? totalExpense,
    double? remainingBudget,
    double? spentPercentage,
    String? financialHealth,
    List<TripSummaryCategoryUiState>? categories,
  }) {
    return TripSummaryUiState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      hasTrip: hasTrip ?? this.hasTrip,
      tripId: tripId ?? this.tripId,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      allocatedBudget: allocatedBudget ?? this.allocatedBudget,
      totalExpense: totalExpense ?? this.totalExpense,
      remainingBudget: remainingBudget ?? this.remainingBudget,
      spentPercentage: spentPercentage ?? this.spentPercentage,
      financialHealth: financialHealth ?? this.financialHealth,
      categories: categories ?? this.categories,
    );
  }
}
