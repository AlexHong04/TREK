enum DashboardFilter { byDate, byTrip }

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

class DashboardTripUiState {
  final String tripId;
  final String destination;
  final String imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final double totalBudget;
  final String travelPreference;

  const DashboardTripUiState({
    required this.tripId,
    required this.destination,
    required this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.totalBudget,
    required this.travelPreference,
  });
}

class FinancialDashboardUiState {
  static const defaultCategories = <DashboardCategoryUiState>[
    DashboardCategoryUiState(name: 'Restaurant', budget: 0, expense: 0),
    DashboardCategoryUiState(name: 'Transport', budget: 0, expense: 0),
    DashboardCategoryUiState(name: 'Attraction', budget: 0, expense: 0),
  ];

  final bool isLoading;
  final bool isLoadingAvailableDates;
  final bool isLoadingCompletedTrips;
  final String? errorMessage;
  final String? availableDatesErrorMessage;
  final String? completedTripsErrorMessage;
  final bool hasCurrentTrip;
  final DateTime selectedDate;
  final DateTime displayedCalendarMonth;
  final String tripId;
  final String userId;
  final String destination;
  final double topUpBudget;
  final String profileName;
  final String? profilePictureUrl;
  final List<DateTime> availableDates;
  final List<DashboardTripUiState> completedTrips;
  final List<DashboardCategoryUiState> categories;

  const FinancialDashboardUiState({
    this.isLoading = false,
    this.isLoadingAvailableDates = false,
    this.isLoadingCompletedTrips = false,
    this.errorMessage,
    this.availableDatesErrorMessage,
    this.completedTripsErrorMessage,
    this.hasCurrentTrip = false,
    required this.selectedDate,
    required this.displayedCalendarMonth,
    this.tripId = '',
    this.userId = '',
    this.destination = '',
    this.topUpBudget = 0,
    this.profileName = '',
    this.profilePictureUrl,
    this.availableDates = const [],
    this.completedTrips = const [],
    this.categories = defaultCategories,
  });

  double get totalAllocatedBudget =>
      categories.fold(0, (sum, category) => sum + category.budget);

  double get totalExpense =>
      categories.fold(0, (sum, category) => sum + category.expense);

  double get remainingBudget =>
      totalAllocatedBudget + topUpBudget - totalExpense;

  FinancialDashboardUiState copyWith({
    bool? isLoading,
    bool? isLoadingAvailableDates,
    bool? isLoadingCompletedTrips,
    String? errorMessage,
    bool clearError = false,
    String? availableDatesErrorMessage,
    bool clearAvailableDatesError = false,
    String? completedTripsErrorMessage,
    bool clearCompletedTripsError = false,
    bool? hasCurrentTrip,
    DateTime? selectedDate,
    DateTime? displayedCalendarMonth,
    String? tripId,
    String? userId,
    String? destination,
    double? topUpBudget,
    String? profileName,
    String? profilePictureUrl,
    bool clearProfilePictureUrl = false,
    List<DateTime>? availableDates,
    List<DashboardTripUiState>? completedTrips,
    List<DashboardCategoryUiState>? categories,
  }) {
    return FinancialDashboardUiState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingAvailableDates:
          isLoadingAvailableDates ?? this.isLoadingAvailableDates,
      isLoadingCompletedTrips:
          isLoadingCompletedTrips ?? this.isLoadingCompletedTrips,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      availableDatesErrorMessage: clearAvailableDatesError
          ? null
          : availableDatesErrorMessage ?? this.availableDatesErrorMessage,
      completedTripsErrorMessage: clearCompletedTripsError
          ? null
          : completedTripsErrorMessage ?? this.completedTripsErrorMessage,
      hasCurrentTrip: hasCurrentTrip ?? this.hasCurrentTrip,
      selectedDate: selectedDate ?? this.selectedDate,
      displayedCalendarMonth:
          displayedCalendarMonth ?? this.displayedCalendarMonth,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      destination: destination ?? this.destination,
      topUpBudget: topUpBudget ?? this.topUpBudget,
      profileName: profileName ?? this.profileName,
      profilePictureUrl: clearProfilePictureUrl
          ? null
          : (profilePictureUrl ?? this.profilePictureUrl),
      availableDates: availableDates ?? this.availableDates,
      completedTrips: completedTrips ?? this.completedTrips,
      categories: categories ?? this.categories,
    );
  }
}
