import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/repository/itinerary_repository.dart';
import '../ui_state/home_ui_state.dart';
import '../../models/services/itinerary_service.dart';
import '../../models/services/i_auth_service.dart';

class HomeViewModel extends ChangeNotifier {
  final ItineraryService _itineraryService = ItineraryService();
  final IAuthService _authService;

  HomeUiState _uiState = const HomeUiState(email: 'User');
  HomeUiState get uiState => _uiState;

  /// Monotonic id for trip loads. Only the newest in-flight request may write
  /// to the UI state, so a slow older response can never overwrite a newer one.
  int _tripRequestId = 0;

  /// The user id the currently displayed trip belongs to. Lets us tell a real
  /// sign-in/sign-out apart from an auth notification that changed nothing.
  String? _lastUserId;

  HomeViewModel(this._authService) {
    _lastUserId = _authService.currentUserId;
    _applyUserFields(notify: false);
    _authService.addListener(_handleAuthUserChanged);
    fetchLatestTripWithCurrentUserId();
  }

  void _handleAuthUserChanged() {
    final user = _authService.currentUser;
    final userId = user?.userId;
    final userChanged = userId != _lastUserId;
    _lastUserId = userId;

    if (user == null) {
      // Signed out: invalidate any in-flight fetch and clear everything.
      _tripRequestId++;
      _uiState = const HomeUiState(email: 'User');
      notifyListeners();
      return;
    }

    // Same user, new auth event (token refresh, app resume, profile reload).
    // Refresh ONLY the profile fields and keep the trip that is on screen.
    // Nulling latestTrip/hasPlan here is what made the card flash "No plans
    // yet" and momentarily drop the trip on every auth notification.
    _applyUserFields(notify: true);

    // Only reload the trip when a different user just signed in.
    if (userChanged) {
      fetchLatestTripWithCurrentUserId();
    }
  }

  void _applyUserFields({bool notify = true}) {
    final user = _authService.currentUser;
    if (user == null) {
      _uiState = const HomeUiState(email: 'User');
    } else {
      _uiState = _uiState.copyWith(
        email: user.email,
        userName: user.fullName,
        profilePictureUrl: user.profilePicture,
        clearProfilePicture: (user.profilePicture ?? '').isEmpty,
      );
    }
    if (notify) notifyListeners();
  }

  Future<void> refreshProfile() async {
    await _authService.refreshCurrentUser();
  }

  // kokhong
  Future<void> fetchLatestTrip() async {
    final requestId = ++_tripRequestId;

    // Keep the current card visible while refreshing; only block with the
    // spinner when there is nothing on screen yet.
    if (_uiState.latestTrip == null) {
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

  @override
  void dispose() {
    _authService.removeListener(_handleAuthUserChanged);
    super.dispose();
  }

  // weisong
  Future<void> fetchLatestTripWithCurrentUserId() async {
    final requestId = ++_tripRequestId;

    // Only block with a spinner on the very first load (no trip on screen).
    if (_uiState.latestTrip == null) {
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
      create: (_) => HomeViewModel(context.read<IAuthService>()),
      child: child,
    );
  }
}
