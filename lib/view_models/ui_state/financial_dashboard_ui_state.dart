class DashboardExpenseDetailUiState {
  final String activityName;
  final String activityImageUrl;
  final String timeText;
  final double amount;
  final String paymentMethod;

  const DashboardExpenseDetailUiState({
    required this.activityName,
    required this.activityImageUrl,
    required this.timeText,
    required this.amount,
    required this.paymentMethod,
  });
}

class DashboardCategoryUiState {
  final String name;
  final double budget;
  final double expense;
  final List<DashboardExpenseDetailUiState> expenseDetails;

  const DashboardCategoryUiState({
    required this.name,
    required this.budget,
    required this.expense,
    this.expenseDetails = const [],
  });

  double get remaining => budget - expense;
  bool get isOverspent => expense > budget;
}

class FinancialDashboardUiState {
  final bool isLoading;
  final bool isLoadingAvailableDates;
  final String? errorMessage;
  final String? availableDatesErrorMessage;
  final bool hasCurrentTrip;
  final DateTime selectedDate;
  final String tripId;
  final String userId;
  final String destination;
  final List<DateTime> availableDates;
  final List<DashboardCategoryUiState> categories;

  const FinancialDashboardUiState({
    this.isLoading = false,
    this.isLoadingAvailableDates = false,
    this.errorMessage,
    this.availableDatesErrorMessage,
    this.hasCurrentTrip = false,
    required this.selectedDate,
    this.tripId = '',
    this.userId = '',
    this.destination = '',
    this.availableDates = const [],
    this.categories = const [],
  });

  double get totalAllocatedBudget =>
      categories.fold(0, (sum, category) => sum + category.budget);

  double get totalExpense =>
      categories.fold(0, (sum, category) => sum + category.expense);

  double get remainingBudget => totalAllocatedBudget - totalExpense;

  FinancialDashboardUiState copyWith({
    bool? isLoading,
    bool? isLoadingAvailableDates,
    String? errorMessage,
    bool clearError = false,
    String? availableDatesErrorMessage,
    bool clearAvailableDatesError = false,
    bool? hasCurrentTrip,
    DateTime? selectedDate,
    String? tripId,
    String? userId,
    String? destination,
    List<DateTime>? availableDates,
    List<DashboardCategoryUiState>? categories,
  }) {
    return FinancialDashboardUiState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingAvailableDates:
          isLoadingAvailableDates ?? this.isLoadingAvailableDates,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      availableDatesErrorMessage: clearAvailableDatesError
          ? null
          : availableDatesErrorMessage ?? this.availableDatesErrorMessage,
      hasCurrentTrip: hasCurrentTrip ?? this.hasCurrentTrip,
      selectedDate: selectedDate ?? this.selectedDate,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      destination: destination ?? this.destination,
      availableDates: availableDates ?? this.availableDates,
      categories: categories ?? this.categories,
    );
  }
}
