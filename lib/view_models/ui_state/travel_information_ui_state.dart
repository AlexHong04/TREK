import 'package:flutter/material.dart';

class TravelInformationUiState {
  final bool isLoading;
  final String? selectedPreference;
  final String? selectedEmergencyFund;
  final String? errorMessage;
  final List<String> wishlistItems;
  final List<String> suggestions;
  final bool isSearchingSuggestions;

  const TravelInformationUiState({
    this.isLoading = false,
    this.selectedPreference,
    this.selectedEmergencyFund,
    this.errorMessage,
    this.wishlistItems = const [],
    this.suggestions = const [],
    this.isSearchingSuggestions = false,
  });

  TravelInformationUiState copyWith({
    bool? isLoading,
    String? selectedPreference,
    String? selectedEmergencyFund,
    String? errorMessage,
    List<String>? wishlistItems,
    List<String>? suggestions,
    bool? isSearchingSuggestions,
  }) {
    return TravelInformationUiState(
      isLoading: isLoading ?? this.isLoading,
      selectedPreference: selectedPreference ?? this.selectedPreference,
      selectedEmergencyFund:
          selectedEmergencyFund ?? this.selectedEmergencyFund,
      errorMessage: errorMessage ?? this.errorMessage,
      wishlistItems: wishlistItems ?? this.wishlistItems,
      suggestions: suggestions ?? this.suggestions,
      isSearchingSuggestions:
          isSearchingSuggestions ?? this.isSearchingSuggestions,
    );
  }
}

class PreferenceItemModel {
  PreferenceItemModel({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
