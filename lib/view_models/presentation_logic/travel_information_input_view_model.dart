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
    if (current.isEmpty) {
      final resetHotels = _uiState.hotels
          .map((h) => h.copyWith(location: ''))
          .toList();
      _uiState = _uiState.copyWith(
        selectedDestinations: current,
        hotels: resetHotels,
      );
      clearHotelSuggestions();
    } else {
      _uiState = _uiState.copyWith(selectedDestinations: current);
    }
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
    if (current.isEmpty) {
      final resetHotels = _uiState.hotels
          .map((h) => h.copyWith(location: ''))
          .toList();
      _uiState = _uiState.copyWith(
        selectedDestinations: current,
        hotels: resetHotels,
      );
      clearHotelSuggestions();
    } else {
      _uiState = _uiState.copyWith(selectedDestinations: current);
    }
    notifyListeners();

    if (_currentWishlistQuery.trim().isNotEmpty) {
      onWishlistChanged(_currentWishlistQuery);
    }
    if (_activeHotelField != null) {
      _loadHotelSuggestions(_currentHotelQuery);
    }
  }

  void clearDestinations() {
    final resetHotels = _uiState.hotels
        .map((h) => h.copyWith(location: ''))
        .toList();
    _uiState = _uiState.copyWith(
      selectedDestinations: const [],
      hotels: resetHotels,
    );
    clearHotelSuggestions();
    notifyListeners();
  }

  void setSelectedDestinations(List<String> states) {
    if (states.isEmpty) {
      final resetHotels = _uiState.hotels
          .map((h) => h.copyWith(location: ''))
          .toList();
      _uiState = _uiState.copyWith(
        selectedDestinations: states,
        hotels: resetHotels,
      );
      clearHotelSuggestions();
    } else {
      _uiState = _uiState.copyWith(selectedDestinations: states);
    }
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

  void updateTripDates(DateTime start, DateTime end) {
    final startFormatted = start.toLocal().toString().split(' ')[0];
    final endFormatted = end.toLocal().toString().split(' ')[0];
    final minDate = start.subtract(const Duration(days: 1));
    final maxDate = end.add(const Duration(days: 1));

    final updatedArrivals = _uiState.arrivals.map((arr) {
      if (arr.date.trim().isEmpty) {
        return arr.copyWith(date: startFormatted);
      }
      final parsed = DateTime.tryParse(arr.date.trim());
      if (parsed == null || parsed.isBefore(minDate) || parsed.isAfter(maxDate)) {
        return arr.copyWith(date: startFormatted);
      }
      return arr;
    }).toList();

    final updatedDepartures = _uiState.departures.map((dep) {
      if (dep.date.trim().isEmpty) {
        return dep.copyWith(date: endFormatted);
      }
      final parsed = DateTime.tryParse(dep.date.trim());
      if (parsed == null || parsed.isBefore(minDate) || parsed.isAfter(maxDate)) {
        return dep.copyWith(date: endFormatted);
      }
      return dep;
    }).toList();

    _uiState = _uiState.copyWith(
      startDate: start,
      endDate: end,
      arrivals: updatedArrivals,
      departures: updatedDepartures,
    );
    notifyListeners();
  }

  void addArrival() {
    final newId = 'arr_${DateTime.now().millisecondsSinceEpoch}';
    final defaultDate = _uiState.startDate != null
        ? _uiState.startDate!.toLocal().toString().split(' ')[0]
        : '';
    final updated = List<TransitPoint>.from(_uiState.arrivals)
      ..add(TransitPoint(
        id: newId,
        location: '',
        time: '09:00 AM',
        type: 'Flight',
        date: defaultDate,
      ));
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

  void updateArrivalDate(int index, String date) {
    if (index >= 0 && index < _uiState.arrivals.length) {
      final updated = List<TransitPoint>.from(_uiState.arrivals);
      updated[index] = updated[index].copyWith(date: date);
      _uiState = _uiState.copyWith(arrivals: updated);
      notifyListeners();
    }
  }

  void addDeparture() {
    final newId = 'dep_${DateTime.now().millisecondsSinceEpoch}';
    final defaultDate = _uiState.endDate != null
        ? _uiState.endDate!.toLocal().toString().split(' ')[0]
        : '';
    final updated = List<TransitPoint>.from(_uiState.departures)
      ..add(TransitPoint(
        id: newId,
        location: '',
        time: '06:00 PM',
        type: 'Flight',
        date: defaultDate,
      ));
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

  void updateDepartureDate(int index, String date) {
    if (index >= 0 && index < _uiState.departures.length) {
      final updated = List<TransitPoint>.from(_uiState.departures);
      updated[index] = updated[index].copyWith(date: date);
      _uiState = _uiState.copyWith(departures: updated);
      notifyListeners();
    }
  }

  void updateArrivalType(int index, String type) {
    if (index >= 0 && index < _uiState.arrivals.length) {
      final updated = List<TransitPoint>.from(_uiState.arrivals);
      final current = updated[index];
      if (current.type != type) {
        updated[index] = current.copyWith(type: type, location: '');
      }
      _uiState = _uiState.copyWith(arrivals: updated);
      notifyListeners();
    }
  }

  void updateDepartureType(int index, String type) {
    if (index >= 0 && index < _uiState.departures.length) {
      final updated = List<TransitPoint>.from(_uiState.departures);
      final current = updated[index];
      if (current.type != type) {
        updated[index] = current.copyWith(type: type, location: '');
      }
      _uiState = _uiState.copyWith(departures: updated);
      notifyListeners();
    }
  }

  void syncTransitType(String type, {int? index}) {
    final updatedArrivals = _uiState.arrivals.asMap().entries.map((e) {
      if (index == null || e.key == index || _uiState.arrivals.length == 1) {
        if (e.value.type != type) {
          return e.value.copyWith(type: type, location: '');
        }
      }
      return e.value;
    }).toList();

    final updatedDepartures = _uiState.departures.asMap().entries.map((e) {
      if (index == null || e.key == index || _uiState.departures.length == 1) {
        if (e.value.type != type) {
          return e.value.copyWith(type: type, location: '');
        }
      }
      return e.value;
    }).toList();

    _uiState = _uiState.copyWith(
      arrivals: updatedArrivals,
      departures: updatedDepartures,
    );
    notifyListeners();
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
    if (_uiState.selectedDestinations.isEmpty) {
      return;
    }
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
    if (_uiState.selectedDestinations.isEmpty && location.trim().isNotEmpty) {
      return;
    }
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

  String? validateTransitDates() {
    if (_uiState.startDate == null || _uiState.endDate == null) {
      return null;
    }
    final minDate = _uiState.startDate!.subtract(const Duration(days: 1));
    final maxDate = _uiState.endDate!.add(const Duration(days: 1));

    for (int i = 0; i < _uiState.arrivals.length; i++) {
      final arr = _uiState.arrivals[i];
      if (arr.date.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(arr.date.trim());
        if (parsed != null && (parsed.isBefore(minDate) || parsed.isAfter(maxDate))) {
          final minStr = minDate.toLocal().toString().split(' ')[0];
          final maxStr = maxDate.toLocal().toString().split(' ')[0];
          return 'Arrival ${i + 1} date must be between $minStr and $maxStr';
        }
      }
    }

    for (int i = 0; i < _uiState.departures.length; i++) {
      final dep = _uiState.departures[i];
      if (dep.date.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(dep.date.trim());
        if (parsed != null && (parsed.isBefore(minDate) || parsed.isAfter(maxDate))) {
          final minStr = minDate.toLocal().toString().split(' ')[0];
          final maxStr = maxDate.toLocal().toString().split(' ')[0];
          return 'Departure ${i + 1} date must be between $minStr and $maxStr';
        }
      }
    }
    return null;
  }

  String? validateHotels() {
    final hasHotel = _uiState.hotels.any((h) => h.location.trim().isNotEmpty);
    if (hasHotel && _uiState.selectedDestinations.isEmpty) {
      return 'Please select destination state(s) first before entering hotel details';
    }
    return null;
  }

  String? generateItinerary({
    String? destination,
    String? date,
    String? budget,
  }) {
    final String? destinationError = validateDestinations();
    final String? dateError = validateDate(date);
    final String? budgetError = validateBudget(budget);
    final String? transitDateError = validateTransitDates();
    final String? hotelError = validateHotels();

    if (destinationError != null ||
        dateError != null ||
        budgetError != null ||
        transitDateError != null ||
        hotelError != null) {
      return destinationError ??
          dateError ??
          budgetError ??
          transitDateError ??
          hotelError ??
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
    if (_uiState.selectedDestinations.isEmpty) return;
    _activeHotelField = 'hotel_$index';
    _hotelDebounce?.cancel();
    final currentText = index < _uiState.hotels.length
        ? _uiState.hotels[index].location
        : '';
    _loadHotelSuggestions(currentText);
  }

  void onHotelLocationChanged(int index, String value) {
    if (_uiState.selectedDestinations.isEmpty) return;
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

      final seen = <String>{};
      final uniqueResults = <String>[];
      for (final item in results) {
        final trimmed = item.trim();
        if (trimmed.isEmpty) continue;
        final key = trimmed
            .toLowerCase()
            .replaceAll(RegExp(r',\s*malaysia$', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (key.isNotEmpty && seen.add(key)) {
          uniqueResults.add(trimmed);
        }
      }

      _uiState = _uiState.copyWith(
        hotelSuggestions: uniqueResults,
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
