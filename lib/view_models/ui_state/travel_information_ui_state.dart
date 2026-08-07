import 'ui_status.dart';

class TravelInformationUiState {
  final UiStatus status;
  final String? selectedPreference;
  final String? selectedEmergencyFund;
  final String? errorMessage;
  
  const TravelInformationUiState({
    this.status = UiStatus.initial,
    this.selectedPreference,
    this.selectedEmergencyFund,
    this.errorMessage,
  });

  TravelInformationUiState copyWith({
    UiStatus? status,
    String? selectedPreference,
    String? selectedEmergencyFund,
    String? errorMessage,
  }) {
    return TravelInformationUiState(
      status: status ?? this.status,
      selectedPreference: selectedPreference ?? this.selectedPreference,
      selectedEmergencyFund: selectedEmergencyFund ?? this.selectedEmergencyFund,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
