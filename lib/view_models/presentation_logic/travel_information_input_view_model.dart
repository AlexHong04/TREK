import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/configurations/frankfurter_api_config.dart';
import '../../models/configurations/google_places_api_config.dart';
import '../../models/services/i_auth_service.dart';
import '../../models/services/i_profile_service.dart'; // added this
import '../../models/services/i_itinerary_service.dart';
import '../../models/services/itinerary_service.dart';
import '../../utils/explicit_word_validation.dart';
import '../../utils/transit_schedule_helper.dart';
import '../ui_state/travel_information_ui_state.dart';

class TravelInformationInputViewModel extends ChangeNotifier {
  final IItineraryService _itineraryService;
  final IAuthService? _authService;
  final IProfileService _profileService; // added this
  Timer? _hotelDebounce;
  String _currentHotelQuery = '';
  String? _activeHotelField;

  TravelInformationInputViewModel({
    IItineraryService? itineraryService,
    IAuthService? authService,
    required IProfileService profileService, // added this
  })  : _itineraryService = itineraryService ?? ItineraryService(),
        _profileService = profileService, // added this
        _authService = authService {
    _authService?.addListener(_onAuthServiceChanged);
    _syncPreferredCurrency();
    _loadExistingTrips();
  }

  double? _cachedRateToMyr = 1.0;
  double? get cachedRateToMyr => _cachedRateToMyr;

  int get numberOfDays {
    if (_uiState.startDate != null && _uiState.endDate != null) {
      final diff = _uiState.endDate!.difference(_uiState.startDate!).inDays + 1;
      return diff > 0 ? diff : 1;
    }
    return 1;
  }

  void _syncPreferredCurrency() {
    final currency = _profileService.preferredCurrency.trim().toUpperCase();
    if (currency.isNotEmpty && currency != _uiState.preferredCurrency) {
      _uiState = _uiState.copyWith(preferredCurrency: currency);
    }
    _updateCachedRateToMyr();
  }

  void _updateCachedRateToMyr() {
    final currency = preferredCurrency;
    if (currency == 'MYR') {
      _cachedRateToMyr = 1.0;
    } else {
      getExchangeRate(fromCurrency: currency, toCurrency: 'MYR').then((rate) {
        if (rate != null) {
          _cachedRateToMyr = rate;
        }
      }).catchError((_) {});
    }
  }

  void _onAuthServiceChanged() {
    _syncPreferredCurrency();
    notifyListeners();
  }

  String get preferredCurrency => _uiState.preferredCurrency;

