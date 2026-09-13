import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/repository/itinerary_repository.dart';
import '../ui_state/home_ui_state.dart';
import '../../models/services/itinerary_service.dart';
import '../../models/services/i_auth_service.dart';
import '../../models/services/i_profile_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';


class HomeViewModel extends ChangeNotifier {
  final ItineraryService _itineraryService = ItineraryService();
  final IAuthService _authService;
  final IProfileService _profileService;
  bool _disposed = false;
  bool _tripRequestInFlight = false;

  /// True once a trip load has completed (successfully or not). Used so the
  /// Home card only blocks with the spinner on the very first load, instead of
  /// flickering between "loading" and "No plans yet" on every refresh.
  bool _hasLoadedTripOnce = false;

  /// Monotonic id for trip loads. Only the newest in-flight request may write
  /// to the UI state, so a slow older response can never overwrite a newer one.
  int _tripRequestId = 0;

  // andrew
  HomeViewModel(this._authService, this._profileService) {
    _authService.addListener(_handleAccountChanged);
    _syncProfile(notify: false);
    if (!_authService.isOffline) fetchLatestTripWithCurrentUserId();
  }

  HomeUiState _uiState = const HomeUiState(email: '');
  HomeUiState get uiState => _uiState;

  void _handleAccountChanged() {
    _syncProfile();
    if (!_authService.isOffline && !_tripRequestInFlight) {
      fetchLatestTripWithCurrentUserId();
    }
  }

  Future<void> refreshProfile() async {
    try {
      await _profileService.refreshCurrentUser();
    } on NetworkUnavailableException {
      _syncProfile();
    }
  }

  void _syncProfile({bool notify = true}) {
    final user = _profileService.currentUser;
    _uiState = _uiState.copyWith(
      email: user?.email ?? '',
      userName: InputValidator.normalizeDisplayName(user?.fullName ?? ''),
      profilePictureUrl: user?.profilePicture,
      cachedProfilePicturePath: user?.cachedProfilePicturePath,
      isOffline: _authService.isOffline,
      isEmailVerified: user?.isEmailVerified ?? false,
      verificationDaysRemaining: _authService.verificationDaysRemaining,
      clearProfilePicture:
      user?.profilePicture == null || user!.profilePicture!.isEmpty,
      clearCachedProfilePicture: user?.cachedProfilePicturePath == null ||
          user!.cachedProfilePicturePath!.isEmpty,
    );
    if (notify) _notify();
  }

  // kokhong
  Future<void> fetchLatestTrip() async {
    _tripRequestInFlight = true;
    final requestId = ++_tripRequestId;

    // Show the blocking spinner only for the very first load. Later refreshes
    // (including repeated auth notifications) must not toggle the card back to
    // a spinner - that caused the "keeps loading / No plans yet" flicker.
    if (!_hasLoadedTripOnce && _uiState.latestTrip == null) {
      _uiState = _uiState.copyWith(isLoading: true);
      notifyListeners();
    }

    try {
      final result = await _itineraryService.fetchLatestTrip();

      if (requestId != _tripRequestId) return; // stale response, ignore

      if (result != null) {
        final trip = result.trip;
        final activity = result.activities;
        final activityImgUrl =
            activity.isNotEmpty ? activity.first.activityImgUrl.trim() : '';

        debugPrint('>>> [VM] Result received for tripId: ${trip.tripId}');
        debugPrint('>>> [VM] Trip direct imgUrl: "$activityImgUrl"');

        _uiState = _uiState.copyWith(
          isLoading: false,
          hasPlan: true,
          latestTrip: trip.copyWith(imgUrl: activityImgUrl),
          bannerImgUrl: activityImgUrl,
          clearErrorMessage: true,
        );
      } else {
        _uiState = _uiState.copyWith(
          isLoading: false,
          hasPlan: false,
          clearLatestTrip: true,
          clearBannerImgUrl: true,
        );
      }
    } catch (e) {
      if (requestId != _tripRequestId) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    } finally {
      _tripRequestInFlight = false;
      _hasLoadedTripOnce = true;
    }
    notifyListeners();
  }

  Future<void> startTrip(String tripId) async {
    try{
      _uiState = _uiState.copyWith(isLoading: true);
      notifyListeners();

      await _itineraryService.updateTripStatus(tripId, 'ongoing');

      // refresh the UI reflects the updated state
      await fetchLatestTrip();
    } catch(e) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      notifyListeners();
    }
  }

  // Placeholder for future logic before navigating
  void prepareNewPlan() {
    // Initialize or reset states if needed
  }

  // andrew
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authService.removeListener(_handleAccountChanged);
    super.dispose();
  }

  // weisong
  Future<void> fetchLatestTripWithCurrentUserId() async {
    _tripRequestInFlight = true;
    final requestId = ++_tripRequestId;

    // Only block with a spinner on the very first load (no trip on screen).
    // Repeated refreshes must not toggle the card back to a spinner.
    if (!_hasLoadedTripOnce && _uiState.latestTrip == null) {
      _uiState = _uiState.copyWith(isLoading: true);
      notifyListeners();
    }

    try {
      // Calls the user-scoped fetch method
      final result = await _itineraryService.fetchLatestTripWithCurrentUserId();

      if (requestId != _tripRequestId) return; // stale response, ignore

      if (result != null) {
        final tripImg = result.imgUrl;

        _uiState = _uiState.copyWith(
          isLoading: false,
          hasPlan: true,
          latestTrip: result.copyWith(imgUrl: tripImg),
          bannerImgUrl: tripImg,
          clearErrorMessage: true,
        );
      } else {
        _uiState = _uiState.copyWith(
          isLoading: false,
          hasPlan: false,
          clearLatestTrip: true,
          clearBannerImgUrl: true,
        );
      }
    } catch (e) {
      if (requestId != _tripRequestId) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    } finally {
      _tripRequestInFlight = false;
      _hasLoadedTripOnce = true;
    }
    notifyListeners();
  }
}

class HomeViewModelScope extends StatelessWidget {
  final Widget child;

  const HomeViewModelScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(
        context.read<IAuthService>(),
        context.read<IProfileService>(),
      ),
      child: child,
    );
  }
}
