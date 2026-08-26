import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/entities/personal_constraint.dart';
import '../../models/services/i_auth_service.dart';
import '../../models/services/profile_service.dart';
import 'registration_view_model.dart';
import '../ui_state/edit_profile_ui_state.dart';

class EditProfileViewModel extends ChangeNotifier {
  final IAuthService _authService;
  final ProfileService _profileService;

  EditProfileViewModel(this._authService, this._profileService);

  EditProfileUiState _uiState = const EditProfileUiState();
  EditProfileUiState get uiState => _uiState;

  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _special =
  RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\;\[\]~`]');

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
      isLoading: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
    try {
      final allConstraints = await _profileService.getAllConstraints();
      final selected = await _profileService.getUserConstraints(user.userId);
      _uiState = _uiState.copyWith(
        user: user.copyWith(personalConstraints: selected),
        fullName: user.fullName,
        currency: user.currency,
        availableConstraints: allConstraints,
        selectedConstraintIds:
        selected.map((item) => item.constraintId).toSet(),
        isLoading: false,
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        user: user,
        fullName: user.fullName,
        currency: user.currency,
        isLoading: false,
        errorMessage: 'Unable to load your profile. Please try again.',
      );
    }
    notifyListeners();
  }

  void onFullNameChanged(String value) {
    _uiState = _uiState.copyWith(
      fullName: value,
      clearFullNameError: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
  }

  void onCurrencyChanged(String? value) {
    _uiState = _uiState.copyWith(
      currency: value ?? '',
      clearCurrencyError: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
  }

  Future<void> saveProfile() async {
    final fullName = _uiState.fullName.trim();
    final fullNameError =
    fullName.isEmpty ? 'Full name is required.' : null;
    final currencyError =
    RegistrationViewModel.supportedCurrencies.contains(_uiState.currency)
        ? null
        : 'Please select a supported currency.';
    if (fullNameError != null || currencyError != null) {
      _uiState = _uiState.copyWith(
        fullNameError: fullNameError,
        currencyError: currencyError,
        clearFullNameError: fullNameError == null,
        clearCurrencyError: currencyError == null,
      );
      notifyListeners();
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      _setSessionExpired();
      return;
    }
    _uiState = _uiState.copyWith(
      isSavingProfile: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
    try {
      await _profileService.updateProfile(
        userId: userId,
        fullName: fullName,
        currency: _uiState.currency,
      );
      await _authService.refreshCurrentUser();
      final refreshed = _authService.currentUser;
      _uiState = _uiState.copyWith(
        user: refreshed,
        fullName: refreshed?.fullName ?? fullName,
        currency: refreshed?.currency ?? _uiState.currency,
        isSavingProfile: false,
        successMessage: 'Profile updated successfully.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isSavingProfile: false,
        errorMessage: 'Unable to update your profile. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> saveProfilePicture(File imageFile) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      _setSessionExpired();
      return;
    }
    _uiState = _uiState.copyWith(
      isUploadingPicture: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
    try {
      await _profileService.saveProfilePicture(
        userId: userId,
        imageFile: imageFile,
      );
      await _authService.refreshCurrentUser();
      _uiState = _uiState.copyWith(
        user: _authService.currentUser,
        isUploadingPicture: false,
        successMessage: 'Profile picture updated successfully.',
      );
    } on ImageTooLargeException {
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        errorMessage: 'The image must be 5 MB or smaller.',
      );
    } on InvalidImageFormatException {
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        errorMessage: 'Please select a valid JPG, JPEG, or PNG image.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        errorMessage: 'Unable to update the profile picture. Please try again.',
      );
    }
    notifyListeners();
  }

  void toggleConstraint(PersonalConstraint constraint) {
    final selected = Set<String>.from(_uiState.selectedConstraintIds);
    if (selected.remove(constraint.constraintId)) {
      _uiState = _uiState.copyWith(selectedConstraintIds: selected);
      notifyListeners();
      return;
    }

    final categoryItems = _uiState.availableConstraints
        .where((item) => item.category == constraint.category);
    if (_meansNoRestriction(constraint.constraintName)) {
      selected.removeAll(categoryItems.map((item) => item.constraintId));
    } else {
      selected.removeAll(
        categoryItems
            .where((item) => _meansNoRestriction(item.constraintName))
            .map((item) => item.constraintId),
      );
    }
    selected.add(constraint.constraintId);
    _uiState = _uiState.copyWith(
      selectedConstraintIds: selected,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
  }

  Future<void> saveConstraints() async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      _setSessionExpired();
      return;
    }
    _uiState = _uiState.copyWith(
      isSavingConstraints: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
    try {
      final ids = _uiState.selectedConstraintIds.toList()..sort();
      await _profileService.saveUserConstraints(
        userId: userId,
        constraintIds: ids,
      );
      await _authService.refreshCurrentUser();
      _uiState = _uiState.copyWith(
        user: _authService.currentUser,
        isSavingConstraints: false,
        successMessage: 'Personal constraints updated successfully.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isSavingConstraints: false,
        errorMessage:
        'Unable to update personal constraints. Please try again.',
      );
    }
    notifyListeners();
  }

  void onCurrentPasswordChanged(String value) {
    _uiState = _uiState.copyWith(
      currentPassword: value,
      clearCurrentPasswordError: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
  }

  void onNewPasswordChanged(String value) {
    _uiState = _uiState.copyWith(
      newPassword: value,
      clearNewPasswordError: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
  }

  void onConfirmPasswordChanged(String value) {
    _uiState = _uiState.copyWith(
      confirmPassword: value,
      clearConfirmPasswordError: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
  }

  void toggleCurrentPasswordVisibility() {
    _uiState = _uiState.copyWith(
      obscureCurrentPassword: !_uiState.obscureCurrentPassword,
    );
    notifyListeners();
  }

  void toggleNewPasswordVisibility() {
    _uiState = _uiState.copyWith(
      obscureNewPassword: !_uiState.obscureNewPassword,
    );
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _uiState = _uiState.copyWith(
      obscureConfirmPassword: !_uiState.obscureConfirmPassword,
    );
    notifyListeners();
  }

  Future<void> changePassword() async {
    final currentError = _uiState.currentPassword.isEmpty
        ? 'Current password is required.'
        : null;
    final newError = _validateNewPassword(_uiState.newPassword);
    final confirmError = _uiState.confirmPassword.isEmpty
        ? 'Please confirm your new password.'
        : _uiState.confirmPassword != _uiState.newPassword
        ? 'Passwords do not match.'
        : null;
    if (currentError != null || newError != null || confirmError != null) {
      _uiState = _uiState.copyWith(
        currentPasswordError: currentError,
        newPasswordError: newError,
        confirmPasswordError: confirmError,
        clearCurrentPasswordError: currentError == null,
        clearNewPasswordError: newError == null,
        clearConfirmPasswordError: confirmError == null,
      );
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      isChangingPassword: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
    try {
      await _authService.changePassword(
        currentPassword: _uiState.currentPassword,
        newPassword: _uiState.newPassword,
      );
      _uiState = _uiState.copyWith(
        isChangingPassword: false,
        passwordChanged: true,
        logoutSucceeded: true,
        successMessage: 'Password changed. Please log in again.',
      );
    } on IncorrectCurrentPasswordException {
      _uiState = _uiState.copyWith(
        isChangingPassword: false,
        currentPasswordError: 'Current password is incorrect.',
      );
    } on PasswordReusedException {
      _uiState = _uiState.copyWith(
        isChangingPassword: false,
        newPasswordError:
        'Your new password must be different from your current password.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isChangingPassword: false,
        errorMessage: 'Unable to change your password. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> logout() async {
    if (_uiState.isLoggingOut) return;
    _uiState = _uiState.copyWith(
      isLoggingOut: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
    try {
      await _authService.logout();
      _uiState = _uiState.copyWith(
        isLoggingOut: false,
        logoutSucceeded: true,
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoggingOut: false,
        errorMessage: 'Unable to log out. Please try again.',
      );
    }
    notifyListeners();
  }

  void consumeSessionEnd() {
    _uiState = _uiState.copyWith(
      passwordChanged: false,
      logoutSucceeded: false,
    );
    notifyListeners();
  }

  String? _validateNewPassword(String password) {
    if (password.isEmpty) return 'New password is required.';
    if (password.length < 8 ||
        !_uppercase.hasMatch(password) ||
        !_lowercase.hasMatch(password) ||
        !_digit.hasMatch(password) ||
        !_special.hasMatch(password)) {
      return 'Use at least 8 characters with uppercase, lowercase, a digit, and a special character.';
    }
    if (password == _uiState.currentPassword) {
      return 'Your new password must be different from your current password.';
    }
    return null;
  }

  static bool _meansNoRestriction(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'none' ||
        normalized == 'no restriction' ||
        normalized == 'no restrictions' ||
        normalized == 'no preference';
  }

  void _setSessionExpired() {
    _uiState = _uiState.copyWith(
      errorMessage: 'Your session has expired. Please log in again.',
    );
    notifyListeners();
  }
}
