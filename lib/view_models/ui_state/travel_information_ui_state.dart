import 'package:flutter/material.dart';

class TravelInformationUiState {
  final bool isLoading;
  final String? selectedPreference;
  final String? selectedEmergencyFund;
  final String? errorMessage;
  final List<String> selectedDestinations;
  final List<String> wishlistItems;
  final List<String> suggestions;
  final bool isSearchingSuggestions;
  final List<String> transitSuggestions;
  final bool isSearchingTransitSuggestions;
  final String? activeTransitField;
  final List<String> hotelSuggestions;
  final bool isSearchingHotelSuggestions;
  final String? activeHotelField;
  final List<DateTimeRange> unavailableDateRanges;
  final List<TransitPoint> arrivals;
  final List<TransitPoint> departures;
  final List<HotelStay> hotels;

  String get arrivalLocation =>
      arrivals.isNotEmpty ? arrivals.first.location : '';
  String get arrivalTime =>
      arrivals.isNotEmpty ? arrivals.first.time : '09:00 AM';
  String get departureLocation =>
      departures.isNotEmpty ? departures.first.location : '';
  String get departureTime =>
      departures.isNotEmpty ? departures.first.time : '06:00 PM';
  String get hotelLocation => hotels.isNotEmpty ? hotels.first.location : '';
  String get hotelCheckInTime =>
      hotels.isNotEmpty ? hotels.first.checkInTime : '03:00 PM';
  String get hotelCheckOutTime =>
      hotels.isNotEmpty ? hotels.first.checkOutTime : '12:00 PM';

  const TravelInformationUiState({
    this.isLoading = false,
    this.selectedPreference,
    this.selectedEmergencyFund,
    this.errorMessage,
    this.selectedDestinations = const [],
    this.wishlistItems = const [],
    this.suggestions = const [],
    this.isSearchingSuggestions = false,
    this.transitSuggestions = const [],
    this.isSearchingTransitSuggestions = false,
    this.activeTransitField,
    this.hotelSuggestions = const [],
    this.isSearchingHotelSuggestions = false,
    this.activeHotelField,
    this.unavailableDateRanges = const [],
    this.arrivals = const [
      TransitPoint(id: 'arr_0', location: '', time: '09:00 AM'),
    ],
    this.departures = const [
      TransitPoint(id: 'dep_0', location: '', time: '06:00 PM'),
    ],
    this.hotels = const [
      HotelStay(
        id: 'hotel_0',
        location: '',
        checkInTime: '03:00 PM',
        checkOutTime: '12:00 PM',
      ),
    ],
  });

