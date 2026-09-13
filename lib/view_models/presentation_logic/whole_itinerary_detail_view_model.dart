import 'package:flutter/foundation.dart';

import '../../models/services/i_auth_service.dart';
import '../../models/services/i_profile_service.dart'; // added this
import '../../models/services/i_itinerary_service.dart';
import '../../models/services/itinerary_service.dart';
import '../../models/entities/future_suggestion.dart';
import '../../models/repository/dashboard_repository.dart';
import '../../models/configurations/supabase_config.dart';
import '../ui_state/whole_itinerary_ui_state.dart';
import 'package:intl/intl.dart';

class WholeItineraryDetailViewModel extends ChangeNotifier {
  final IItineraryService _itineraryService;
  final IAuthService _authService;
  final IProfileService _profileService; // added this

  WholeItineraryDetailViewModel({
    IItineraryService? itineraryService,
    required IAuthService authService,
    required IProfileService profileService, // added this
  }) : _itineraryService = itineraryService ?? ItineraryService(),
       _authService = authService,
       _profileService = profileService; // added this

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

  int get plannedStopsCount => _uiState.activities
      .where((a) => a.status != 'empty' && a.destination.isNotEmpty)
      .length;

  /// True while any time slot is still empty (deleted, or not yet filled),
  /// which blocks confirming the plan.
  bool get hasEmptyActivitySlots => _uiState.activities.any(
    (a) =>
        a.status == 'empty' ||
        (a.destination.trim().isEmpty && a.description.trim().isEmpty),
  );

  /// True if extra budget is needed or spent budget exceeds total budget.
  /// Tolerance of 0.01 is applied to prevent IEEE-754 floating point inaccuracies.
  bool get hasExtraBudgetNeeded {
    if (_uiState.estimatedExtraBudgetNeeded > 0.01) return true;
    if (totalBudget > 0) {
      return (spentBudget - totalBudget) > 0.01;
    }
    return spentBudget > 0.01;
  }

  /// True if wishlist has uncovered items.
  bool get hasUncoveredWishlist {
    final wishlist = _uiState.wishlist;
    if (wishlist == null || wishlist.isEmpty) return false;
    return _uiState.wishlistItemsCoveredCount < wishlist.length;
  }

  /// True if budget is insufficient or wishlist is not fully covered.
  bool get needsTopUp => hasExtraBudgetNeeded || hasUncoveredWishlist;

  /// Confirm is only allowed once every time slot has been filled, we are
  /// not busy generating, and no extra budget is needed.
  bool get canConfirmItinerary =>
      !_uiState.isLoading &&
      _uiState.activities.isNotEmpty &&
      !hasEmptyActivitySlots &&
      !hasExtraBudgetNeeded;

  static bool _matchesWishlist(
    String wishlistName,
    String destinationName, [
    String description = '',
  ]) {
    final wLower = wishlistName.toLowerCase().trim();
    final dLower = destinationName.toLowerCase().trim();
    final descLower = description.toLowerCase().trim();

    if (dLower.contains(wLower) || wLower.contains(dLower)) return true;
    if (descLower.contains(wLower)) return true;

    final cleanW = wLower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanD = dLower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanDesc = descLower.replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (cleanW.isNotEmpty) {
      if (cleanD.contains(cleanW) || cleanW.contains(cleanD)) return true;
      if (cleanDesc.contains(cleanW)) return true;
    }

    final tokens = wLower
        .split(RegExp(r'[\s,]+'))
        .where((t) => t.length >= 3)
        .toList();
    if (tokens.length >= 2) {
      final matchedTokens = tokens
          .where((t) => dLower.contains(t) || cleanD.contains(t))
          .length;
      if (matchedTokens >= 2) return true;
    }

    return false;
  }

  /// Wishlist items that are matched by any active activity in the itinerary.
  List<String> get coveredWishlistItems {
    final wishlist = _uiState.wishlist;
    if (wishlist == null || wishlist.isEmpty) return [];

    final activeActivities = _uiState.activities
        .where((a) => a.status != 'empty' && a.destination.trim().isNotEmpty)
        .toList();

    return wishlist.where((item) {
      return activeActivities.any(
        (a) => _matchesWishlist(item, a.destination, a.description),
      );
    }).toList();
  }