  Future<double?> getExchangeRate({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (fromCurrency.toUpperCase() == toCurrency.toUpperCase()) {
      return 1.0;
    }
    try {
      return await FrankfurterApiConfig.getRate(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );
    } catch (e) {
      debugPrint('Error fetching exchange rate: $e');
      return null;
    }
  }

  Future<double?> convertToMyr(double amount) async {
    final currency = preferredCurrency;
    if (currency == 'MYR') return amount;
    final rate = await getExchangeRate(
      fromCurrency: currency,
      toCurrency: 'MYR',
    );
    if (rate != null) {
      return amount * rate;
    }
    return null;
  }

  Future<double?> convertAmount({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (fromCurrency.toUpperCase() == toCurrency.toUpperCase()) {
      return amount;
    }
    final rate = await getExchangeRate(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
    );
    if (rate != null) {
      return amount * rate;
    }
    return null;
  }

  static final List<TextInputFormatter> _wishlistInputFormatters = [
    FilteringTextInputFormatter.allow(
      RegExp(r"[a-zA-Z0-9\u4e00-\u9fa5\s.,'()\-&/]"),
    ),
    LengthLimitingTextInputFormatter(60),
  ];

  List<TextInputFormatter> get wishlistInputFormatters =>
      _wishlistInputFormatters;

  Future<void> refreshExistingTrips() async {
    await _loadExistingTrips();
  }

  Future<void> _loadExistingTrips() async {
    try {
      final trips = await _itineraryService.fetchAllTrip();
      final ranges = trips
          .where((t) => t.status.toLowerCase() != 'terminated')
          .map((t) {
        // We normalize the start and end dates to just year/month/day
        final localStart = t.startDate.toLocal();
        final localEnd = t.endDate.toLocal();
        return DateTimeRange(
          start: DateTime(localStart.year, localStart.month, localStart.day),
          end: DateTime(localEnd.year, localEnd.month, localEnd.day),
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
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Please enter a budget';
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      return 'Please enter a valid positive budget amount';
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

  int? _parseTimeToMinutes(String timeStr) {
    try {
      final trimmed = timeStr.trim();
      if (trimmed.isEmpty) return null;
      final parts = trimmed.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
        hour += 12;
      } else if (parts.length > 1 &&
          parts[1].toUpperCase() == 'AM' &&
          hour == 12) {
        hour = 0;
      }
      return hour * 60 + minute;
    } catch (_) {
      return null;
    }
  }

  void addTransitLeg() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaultArrivalDate = _uiState.startDate != null
        ? _uiState.startDate!.toLocal().toString().split(' ')[0]
        : '';
    final defaultDepartureDate = _uiState.endDate != null
        ? _uiState.endDate!.toLocal().toString().split(' ')[0]
        : '';

    final hasPreviousDeparture = _uiState.departures.isNotEmpty;
    final prevDeparture =
        hasPreviousDeparture ? _uiState.departures.last : null;

    // Inherit arrival type from previous leg's departure (e.g. Flight, Train, Bus)
    final inheritedArrivalType = prevDeparture?.type.isNotEmpty == true
        ? prevDeparture!.type
        : 'Flight';

    // Default arrival date to previous departure date (or trip start date)
    final inheritedArrivalDate = prevDeparture?.date.isNotEmpty == true
        ? prevDeparture!.date
        : defaultArrivalDate;

    // Default arrival time to previous departure time (or 09:00 AM)
    final inheritedArrivalTime = prevDeparture?.time.isNotEmpty == true
        ? prevDeparture!.time
        : '09:00 AM';

    String finalArrivalDate = inheritedArrivalDate;
    String finalArrivalTime = inheritedArrivalTime;

    // Calculate realistic arrival date/time based on transport duration
    if (prevDeparture != null) {
      final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
        transitType: inheritedArrivalType,
        fromLocation: prevDeparture.location,
        toLocation: '',
        selectedDestinations: _uiState.selectedDestinations,
      );
      final calculated = TransitScheduleHelper.calculateArrivalDateTime(
        departureDate: inheritedArrivalDate,
        departureTimeStr: inheritedArrivalTime,
        minutesToAdd: durationMin,
      );
      finalArrivalDate = calculated['date'] as String;
      finalArrivalTime = calculated['time'] as String;
    }

    final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals)
      ..add(TransitPoint(
        id: 'arr_$now',
        location: '',
        time: finalArrivalTime,
        type: inheritedArrivalType,
        date: finalArrivalDate,
      ));
    final updatedDepartures = List<TransitPoint>.from(_uiState.departures)
      ..add(TransitPoint(
        id: 'dep_$now',
        location: '',
        time: '09:00 PM',
        type: inheritedArrivalType,
        date: defaultDepartureDate.isNotEmpty
            ? defaultDepartureDate
            : finalArrivalDate,
      ));

    _uiState = _uiState.copyWith(
      arrivals: updatedArrivals,
      departures: updatedDepartures,
    );
    notifyListeners();
  }

  void removeTransitLeg(int index) {
    final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
    final updatedDepartures = List<TransitPoint>.from(_uiState.departures);

    if (updatedArrivals.length > 1 &&
        index >= 0 &&
        index < updatedArrivals.length) {
      updatedArrivals.removeAt(index);
    }
    if (updatedDepartures.length > 1 &&
        index >= 0 &&
        index < updatedDepartures.length) {
      updatedDepartures.removeAt(index);
    }

    _uiState = _uiState.copyWith(
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
      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      updatedArrivals[index] = updatedArrivals[index].copyWith(time: time);

      final updatedDepartures = List<TransitPoint>.from(_uiState.departures);
      if (index < updatedDepartures.length) {
        final curArr = updatedArrivals[index];
        final curDep = updatedDepartures[index];
        if (curArr.date.isNotEmpty && curArr.date == curDep.date) {
          final arrMin = _parseTimeToMinutes(time);
          final depMin = _parseTimeToMinutes(curDep.time);
          if (arrMin != null && depMin != null && depMin < arrMin) {
            updatedDepartures[index] = curDep.copyWith(time: time);
          }
        }
      }

      _uiState = _uiState.copyWith(
        arrivals: updatedArrivals,
        departures: updatedDepartures,
      );
      notifyListeners();
    }
  }

  void updateArrivalDate(int index, String date) {
    if (index >= 0 && index < _uiState.arrivals.length) {
      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      updatedArrivals[index] = updatedArrivals[index].copyWith(date: date);

      final updatedDepartures = List<TransitPoint>.from(_uiState.departures);
      if (index < updatedDepartures.length && date.isNotEmpty) {
        final curDep = updatedDepartures[index];
        if (curDep.date.isNotEmpty) {
          final arrD = DateTime.tryParse(date);
          final depD = DateTime.tryParse(curDep.date);
          if (arrD != null && depD != null && depD.isBefore(arrD)) {
            updatedDepartures[index] = curDep.copyWith(date: date);
          }
        }
      }

      _uiState = _uiState.copyWith(
        arrivals: updatedArrivals,
        departures: updatedDepartures,
      );
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
        time: '09:00 PM',
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
      final updatedDepartures = List<TransitPoint>.from(_uiState.departures);
      updatedDepartures[index] = updatedDepartures[index].copyWith(date: date);

      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      if (index + 1 < updatedArrivals.length && date.isNotEmpty) {
        final curDep = updatedDepartures[index];
        final nextArr = updatedArrivals[index + 1];
        final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
          transitType: curDep.type,
          fromLocation: curDep.location,
          toLocation: nextArr.location,
          selectedDestinations: _uiState.selectedDestinations,
        );
        final calculated = TransitScheduleHelper.calculateArrivalDateTime(
          departureDate: date,
          departureTimeStr: curDep.time,
          minutesToAdd: durationMin,
        );
        updatedArrivals[index + 1] = nextArr.copyWith(
          time: calculated['time'] as String,
          date: calculated['date'] as String,
        );
      }

      _uiState = _uiState.copyWith(
        departures: updatedDepartures,
        arrivals: updatedArrivals,
      );
      notifyListeners();
    }
  }

  void updateArrivalType(int index, String type) {
    if (index >= 0 && index < _uiState.arrivals.length) {
      // If this is transit leg 2+, its arrival type is locked to previous departure
      if (index > 0 && index - 1 < _uiState.departures.length) {
        final lockedType = _uiState.departures[index - 1].type;
        if (lockedType.isNotEmpty && type != lockedType) {
          return; // Prevent changing to an unlinked category
        }
      }
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
      final updatedDepartures = List<TransitPoint>.from(_uiState.departures);
      final current = updatedDepartures[index];
      if (current.type != type) {
        updatedDepartures[index] = current.copyWith(type: type, location: '');
      }

      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      if (index + 1 < updatedArrivals.length) {
        final nextArr = updatedArrivals[index + 1];
        final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
          transitType: type,
          fromLocation: updatedDepartures[index].location,
          toLocation: nextArr.location,
          selectedDestinations: _uiState.selectedDestinations,
        );
        final calculated = TransitScheduleHelper.calculateArrivalDateTime(
          departureDate: updatedDepartures[index].date,
          departureTimeStr: updatedDepartures[index].time,
          minutesToAdd: durationMin,
        );
        updatedArrivals[index + 1] = nextArr.copyWith(
          type: type,
          location: nextArr.type != type ? '' : nextArr.location,
          time: calculated['time'] as String,
          date: calculated['date'] as String,
        );
      }

      _uiState = _uiState.copyWith(
        departures: updatedDepartures,
        arrivals: updatedArrivals,
      );
      notifyListeners();
    }
  }

  void updateArrivalHub(
    int index, {
    required String type,
    required String location,
  }) {
    if (index >= 0 && index < _uiState.arrivals.length) {
      String effectiveType = type;
      if (index > 0 && index - 1 < _uiState.departures.length) {
        final lockedType = _uiState.departures[index - 1].type;
        if (lockedType.isNotEmpty) {
          effectiveType = lockedType;
        }
      }
      final updated = List<TransitPoint>.from(_uiState.arrivals);
      var updatedArr =
          updated[index].copyWith(type: effectiveType, location: location);

      if (index > 0 && index - 1 < _uiState.departures.length) {
        final prevDep = _uiState.departures[index - 1];
        final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
          transitType: effectiveType,
          fromLocation: prevDep.location,
          toLocation: location,
          selectedDestinations: _uiState.selectedDestinations,
        );
        final calculated = TransitScheduleHelper.calculateArrivalDateTime(
          departureDate: prevDep.date,
          departureTimeStr: prevDep.time,
          minutesToAdd: durationMin,
        );
        updatedArr = updatedArr.copyWith(
          time: calculated['time'] as String,
          date: calculated['date'] as String,
        );
      }

      updated[index] = updatedArr;
      _uiState = _uiState.copyWith(arrivals: updated);
      notifyListeners();
    }
  }

