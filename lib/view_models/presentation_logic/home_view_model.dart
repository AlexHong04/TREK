import 'package:flutter/material.dart';

import '../ui_state/home_ui_state.dart';

class HomeViewModel extends ChangeNotifier {
  HomeUiState _uiState = const HomeUiState();
  HomeUiState get uiState => _uiState;

  void onStartPlan(BuildContext context) {
    // TODO: Navigate to existing plan details
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No plan available yet.')));
  }

  void onPlanNew(BuildContext context) {
    Navigator.of(context).pushNamed('/travelInformationInputScreen');
  }
}
