import 'package:flutter/foundation.dart';

import '../../models/entities/activity.dart';
import '../../models/services/i_itinerary_service.dart';
import '../../models/services/itinerary_service.dart';
import '../ui_state/whole_itinerary_ui_state.dart';

class WholeItineraryDetailViewModel extends ChangeNotifier {
  final IItineraryService _itineraryService;

  WholeItineraryDetailViewModel({IItineraryService? itineraryService})
    : _itineraryService = itineraryService ?? ItineraryService();

  WholeItineraryUiState _uiState = const WholeItineraryUiState();

  WholeItineraryUiState get uiState => _uiState;

  // -- Computed Properties (Presentation Logic) --
  double get totalBudget => double.tryParse(_uiState.budgetText) ?? 0.0;

  double get spentBudget =>
      _uiState.activities.fold(0.0, (sum, a) => sum + a.allocatedBudget);

  double get remainingBudget => totalBudget - spentBudget;

  double get overspentBudget => _uiState.activities
      .where((a) => a.isOverspend == true)
      .fold(0.0, (sum, a) => sum + (a.overspendAmount ?? 0.0));

  String get usedPercentageString {
    if (totalBudget == 0) return '0% Used';
    return '${((spentBudget / totalBudget) * 100).toStringAsFixed(0)}% Used';
  }

  double get usedPercentageValue {
    if (totalBudget == 0) return 0.0;
    return (spentBudget / totalBudget).clamp(0.0, 1.0);
  }

  double get totalRestaurantMinPrice => _uiState.activities
      .where((a) => a.activityCategory.toLowerCase() == 'restaurant')
      .fold(0.0, (sum, a) => sum + (a.minAllocatedBudget ?? a.allocatedBudget));

  double get totalRestaurantMaxPrice => _uiState.activities
      .where((a) => a.activityCategory.toLowerCase() == 'restaurant')
      .fold(0.0, (sum, a) => sum + a.allocatedBudget);

  int get sufficientDays => 7;

  Future<void> initialize({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    List<String>? wishlist,
  }) async {
    _uiState = _uiState.copyWith(
      isLoading: true,
      destinationTitle: destination,
      datesText: dates,
      budgetText: budget,
      preference: preference,
      wishlist: wishlist,
      errorMessage: null,
    );
    notifyListeners();

    try {
      final fetchedResult = await _itineraryService.generateItinerary(
        destination: destination,
        dates: dates,
        budget: budget,
        preference: preference,
        wishlist: wishlist,
      );

      _uiState = _uiState.copyWith(
        isLoading: false,
        activities: fetchedResult.activities,
        totalAllocatedBudget: fetchedResult.totalAllocatedBudget,
        wishlistItemsCoveredCount: fetchedResult.wishlistItemsCoveredCount,
        estimatedExtraBudgetNeeded: fetchedResult.estimatedExtraBudgetNeeded,
        showWishlistWarning: fetchedResult.estimatedExtraBudgetNeeded > 0,
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

  Future<void> generateItinerary() async {
    await initialize(
      destination: _uiState.destinationTitle,
      dates: _uiState.datesText,
      budget: _uiState.budgetText,
      preference: _uiState.preference,
      wishlist: _uiState.wishlist,
    );
  }

  Future<bool> topUpBudget(double amount) async {
    if (amount <= 0) {
      return false;
    }

    final budget = double.tryParse(_uiState.budgetText) ?? 0.0;
    final newBudget = budget + amount;

    final remainingShortage = (_uiState.estimatedExtraBudgetNeeded - amount)
        .clamp(0.0, double.infinity);

    final isSufficient = remainingShortage <= 0.0;

    _uiState = _uiState.copyWith(
      budgetText: newBudget.toStringAsFixed(2),
      estimatedExtraBudgetNeeded: remainingShortage,
      showWishlistWarning: false,
    );

    notifyListeners();

    return isSufficient;
  }

  void dismissWishlistWarning() {
    _uiState = _uiState.copyWith(showWishlistWarning: false);
    notifyListeners();
  }

  // Remove the activity from the trip but retain the card placeholder
  void removeActivity(String activitiesId) {
    Activity? targetActivity;

    final updatedActivities = _uiState.activities.map((activity) {
      if (activity.activitiesId == activitiesId) {
        targetActivity = activity;
        return Activity(
          activitiesId: activitiesId,
          dayTripId: activity.dayTripId,
          date: activity.date,
          destination: '',
          description: '',
          activityImgUrl: '',
          allocatedBudget: 0.0,
          overspendAmount: null,
          status: 'empty',
          startTime: activity.startTime,
          endTime: activity.endTime,
          duration: '',
          activityCategory: '',
          isOverspend: false,
        );
      }
      return activity;
    }).toList();

    List<Activity> updatedStash = List<Activity>.from(
      _uiState.stashedActivities,
    );
    if (targetActivity != null && targetActivity!.destination.isNotEmpty) {
      updatedStash.add(targetActivity!);
    }

    _uiState = _uiState.copyWith(
      activities: updatedActivities,
      stashedActivities: updatedStash,
    );

    notifyListeners();
  }

  // Generate a replacement activity excluding previously visited or generated places
  Future<void> generateAlternativeActivity({
    required String slotActivityId,
    required String destination,
  }) async {
    final slotIndex = _uiState.activities.indexWhere(
      (a) => a.activitiesId == slotActivityId,
    );
    if (slotIndex == -1) return;

    final targetSlot = _uiState.activities[slotIndex];

    // Set slot-specific loading state instead of screen-wide loading
    _uiState = _uiState.copyWith(
      regeneratingSlotId: slotActivityId,
      errorMessage: null,
    );
    notifyListeners();

    try {
      final excludedActivity = <String>[
        ..._uiState.stashedActivities
            .where((a) => a.destination.isNotEmpty)
            .map((a) => a.destination),
        ..._uiState.activities
            .where((a) => a.destination.isNotEmpty)
            .map((a) => a.destination),
      ];

      // Retrieve original budget and category if available in stashed list
      final stashedMatch = _uiState.stashedActivities
          .where((a) => a.activitiesId == slotActivityId)
          .lastOrNull;

      final category = (targetSlot.activityCategory.isNotEmpty)
          ? targetSlot.activityCategory
          : (stashedMatch?.activityCategory ?? 'Attraction');

      final budgetLimit = stashedMatch?.allocatedBudget ?? 50.0;

      final newActivity = await _itineraryService.generateAlternativeItinerary(
        destination: destination,
        slotDate: targetSlot.date,
        startTime: targetSlot.startTime ?? '09:00',
        endTime: targetSlot.endTime ?? '11:00',
        category: category,
        excludedActivity: excludedActivity,
        existingActivityId: slotActivityId,
        dayTripId: targetSlot.dayTripId,
        budgetLimit: budgetLimit,
      );

      final updatedList = List<Activity>.from(_uiState.activities);
      updatedList[slotIndex] = newActivity;

      _uiState = _uiState.copyWith(
        activities: updatedList,
        clearRegeneratingSlot: true,
      );
    } catch (e) {
      _uiState = _uiState.copyWith(
        clearRegeneratingSlot: true,
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
      if (success) return null;
      return 'Failed to save itinerary to database (Unknown error).';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> loadAllTrips() async {
    _uiState = _uiState.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final trips = await _itineraryService.fetchAllTrip();
      _uiState = _uiState.copyWith(isLoading: false, allTrips: trips);
    } catch (e) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  void setStatusFilter(String filter) {
    _uiState = _uiState.copyWith(selectedStatusFilter: filter);
    notifyListeners();
  }
}
