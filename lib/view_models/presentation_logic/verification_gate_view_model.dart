import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../../utils/network_error.dart';
import '../ui_state/verification_gate_ui_state.dart';

class VerificationGateViewModel extends ChangeNotifier {
  final IAuthService _authService;
  bool _disposed = false;

  VerificationGateViewModel(this._authService)
      : _uiState = VerificationGateUiState(
    email: _authService.currentUser?.email ?? '',
  ) {
    _authService.addListener(_syncEmail);
  }

  VerificationGateUiState _uiState;
  VerificationGateUiState get uiState => _uiState;

  Future<void> sendVerificationLink() async {
    if (_uiState.isBusy || _authService.isOffline) {
      if (_authService.isOffline) {
        _uiState = _uiState.copyWith(
          errorMessage: 'No internet connection. Check your connection and try again.',
        );
        _notify();
      }
      return;
    }
    _uiState = _uiState.copyWith(isSending: true, clearErrorMessage: true);
    _notify();
    try {
      await _authService.resendVerificationEmail(email: _uiState.email);
      if (_disposed) return;
      _uiState = _uiState.copyWith(isSending: false, linkSent: true);
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSending: false,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isSending: false,
        errorMessage: 'Unable to send the verification link. Please try again.',
      );
    }
    _notify();
  }

  Future<void> logout() async {
    if (_uiState.isBusy) return;
    _uiState = _uiState.copyWith(isLoggingOut: true, clearErrorMessage: true);
    _notify();
    try {
      await _authService.logout();
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isLoggingOut: false,
        errorMessage: 'Unable to log out. Please try again.',
      );
      _notify();
    }
  }

  void _syncEmail() {
    final email = _authService.currentUser?.email;
    if (email == null || email == _uiState.email) return;
    _uiState = _uiState.copyWith(email: email, linkSent: false);
    _notify();
  }

  void consumeErrorMessage() {
    _uiState = _uiState.copyWith(clearErrorMessage: true);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authService.removeListener(_syncEmail);
    super.dispose();
  }
}

class VerificationGateViewModelScope extends StatelessWidget {
  final Widget child;

  const VerificationGateViewModelScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VerificationGateViewModel(context.read<IAuthService>()),
      child: child,
    );
  }
}
