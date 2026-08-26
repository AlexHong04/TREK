class DashboardCategoryUiState {
  final String name;
  final double budget;
  final double expense;

  const DashboardCategoryUiState({
    required this.name,
    required this.budget,
    required this.expense,
  });

  double get remaining => budget - expense;
  bool get isOverspent => expense > budget;
}

class FinancialDashboardUiState {
  final bool isLoading;
  final String? errorMessage;
  final bool hasCurrentTrip;
  final DateTime selectedDate;
  final String destination;
  final List<DashboardCategoryUiState> categories;

  const FinancialDashboardUiState({
    this.isLoading = false,
    this.errorMessage,
    this.hasCurrentTrip = false,
    required this.selectedDate,
    this.destination = '',
    this.categories = const [],
  });

  double get totalAllocatedBudget =>
      categories.fold(0, (sum, category) => sum + category.budget);

  double get totalExpense =>
      categories.fold(0, (sum, category) => sum + category.expense);

  double get remainingBudget => totalAllocatedBudget - totalExpense;

  FinancialDashboardUiState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? hasCurrentTrip,
    DateTime? selectedDate,
    String? destination,
    List<DashboardCategoryUiState>? categories,
  }) {
    return FinancialDashboardUiState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      hasCurrentTrip: hasCurrentTrip ?? this.hasCurrentTrip,
      selectedDate: selectedDate ?? this.selectedDate,
      destination: destination ?? this.destination,
      categories: categories ?? this.categories,
    );
  }
}
