import '../../models/entities/day_itinerary_detail_model.dart';

class DayItineraryUiState {
  final bool isLoading;
  final List<ActivityItemModel> activities;
  final String? errorMessage;

  const DayItineraryUiState({
    this.isLoading = false,
    this.activities = const [],
    this.errorMessage,
  });

  DayItineraryUiState copyWith({
    bool? isLoading,
    List<ActivityItemModel>? activities,
    String? errorMessage,
  }) {
    return DayItineraryUiState(
      isLoading: isLoading ?? this.isLoading,
      activities: activities ?? this.activities,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