  void updateDepartureHub(
    int index, {
    required String type,
    required String location,
  }) {
    if (index >= 0 && index < _uiState.departures.length) {
      final updatedDepartures = List<TransitPoint>.from(_uiState.departures);
      updatedDepartures[index] =
          updatedDepartures[index].copyWith(type: type, location: location);

      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      if (index + 1 < updatedArrivals.length) {
        final nextArr = updatedArrivals[index + 1];
        final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
          transitType: type,
          fromLocation: location,
          toLocation: nextArr.location,
          selectedDestinations: _uiState.selectedDestinations,
        );
        final calculated = TransitScheduleHelper.calculateArrivalDateTime(
          departureDate: updatedDepartures[index].date,
          departureTimeStr: updatedDepartures[index].time,
          minutesToAdd: durationMin,
        );

        updatedArrivals[index + 1] = nextArr.copyWith(
          type: type,
          location: nextArr.type != type ? '' : nextArr.location,
          time: calculated['time'] as String,
          date: calculated['date'] as String,
        );
      }

      _uiState = _uiState.copyWith(
        departures: updatedDepartures,
        arrivals: updatedArrivals,
      );
      notifyListeners();
    }
  }

  void syncTransitType(String type, {int? index}) {
    final updatedArrivals = _uiState.arrivals.asMap().entries.map((e) {
      if (index == null || e.key == index) {
        if (e.value.type != type) {
          return e.value.copyWith(type: type);
        }
      }
      return e.value;
    }).toList();

    final updatedDepartures = _uiState.departures.asMap().entries.map((e) {
      if (index == null || e.key == index) {
        if (e.value.type != type) {
          return e.value.copyWith(type: type);
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
      final updatedDepartures = List<TransitPoint>.from(_uiState.departures);
      updatedDepartures[index] = updatedDepartures[index].copyWith(time: time);

      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      if (index + 1 < updatedArrivals.length) {
        final curDep = updatedDepartures[index];
        final nextArr = updatedArrivals[index + 1];

        final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
          transitType: curDep.type,
          fromLocation: curDep.location,
          toLocation: nextArr.location,
          selectedDestinations: _uiState.selectedDestinations,
        );

        final calculated = TransitScheduleHelper.calculateArrivalDateTime(
          departureDate: curDep.date,
          departureTimeStr: time,
          minutesToAdd: durationMin,
        );

        updatedArrivals[index + 1] = nextArr.copyWith(
          time: calculated['time'] as String,
          date: calculated['date'] as String,
        );
      }

      _uiState = _uiState.copyWith(
        departures: updatedDepartures,
        arrivals: updatedArrivals,
      );
      notifyListeners();
    }
  }

  void syncLegArrivalWithDepartureDuration(int legIndex) {
    if (legIndex > 0 &&
        legIndex < _uiState.arrivals.length &&
        legIndex - 1 < _uiState.departures.length) {
      final prevDep = _uiState.departures[legIndex - 1];
      final curArr = _uiState.arrivals[legIndex];
      final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
        transitType: curArr.type.isNotEmpty ? curArr.type : prevDep.type,
        fromLocation: prevDep.location,
        toLocation: curArr.location,
        selectedDestinations: _uiState.selectedDestinations,
      );
      final calc = TransitScheduleHelper.calculateArrivalDateTime(
        departureDate: prevDep.date,
        departureTimeStr: prevDep.time,
        minutesToAdd: durationMin,
      );
      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      updatedArrivals[legIndex] = curArr.copyWith(
        time: calc['time'] as String,
        date: calc['date'] as String,
      );
      _uiState = _uiState.copyWith(arrivals: updatedArrivals);
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

    final error = validatePlaceInput(trimmed);
    if (error != null) {
      _uiState = _uiState.copyWith(wishlistError: error);
      notifyListeners();
      return;
    }

    if (!_uiState.wishlistItems.contains(trimmed)) {
      _uiState = _uiState.copyWith(
        wishlistItems: [..._uiState.wishlistItems, trimmed],
        clearWishlistError: true,
      );
    }
    clearSuggestions();
  }

  void removeWishlistItem(String item) {
    final updatedList = List<String>.from(_uiState.wishlistItems)..remove(item);
    _uiState = _uiState.copyWith(wishlistItems: updatedList);
    notifyListeners();
  }

  void clearWishlist() {
    _currentWishlistQuery = '';
    _uiState = _uiState.copyWith(
      wishlistItems: const [],
      clearWishlistError: true,
    );
    clearSuggestions();
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
    for (final hotel in _uiState.hotels) {
      final err = validateExplicitWord(hotel.location);
      if (err != null) return err;
    }
    return null;
  }

  String? validateExplicitWord(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    return validatePlaceInput(value);
  }

  String? validateWishlist(String? value) => validateExplicitWord(value);

  String? generateItinerary({
    String? destination,
    String? date,
    String? budget,
    String? wishlistQuery,
  }) {
    if (_uiState.wishlistError != null) {
      return _uiState.wishlistError;
    }
    if ((wishlistQuery ?? '').trim().isNotEmpty) {
      final wErr = validatePlaceInput(wishlistQuery);
      if (wErr != null) {
        _uiState = _uiState.copyWith(
          wishlistError: wErr,
          suggestions: const [],
          isSearchingSuggestions: false,
        );
        notifyListeners();
        return wErr;
      }
    }
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
      _uiState = _uiState.copyWith(
        clearWishlistError: true,
        suggestions: const [],
        isSearchingSuggestions: false,
      );
      notifyListeners();
      return;
    }

    final validationError = validatePlaceInput(trimmed);
    if (validationError != null) {
      _uiState = _uiState.copyWith(
        wishlistError: validationError,
        suggestions: const [],
        isSearchingSuggestions: false,
      );
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(clearWishlistError: true);
    notifyListeners();

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

        final filteredResults = results
            .where((item) => !GooglePlacesApiConfig.isParkingText(item))
            .toList();

        _uiState = _uiState.copyWith(
          suggestions: filteredResults,
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
    _authService?.removeListener(_onAuthServiceChanged);
    _debounce?.cancel();
    _hotelDebounce?.cancel();
    super.dispose();
  }
}

class TravelInformationInputViewModelScope extends StatelessWidget {
  final Widget child;

  const TravelInformationInputViewModelScope({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TravelInformationInputViewModel>(
      create: (context) => TravelInformationInputViewModel(
        itineraryService: context.read<IItineraryService>(),
        authService: context.read<IAuthService>(),
        profileService: context.read<IProfileService>(), // added this
      ),
      child: child,
    );
  }
}
