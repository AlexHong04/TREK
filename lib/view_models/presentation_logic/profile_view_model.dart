import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../../models/services/i_profile_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import '../ui_state/profile_ui_state.dart';

class ProfileViewModel extends ChangeNotifier {
  final IAuthService _authService;
  final IProfileService _profileService;
  bool _disposed = false;
  bool _loadInProgress = false;

  ProfileViewModel(this._authService, this._profileService) {
    _authService.addListener(_syncFromServices);
    _applyCurrentUser();
  }

  ProfileUiState _uiState = const ProfileUiState();
  ProfileUiState get uiState => _uiState;

  Future<void> load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    final needsBlockingLoad = _uiState.email.isEmpty;
    _uiState = _uiState.copyWith(
      isLoading: needsBlockingLoad,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
    try {
      final wasVerified = _uiState.isEmailVerified;
      await _profileService.refreshCurrentUser();
      if (_disposed) return;
      _applyCurrentUser(isLoading: false);
      if (!wasVerified && _uiState.isEmailVerified) {
        _uiState = _uiState.copyWith(
          successMessage: 'Email verified successfully.',
        );
      }
    } on NetworkUnavailableException {
      if (_disposed) return;
      _applyCurrentUser(isLoading: false);
      _uiState = _uiState.copyWith(isOffline: true);
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to refresh your profile. Please try again.',
      );
    } finally {
      _loadInProgress = false;
    }
    _notify();
  }

  Future<void> chooseFromGallery() {
    return _changeProfilePicture(ProfileImageSource.gallery);
  }

  Future<void> takePhoto() {
    return _changeProfilePicture(ProfileImageSource.camera);
  }

  Future<void> removePhoto() async {
    if (_uiState.isUploadingPicture ||
        (_uiState.profilePictureUrl?.isNotEmpty != true &&
            _uiState.cachedProfilePicturePath?.isNotEmpty != true)) {
      return;
    }
    _uiState = _uiState.copyWith(
      isUploadingPicture: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
    try {
      await _profileService.removeProfilePicture();
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        clearProfilePicture: true,
        clearCachedProfilePicture: true,
        successMessage: 'Profile picture removed successfully.',
      );
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        isOffline: true,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        errorMessage: 'Unable to remove the profile picture. Please try again.',
      );
    }
    _notify();
  }

  Future<void> _changeProfilePicture(ProfileImageSource source) async {
    if (_uiState.isUploadingPicture) return;
    _uiState = _uiState.copyWith(
      isUploadingPicture: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
    try {
      final pictureUrl = await _profileService.updateProfilePicture(source);
      if (_disposed) return;
      _applyCurrentUser(isLoading: false);
      _uiState = _uiState.copyWith(
        profilePictureUrl: pictureUrl ?? _uiState.profilePictureUrl,
        isUploadingPicture: false,
        successMessage:
        pictureUrl == null ? null : 'Profile picture updated successfully.',
      );
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        isOffline: true,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } on ProfileImageTooLargeException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        errorMessage: 'The image must be 5 MB or smaller.',
      );
    } on ProfileInvalidImageFormatException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        errorMessage: 'Please select a valid JPG, JPEG, or PNG image.',
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isUploadingPicture: false,
        errorMessage: 'Unable to update the profile picture. Please try again.',
      );
    }
    _notify();
  }

  Future<void> sendVerificationEmail() async {
    if (_uiState.isEmailVerified ||
        _uiState.isSendingVerification ||
        _uiState.verificationCooldownSeconds > 0 ||
        _uiState.isOffline) {
      return;
    }
    _uiState = _uiState.copyWith(
      isSendingVerification: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
    try {
      await _authService.resendVerificationEmail(email: _uiState.email);
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSendingVerification: false,
        successMessage:
        'Verification link sent. You may open it on any device.',
      );
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSendingVerification: false,
        isOffline: true,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } on EmailRequestRateLimitedException catch (error) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSendingVerification: false,
        verificationCooldownSeconds: error.retryAfterSeconds,
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSendingVerification: false,
        errorMessage: 'Unable to send the verification email.',
      );
    }
    _notify();
  }

  Future<void> logout() async {
    if (_uiState.isLoggingOut) return;
    _uiState = _uiState.copyWith(
      isLoggingOut: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    _notify();
    try {
      await _authService.logout();
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoggingOut: false,
        logoutSucceeded: true,
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoggingOut: false,
        errorMessage: 'Unable to log out. Please try again.',
      );
    }
    _notify();
  }

  void _syncFromServices() {
    if (_authService.currentUser == null) return;
    _applyCurrentUser();
    _notify();
  }

  void _applyCurrentUser({bool? isLoading}) {
    final user = _profileService.currentUser;
    if (user == null) return;
    final info = _authService.accountInfo;
    _uiState = _uiState.copyWith(
      // Keep raw editable data in state. The Profile screen owns the visual
      // fallback so Edit Profile can correctly show an empty field.
      fullName: InputValidator.normalizeDisplayName(user.fullName),
      email: user.email,
      currency: user.currency,
      profilePictureUrl: user.profilePicture,
      cachedProfilePicturePath: user.cachedProfilePicturePath,
      isEmailVerified: user.isEmailVerified,
      verificationDaysRemaining: _authService.verificationDaysRemaining,
      verificationCooldownSeconds: _authService.emailCooldownSeconds(
        EmailActionType.verification,
      ),
      hasPasswordSignIn: info?.hasPasswordSignIn ?? false,
      isOffline: _authService.isOffline,
      isLoading: isLoading,
      clearProfilePicture:
      user.profilePicture == null || user.profilePicture!.isEmpty,
      clearCachedProfilePicture: user.cachedProfilePicturePath == null ||
          user.cachedProfilePicturePath!.isEmpty,
    );
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authService.removeListener(_syncFromServices);
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
        context.read<IProfileService>(),
      )..load(),
      child: child,
    );
  }
}
