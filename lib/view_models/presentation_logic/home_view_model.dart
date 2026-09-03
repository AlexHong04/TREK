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

  HomeViewModel(this._authService) {
    _authService.addListener(_handleAuthUserChanged);
    _syncAuthUser(notify: false);
    fetchLatestTripWithCurrentUserId();
  }

  void _handleAuthUserChanged() {
    _syncAuthUser(notify: true);
    fetchLatestTripWithCurrentUserId();
  }

  Future<void> refreshProfile() async {
    await _authService.refreshCurrentUser();
  }

  void _syncAuthUser({bool notify = true}) {
    final user = _authService.currentUser;
    _uiState = HomeUiState(
      email: user?.email ?? 'User',
      userName: user?.fullName,
      profilePictureUrl: user?.profilePicture,
      latestTrip: null,
      hasPlan: false,
      bannerImgUrl: null,
      errorMessage: null,
    );
    if (notify) notifyListeners();
  }

  // kokhong
  Future<void> fetchLatestTrip() async {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {

      final result = await _itineraryService.fetchLatestTrip();

      if (result != null) {
        var trip = result.trip;
        final activity = result.activities;
        final activityImgUrl = activity.first.activityImgUrl.trim();

        debugPrint('>>> [VM] Result received for tripId: ${trip.tripId}');
        debugPrint('>>> [VM] Trip direct imgUrl: "$activityImgUrl"');
        trip = trip.copyWith(
          imgUrl: activityImgUrl,
        );

        _uiState = _uiState.copyWith(
          isLoading: false,
          hasPlan: true,
          latestTrip: trip,
          bannerImgUrl: activityImgUrl,
        );
      } else {
        _uiState = _uiState.copyWith(
          isLoading: false,
          hasPlan: false,
          bannerImgUrl: null,
        );
      }
    } catch (e) {
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
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      // Calls the user-scoped fetch method
      final result = await _itineraryService.fetchLatestTripWithCurrentUserId();

      if (result != null) {
        final trip = result;
        final tripImg = result.imgUrl;

        _uiState = _uiState.copyWith(
          isLoading: false,
          hasPlan: true,
          latestTrip: trip.copyWith(imgUrl: tripImg),
          bannerImgUrl: tripImg,
        );
      } else {
        _uiState = _uiState.copyWith(
          isLoading: false,
          hasPlan: false,
          latestTrip: null,
          bannerImgUrl: null,
        );
      }
    } catch (e) {
      _uiState = _uiState.copyWith(isLoading: false, errorMessage: e.toString());
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
