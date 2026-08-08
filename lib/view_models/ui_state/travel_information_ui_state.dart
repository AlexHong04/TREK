class TravelInformationUiState {
  final bool isLoading;
  final String? selectedPreference;
  final String? selectedEmergencyFund;
  final String? errorMessage;

  const TravelInformationUiState({
    this.isLoading = false,
    this.selectedPreference,
    this.selectedEmergencyFund,
    this.errorMessage,
  });

  TravelInformationUiState copyWith({
    bool? isLoading,
    String? selectedPreference,
    String? selectedEmergencyFund,
    String? errorMessage,
  }) {
    return TravelInformationUiState(
      isLoading: isLoading ?? this.isLoading,
      selectedPreference: selectedPreference ?? this.selectedPreference,
      selectedEmergencyFund:
          selectedEmergencyFund ?? this.selectedEmergencyFund,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
