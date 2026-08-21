import 'package:flutter/foundation.dart';

import '../ui_state/home_ui_state.dart';

class HomeViewModel extends ChangeNotifier {
  final HomeUiState _uiState = const HomeUiState(email: '');
  HomeUiState get uiState => _uiState;

  // Placeholder for future logic before navigating
  void prepareNewPlan() {
    // Initialize or reset states if needed
  }

  //TODO: Update the home page available trip
  void fetchLatestTrip() {}
}
