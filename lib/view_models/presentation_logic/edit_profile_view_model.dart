import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/edit_profile_ui_state.dart';

class EditProfileViewModel extends ChangeNotifier {
  final IAuthService _authService;

  EditProfileViewModel(this._authService);

  EditProfileUiState _uiState = const EditProfileUiState();
  EditProfileUiState get uiState => _uiState;

  Future<void> load() async {
    if (_uiState.isLoading) return;
    final user = _authService.currentUser;
    if (user == null) {
      _uiState = _uiState.copyWith(
        errorMessage: 'Your session has expired. Please log in again.',
      );
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      fullName: user.fullName,
      originalFullName: user.fullName,
      email: user.email,
      currency: user.currency,
      isLoading: true,
      clearErrorMessage: true,
    );
    notifyListeners();
    try {
      final currencies = await _authService.getSupportedCurrencies();
      _uiState = _uiState.copyWith(
        availableCurrencies: currencies,
        isLoading: false,
      );
    } catch (_) {
      _uiState = _uiState.copyWith(isLoading: false);
    }
    notifyListeners();
  }

  void onFullNameChanged(String value) {
    _uiState = _uiState.copyWith(
      fullName: value,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  void onCurrencyChanged(String? value) {
    _uiState = _uiState.copyWith(
      currency: value ?? '',
      clearCurrencyError: true,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  Future<void> save() async {
    if (_uiState.isSaving) return;
    if (_authService.currentUserId == null) {
      _uiState = _uiState.copyWith(
        errorMessage: 'Your session has expired. Please log in again.',
      );
      notifyListeners();
      return;
    }

    if (!_uiState.availableCurrencies.contains(_uiState.currency)) {
      _uiState = _uiState.copyWith(
        currencyError: 'Please select a supported currency.',
      );
      notifyListeners();
      return;
    }

    final enteredName = _uiState.fullName.trim();
    final savedName = enteredName.isNotEmpty
        ? enteredName
        : (_uiState.originalFullName.trim().isNotEmpty
        ? _uiState.originalFullName.trim()
        : 'Tourist');

    _uiState = _uiState.copyWith(
      isSaving: true,
      saveSucceeded: false,
      clearErrorMessage: true,
    );
    notifyListeners();
    try {
      await _authService.updateCurrentProfile(
        fullName: savedName,
        currency: _uiState.currency,
      );
      _uiState = _uiState.copyWith(
        fullName: savedName,
        originalFullName: savedName,
        isSaving: false,
        saveSucceeded: true,
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isSaving: false,
        errorMessage: 'Unable to update your profile. Please try again.',
      );
    }
    notifyListeners();
  }

  void consumeSaveSuccess() {
    _uiState = _uiState.copyWith(saveSucceeded: false);
  }

  void consumeErrorMessage() {
    _uiState = _uiState.copyWith(clearErrorMessage: true);
  }
}

class EditProfileViewModelScope extends StatelessWidget {
  final Widget child;

  const EditProfileViewModelScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditProfileViewModel(
        context.read<IAuthService>(),
      )..load(),
      child: child,
    );
  }
}
