import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/services/i_itinerary_service.dart';
import '../../models/services/itinerary_service.dart';
import '../ui_state/travel_information_ui_state.dart';

class TravelInformationInputViewModel extends ChangeNotifier {
  final IItineraryService _itineraryService;

  TravelInformationInputViewModel({IItineraryService? itineraryService})
    : _itineraryService = itineraryService ?? ItineraryService();

  final TextEditingController destinationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController budgetController = TextEditingController();
  final TextEditingController wishlistController = TextEditingController();

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

  void updateDateRange(DateTime start, DateTime end) {
    dateController.text =
        '${start.toLocal().toString().split(' ')[0]} - ${end.toLocal().toString().split(' ')[0]}';
    notifyListeners();
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
    wishlistController.clear();
    notifyListeners();
  }

  void removeWishlistItem(String item) {
    final updatedList = List<String>.from(_uiState.wishlistItems)..remove(item);
    _uiState = _uiState.copyWith(wishlistItems: updatedList);
    notifyListeners();
  }

  String? generateItinerary() {
    final String? destinationError = validateDestination(
      destinationController.text,
    );
    final String? dateError = validateDate(dateController.text);
    final String? budgetError = validateBudget(budgetController.text);

    if (destinationError != null || dateError != null || budgetError != null) {
      return destinationError ??
          dateError ??
          budgetError ??
          'Please complete the form';
    }

    return null; // Return null if success
  }

  void clearSuggestions() {
    _uiState = _uiState.copyWith(
      suggestions: const [],
      isSearchingSuggestions: false,
    );
    notifyListeners();
  }

  void onWishlistChanged(String value) {
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
    destinationController.dispose();
    dateController.dispose();
    budgetController.dispose();
    wishlistController.dispose();
    super.dispose();
  }
}
