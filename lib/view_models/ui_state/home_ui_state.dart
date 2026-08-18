class HomeUiState {
  final bool isLoading;
  final String? userName;
  final String email;
  final bool hasPlan;
  final String? errorMessage;

  const HomeUiState({
    this.isLoading = false,
    this.userName,
    required this.email,
    this.hasPlan = false,
    this.errorMessage,
  });

  String get displayName =>
      userName?.trim().isNotEmpty == true ? userName! : email;

  HomeUiState copyWith({
    bool? isLoading,
    String? userName,
    String? email,
    bool? hasPlan,
    String? errorMessage,
  }) {
    return HomeUiState(
      isLoading: isLoading ?? this.isLoading,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      hasPlan: hasPlan ?? this.hasPlan,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}