  TravelInformationUiState copyWith({
    bool? isLoading,
    String? selectedPreference,
    String? selectedEmergencyFund,
    String? errorMessage,
    List<String>? selectedDestinations,
    List<String>? wishlistItems,
    List<String>? suggestions,
    bool? isSearchingSuggestions,
    List<String>? transitSuggestions,
    bool? isSearchingTransitSuggestions,
    String? activeTransitField,
    bool clearActiveTransitField = false,
    List<String>? hotelSuggestions,
    bool? isSearchingHotelSuggestions,
    String? activeHotelField,
    bool clearActiveHotelField = false,
    List<DateTimeRange>? unavailableDateRanges,
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
  }) {
    List<TransitPoint>? resolvedArrivals = arrivals;
    if (resolvedArrivals == null &&
        (arrivalLocation != null || arrivalTime != null)) {
      final currentFirst = this.arrivals.isNotEmpty
          ? this.arrivals.first
          : const TransitPoint(id: 'arr_0');
      final updatedFirst = currentFirst.copyWith(
        location: arrivalLocation ?? currentFirst.location,
        time: arrivalTime ?? currentFirst.time,
      );
      resolvedArrivals = [
        updatedFirst,
        if (this.arrivals.length > 1) ...this.arrivals.sublist(1),
      ];
    }

    List<TransitPoint>? resolvedDepartures = departures;
    if (resolvedDepartures == null &&
        (departureLocation != null || departureTime != null)) {
      final currentFirst = this.departures.isNotEmpty
          ? this.departures.first
          : const TransitPoint(id: 'dep_0');
      final updatedFirst = currentFirst.copyWith(
        location: departureLocation ?? currentFirst.location,
        time: departureTime ?? currentFirst.time,
      );
      resolvedDepartures = [
        updatedFirst,
        if (this.departures.length > 1) ...this.departures.sublist(1),
      ];
    }

    List<HotelStay>? resolvedHotels = hotels;
    if (resolvedHotels == null &&
        (hotelLocation != null ||
            hotelCheckInTime != null ||
            hotelCheckOutTime != null)) {
      final currentFirst = this.hotels.isNotEmpty
          ? this.hotels.first
          : const HotelStay(id: 'hotel_0');
      final updatedFirst = currentFirst.copyWith(
        location: hotelLocation ?? currentFirst.location,
        checkInTime: hotelCheckInTime ?? currentFirst.checkInTime,
        checkOutTime: hotelCheckOutTime ?? currentFirst.checkOutTime,
      );
      resolvedHotels = [
        updatedFirst,
        if (this.hotels.length > 1) ...this.hotels.sublist(1),
      ];
    }

    return TravelInformationUiState(
      isLoading: isLoading ?? this.isLoading,
      selectedPreference: selectedPreference ?? this.selectedPreference,
      selectedEmergencyFund:
          selectedEmergencyFund ?? this.selectedEmergencyFund,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedDestinations: selectedDestinations ?? this.selectedDestinations,
      wishlistItems: wishlistItems ?? this.wishlistItems,
      suggestions: suggestions ?? this.suggestions,
      isSearchingSuggestions:
          isSearchingSuggestions ?? this.isSearchingSuggestions,
      transitSuggestions: transitSuggestions ?? this.transitSuggestions,
      isSearchingTransitSuggestions:
          isSearchingTransitSuggestions ?? this.isSearchingTransitSuggestions,
      activeTransitField: clearActiveTransitField
          ? null
          : (activeTransitField ?? this.activeTransitField),
      hotelSuggestions: hotelSuggestions ?? this.hotelSuggestions,
      isSearchingHotelSuggestions:
          isSearchingHotelSuggestions ?? this.isSearchingHotelSuggestions,
      activeHotelField: clearActiveHotelField
          ? null
          : (activeHotelField ?? this.activeHotelField),
      unavailableDateRanges:
          unavailableDateRanges ?? this.unavailableDateRanges,
      arrivals: resolvedArrivals ?? this.arrivals,
      departures: resolvedDepartures ?? this.departures,
      hotels: resolvedHotels ?? this.hotels,
    );
  }
}

class PreferenceItemModel {
  PreferenceItemModel({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class TransitPoint {
  final String id;
  final String location;
  final String time;

  const TransitPoint({
    required this.id,
    this.location = '',
    this.time = '09:00 AM',
  });

  TransitPoint copyWith({
    String? id,
    String? location,
    String? time,
  }) {
    return TransitPoint(
      id: id ?? this.id,
      location: location ?? this.location,
      time: time ?? this.time,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location': location,
      'time': time,
    };
  }

  factory TransitPoint.fromJson(Map<String, dynamic> json) {
    return TransitPoint(
      id: json['id'] as String? ?? '',
      location: json['location'] as String? ?? '',
      time: json['time'] as String? ?? '09:00 AM',
    );
  }
}

class HotelStay {
  final String id;
  final String location;
  final String checkInTime;
  final String checkOutTime;

  const HotelStay({
    required this.id,
    this.location = '',
    this.checkInTime = '03:00 PM',
    this.checkOutTime = '12:00 PM',
  });

  HotelStay copyWith({
    String? id,
    String? location,
    String? checkInTime,
    String? checkOutTime,
  }) {
    return HotelStay(
      id: id ?? this.id,
      location: location ?? this.location,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location': location,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
    };
  }

  factory HotelStay.fromJson(Map<String, dynamic> json) {
    return HotelStay(
      id: json['id'] as String? ?? '',
      location: json['location'] as String? ?? '',
      checkInTime: json['checkInTime'] as String? ?? '03:00 PM',
      checkOutTime: json['checkOutTime'] as String? ?? '12:00 PM',
    );
  }
}
