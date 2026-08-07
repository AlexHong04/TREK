import 'package:flutter/material.dart';

import '../../models/entities/day_itinerary_detail_model.dart';
import '../ui_state/travel_information_ui_state.dart';

class TravelInformationInputViewModel extends ChangeNotifier {
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController budgetController = TextEditingController();
  final TextEditingController wishlistController = TextEditingController();

  TravelInformationUiState _uiState = const TravelInformationUiState();
  TravelInformationUiState get uiState => _uiState;

  final List<PreferenceItemModel> preferences = [
    PreferenceItemModel(label: 'Nature', icon: Icons.park_outlined),
    PreferenceItemModel(label: 'Adventure', icon: Icons.explore_outlined),
    PreferenceItemModel(label: 'Foodie', icon: Icons.menu_book_outlined),
    PreferenceItemModel(
      label: 'Relaxation',
      icon: Icons.nightlight_round_outlined,
    ),
  ];

  String? validateDestination(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Please enter a destination';
    }
    return null;
  }

  String? validateDate(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Please select dates';
    }
    return null;
  }

  String? validateBudget(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Please enter a budget';
    }
    return null;
  }

  Future<void> selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      dateController.text =
          '${picked.start.toLocal().toString().split(' ')[0]} - ${picked.end.toLocal().toString().split(' ')[0]}';
      notifyListeners();
    }
  }

  void selectPreference(String label) {
    _uiState = _uiState.copyWith(selectedPreference: label);
    notifyListeners();
  }

  void selectEmergencyFund(String percentage) {
    _uiState = _uiState.copyWith(selectedEmergencyFund: percentage);
    notifyListeners();
  }

  Future<void> generateItinerary(BuildContext context) async {
    final String? destinationError = validateDestination(
      destinationController.text,
    );
    final String? dateError = validateDate(dateController.text);
    final String? budgetError = validateBudget(budgetController.text);

    if (destinationError != null || dateError != null || budgetError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            destinationError ??
                dateError ??
                budgetError ??
                'Please complete the form',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Itinerary generation started!')),
    );
  }
}
