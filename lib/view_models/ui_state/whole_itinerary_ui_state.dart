import '../../models/entities/activity.dart';

class WholeItineraryUiState {
  final bool isLoading;
  final List<Activity> activities;
  final List<Activity> stashedActivities;
  final String? errorMessage;

  const WholeItineraryUiState({
    this.isLoading = false,
    this.activities = const [],
    this.stashedActivities = const [],
    this.errorMessage,
  });

  WholeItineraryUiState copyWith({
    bool? isLoading,
    List<Activity>? activities,
    List<Activity>? stashedActivities,
    String? errorMessage,
  }) {
    return WholeItineraryUiState(
      isLoading: isLoading ?? this.isLoading,
      activities: activities ?? this.activities,
      stashedActivities: stashedActivities ?? this.stashedActivities,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  double get totalBudget => 2450.0; // Simulated

  double get spentBudget =>
      activities.fold(0, (sum, a) => sum + a.allocatedBudget);

  double get remainingBudget => totalBudget - spentBudget;

  double get overspentBudget => activities
      .where((a) => a.isOverspend == true)
      .fold(0, (sum, a) => sum + (a.overspendAmount ?? 0));

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
