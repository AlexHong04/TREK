import 'package:flutter/material.dart';

import '../../models/entities/activity.dart';
import '../../models/services/itinerary_service.dart';
import '../ui_state/whole_itinerary_ui_state.dart';

class WholeItineraryDetailViewModel extends ChangeNotifier {
  WholeItineraryUiState _uiState = const WholeItineraryUiState();

  WholeItineraryUiState get uiState => _uiState;

  final ItineraryService _itineraryService = ItineraryService();

  String destinationTitle = '';
  String datesText = '';
  String budgetText = '';

  Future<void> initialize({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    String? emergencyFund,
  }) async {
    destinationTitle = destination;
    datesText = dates;
    budgetText = budget;

    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    final fetchedActivities = await _itineraryService.generateItinerary(
      destination: destination,
      dates: dates,
      budget: budget,
      preference: preference,
      emergencyFund: emergencyFund,
    );

    _uiState = _uiState.copyWith(
      isLoading: false,
      activities: fetchedActivities,
    );
    notifyListeners();
  }

  void removeActivity(String activitiesId) {
    final updatedActivities = List<Activity>.from(_uiState.activities)
      ..removeWhere((activity) => activity.activitiesId == activitiesId);

    _uiState = _uiState.copyWith(activities: updatedActivities);

    notifyListeners();
  }

  Future<String?> confirmItinerary() async {
    try {
      final success = await _itineraryService.saveItinerary(
        _uiState.activities,
        destination: destinationTitle,
        datesText: datesText,
        budgetText: budgetText,
      );
      if (success) return null; // no error
      return 'Failed to save itinerary to database (Unknown error).';
    } catch (e) {
      return e.toString(); // Return error text
    }
  }
}
