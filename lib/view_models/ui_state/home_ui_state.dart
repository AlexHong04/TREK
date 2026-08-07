import 'ui_status.dart';

class HomeUiState {
  final UiStatus status;
  final String userName;
  final bool hasPlan;
  final String? errorMessage;

  const HomeUiState({
    this.status = UiStatus.initial,
    this.userName = 'Alex',
    this.hasPlan = false,
    this.errorMessage,
  });

  HomeUiState copyWith({
    UiStatus? status,
    String? userName,
    bool? hasPlan,
    String? errorMessage,
  }) {
    return HomeUiState(
      status: status ?? this.status,
      userName: userName ?? this.userName,
      hasPlan: hasPlan ?? this.hasPlan,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
