import 'package:flutter/material.dart';

import '../../models/entities/day_itinerary_detail_model.dart';

import '../ui_state/day_itinerary_ui_state.dart';

class DayItineraryDetailViewModel extends ChangeNotifier {
  DayItineraryUiState _uiState = const DayItineraryUiState();
  DayItineraryUiState get uiState => _uiState;

  void initialize() {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    // Simulate some loading or just directly load
    final newActivities = [
      ActivityItemModel(
        id: '1',
        time: '08:00 - 10:00',
        title: 'Kinkaku-ji Temple',
        description:
            'Explore the Golden Pavilion and enjoy the peaceful temple gardens.',
        duration: '2 hrs',
        cost: '\$15',
        imagePath: '',
      ),
      ActivityItemModel(
        id: '2',
        time: '10:30 - 12:30',
        title: 'Traditional Kaiseki Lunch',
        description:
            'Enjoy a multi-course Kyoto lunch with seasonal ingredients.',
        duration: '2 hrs',
        cost: '\$40',
        imagePath: '',
      ),
    ];

    _uiState = _uiState.copyWith(isLoading: false, activities: newActivities);
    notifyListeners();
  }

  void removeActivity(String id) {
    final updatedActivities = List<ActivityItemModel>.from(_uiState.activities)
      ..removeWhere((activity) => activity.id == id);

    _uiState = _uiState.copyWith(activities: updatedActivities);
    notifyListeners();
  }

  Future<void> onConfirmPressed(BuildContext context) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Itinerary confirmed!')));
  }
}
