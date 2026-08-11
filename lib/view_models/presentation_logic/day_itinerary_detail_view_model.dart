import 'package:flutter/material.dart';

import '../../models/entities/activity.dart';
import '../ui_state/day_itinerary_ui_state.dart';

class DayItineraryDetailViewModel extends ChangeNotifier {
  DayItineraryUiState _uiState = const DayItineraryUiState();

  DayItineraryUiState get uiState => _uiState;

  void initialize() {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    final newActivities = [
      Activity(
        activitiesId: '1',
        dayTripId: 'day-trip-1',
        destination: 'Kinkaku-ji Temple',
        description: '',
        activityImgUrl: '',
        date: DateTime(2026, 8, 12),
        allocatedBudget: 20.0,
        overspendAmount: 15.0,
        status: 'planned',
        startTime: '08:00',
        endTime: '10:00',
        activityCategory: 'Culture',
        isOverspend: false,

      ),
      Activity(
        activitiesId: '2',
        dayTripId: 'day-trip-1',
        destination: 'Traditional Kaiseki Lunch',
          description: '',
          activityImgUrl: '',
        date: DateTime(2026, 8, 12),
        allocatedBudget: 50.0,
        overspendAmount: 40.0,
        status: 'planned',
        startTime: '10:30',
        endTime: '12:30',
        activityCategory: 'Food',
        isOverspend: false
      ),
    ];

    _uiState = _uiState.copyWith(
      isLoading: false,
      activities: newActivities,
    );

    notifyListeners();
  }

  void removeActivity(String activitiesId) {
    final updatedActivities = List<Activity>.from(_uiState.activities)
      ..removeWhere(
            (activity) => activity.activitiesId == activitiesId,
      );

    _uiState = _uiState.copyWith(
      activities: updatedActivities,
    );

    notifyListeners();
  }

  Future<void> onConfirmPressed(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Itinerary confirmed!'),
      ),
    );
  }
}