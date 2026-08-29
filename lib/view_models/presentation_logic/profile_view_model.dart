import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/profile_ui_state.dart';

class ProfileViewModel extends ChangeNotifier {
  final IAuthService _authService;

  ProfileViewModel(this._authService) {
    _authService.addListener(_syncFromAuthService);
  }

  ProfileUiState _uiState = const ProfileUiState();
  ProfileUiState get uiState => _uiState;

  Future<void> load() async {
    if (_uiState.isLoading) return;
    _uiState = _uiState.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
    try {
      final hadLoadedProfile = _uiState.email.isNotEmpty;
      final wasEmailVerified = _uiState.isEmailVerified;
      await _authService.refreshCurrentUser();
      final user = _authService.currentUser;
      if (user == null) {
        throw StateError('No active tourist session.');
      }
      _applyCurrentUser(isLoading: false);
      _showVerificationSuccessIfNeeded(
        hadLoadedProfile: hadLoadedProfile,
        wasEmailVerified: wasEmailVerified,
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load your profile. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> chooseFromGallery() {
    return _changeProfilePicture(ProfileImageSource.gallery);
  }

  Future<void> takePhoto() {
    return _changeProfilePicture(ProfileImageSource.camera);
  }

  Future<void> removePhoto() async {
    if (_uiState.isUploadingPicture ||
        _uiState.profilePictureUrl?.isNotEmpty != true) {
      return;
    }

    _uiState = _uiState.copyWith(
      isUploadingPicture: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
    try {
      await _authService.removeProfilePicture();
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        clearProfilePicture: true,
        successMessage: 'Profile picture removed successfully.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        errorMessage: 'Unable to remove the profile picture. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> _changeProfilePicture(ProfileImageSource source) async {
    if (_uiState.isUploadingPicture) return;
    final userId = _authService.currentUserId;
    if (userId == null) {
      _uiState = _uiState.copyWith(
        errorMessage: 'Your session has expired. Please log in again.',
      );
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      isUploadingPicture: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
    try {
      final pictureUrl = await _authService.updateProfilePicture(source);
      if (pictureUrl == null) {
        _uiState = _uiState.copyWith(isUploadingPicture: false);
      } else {
        await _authService.refreshCurrentUser();
        _uiState = _uiState.copyWith(
          profilePictureUrl: pictureUrl,
          isUploadingPicture: false,
          successMessage: 'Profile picture updated successfully.',
        );
      }
    } on ProfileImageTooLargeException {
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        errorMessage: 'The image must be 5 MB or smaller.',
      );
    } on ProfileInvalidImageFormatException {
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

  Future<void> sendVerificationEmail() async {
    if (_uiState.isEmailVerified || _uiState.isSendingVerification) return;
    _uiState = _uiState.copyWith(
      isSendingVerification: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    notifyListeners();
    try {
      await _authService.resendVerificationEmail(email: _uiState.email);
      _uiState = _uiState.copyWith(
        isSendingVerification: false,
        successMessage:
        'Verification link sent. Open it on this device to verify your email.',
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isSendingVerification: false,
        errorMessage: 'Unable to send the verification email.',
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

  void consumeLogoutSuccess() {
    _uiState = _uiState.copyWith(logoutSucceeded: false);
  }

  void consumeMessages() {
    _uiState = _uiState.copyWith(
      clearSuccessMessage: true,
      clearErrorMessage: true,
    );
  }

  void _syncFromAuthService() {
    if (_authService.currentUser == null) return;
    final hadLoadedProfile = _uiState.email.isNotEmpty;
    final wasEmailVerified = _uiState.isEmailVerified;
    _applyCurrentUser();
    _showVerificationSuccessIfNeeded(
      hadLoadedProfile: hadLoadedProfile,
      wasEmailVerified: wasEmailVerified,
    );
    notifyListeners();
  }

  void _showVerificationSuccessIfNeeded({
    required bool hadLoadedProfile,
    required bool wasEmailVerified,
  }) {
    if (hadLoadedProfile &&
        !wasEmailVerified &&
        _uiState.isEmailVerified) {
      _uiState = _uiState.copyWith(
        successMessage: 'Email verified successfully.',
        clearErrorMessage: true,
      );
    }
  }

  void _applyCurrentUser({bool? isLoading}) {
    final user = _authService.currentUser;
    if (user == null) return;
    _uiState = _uiState.copyWith(
      fullName: user.fullName.trim().isEmpty ? 'Tourist' : user.fullName,
      email: user.email,
      currency: user.currency,
      profilePictureUrl: user.profilePicture,
      isEmailVerified: user.isEmailVerified,
      isLoading: isLoading,
      clearProfilePicture:
      user.profilePicture == null || user.profilePicture!.isEmpty,
    );
  }

  @override
  void dispose() {
    _authService.removeListener(_syncFromAuthService);
    super.dispose();
  }
}

class ProfileViewModelScope extends StatelessWidget {
  final Widget child;

  const ProfileViewModelScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileViewModel(
        context.read<IAuthService>(),
      )..load(),
      child: child,
    );
  }
}
