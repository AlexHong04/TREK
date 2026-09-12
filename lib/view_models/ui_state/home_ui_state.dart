import '../../models/entities/whole_trip.dart';

class HomeUiState {
  final bool isLoading;
  final String? userName;
  final String email;
  final bool isOffline;
  final bool isEmailVerified;
  final int verificationDaysRemaining;
  final bool hasPlan;
  final String? errorMessage;
  final WholeTrip? latestTrip;
  final String? bannerImgUrl;
  final String? profilePictureUrl;
  final String? cachedProfilePicturePath;

  const HomeUiState({
    this.isLoading = false,
    this.userName,
    required this.email,
    this.isOffline = false,
    this.isEmailVerified = false,
    this.verificationDaysRemaining = 0,
    this.hasPlan = false,
    this.errorMessage,
    this.latestTrip,
    this.bannerImgUrl,
    this.profilePictureUrl,
    this.cachedProfilePicturePath,
  });

  String get displayName =>
      userName?.trim().isNotEmpty == true ? userName! : 'Trekker';

  HomeUiState copyWith({
    bool? isLoading,
    String? userName,
    String? email,
    bool? isOffline,
    bool? isEmailVerified,
    int? verificationDaysRemaining,
    bool? hasPlan,
    String? errorMessage,
    WholeTrip? latestTrip,
    String? bannerImgUrl,
    String? profilePictureUrl,
    String? cachedProfilePicturePath,
    bool clearProfilePicture = false,
    bool clearCachedProfilePicture = false,
    bool clearLatestTrip = false,
    bool clearBannerImgUrl = false,
    bool clearErrorMessage = false,
  }) {
    return HomeUiState(
      isLoading: isLoading ?? this.isLoading,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      isOffline: isOffline ?? this.isOffline,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      verificationDaysRemaining:
      verificationDaysRemaining ?? this.verificationDaysRemaining,
      hasPlan: hasPlan ?? this.hasPlan,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      latestTrip: clearLatestTrip ? null : (latestTrip ?? this.latestTrip),
      bannerImgUrl: clearBannerImgUrl
          ? null
          : (bannerImgUrl ?? this.bannerImgUrl),
      profilePictureUrl: clearProfilePicture
          ? null
          : (profilePictureUrl ?? this.profilePictureUrl),
      cachedProfilePicturePath: clearCachedProfilePicture
          ? null
          : (cachedProfilePicturePath ?? this.cachedProfilePicturePath),
    );
  }
}
