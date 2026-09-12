import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_profile_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import '../ui_state/edit_profile_ui_state.dart';

class EditProfileViewModel extends ChangeNotifier {
  final IProfileService _profileService;
  bool _disposed = false;
  bool _nameTouched = false;

  EditProfileViewModel(this._profileService);

  EditProfileUiState _uiState = const EditProfileUiState();
  EditProfileUiState get uiState => _uiState;

  Future<void> load() async {
    if (_uiState.isLoading) return;
    final user = _profileService.currentUser;
    if (user == null) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Your session has expired. Please log in again.',
      );
      _notify();
      return;
    }
    final editableName = _editableFullName(user.fullName);
    _uiState = _uiState.copyWith(
      fullName: editableName,
      originalFullName: editableName,
      currency: user.currency,
      isOffline: _profileService.isOffline,
      isLoading: true,
      clearErrorMessage: true,
    );
    _notify();
    try {
      final currencies = await _profileService.getSupportedCurrencies();
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        availableCurrencies: currencies,
        isLoading: false,
        isOffline: _profileService.isOffline,
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        isOffline: _profileService.isOffline,
      );
    }
    _notify();
  }

  void onFullNameChanged(String value) {
    final error =
    _nameTouched ? InputValidator.validateDisplayName(value) : null;
    _uiState = _uiState.copyWith(
      fullName: value,
      fullNameError: error,
      clearFullNameError: error == null,
      clearErrorMessage: true,
    );
    _notify();
  }

  void onFullNameFocusLost() {
    _nameTouched = true;
    final error = InputValidator.validateDisplayName(_uiState.fullName);
    _uiState = _uiState.copyWith(
      fullNameError: error,
      clearFullNameError: error == null,
    );
    _notify();
  }

  void onCurrencyChanged(String? value) {
    _uiState = _uiState.copyWith(
      currency: value ?? '',
      clearCurrencyError: true,
      clearErrorMessage: true,
    );
    _notify();
  }

  Future<void> save() async {
    if (_uiState.isSaving) return;
    if (_profileService.isOffline) {
      _uiState = _uiState.copyWith(
        isOffline: true,
        errorMessage:
        'No internet connection. Saved information is view-only while offline.',
      );
      _notify();
      return;
    }

    _nameTouched = true;
    final nameError = InputValidator.validateDisplayName(_uiState.fullName);
    final currencyError = !_uiState.availableCurrencies.contains(_uiState.currency)
        ? 'Please select a supported currency.'
        : null;
    if (nameError != null || currencyError != null) {
      _uiState = _uiState.copyWith(
        fullNameError: nameError,
        currencyError: currencyError,
        clearFullNameError: nameError == null,
        clearCurrencyError: currencyError == null,
      );
      _notify();
      return;
    }

    final savedName = InputValidator.normalizeDisplayName(_uiState.fullName);
    _uiState = _uiState.copyWith(
      isSaving: true,
      saveSucceeded: false,
      clearErrorMessage: true,
    );
    _notify();
    try {
      await _profileService.updateCurrentProfile(
        fullName: savedName,
        currency: _uiState.currency,
      );
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        fullName: savedName,
        originalFullName: savedName,
        isSaving: false,
        saveSucceeded: true,
        usedDefaultName: false,
      );
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSaving: false,
        isOffline: true,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } on InappropriateDisplayNameException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSaving: false,
        fullNameError: 'Please enter an appropriate full name.',
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSaving: false,
        errorMessage: 'Unable to update your profile. Please try again.',
      );
    }
    _notify();
  }

  void consumeSaveSuccess() {
    _uiState = _uiState.copyWith(saveSucceeded: false);
  }

  void consumeErrorMessage() {
    _uiState = _uiState.copyWith(clearErrorMessage: true);
  }

  static String _editableFullName(String value) {
    final normalized = InputValidator.normalizeDisplayName(value);
    // Older TREK profiles may already contain the former placeholder. Treat it
    // as missing data only in the editor; Home and Profile still show Trekker.
    return normalized.toLowerCase() ==
        InputValidator.defaultDisplayName.toLowerCase()
        ? ''
        : normalized;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class EditProfileViewModelScope extends StatelessWidget {
  final Widget child;

  const EditProfileViewModelScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditProfileViewModel(
        context.read<IProfileService>(),
      )..load(),
      child: child,
    );
  }
}