  /// Wishlist items that are NOT covered in the itinerary activities.
  List<String> get uncoveredWishlistItems {
    final wishlist = _uiState.wishlist;
    if (wishlist == null || wishlist.isEmpty) return [];

    // If marked as fully covered (e.g. after budget top-up or 100% matched)
    if (_uiState.wishlistItemsCoveredCount >= wishlist.length) {
      return [];
    }

    final covered = coveredWishlistItems.toSet();
    if (covered.length >= wishlist.length) {
      return [];
    }

    final unmatched = wishlist
        .where((item) => !covered.contains(item))
        .toList();

    return List.unmodifiable(unmatched);
  }

  int get uncoveredWishlistCount => uncoveredWishlistItems.length;

  Future<void> initialize({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    List<String>? wishlist,
    List<String>? constraints,
    List<FutureSuggestion>? futureSuggestions,
    bool suppressWarning = false,
    List<TransitPoint>? arrivals,
    List<TransitPoint>? departures,
    List<HotelStay>? hotels,
    String? arrivalLocation,
    String? arrivalTime,
    String? departureLocation,
    String? departureTime,
    String? hotelLocation,
    String? hotelCheckInTime,
    String? hotelCheckOutTime,
  }) async {
    _uiState = _uiState.copyWith(
      isLoading: true,
      destinationTitle: destination,
      datesText: dates,
      budgetText: budget,
      preference: preference,
      wishlist: wishlist,
      constraints: constraints,
      arrivals: arrivals ?? _uiState.arrivals,
      departures: departures ?? _uiState.departures,
      hotels: hotels ?? _uiState.hotels,
      arrivalLocation: arrivalLocation,
      arrivalTime: arrivalTime,
      departureLocation: departureLocation,
      departureTime: departureTime,
      hotelLocation: hotelLocation ?? _uiState.hotelLocation,
      hotelCheckInTime: hotelCheckInTime ?? _uiState.hotelCheckInTime,
      hotelCheckOutTime: hotelCheckOutTime ?? _uiState.hotelCheckOutTime,
      errorMessage: null,
    );
    notifyListeners();

    try {
      List<FutureSuggestion> resolvedSuggestions = futureSuggestions ?? [];
      if (futureSuggestions == null) {
        final userId = SupabaseConfig.client.auth.currentUser?.id;
        if (userId != null) {
          final dashboardRepository = DashboardRepository();
          final trips = await dashboardRepository.getTripsForCurrentUser();
          final completedTrips = trips
              .where((t) => t.status.toLowerCase() == 'completed')
              .toList();
          if (completedTrips.isNotEmpty &&
              completedTrips.first.tripId != null) {
            resolvedSuggestions = await dashboardRepository
                .getFutureSuggestions(completedTrips.first.tripId!);
          }
        }
      }

      final fetchedResult = await _itineraryService.generateItinerary(
        destination: destination,
        dates: dates,
        budget: budget,
        preference: preference,
        wishlist: wishlist,
        constraints: constraints,
        futureSuggestions: resolvedSuggestions,
        strictBudget: suppressWarning,
        arrivals: _uiState.arrivals,
        departures: _uiState.departures,
        hotels: _uiState.hotels,
        arrivalLocation: arrivalLocation ?? _uiState.arrivalLocation,
        arrivalTime: arrivalTime ?? _uiState.arrivalTime,
        departureLocation: departureLocation ?? _uiState.departureLocation,
        departureTime: departureTime ?? _uiState.departureTime,
        hotelLocation: hotelLocation ?? _uiState.hotelLocation,
        hotelCheckInTime: hotelCheckInTime ?? _uiState.hotelCheckInTime,
        hotelCheckOutTime: hotelCheckOutTime ?? _uiState.hotelCheckOutTime,
      );

      final bool hasShortfall = fetchedResult.estimatedExtraBudgetNeeded > 0.0;
      final bool shouldWarn = !suppressWarning && hasShortfall;

      _uiState = _uiState.copyWith(
        isLoading: false,
        activities: fetchedResult.activities,
        totalAllocatedBudget: fetchedResult.totalAllocatedBudget,
        wishlistItemsCoveredCount: fetchedResult.wishlistItemsCoveredCount,
        estimatedExtraBudgetNeeded: fetchedResult.estimatedExtraBudgetNeeded,
        showWishlistWarning: shouldWarn,
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

  Future<void> generateItinerary({bool suppressWarning = false}) async {
    await initialize(
      destination: _uiState.destinationTitle,
      dates: _uiState.datesText,
      budget: _uiState.budgetText,
      preference: _uiState.preference,
      wishlist: _uiState.wishlist,
      constraints: _uiState.constraints,
      futureSuggestions: _uiState.futureSuggestions,
      suppressWarning: suppressWarning,
      arrivals: _uiState.arrivals,
      departures: _uiState.departures,
      hotels: _uiState.hotels,
      arrivalLocation: _uiState.arrivalLocation,
      arrivalTime: _uiState.arrivalTime,
      departureLocation: _uiState.departureLocation,
      departureTime: _uiState.departureTime,
      hotelLocation: _uiState.hotelLocation,
      hotelCheckInTime: _uiState.hotelCheckInTime,
      hotelCheckOutTime: _uiState.hotelCheckOutTime,
    );
  }

  // zhiqin
  String get preferredCurrency =>
      _profileService.preferredCurrency; // changed this

  // zhiqin
  Future<double?> convertAmountToCurrency({required double amount}) async {
    try {
      final result = await _profileService.convertToPreferredCurrency(
        amount: amount,
        fromCurrency: 'MYR'
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  // zhiqin
  Future<double?> convertAmountToMYR({required double amount}) async {
    try {
      final result = await _profileService.convertPreferredCurrencyToMyr(
          amount: amount,
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  String? validateTopUpAmount({
    String? symbol,
    required String value,
    required double minTopUp,
    required double shortageAmount,
  }) {
    if (value.trim().isEmpty) {
      return null;
    }

    final amount = double.tryParse(value.trim());

    if (amount == null) {
      return 'Please enter a valid amount.';
    }

    if (amount < minTopUp) {
      return 'Top-up amount must be at least ${symbol ?? 'MYR'} ${minTopUp.toStringAsFixed(2)}.';
    }

    if (amount > shortageAmount) {
      return 'Top-up amount cannot exceed ${symbol ?? 'MYR'} ${shortageAmount.toStringAsFixed(2)}.';
    }

    return null;
  }

  // zhiqin
  Future<bool> topUpBudget(double amount) async {
    if (amount <= 0) {
      return false;
    }

    final budget = double.tryParse(_uiState.budgetText) ?? 0.0;
    final myrAmount = await _profileService.convertPreferredCurrencyToMyr(
      amount: amount,
    ); // changed this

    final shortfall = spentBudget - budget;
    final shortage = _uiState.estimatedExtraBudgetNeeded > shortfall
        ? _uiState.estimatedExtraBudgetNeeded
        : shortfall;

    final minRequired = double.parse((shortage * 0.50).toStringAsFixed(2));
    final myrMinRequired = await _profileService.convertPreferredCurrencyToMyr(amount: minRequired) ?? minRequired;
    final myrShortfall = await _profileService.convertPreferredCurrencyToMyr(amount: shortfall) ?? shortfall;

    final isSufficient = myrAmount! >= myrMinRequired || myrAmount <= myrShortfall;

    final double updatedBudget = isSufficient
        ? (budget + myrAmount < spentBudget ? spentBudget : budget + myrAmount)
        : (budget + myrAmount);

    final remainingShortage = isSufficient
        ? 0.0
        : shortage - myrAmount;

    _uiState = _uiState.copyWith(
      budgetText: updatedBudget.toStringAsFixed(2),
      estimatedExtraBudgetNeeded: remainingShortage,
      showWishlistWarning: false,
      wishlistItemsCoveredCount: isSufficient
          ? (_uiState.wishlist?.length ?? 0)
          : _uiState.wishlistItemsCoveredCount,
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

  // Remove multiple activities from the trip, retaining card placeholders
  void removeMultipleActivities(Set<String> activityIds) {
    if (activityIds.isEmpty) return;

    final updatedStash = List<Activity>.from(_uiState.stashedActivities);

    final updatedActivities = _uiState.activities.map((activity) {
      if (activityIds.contains(activity.activitiesId)) {
        if (activity.destination.isNotEmpty) {
          updatedStash.add(activity);
        }
        return Activity(
          activitiesId: activity.activitiesId,
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

    _uiState = _uiState.copyWith(
      activities: updatedActivities,
      stashedActivities: updatedStash,
    );

    notifyListeners();
  }

  // Remove an item from the wishlist and recalculate coverage and shortfall
  void deleteWishlistItem(String item) {
    final currentWishlist = _uiState.wishlist;
    if (currentWishlist == null || !currentWishlist.contains(item)) return;

    final updatedWishlist = List<String>.from(currentWishlist)..remove(item);

    int coveredCount = 0;
    final activeActivities = _uiState.activities
        .where((a) => a.status != 'empty' && a.destination.trim().isNotEmpty)
        .toList();
    for (final w in updatedWishlist) {
      if (activeActivities.any(
        (a) => _matchesWishlist(w, a.destination, a.description),
      )) {
        coveredCount++;
      }
    }

    final double parsedBudget = double.tryParse(_uiState.budgetText) ?? 0.0;
    final double mathShortfall = (_uiState.totalAllocatedBudget - parsedBudget)
        .clamp(0.0, double.infinity);

    final double newExtraBudget = mathShortfall;

    _uiState = _uiState.copyWith(
      wishlist: updatedWishlist,
      wishlistItemsCoveredCount: coveredCount,
      estimatedExtraBudgetNeeded: newExtraBudget,
      showWishlistWarning: newExtraBudget > 0,
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

      // Derive surrounding activities for geographic coherence.
      // Find the non-empty, non-transportation activity before and after this slot.
      String? previousDest;
      String? nextDest;
      for (int i = slotIndex - 1; i >= 0; i--) {
        final a = _uiState.activities[i];
        if (a.destination.isNotEmpty &&
            a.activityCategory.toLowerCase() != 'transportation') {
          previousDest = a.destination;
          break;
        }
      }
      for (int i = slotIndex + 1; i < _uiState.activities.length; i++) {
        final a = _uiState.activities[i];
        if (a.destination.isNotEmpty &&
            a.activityCategory.toLowerCase() != 'transportation') {
          nextDest = a.destination;
          break;
        }
      }

      // Derive day number and total days from trip dates
      int totalDays = 1;
      int dayNumber = 1;
      try {
        final parts = _uiState.datesText.split(' - ');
        if (parts.length == 2) {
          final start = DateTime.parse(parts[0].trim());
          final end = DateTime.parse(parts[1].trim());
          totalDays = end.difference(start).inDays + 1;
          dayNumber = targetSlot.date.difference(start).inDays + 1;
          if (dayNumber < 1) dayNumber = 1;
          if (dayNumber > totalDays) dayNumber = totalDays;
        }
      } catch (_) {}

      final newActivity = await _itineraryService.generateAlternativeItinerary(
        destination: destination.isNotEmpty
            ? destination
            : _uiState.destinationTitle,
        slotDate: targetSlot.date,
        startTime: targetSlot.startTime ?? '09:00',
        endTime: targetSlot.endTime ?? '11:00',
        category: category,
        excludedActivity: excludedActivity,
        existingActivityId: slotActivityId,
        dayTripId: targetSlot.dayTripId,
        budgetLimit: budgetLimit,
        dayNumber: dayNumber,
        preference: _uiState.preference,
        constraints: _uiState.constraints,
        previousActivityDestination: previousDest,
        nextActivityDestination: nextDest,
        isFirstDay: dayNumber == 1,
        isLastDay: dayNumber == totalDays,
        totalDays: totalDays,
      );

      final updatedList = List<Activity>.from(_uiState.activities);
      updatedList[slotIndex] = newActivity;

      _uiState = _uiState.copyWith(
        activities: updatedList,
        clearRegeneratingSlot: true,
        isLoading: false,
      );
    } catch (e) {
      _uiState = _uiState.copyWith(
        clearRegeneratingSlot: true,
        errorMessage: e.toString(),
        isLoading: false,
      );
    }
    notifyListeners();
  }

  /// Regenerates all empty slots using the remaining activities as route/timing context.
  Future<void> regeneratePlanFromRemaining() async {
    final emptySlots = _uiState.activities
        .where(
          (a) =>
              a.status == 'empty' ||
              (a.destination.trim().isEmpty && a.description.trim().isEmpty),
        )
        .toList();
    if (emptySlots.isEmpty) return;

    final activeActivities = _uiState.activities
        .where((a) => a.status != 'empty' && a.destination.trim().isNotEmpty)
        .toList();

    // If all activities were deleted, generate from scratch
    if (activeActivities.isEmpty) {
      await generateItinerary();
      return;
    }

    _uiState = _uiState.copyWith(isRegeneratingPlan: true, errorMessage: null);
    notifyListeners();

    try {
      final excludedPlaces = <String>{
        ..._uiState.stashedActivities
            .where((a) => a.destination.trim().isNotEmpty)
            .map((a) => a.destination.trim()),
        ...activeActivities.map((a) => a.destination.trim()),
      }.toList();

      final double effectiveRemainingBudget = (totalBudget - spentBudget).clamp(
        0.0,
        double.infinity,
      );

      final newFilledActivities = await _itineraryService
          .regenerateEmptySlotsFromRemainingPlan(
            destination: _uiState.destinationTitle,
            remainingBudget: effectiveRemainingBudget,
            remainingActivities: activeActivities,
            emptySlots: emptySlots,
            excludedPlaces: excludedPlaces,
            uncoveredWishlist: uncoveredWishlistItems,
            preference: _uiState.preference,
            constraints: _uiState.constraints,
          );

      final Map<String, Activity> filledMap = {
        for (final act in newFilledActivities) act.activitiesId: act,
      };

      final updatedList = _uiState.activities.map((act) {
        if (filledMap.containsKey(act.activitiesId)) {
          return filledMap[act.activitiesId]!;
        }
        return act;
      }).toList();

      final newTotalAllocated = updatedList.fold(
        0.0,
        (sum, a) => sum + a.allocatedBudget,
      );
      final mathShortfall = (newTotalAllocated - totalBudget).clamp(
        0.0,
        double.infinity,
      );

      // Recalculate covered wishlist
      final wishlist = _uiState.wishlist ?? [];
      int coveredCount = 0;
      if (wishlist.isNotEmpty) {
        final activeActivities = updatedList
            .where(
              (a) => a.status != 'empty' && a.destination.trim().isNotEmpty,
            )
            .toList();
        for (final w in wishlist) {
          if (activeActivities.any(
            (a) => _matchesWishlist(w, a.destination, a.description),
          )) {
            coveredCount++;
          }
        }
      }

      _uiState = _uiState.copyWith(
        isRegeneratingPlan: false,
        activities: updatedList,
        totalAllocatedBudget: newTotalAllocated,
        wishlistItemsCoveredCount: coveredCount,
        estimatedExtraBudgetNeeded: mathShortfall,
        showWishlistWarning: false,
      );
    } catch (e) {
      _uiState = _uiState.copyWith(
        isRegeneratingPlan: false,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  Future<String?> confirmItinerary() async {
    if (!canConfirmItinerary) {
      if (hasExtraBudgetNeeded) {
        return 'Cannot confirm itinerary while extra budget is needed. Please top up your budget first.';
      }
      return 'Cannot confirm itinerary while some slots are empty or generation is in progress.';
    }
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

  void setDateFilter(DateTime? filterDate) {
    if (filterDate == null) {
      _uiState = _uiState.copyWith(clearDateFilter: true);
    } else {
      _uiState = _uiState.copyWith(selectedDateFilter: filterDate);
    }
    notifyListeners();
  }

  Future<void> loadSavedTrip({required String tripId, WholeTrip? trip}) async {
    final startDateStr = trip?.startDate != null
        ? DateFormat('MMM dd').format(trip!.startDate)
        : '';
    final endDateStr = trip?.endDate != null
        ? DateFormat('MMM dd, yyyy').format(trip!.endDate)
        : '';
    final dateRangeText = (startDateStr.isNotEmpty && endDateStr.isNotEmpty)
        ? '$startDateStr - $endDateStr'
        : '';

    _uiState = _uiState.copyWith(
      isLoading: true,
      destinationTitle: trip?.destination ?? '',
      datesText: dateRangeText,
      budgetText: trip?.totalBudget.toStringAsFixed(2) ?? '0',
      errorMessage: null,
    );
    notifyListeners();

    try {
      final activities = await _itineraryService.fetchAllActivitiesByTrip(
        tripId,
      );

      _uiState = _uiState.copyWith(
        isLoading: false,
        activities: activities,
        totalAllocatedBudget: trip?.totalBudget ?? 0.0,
        showWishlistWarning: false,
      );
    } catch (e) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> deletePendingTrip(String? tripId) async {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      if (tripId != null && tripId.isNotEmpty) {
        await _itineraryService.deleteWholeTrip(tripId);

        final updatedTrips = _uiState.allTrips
            .where((trip) => trip.tripId != tripId)
            .toList();
        _uiState = _uiState.copyWith(allTrips: updatedTrips, isLoading: false);

        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ViewModel] Failed to delete trip: $e');
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    } finally {
      _uiState = _uiState.copyWith(isLoading: false);
      notifyListeners();
    }
  }
}
