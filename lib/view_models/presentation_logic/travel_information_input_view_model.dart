import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/services/i_itinerary_service.dart';
import '../../models/services/itinerary_service.dart';
import '../ui_state/travel_information_ui_state.dart';

class TravelInformationInputViewModel extends ChangeNotifier {
  final IItineraryService _itineraryService;

  TravelInformationInputViewModel({IItineraryService? itineraryService})
    : _itineraryService = itineraryService ?? ItineraryService() {
    _loadExistingTrips();
  }

  Future<void> _loadExistingTrips() async {
    try {
      final trips = await _itineraryService.fetchAllTrip();
      final ranges = trips.map((t) {
        // We normalize the start and end dates to just year/month/day
        return DateTimeRange(
          start: DateTime(t.startDate.year, t.startDate.month, t.startDate.day),
          end: DateTime(t.endDate.year, t.endDate.month, t.endDate.day),
        );
      }).toList();
      _uiState = _uiState.copyWith(unavailableDateRanges: ranges);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading existing trips for dates: $e');
    }
  }

  String _currentWishlistQuery = '';

  TravelInformationUiState _uiState = const TravelInformationUiState();
  TravelInformationUiState get uiState => _uiState;
  Timer? _debounce;

  final List<PreferenceItemModel> preferences = [
    PreferenceItemModel(label: 'Nature', icon: Icons.park_outlined),
    PreferenceItemModel(label: 'Adventure', icon: Icons.explore_outlined),
    PreferenceItemModel(label: 'Foodie', icon: Icons.menu_book_outlined),
    PreferenceItemModel(
      label: 'Relaxation',
      icon: Icons.nightlight_round_outlined,
    ),
  ];

  String? validateDestination(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Please enter a destination';
    }
    return null;
  }

  String? validateDate(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Please select dates';
    }
    return null;
  }

  String? validateBudget(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Please enter a budget';
    }
    return null;
  }

  String formatDateRange(DateTime start, DateTime end) {
    return '${start.toLocal().toString().split(' ')[0]} - ${end.toLocal().toString().split(' ')[0]}';
  }

  void selectPreference(String label) {
    _uiState = _uiState.copyWith(selectedPreference: label);
    notifyListeners();
  }

  void addWishlistItem(String item) {
    final trimmed = item.trim();
    if (trimmed.isEmpty) return;

    if (!_uiState.wishlistItems.contains(trimmed)) {
      _uiState = _uiState.copyWith(
        wishlistItems: [..._uiState.wishlistItems, trimmed],
      );
    }
    clearSuggestions();
  }

  void removeWishlistItem(String item) {
    final updatedList = List<String>.from(_uiState.wishlistItems)..remove(item);
    _uiState = _uiState.copyWith(wishlistItems: updatedList);
    notifyListeners();
  }

  String? generateItinerary({
    String? destination,
    String? date,
    String? budget,
  }) {
    final String? destinationError = validateDestination(destination);
    final String? dateError = validateDate(date);
    final String? budgetError = validateBudget(budget);

    if (destinationError != null || dateError != null || budgetError != null) {
      return destinationError ??
          dateError ??
          budgetError ??
          'Please complete the form';
    }

    return null; // Return null if success
  }

  void clearSuggestions() {
    _currentWishlistQuery = '';
    _debounce?.cancel();
    _uiState = _uiState.copyWith(
      suggestions: const [],
      isSearchingSuggestions: false,
    );
    notifyListeners();
  }

  void onWishlistChanged(String value) {
    _currentWishlistQuery = value;
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      clearSuggestions();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      _uiState = _uiState.copyWith(isSearchingSuggestions: true);
      notifyListeners();

      try {
        final results = await _itineraryService.getAutocompleteSuggestions(
          trimmed,
        );

        // If the query was cleared while request was in-flight, ignore results
        if (_currentWishlistQuery.trim().isEmpty) {
          return;
        }

        _uiState = _uiState.copyWith(
          suggestions: results,
          isSearchingSuggestions: false,
        );
        notifyListeners();
      } catch (e) {
        debugPrint('Autocomplete search error: $e');
        _uiState = _uiState.copyWith(isSearchingSuggestions: false);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
