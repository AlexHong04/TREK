import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/services/i_itinerary_service.dart';
import '../../models/services/itinerary_service.dart';
import '../ui_state/travel_information_ui_state.dart';

class TravelInformationInputViewModel extends ChangeNotifier {
  final IItineraryService _itineraryService;
  Timer? _hotelDebounce;
  String _currentHotelQuery = '';
  String? _activeHotelField;

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
    if (_uiState.selectedDestinations.isEmpty && (value ?? '').trim().isEmpty) {
      return 'Please select at least one destination state';
    }
    return null;
  }

  String? validateDestinations() {
    if (_uiState.selectedDestinations.isEmpty) {
      return 'Please select at least one destination state';
    }
    return null;
  }

  void toggleDestination(String stateName) {
    final current = List<String>.from(_uiState.selectedDestinations);
    if (current.contains(stateName)) {
      current.remove(stateName);
    } else {
      current.add(stateName);
    }
    _uiState = _uiState.copyWith(selectedDestinations: current);
    notifyListeners();

    if (_currentWishlistQuery.trim().isNotEmpty) {
      onWishlistChanged(_currentWishlistQuery);
    }
    if (_activeHotelField != null) {
      _loadHotelSuggestions(_currentHotelQuery);
    }
  }

  void removeDestination(String stateName) {
    final current = List<String>.from(_uiState.selectedDestinations)
      ..remove(stateName);
    _uiState = _uiState.copyWith(selectedDestinations: current);
    notifyListeners();

    if (_currentWishlistQuery.trim().isNotEmpty) {
      onWishlistChanged(_currentWishlistQuery);
    }
    if (_activeHotelField != null) {
      _loadHotelSuggestions(_currentHotelQuery);
    }
  }

  void clearDestinations() {
    _uiState = _uiState.copyWith(selectedDestinations: const []);
    notifyListeners();
    if (_activeHotelField != null) {
      _loadHotelSuggestions(_currentHotelQuery);
    }
  }

  void setSelectedDestinations(List<String> states) {
    _uiState = _uiState.copyWith(selectedDestinations: states);
    notifyListeners();

    if (_currentWishlistQuery.trim().isNotEmpty) {
      onWishlistChanged(_currentWishlistQuery);
    }
    if (_activeHotelField != null) {
      _loadHotelSuggestions(_currentHotelQuery);
    }
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

  void addArrival() {
    final newId = 'arr_${DateTime.now().millisecondsSinceEpoch}';
    final updated = List<TransitPoint>.from(_uiState.arrivals)
      ..add(TransitPoint(id: newId, location: '', time: '09:00 AM'));
    _uiState = _uiState.copyWith(arrivals: updated);
    notifyListeners();
  }

  void removeArrival(int index) {
    if (index >= 0 &&
        index < _uiState.arrivals.length &&
        _uiState.arrivals.length > 1) {
      final updated = List<TransitPoint>.from(_uiState.arrivals)
        ..removeAt(index);
      _uiState = _uiState.copyWith(arrivals: updated);
      notifyListeners();
    }
  }

  void updateArrivalLocation(int index, String location) {
    if (index >= 0 && index < _uiState.arrivals.length) {
      final updated = List<TransitPoint>.from(_uiState.arrivals);
      updated[index] = updated[index].copyWith(location: location);
      _uiState = _uiState.copyWith(arrivals: updated);
      notifyListeners();
    }
  }

  void updateArrivalTime(int index, String time) {
    if (index >= 0 && index < _uiState.arrivals.length) {
      final updated = List<TransitPoint>.from(_uiState.arrivals);
      updated[index] = updated[index].copyWith(time: time);
      _uiState = _uiState.copyWith(arrivals: updated);
      notifyListeners();
    }
  }

  void addDeparture() {
    final newId = 'dep_${DateTime.now().millisecondsSinceEpoch}';
    final updated = List<TransitPoint>.from(_uiState.departures)
      ..add(TransitPoint(id: newId, location: '', time: '06:00 PM'));
    _uiState = _uiState.copyWith(departures: updated);
    notifyListeners();
  }

  void removeDeparture(int index) {
    if (index >= 0 &&
        index < _uiState.departures.length &&
        _uiState.departures.length > 1) {
      final updated = List<TransitPoint>.from(_uiState.departures)
        ..removeAt(index);
      _uiState = _uiState.copyWith(departures: updated);
      notifyListeners();
    }
  }

  void updateDepartureLocation(int index, String location) {
    if (index >= 0 && index < _uiState.departures.length) {
      final updated = List<TransitPoint>.from(_uiState.departures);
      updated[index] = updated[index].copyWith(location: location);
      _uiState = _uiState.copyWith(departures: updated);
      notifyListeners();
    }
  }

  void updateDepartureTime(int index, String time) {
    if (index >= 0 && index < _uiState.departures.length) {
      final updated = List<TransitPoint>.from(_uiState.departures);
      updated[index] = updated[index].copyWith(time: time);
      _uiState = _uiState.copyWith(departures: updated);
      notifyListeners();
    }
  }

  void setArrivalTime(String time) => updateArrivalTime(0, time);

  void setDepartureTime(String time) => updateDepartureTime(0, time);

  void setArrivalLocation(String location) =>
      updateArrivalLocation(0, location);

  void setDepartureLocation(String location) =>
      updateDepartureLocation(0, location);

  void addHotel() {
    final newId = 'hotel_${DateTime.now().millisecondsSinceEpoch}';
    final updated = List<HotelStay>.from(_uiState.hotels)
      ..add(
        HotelStay(
          id: newId,
          location: '',
          checkInTime: '03:00 PM',
          checkOutTime: '12:00 PM',
        ),
      );
    _uiState = _uiState.copyWith(hotels: updated);
    notifyListeners();
  }

  void removeHotel(int index) {
    if (index >= 0 &&
        index < _uiState.hotels.length &&
        _uiState.hotels.length > 1) {
      final updated = List<HotelStay>.from(_uiState.hotels)..removeAt(index);
      _uiState = _uiState.copyWith(hotels: updated);
      notifyListeners();
    }
  }

  void updateHotelLocation(int index, String location) {
    if (index >= 0 && index < _uiState.hotels.length) {
      final updated = List<HotelStay>.from(_uiState.hotels);
      updated[index] = updated[index].copyWith(location: location);
      _uiState = _uiState.copyWith(hotels: updated);
      notifyListeners();
    }
  }

  void updateHotelCheckInTime(int index, String time) {
    if (index >= 0 && index < _uiState.hotels.length) {
      final updated = List<HotelStay>.from(_uiState.hotels);
      updated[index] = updated[index].copyWith(checkInTime: time);
      _uiState = _uiState.copyWith(hotels: updated);
      notifyListeners();
    }
  }

  void updateHotelCheckOutTime(int index, String time) {
    if (index >= 0 && index < _uiState.hotels.length) {
      final updated = List<HotelStay>.from(_uiState.hotels);
      updated[index] = updated[index].copyWith(checkOutTime: time);
      _uiState = _uiState.copyWith(hotels: updated);
      notifyListeners();
    }
  }

  void setHotelCheckInTime(String time) => updateHotelCheckInTime(0, time);

  void setHotelCheckOutTime(String time) => updateHotelCheckOutTime(0, time);

  void setHotelLocation(String location) => updateHotelLocation(0, location);

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
    final String? destinationError = validateDestinations();
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

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      _uiState = _uiState.copyWith(isSearchingSuggestions: true);
      notifyListeners();

      try {
        final results = await _itineraryService.getAutocompleteSuggestions(
          trimmed,
          destinations: _uiState.selectedDestinations,
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

  void onHotelFocused(int index) {
    _activeHotelField = 'hotel_$index';
    _hotelDebounce?.cancel();
    final currentText = index < _uiState.hotels.length
        ? _uiState.hotels[index].location
        : '';
    _loadHotelSuggestions(currentText);
  }

  void onHotelLocationChanged(int index, String value) {
    updateHotelLocation(index, value);
    _activeHotelField = 'hotel_$index';
    _debounceHotelSearch(value);
  }

  void selectHotelSuggestion(int index, String suggestion) {
    updateHotelLocation(index, suggestion);
    clearHotelSuggestions();
  }

  void clearHotelSuggestions() {
    _currentHotelQuery = '';
    _activeHotelField = null;
    _hotelDebounce?.cancel();
    _uiState = _uiState.copyWith(
      clearActiveHotelField: true,
      hotelSuggestions: const [],
      isSearchingHotelSuggestions: false,
    );
    notifyListeners();
  }

  void _loadHotelSuggestions(String currentText) {
    _currentHotelQuery = currentText;
    final trimmed = currentText.trim();

    _uiState = _uiState.copyWith(
      activeHotelField: _activeHotelField,
      isSearchingHotelSuggestions: true,
    );
    notifyListeners();

    _fetchHotels(trimmed);
  }

  void _debounceHotelSearch(String value) {
    _currentHotelQuery = value;
    if (_hotelDebounce?.isActive ?? false) _hotelDebounce!.cancel();

    final trimmed = value.trim();

    _uiState = _uiState.copyWith(
      activeHotelField: _activeHotelField,
      isSearchingHotelSuggestions: true,
    );
    notifyListeners();

    _hotelDebounce = Timer(const Duration(milliseconds: 500), () async {
      await _fetchHotels(trimmed);
    });
  }

  Future<void> _fetchHotels(String query) async {
    final capturedField = _activeHotelField;
    try {
      final results = await _itineraryService.getHotelAutocompleteSuggestions(
        query,
        destinations: _uiState.selectedDestinations,
      );

      if (_activeHotelField != capturedField) return;

      _uiState = _uiState.copyWith(
        hotelSuggestions: results,
        isSearchingHotelSuggestions: false,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Hotel autocomplete search error: $e');
      if (_activeHotelField == capturedField) {
        _uiState = _uiState.copyWith(isSearchingHotelSuggestions: false);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hotelDebounce?.cancel();
    super.dispose();
  }
}
