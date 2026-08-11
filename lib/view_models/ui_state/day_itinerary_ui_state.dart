import '../../models/entities/activity.dart';

class DayItineraryUiState {
  final bool isLoading;
  final List<Activity> activities;
  final String? errorMessage;

  const DayItineraryUiState({
    this.isLoading = false,
    this.activities = const [],
    this.errorMessage,
  });

  DayItineraryUiState copyWith({
    bool? isLoading,
    List<Activity>? activities,
    String? errorMessage,
  }) {
    return DayItineraryUiState(
      isLoading: isLoading ?? this.isLoading,
      activities: activities ?? this.activities,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
