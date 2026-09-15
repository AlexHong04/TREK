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
import '../../widgets/destination_spending_rates_dialog.dart';
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
  }) : _itineraryService = itineraryService ?? ItineraryService(),
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
      getExchangeRate(fromCurrency: currency, toCurrency: 'MYR')
          .then((rate) {
            if (rate != null) {
              _cachedRateToMyr = rate;
            }
          })
          .catchError((_) {});
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
              start: DateTime(
                localStart.year,
                localStart.month,
                localStart.day,
              ),
              end: DateTime(localEnd.year, localEnd.month, localEnd.day),
            );
          })
          .toList();
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

  BudgetRecommendation getBudgetRecommendationForCurrentTrip() {
    final isForeign = preferredCurrency != 'MYR';
    final days = numberOfDays > 0 ? numberOfDays : 1;
    return getBudgetRecommendation(
      destinations: _uiState.selectedDestinations,
      numberOfDays: days,
      isInternational: isForeign,
    );
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

    final isForeign = preferredCurrency != 'MYR';
    final days = numberOfDays > 0 ? numberOfDays : 1;
    final rec = getBudgetRecommendation(
      destinations: _uiState.selectedDestinations,
      numberOfDays: days,
      isInternational: isForeign,
    );
    final minRequiredMyr = rec.minTotalMyr;

    // Convert required budget to preferred currency
    final rateToMyr = _cachedRateToMyr ?? 1.0;
    final double minRequiredInPreferred = preferredCurrency == 'MYR'
        ? minRequiredMyr
        : (minRequiredMyr / (rateToMyr > 0 ? rateToMyr : 1.0));
    final int displayMin = minRequiredInPreferred.round();

    // Check if entered amount is below minimum (accounting for integer display rounding)
    final bool isBelowMin =
        parsed < displayMin && parsed < minRequiredInPreferred;

    if (isBelowMin) {
      final isMultiple = rec.matchedDestinations.length > 1;
      final destNames = rec.matchedDestinations.isNotEmpty
          ? rec.matchedDestinations.join(', ')
          : _uiState.selectedDestinations.join(', ');
      final daysText = '$days ${days > 1 ? "days" : "day"}';

      if (preferredCurrency == 'MYR') {
        final formattedMin = displayMin.toString();
        if (isMultiple) {
          return 'Minimum budget for your selected destinations(s) is RM $formattedMin';
        } else if (destNames.isNotEmpty) {
          return 'Minimum budget for $destNames is RM $formattedMin';
        } else {
          return 'Minimum budget required is RM $formattedMin';
        }
      } else {
        final formattedMin = displayMin.toString();
        if (isMultiple) {
          return 'Minimum budget for your selected destinations(s) is $preferredCurrency $formattedMin';
        } else if (destNames.isNotEmpty) {
          return 'Minimum budget for $destNames is $preferredCurrency $formattedMin';
        } else {
          return 'Minimum budget required is $preferredCurrency $formattedMin';
        }
      }
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
    final minDate = start;
    final maxDate = end;

    final updatedArrivals = _uiState.arrivals.map((arr) {
      if (arr.date.trim().isEmpty) {
        return arr.copyWith(date: startFormatted);
      }
      final parsed = DateTime.tryParse(arr.date.trim());
      if (parsed == null ||
          parsed.isBefore(minDate) ||
          parsed.isAfter(maxDate)) {
        return arr.copyWith(date: startFormatted);
      }
      return arr;
    }).toList();

    final updatedDepartures = _uiState.departures.map((dep) {
      if (dep.date.trim().isEmpty) {
        return dep.copyWith(date: endFormatted);
      }
      final parsed = DateTime.tryParse(dep.date.trim());
      if (parsed == null ||
          parsed.isBefore(minDate) ||
          parsed.isAfter(maxDate)) {
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
    final isForeign = _uiState.preferredCurrency.trim().toUpperCase() != 'MYR';

    final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
    final updatedDepartures = List<TransitPoint>.from(_uiState.departures);

    if (isForeign) {
      // In Foreign mode:
      // arrivals[0] = Start Arrival (flight landing in Malaysia)
      // arrivals[1..N] = Transit Arrivals (destination of each transit)
      // departures[0..N-1] = Transit Departures (origin of each transit)
      // departures.last = End Departure (flight leaving Malaysia)
      //
      // If the user already entered End Departure (departures.last), it must be PRESERVED at departures.last!
      // The new transit departure must be inserted BEFORE departures.last (i.e. at departures.length - 1).
      final prevPoint = _uiState.arrivals.isNotEmpty
          ? _uiState.arrivals.last
          : null;
      final transitType = prevPoint?.type.isNotEmpty == true
          ? prevPoint!.type
          : 'Flight';
      final prevDate = prevPoint?.date.isNotEmpty == true
          ? prevPoint!.date
          : defaultArrivalDate;
      final prevTime = prevPoint?.time.isNotEmpty == true
          ? prevPoint!.time
          : '09:00 AM';
      // Default the new transit departure to 1 hour after the previous arrival
      final shifted = TransitScheduleHelper.calculateArrivalDateTime(
        departureDate: prevDate,
        departureTimeStr: prevTime,
        minutesToAdd: 60,
      );
      final transitDate = shifted['date'] as String;
      final transitTime = shifted['time'] as String;

      final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
        transitType: transitType,
        fromLocation: '',
        toLocation: '',
        selectedDestinations: _uiState.selectedDestinations,
      );
      final calculated = TransitScheduleHelper.calculateArrivalDateTime(
        departureDate: transitDate,
        departureTimeStr: transitTime,
        minutesToAdd: durationMin,
      );
      final transitArrivalDate = calculated['date'] as String;
      final transitArrivalTime = calculated['time'] as String;

      final newTransitDeparture = TransitPoint(
        id: 'dep_$now',
        location: '',
        time: transitTime,
        type: transitType,
        date: transitDate,
      );
      final newTransitArrival = TransitPoint(
        id: 'arr_$now',
        location: '',
        time: transitArrivalTime,
        type: transitType,
        date: transitArrivalDate,
      );

      if (updatedDepartures.isNotEmpty) {
        // Insert before End Departure so the user's End Departure is preserved as departures.last!
        updatedDepartures.insert(
          updatedDepartures.length - 1,
          newTransitDeparture,
        );
      } else {
        updatedDepartures.add(newTransitDeparture);
      }
      updatedArrivals.add(newTransitArrival);
    } else {
      // Local Malaysian mode:
      // When transitCount == 1: START is Leg 0. Adding a leg creates END (Leg 1).
      // When transitCount >= 2: START is Leg 0, END is Leg (length - 1).
      // Adding a transit adds an INTERMEDIATE transit before END!
      if (updatedDepartures.length <= 1) {
        final prevDep = updatedDepartures.isNotEmpty
            ? updatedDepartures.first
            : null;
        final transitType = prevDep?.type.isNotEmpty == true
            ? prevDep!.type
            : 'Train';
        final transitDate = defaultDepartureDate.isNotEmpty
            ? defaultDepartureDate
            : (prevDep?.date.isNotEmpty == true
                  ? prevDep!.date
                  : defaultArrivalDate);

        final newDep = TransitPoint(
          id: 'dep_$now',
          location: '',
          time: '09:00 PM',
          type: transitType,
          date: transitDate,
        );
        final newArr = TransitPoint(
          id: 'arr_$now',
          location: '',
          time: '11:00 PM',
          type: transitType,
          date: transitDate,
        );
        updatedArrivals.add(newArr);
        updatedDepartures.add(newDep);
      } else {
        // Insert intermediate transit before the END leg
        final prevArrival = updatedArrivals[updatedArrivals.length - 2];
        final transitType = prevArrival.type.isNotEmpty
            ? prevArrival.type
            : 'Train';
        final prevDate = prevArrival.date.isNotEmpty
            ? prevArrival.date
            : defaultArrivalDate;
        final prevTime = prevArrival.time.isNotEmpty
            ? prevArrival.time
            : '09:00 AM';
        // Default the new transit departure to 1 hour after the previous arrival
        final shifted = TransitScheduleHelper.calculateArrivalDateTime(
          departureDate: prevDate,
          departureTimeStr: prevTime,
          minutesToAdd: 60,
        );
        final transitDate = shifted['date'] as String;
        final transitTime = shifted['time'] as String;

        final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
          transitType: transitType,
          fromLocation: '',
          toLocation: '',
          selectedDestinations: _uiState.selectedDestinations,
        );
        final calculated = TransitScheduleHelper.calculateArrivalDateTime(
          departureDate: transitDate,
          departureTimeStr: transitTime,
          minutesToAdd: durationMin,
        );

        final newDep = TransitPoint(
          id: 'dep_$now',
          location: '',
          time: transitTime,
          type: transitType,
          date: transitDate,
        );
        final newArr = TransitPoint(
          id: 'arr_$now',
          location: '',
          time: calculated['time'] as String,
          type: transitType,
          date: calculated['date'] as String,
        );
        updatedDepartures.insert(updatedDepartures.length - 1, newDep);
        updatedArrivals.insert(updatedArrivals.length - 1, newArr);
      }
    }

    _uiState = _uiState.copyWith(
      arrivals: updatedArrivals,
      departures: updatedDepartures,
    );
    notifyListeners();
  }

  void removeTransitLeg(int index) {
    final isForeign = _uiState.preferredCurrency.trim().toUpperCase() != 'MYR';
    final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
    final updatedDepartures = List<TransitPoint>.from(_uiState.departures);

    if (isForeign) {
      // In Foreign mode:
      // index is the transit arrival index (1, 2, ...).
      // Corresponding transit departure is at index - 1 (0, 1, ...).
      // departures.last is the End Departure and must NEVER be deleted when removing an intermediate transit!
      final arrivalIndex = index;
      final departureIndex = index - 1;

      if (updatedArrivals.length > 1 &&
          arrivalIndex >= 1 &&
          arrivalIndex < updatedArrivals.length) {
        updatedArrivals.removeAt(arrivalIndex);
      }
      if (updatedDepartures.length > 1 &&
          departureIndex >= 0 &&
          departureIndex < updatedDepartures.length - 1) {
        updatedDepartures.removeAt(departureIndex);
      }
    } else {
      // Local Malaysian mode: Leg index is identical in arrivals and departures
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
      ..add(
        TransitPoint(
          id: newId,
          location: '',
          time: '09:00 AM',
          type: 'Flight',
          date: defaultDate,
        ),
      );
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
      _uiState = _uiState.copyWith(arrivals: updated, clearTransitError: true);
      notifyListeners();
    }
  }

  void updateArrivalTime(int index, String time) {
    if (index >= 0 && index < _uiState.arrivals.length) {
      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      String effectiveTime = time;
      String effectiveDate = updatedArrivals[index].date;

      // AUTOMATIC CHECK: If this is Transit 2+ arrival, check against Transit 1 departure + travel duration
      if (index > 0 && index - 1 < _uiState.departures.length) {
        final prevDep = _uiState.departures[index - 1];
        final curArr = updatedArrivals[index];
        final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
          transitType: curArr.type.isNotEmpty ? curArr.type : prevDep.type,
          fromLocation: prevDep.location,
          toLocation: curArr.location,
          selectedDestinations: _uiState.selectedDestinations,
        );
        final depDate = prevDep.date.isNotEmpty
            ? prevDep.date
            : (_uiState.startDate?.toLocal().toString().split(' ')[0] ??
                  DateTime.now().toLocal().toString().split(' ')[0]);
        final calculated = TransitScheduleHelper.calculateArrivalDateTime(
          departureDate: depDate,
          departureTimeStr: prevDep.time,
          minutesToAdd: durationMin,
        );
        final minArrDate = calculated['date'] as String;
        final minArrTime = calculated['time'] as String;

        final curArrDateStr = curArr.date.isNotEmpty ? curArr.date : minArrDate;
        final arrD = DateTime.tryParse(curArrDateStr);
        final minD = DateTime.tryParse(minArrDate);

        bool isInvalid = false;
        if (arrD != null && minD != null) {
          final aDay = DateTime(arrD.year, arrD.month, arrD.day);
          final mDay = DateTime(minD.year, minD.month, minD.day);
          if (aDay.isBefore(mDay)) {
            isInvalid = true;
          } else if (aDay.isAtSameMomentAs(mDay)) {
            final pickedMin = _parseTimeToMinutes(time);
            final minMin = _parseTimeToMinutes(minArrTime);
            if (pickedMin != null && minMin != null && pickedMin < minMin) {
              isInvalid = true;
            }
          }
        } else {
          final pickedMin = _parseTimeToMinutes(time);
          final minMin = _parseTimeToMinutes(minArrTime);
          if (pickedMin != null && minMin != null && pickedMin < minMin) {
            isInvalid = true;
          }
        }

        // AUTO-SYNC: If user's manual time is invalid ("发现不对"), automatically auto-sync arrival!
        if (isInvalid) {
          effectiveTime = minArrTime;
          effectiveDate = minArrDate;
          if (curArr.type.toLowerCase() == 'bus' ||
              prevDep.type.toLowerCase() == 'bus') {
            syncLegArrivalWithDepartureDurationAsync(index);
          }
        }
      }

      updatedArrivals[index] = updatedArrivals[index].copyWith(
        time: effectiveTime,
        date: effectiveDate,
      );

      final updatedDepartures = List<TransitPoint>.from(_uiState.departures);
      if (index < updatedDepartures.length) {
        final curArr = updatedArrivals[index];
        final curDep = updatedDepartures[index];
        if (curArr.date.isNotEmpty && curArr.date == curDep.date) {
          final arrMin = _parseTimeToMinutes(effectiveTime);
          final depMin = _parseTimeToMinutes(curDep.time);
          if (arrMin != null && depMin != null && depMin < arrMin) {
            updatedDepartures[index] = curDep.copyWith(time: effectiveTime);
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
      String effectiveDate = date;
      String effectiveTime = updatedArrivals[index].time;

      // AUTOMATIC CHECK: If this is Transit 2+ arrival, check against Transit 1 departure + travel duration
      if (index > 0 && index - 1 < _uiState.departures.length) {
        final prevDep = _uiState.departures[index - 1];
        final curArr = updatedArrivals[index];
        final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
          transitType: curArr.type.isNotEmpty ? curArr.type : prevDep.type,
          fromLocation: prevDep.location,
          toLocation: curArr.location,
          selectedDestinations: _uiState.selectedDestinations,
        );
        final depDate = prevDep.date.isNotEmpty
            ? prevDep.date
            : (_uiState.startDate?.toLocal().toString().split(' ')[0] ??
                  DateTime.now().toLocal().toString().split(' ')[0]);
        final calculated = TransitScheduleHelper.calculateArrivalDateTime(
          departureDate: depDate,
          departureTimeStr: prevDep.time,
          minutesToAdd: durationMin,
        );
        final minArrDate = calculated['date'] as String;
        final minArrTime = calculated['time'] as String;
        final chosenD = DateTime.tryParse(date);
        final minD = DateTime.tryParse(minArrDate);
        if (chosenD != null && minD != null) {
          final cDay = DateTime(chosenD.year, chosenD.month, chosenD.day);
          final mDay = DateTime(minD.year, minD.month, minD.day);
          if (cDay.isBefore(mDay)) {
            effectiveDate = minArrDate;
            effectiveTime = minArrTime;
          } else if (cDay.isAtSameMomentAs(mDay)) {
            final curMin = _parseTimeToMinutes(effectiveTime);
            final minMin = _parseTimeToMinutes(minArrTime);
            if (curMin != null && minMin != null && curMin < minMin) {
              effectiveTime = minArrTime;
            }
          }
        }
      }

      updatedArrivals[index] = updatedArrivals[index].copyWith(
        date: effectiveDate,
        time: effectiveTime,
      );

      final updatedDepartures = List<TransitPoint>.from(_uiState.departures);
      if (index < updatedDepartures.length && effectiveDate.isNotEmpty) {
        final curDep = updatedDepartures[index];
        if (curDep.date.isNotEmpty) {
          final arrD = DateTime.tryParse(effectiveDate);
          final depD = DateTime.tryParse(curDep.date);
          if (arrD != null && depD != null && depD.isBefore(arrD)) {
            updatedDepartures[index] = curDep.copyWith(date: effectiveDate);
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
      ..add(
        TransitPoint(
          id: newId,
          location: '',
          time: '09:00 PM',
          type: 'Flight',
          date: defaultDate,
        ),
      );
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

      final isForeign =
          _uiState.preferredCurrency.trim().toUpperCase() != 'MYR';
      final targetArrIndex = isForeign ? index + 1 : index;

      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      if (targetArrIndex < updatedArrivals.length && date.isNotEmpty) {
        final curDep = updatedDepartures[index];
        final nextArr = updatedArrivals[targetArrIndex];
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
        updatedArrivals[targetArrIndex] = nextArr.copyWith(
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

      final isForeign =
          _uiState.preferredCurrency.trim().toUpperCase() != 'MYR';
      final targetArrIndex = isForeign ? index + 1 : index;

      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      if (targetArrIndex < updatedArrivals.length) {
        final nextArr = updatedArrivals[targetArrIndex];
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
        updatedArrivals[targetArrIndex] = nextArr.copyWith(
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
      var updatedArr = updated[index].copyWith(
        type: effectiveType,
        location: location,
      );

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

      if (effectiveType.toLowerCase() == 'bus' && index > 0) {
        syncLegArrivalWithDepartureDurationAsync(index);
      }
    }
  }

  void updateDepartureHub(
    int index, {
    required String type,
    required String location,
  }) {
    if (index >= 0 && index < _uiState.departures.length) {
      final updatedDepartures = List<TransitPoint>.from(_uiState.departures);
      updatedDepartures[index] = updatedDepartures[index].copyWith(
        type: type,
        location: location,
      );

      final isForeign =
          _uiState.preferredCurrency.trim().toUpperCase() != 'MYR';
      final targetArrIndex = isForeign ? index + 1 : index;

      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      if (targetArrIndex < updatedArrivals.length) {
        final nextArr = updatedArrivals[targetArrIndex];
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

        updatedArrivals[targetArrIndex] = nextArr.copyWith(
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

      if (type.toLowerCase() == 'bus' &&
          targetArrIndex < _uiState.arrivals.length) {
        syncLegArrivalWithDepartureDurationAsync(targetArrIndex);
      }
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

    // Recalculate arrival times for dependent legs when type changes
    for (
      int i = 1;
      i < updatedArrivals.length && i - 1 < updatedDepartures.length;
      i++
    ) {
      final prevDep = updatedDepartures[i - 1];
      final curArr = updatedArrivals[i];
      final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
        transitType: curArr.type,
        fromLocation: prevDep.location,
        toLocation: curArr.location,
        selectedDestinations: _uiState.selectedDestinations,
      );
      final depDate = prevDep.date.isNotEmpty
          ? prevDep.date
          : (_uiState.startDate?.toLocal().toString().split(' ')[0] ??
                DateTime.now().toLocal().toString().split(' ')[0]);
      final calc = TransitScheduleHelper.calculateArrivalDateTime(
        departureDate: depDate,
        departureTimeStr: prevDep.time,
        minutesToAdd: durationMin,
      );
      updatedArrivals[i] = curArr.copyWith(
        time: calc['time'] as String,
        date: calc['date'] as String,
      );
    }

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
      _uiState = _uiState.copyWith(
        departures: updated,
        clearTransitError: true,
      );
      notifyListeners();
    }
  }

  void updateDepartureTime(int index, String time) {
    if (index >= 0 && index < _uiState.departures.length) {
      final updatedDepartures = List<TransitPoint>.from(_uiState.departures);
      updatedDepartures[index] = updatedDepartures[index].copyWith(time: time);

      final isForeign =
          _uiState.preferredCurrency.trim().toUpperCase() != 'MYR';
      final targetArrIndex = isForeign ? index + 1 : index;

      final updatedArrivals = List<TransitPoint>.from(_uiState.arrivals);
      if (targetArrIndex < updatedArrivals.length) {
        final curDep = updatedDepartures[index];
        final nextArr = updatedArrivals[targetArrIndex];

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

        updatedArrivals[targetArrIndex] = nextArr.copyWith(
          time: calculated['time'] as String,
          date: calculated['date'] as String,
        );
      }

      _uiState = _uiState.copyWith(
        departures: updatedDepartures,
        arrivals: updatedArrivals,
      );
      notifyListeners();

      if (updatedDepartures[index].type.toLowerCase() == 'bus' &&
          targetArrIndex < _uiState.arrivals.length) {
        syncLegArrivalWithDepartureDurationAsync(targetArrIndex);
      }
    }
  }

  void syncLegArrivalWithDepartureDuration(int legIndex) {
    final isForeign = _uiState.preferredCurrency.trim().toUpperCase() != 'MYR';
    final depIndex = isForeign ? legIndex - 1 : legIndex;
    if (legIndex >= 0 &&
        legIndex < _uiState.arrivals.length &&
        depIndex >= 0 &&
        depIndex < _uiState.departures.length) {
      final prevDep = _uiState.departures[depIndex];
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

  Future<void> syncLegArrivalWithDepartureDurationAsync(int legIndex) async {
    final isForeign = _uiState.preferredCurrency.trim().toUpperCase() != 'MYR';
    final depIndex = isForeign ? legIndex - 1 : legIndex;
    if (legIndex >= 0 &&
        legIndex < _uiState.arrivals.length &&
        depIndex >= 0 &&
        depIndex < _uiState.departures.length) {
      final prevDep = _uiState.departures[depIndex];
      final curArr = _uiState.arrivals[legIndex];
      final durationMin =
          await TransitScheduleHelper.getEstimatedDurationMinutesAsync(
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

  void updateHotelCheckInDate(int index, String date) {
    if (index >= 0 && index < _uiState.hotels.length) {
      final updated = List<HotelStay>.from(_uiState.hotels);
      updated[index] = updated[index].copyWith(checkInDate: date);
      _uiState = _uiState.copyWith(hotels: updated);
      notifyListeners();
    }
  }

  void updateHotelCheckOutDate(int index, String date) {
    if (index >= 0 && index < _uiState.hotels.length) {
      final updated = List<HotelStay>.from(_uiState.hotels);
      updated[index] = updated[index].copyWith(checkOutDate: date);
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

  DateTime? _parsePointDateTime(TransitPoint point) {
    final trimmedDate = point.date.trim();
    if (trimmedDate.isEmpty) return null;
    final parsedDate = DateTime.tryParse(trimmedDate);
    if (parsedDate == null) return null;
    final minutes = _parseTimeToMinutes(point.time);
    if (minutes == null) return parsedDate;
    return DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  void clearTransitError() {
    if (_uiState.transitError != null) {
      _uiState = _uiState.copyWith(clearTransitError: true);
      notifyListeners();
    }
  }

  String? validateTransit() {
    final arrivals = _uiState.arrivals;
    final departures = _uiState.departures;
    final isForeign = _uiState.preferredCurrency.trim().toUpperCase() != 'MYR';
    final transitCount = arrivals.length > departures.length
        ? arrivals.length
        : departures.length;

    final hasAnyTransitLocation =
        arrivals.any((a) => a.location.trim().isNotEmpty) ||
        departures.any((d) => d.location.trim().isNotEmpty);

    // If single leg and no transit locations are specified, transit is completely optional
    if (transitCount <= 1 && !hasAnyTransitLocation) {
      return null;
    }

    // 1. Destinations check: If transit is specified, destination states must be selected first
    if (hasAnyTransitLocation && _uiState.selectedDestinations.isEmpty) {
      return 'Please select destination state(s) first before entering transit details';
    }

    // 2. Inappropriate / Explicit word check
    for (int i = 0; i < arrivals.length; i++) {
      final loc = arrivals[i].location.trim();
      if (loc.isNotEmpty) {
        final err = validateExplicitWord(loc);
        if (err != null) return err;
      }
    }

    for (int i = 0; i < departures.length; i++) {
      final loc = departures[i].location.trim();
      if (loc.isNotEmpty) {
        final err = validateExplicitWord(loc);
        if (err != null) return err;
      }
    }

    // 3. Completeness & Empty location check
    if (transitCount > 1) {
      if (isForeign) {
        // Foreign mode
        if (arrivals.isEmpty || arrivals[0].location.trim().isEmpty) {
          return 'Please select an arrival location for Start Arrival';
        }
        for (int i = 0; i < transitCount - 1; i++) {
          if (i >= departures.length || departures[i].location.trim().isEmpty) {
            return 'Please select a departure location for Transit ${i + 1}';
          }
          if (i + 1 >= arrivals.length ||
              arrivals[i + 1].location.trim().isEmpty) {
            return 'Please select an arrival location for Transit ${i + 1}';
          }
        }
        if (transitCount - 1 >= departures.length ||
            departures[transitCount - 1].location.trim().isEmpty) {
          return 'Please select a departure location for End Departure';
        }
      } else {
        // Local Malaysian mode
        if (departures.isEmpty || departures[0].location.trim().isEmpty) {
          return 'Please select a departure location for Start Departure';
        }
        if (arrivals.isEmpty || arrivals[0].location.trim().isEmpty) {
          return 'Please select an arrival location for Start Arrival';
        }
        for (int i = 1; i < transitCount - 1; i++) {
          if (i >= departures.length || departures[i].location.trim().isEmpty) {
            return 'Please select a departure location for Transit $i';
          }
          if (i >= arrivals.length || arrivals[i].location.trim().isEmpty) {
            return 'Please select an arrival location for Transit $i';
          }
        }
        if (transitCount - 1 >= departures.length ||
            departures[transitCount - 1].location.trim().isEmpty) {
          return 'Please select a departure location for End Departure';
        }
        if (transitCount - 1 >= arrivals.length ||
            arrivals[transitCount - 1].location.trim().isEmpty) {
          return 'Please select an arrival location for End Arrival';
        }
      }
    } else {
      // transitCount == 1
      if (isForeign) {
        final hasArr =
            arrivals.isNotEmpty && arrivals[0].location.trim().isNotEmpty;
        final hasDep =
            departures.isNotEmpty && departures[0].location.trim().isNotEmpty;
        if (hasArr && !hasDep) {
          return 'Please select a departure location for End';
        } else if (!hasArr && hasDep) {
          return 'Please select an arrival location for Start';
        }
      } else {
        final hasDep =
            departures.isNotEmpty && departures[0].location.trim().isNotEmpty;
        final hasArr =
            arrivals.isNotEmpty && arrivals[0].location.trim().isNotEmpty;
        if (hasDep && !hasArr) {
          return 'Please select an arrival location for Start';
        } else if (!hasDep && hasArr) {
          return 'Please select a departure location for Start';
        }
      }
    }

    // 4. Same origin and destination check
    if (isForeign) {
      for (int i = 0; i < transitCount - 1; i++) {
        if (i < departures.length && i + 1 < arrivals.length) {
          final depLoc = departures[i].location.trim().toLowerCase();
          final arrLoc = arrivals[i + 1].location.trim().toLowerCase();
          if (depLoc.isNotEmpty && arrLoc.isNotEmpty && depLoc == arrLoc) {
            return 'Transit ${i + 1} departure and arrival locations cannot be the same (${departures[i].location})';
          }
        }
      }
    } else {
      for (int i = 0; i < transitCount; i++) {
        if (i < departures.length && i < arrivals.length) {
          final depLoc = departures[i].location.trim().toLowerCase();
          final arrLoc = arrivals[i].location.trim().toLowerCase();
          if (depLoc.isNotEmpty && arrLoc.isNotEmpty && depLoc == arrLoc) {
            final legName = i == 0
                ? 'Start'
                : (i == transitCount - 1 && transitCount > 1
                      ? 'End'
                      : 'Transit $i');
            return '$legName departure and arrival locations cannot be the same (${departures[i].location})';
          }
        }
      }
    }

    // 5. Trip Date Range Checks (within startDate and endDate)
    if (_uiState.startDate != null && _uiState.endDate != null) {
      final minDate = DateTime(
        _uiState.startDate!.year,
        _uiState.startDate!.month,
        _uiState.startDate!.day,
      );
      final maxDate = DateTime(
        _uiState.endDate!.year,
        _uiState.endDate!.month,
        _uiState.endDate!.day,
      );
      final minStr = minDate.toLocal().toString().split(' ')[0];
      final maxStr = maxDate.toLocal().toString().split(' ')[0];

      for (int i = 0; i < arrivals.length; i++) {
        final arr = arrivals[i];
        if (arr.date.trim().isNotEmpty) {
          final parsed = DateTime.tryParse(arr.date.trim());
          if (parsed != null) {
            final pDay = DateTime(parsed.year, parsed.month, parsed.day);
            if (pDay.isBefore(minDate) || pDay.isAfter(maxDate)) {
              final label = isForeign
                  ? (i == 0 ? 'Start arrival' : 'Transit $i arrival')
                  : (i == 0
                        ? 'Start arrival'
                        : (i == arrivals.length - 1 && transitCount > 1
                              ? 'End arrival'
                              : 'Transit $i arrival'));
              return '$label date must be between $minStr and $maxStr';
            }
          }
        }
      }

      for (int i = 0; i < departures.length; i++) {
        final dep = departures[i];
        if (dep.date.trim().isNotEmpty) {
          final parsed = DateTime.tryParse(dep.date.trim());
          if (parsed != null) {
            final pDay = DateTime(parsed.year, parsed.month, parsed.day);
            if (pDay.isBefore(minDate) || pDay.isAfter(maxDate)) {
              final label = isForeign
                  ? (i == departures.length - 1
                        ? 'End departure'
                        : 'Transit ${i + 1} departure')
                  : (i == 0
                        ? 'Start departure'
                        : (i == departures.length - 1 && transitCount > 1
                              ? 'End departure'
                              : 'Transit $i departure'));
              return '$label date must be between $minStr and $maxStr';
            }
          }
        }
      }
    }

    // 6. Chronological Date & Time Sequencing Checks
    if (isForeign) {
      final startArrDT = arrivals.isNotEmpty
          ? _parsePointDateTime(arrivals[0])
          : null;
      if (transitCount == 1) {
        final endDepDT = departures.isNotEmpty
            ? _parsePointDateTime(departures[0])
            : null;
        if (startArrDT != null &&
            endDepDT != null &&
            endDepDT.isBefore(startArrDT)) {
          return 'End departure cannot be earlier than start arrival in Malaysia';
        }
      } else {
        DateTime? previousArrivalDT = startArrDT;
        for (int i = 0; i < transitCount - 1; i++) {
          final depDT = i < departures.length
              ? _parsePointDateTime(departures[i])
              : null;
          final arrDT = i + 1 < arrivals.length
              ? _parsePointDateTime(arrivals[i + 1])
              : null;

          if (depDT != null &&
              previousArrivalDT != null &&
              depDT.isBefore(previousArrivalDT)) {
            return 'Transit ${i + 1} departure cannot be earlier than previous arrival';
          }
          if (arrDT != null && depDT != null && arrDT.isBefore(depDT)) {
            return 'Transit ${i + 1} arrival cannot be earlier than departure';
          }
          if (arrDT != null) {
            previousArrivalDT = arrDT;
          }
        }

        if (transitCount - 1 < departures.length) {
          final finalDepDT = _parsePointDateTime(departures[transitCount - 1]);
          if (finalDepDT != null &&
              previousArrivalDT != null &&
              finalDepDT.isBefore(previousArrivalDT)) {
            return 'End departure cannot be earlier than previous transit arrival';
          }
        }
      }
    } else {
      // Local Malaysian flow
      final startDepDT = departures.isNotEmpty
          ? _parsePointDateTime(departures[0])
          : null;
      final startArrDT = arrivals.isNotEmpty
          ? _parsePointDateTime(arrivals[0])
          : null;
      if (startDepDT != null &&
          startArrDT != null &&
          startArrDT.isBefore(startDepDT)) {
        return 'Start arrival cannot be earlier than start departure';
      }

      DateTime? previousArrivalDT = startArrDT;
      for (int i = 1; i < transitCount - 1; i++) {
        final depDT = i < departures.length
            ? _parsePointDateTime(departures[i])
            : null;
        final arrDT = i < arrivals.length
            ? _parsePointDateTime(arrivals[i])
            : null;

        if (depDT != null &&
            previousArrivalDT != null &&
            depDT.isBefore(previousArrivalDT)) {
          return 'Transit $i departure cannot be earlier than previous arrival';
        }
        if (arrDT != null && depDT != null && arrDT.isBefore(depDT)) {
          return 'Transit $i arrival cannot be earlier than departure';
        }
        if (arrDT != null) {
          previousArrivalDT = arrDT;
        }
      }

      if (transitCount > 1 &&
          transitCount - 1 < departures.length &&
          transitCount - 1 < arrivals.length) {
        final endDepDT = _parsePointDateTime(departures[transitCount - 1]);
        final endArrDT = _parsePointDateTime(arrivals[transitCount - 1]);

        if (endDepDT != null &&
            previousArrivalDT != null &&
            endDepDT.isBefore(previousArrivalDT)) {
          return 'End departure cannot be earlier than previous transit arrival';
        }
        if (endDepDT != null &&
            endArrDT != null &&
            endArrDT.isBefore(endDepDT)) {
          return 'End arrival cannot be earlier than end departure';
        }
      }
    }

    return null;
  }

  String? validateTransitDates() => validateTransit();

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
    final String? transitError = validateTransit();
    final String? hotelError = validateHotels();

    if (transitError != null) {
      _uiState = _uiState.copyWith(transitError: transitError);
      notifyListeners();
    } else if (_uiState.transitError != null) {
      _uiState = _uiState.copyWith(clearTransitError: true);
      notifyListeners();
    }

    if (destinationError != null ||
        dateError != null ||
        budgetError != null ||
        transitError != null ||
        hotelError != null) {
      return destinationError ??
          dateError ??
          budgetError ??
          transitError ??
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

  const TravelInformationInputViewModelScope({super.key, required this.child});

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
