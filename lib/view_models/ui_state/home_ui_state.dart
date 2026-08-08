class HomeUiState {
  final bool isLoading;
  final String userName;
  final bool hasPlan;
  final String? errorMessage;

  const HomeUiState({
    this.isLoading = false,
    this.userName = 'Alex',
    this.hasPlan = false,
    this.errorMessage,
  });

  HomeUiState copyWith({
    bool? isLoading,
    String? userName,
    bool? hasPlan,
    String? errorMessage,
  }) {
    return HomeUiState(
      isLoading: isLoading ?? this.isLoading,
      userName: userName ?? this.userName,
      hasPlan: hasPlan ?? this.hasPlan,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
