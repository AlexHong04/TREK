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
  final List<DateTimeRange> unavailableDateRanges;
  final String arrivalLocation;
  final String arrivalTime;
  final String departureLocation;
  final String departureTime;
  final String hotelLocation;
  final String hotelCheckInTime;
  final String hotelCheckOutTime;

  const TravelInformationUiState({
    this.isLoading = false,
    this.selectedPreference,
    this.selectedEmergencyFund,
    this.errorMessage,
    this.selectedDestinations = const [],
    this.wishlistItems = const [],
    this.suggestions = const [],
    this.isSearchingSuggestions = false,
    this.unavailableDateRanges = const [],
    this.arrivalLocation = '',
    this.arrivalTime = '09:00 AM',
    this.departureLocation = '',
    this.departureTime = '06:00 PM',
    this.hotelLocation = '',
    this.hotelCheckInTime = '03:00 PM',
    this.hotelCheckOutTime = '12:00 PM',
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
    List<DateTimeRange>? unavailableDateRanges,
    String? arrivalLocation,
    String? arrivalTime,
    String? departureLocation,
    String? departureTime,
    String? hotelLocation,
    String? hotelCheckInTime,
    String? hotelCheckOutTime,
  }) {
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
      unavailableDateRanges:
          unavailableDateRanges ?? this.unavailableDateRanges,
      arrivalLocation: arrivalLocation ?? this.arrivalLocation,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureLocation: departureLocation ?? this.departureLocation,
      departureTime: departureTime ?? this.departureTime,
      hotelLocation: hotelLocation ?? this.hotelLocation,
      hotelCheckInTime: hotelCheckInTime ?? this.hotelCheckInTime,
      hotelCheckOutTime: hotelCheckOutTime ?? this.hotelCheckOutTime,
    );
  }
}

class PreferenceItemModel {
  PreferenceItemModel({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
