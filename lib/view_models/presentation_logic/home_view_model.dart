import 'package:flutter/foundation.dart';

import '../../models/repository/itinerary_repository.dart';
import '../ui_state/home_ui_state.dart';
import '../../models/services/itinerary_service.dart';

class HomeViewModel extends ChangeNotifier {
  final ItineraryRepository _repository = ItineraryRepository();
  final ItineraryService _service = ItineraryService();

  HomeUiState _uiState = const HomeUiState(email: 'User');
  HomeUiState get uiState => _uiState;

  HomeViewModel() {
    fetchLatestTrip();
  }

  // kokhong
  Future<void> fetchLatestTrip() async {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {

      final result = await _service.fetchLatestTrip();

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

      await _service.updateTripStatus(tripId, 'ongoing');

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
}
