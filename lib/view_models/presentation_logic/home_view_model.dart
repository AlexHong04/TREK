import 'package:flutter/foundation.dart';
import '../../models/repository/itinerary_repository.dart';

import '../ui_state/home_ui_state.dart';

class HomeViewModel extends ChangeNotifier {
  final ItineraryRepository _repository = ItineraryRepository();

  HomeUiState _uiState = const HomeUiState(email: 'User');
  HomeUiState get uiState => _uiState;

  HomeViewModel() {
    fetchLatestTrip();
  }

  Future<void> fetchLatestTrip() async {
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final trip = await _repository.getLatestTrip();

      if (trip != null) {
        _uiState = _uiState.copyWith(
          isLoading: false,
          hasPlan: true,
          latestTrip: trip,
        );
      } else {
        _uiState = _uiState.copyWith(isLoading: false, hasPlan: false);
      }
    } catch (e) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  // Placeholder for future logic before navigating
  void prepareNewPlan() {
    // Initialize or reset states if needed
  }
}
