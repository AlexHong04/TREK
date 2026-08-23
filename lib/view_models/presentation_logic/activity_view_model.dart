import 'package:flutter/material.dart';
import 'package:trek/models/repository/itinerary_repository.dart';
import 'package:trek/models/services/itinerary_service.dart';

import '../../models/entities/activity.dart';
import '../ui_state/activity_ui_state.dart';

class ActivityViewModel extends ChangeNotifier {

  final ItineraryService _itineraryService = ItineraryService();

  ActivityUiState _uiState = const ActivityUiState();
  ActivityUiState get uiState => _uiState;

  ActivityViewModel() {
    initialize();
  }

  Future<void> initialize() async {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final result = await _itineraryService.fetchLatestTrip();

      if(result != null) {
        _uiState = _uiState.copyWith(
          isLoading: false,
          activities: result.activities,
          totalBudget: result.trip.totalBudget,
        );
      } else {
        _uiState = _uiState.copyWith(isLoading: false);
      }
    } catch (e) {
      _uiState = _uiState.copyWith(isLoading: false);
      debugPrint('Error in ActivityViewModel.initialize: $e');
    }
    notifyListeners();
  }

  Future<void> loadTripItinerary(String tripId) async {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final activities = await _itineraryService.fetchAllActivitiesByTrip(tripId);

      _uiState = _uiState.copyWith(
        isLoading: false,
        activities: activities,
      );
    } catch (e) {
      _uiState = _uiState.copyWith(isLoading: false);
      debugPrint('DEBUG: Error in loadTripItinerary: $e');
    }
    notifyListeners();
  }

  void initializeHardcoded() {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    // Mock data matching the UI
    final List<Activity> newActivities = [
      Activity(
        activitiesId: '1',
        dayTripId: 'day1',
        destination: 'Kinkaku-ji Temple',
        description:
            'Marvel at the Zen Buddhist temple whose top two floors are completely covered in gold leaf.',
        activityImgUrl: 'assets/images/placeholder.png', // dummy
        date: DateTime(2026, 8, 12, 9, 0),
        allocatedBudget: 25.0,
        overspendAmount: 25.0,
        status: 'planned',
        duration: '60-90 min',
        activityCategory: 'Culture',
        isOverspend: true, // triggers the blue badge in UI
      ),
      Activity(
        activitiesId: '2',
        dayTripId: 'day1',
        destination: 'Traditional Kaiseki Lunch',
        description:
            'Experience a multi-course dinner that balances taste, texture, and appearance in the historic Gion district.',
        activityImgUrl: 'assets/images/placeholder.png', // dummy
        date: DateTime(2026, 8, 12, 12, 0),
        allocatedBudget: 25.0,
        overspendAmount: 0.0,
        status: 'planned',
        duration: '60-90 min',
        activityCategory: 'Food',
        isOverspend: false,
      ),
    ];

    _uiState = _uiState.copyWith(
      isLoading: false,
      activities: newActivities,
      totalBudget: 2450.00,
      spentBudget: 2425.00,
      remainingBudget: 25.00,
      overspentBudget: 0.00,
      sufficientDays: 7,
      usedPercentageString: '1% Used', // Matching the design text
      usedPercentageValue: 0.01,
    );

    notifyListeners();
  }
}
