import 'package:flutter/foundation.dart';

import '../../models/services/i_itinerary_service.dart';
import '../../models/services/itinerary_service.dart';
import '../ui_state/whole_itinerary_ui_state.dart';

class WholeItineraryDetailViewModel extends ChangeNotifier {
  final IItineraryService _itineraryService;

  WholeItineraryDetailViewModel({IItineraryService? itineraryService})
    : _itineraryService = itineraryService ?? ItineraryService();

  WholeItineraryUiState _uiState = const WholeItineraryUiState();

  WholeItineraryUiState get uiState => _uiState;

  Future<void> initialize({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    String? emergencyFund,
    List<String>? wishlist,
  }) async {
    _uiState = _uiState.copyWith(
      isLoading: true,
      destinationTitle: destination,
      datesText: dates,
      budgetText: budget,
    );
    notifyListeners();

    try {
      final fetchedResult = await _itineraryService.generateItinerary(
        destination: destination,
        dates: dates,
        budget: budget,
        preference: preference,
        emergencyFund: emergencyFund,
        wishlist: wishlist,
      );

      _uiState = _uiState.copyWith(
        isLoading: false,
        activities: fetchedResult.activities,
        totalAllocatedBudget: fetchedResult.totalAllocatedBudget,
        wishlistItemsCoveredCount: fetchedResult.wishlistItemsCoveredCount,
        estimatedExtraBudgetNeeded: fetchedResult.estimatedExtraBudgetNeeded,
        errorMessage: null,
      );
    } catch (e) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  // remove the activity from the trip but remain the card with empty slot
  void removeActivity(String activitiesId) {
    dynamic targetActivity;

    final updatedActivities = _uiState.activities.map((activity) {
      if (activity.activitiesId == activitiesId) {
        // get the stash activity
        targetActivity = activity;
        return _itineraryService.createEmptyActivity(
          activitiesId: activitiesId,
          dayTripId: activity.dayTripId ?? '',
          date: activity.date,
          startTime: activity.startTime,
          endTime: activity.endTime,
        );
      }
      return activity;
    }).toList();

    List<dynamic> updatedStash = List.from(_uiState.stashedActivities);
    if (targetActivity != null &&
        targetActivity.destination.toString().isNotEmpty) {
      updatedStash.add(targetActivity);
    }

    _uiState = _uiState.copyWith(
      activities: updatedActivities,
      stashedActivities: updatedStash,
    );

    notifyListeners();
  }

  // generate the new activity the exclude the removed activity but retain trip information related information
  Future<void> generateAlternativeActivity({
    required String slotActivityId,
    required String destination,
  }) async {
    final slotIndex = _uiState.activities.indexWhere(
      (a) => a.activitiesId == slotActivityId,
    );
    if (slotIndex == -1) return;

    final targetSlot = _uiState.activities[slotIndex];
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final excludedActivity = <String>[
        ..._uiState.stashedActivities.map((a) => a.destination.toString()),
        ..._uiState.activities
            .where((a) => a.destination.toString().isNotEmpty)
            .map((a) => a.destination.toString()),
      ];

      final newActivity = await _itineraryService.generateAlternativeItinerary(
        destination: destination,
        slotDate: targetSlot.date,
        startTime: targetSlot.startTime ?? '09:00',
        endTime: targetSlot.endTime ?? '11:00',
        category: targetSlot.activityCategory,
        excludedActivity: excludedActivity,
        existingActivityId: slotActivityId,
        dayTripId: targetSlot.dayTripId,
      );

      final updatedList = List<dynamic>.from(_uiState.activities);
      updatedList[slotIndex] = newActivity;

      _uiState = _uiState.copyWith(activities: updatedList, isLoading: false);
    } catch (e) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  Future<String?> confirmItinerary() async {
    try {
      final success = await _itineraryService.saveItinerary(
        _uiState.activities,
        destination: _uiState.destinationTitle,
        datesText: _uiState.datesText,
        budgetText: _uiState.budgetText,
      );
      if (success) return null; // no error
      return 'Failed to save itinerary to database (Unknown error).';
    } catch (e) {
      return e.toString();
    }
  }
}
