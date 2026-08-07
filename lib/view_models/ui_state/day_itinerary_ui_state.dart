import '../../models/entities/day_itinerary_detail_model.dart';
import 'ui_status.dart';

class DayItineraryUiState {
  final UiStatus status;
  final List<ActivityItemModel> activities;
  final String? errorMessage;

  const DayItineraryUiState({
    this.status = UiStatus.initial,
    this.activities = const [],
    this.errorMessage,
  });

  DayItineraryUiState copyWith({
    UiStatus? status,
    List<ActivityItemModel>? activities,
    String? errorMessage,
  }) {
    return DayItineraryUiState(
      status: status ?? this.status,
      activities: activities ?? this.activities,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
