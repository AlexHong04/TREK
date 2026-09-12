import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../../utils/network_error.dart';
import '../ui_state/delete_account_ui_state.dart';

class DeleteAccountViewModel extends ChangeNotifier {
  final IAuthService _authService;
  bool _disposed = false;

  DeleteAccountViewModel(this._authService);

  DeleteAccountUiState _uiState = const DeleteAccountUiState();
  DeleteAccountUiState get uiState => _uiState;

  Future<void> deletePermanently() async {
    if (_uiState.isDeleting || _uiState.isCancelling) return;
    _uiState = _uiState.copyWith(isDeleting: true, clearErrorMessage: true);
    _notify();
    try {
      await _authService.permanentlyDeleteAccount();
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isDeleting: false,
        deletionSucceeded: true,
      );
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isDeleting: false,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } on AccountDeletionNotConfirmedException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isDeleting: false,
        errorMessage: 'The deletion confirmation has expired. Start again.',
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isDeleting: false,
        errorMessage: 'Unable to delete the account. Please try again.',
      );
    }
    _notify();
  }

  Future<void> cancelDeletion() async {
    if (_uiState.isDeleting || _uiState.isCancelling) return;
    _uiState = _uiState.copyWith(
      isCancelling: true,
      clearErrorMessage: true,
    );
    _notify();
    try {
      await _authService.cancelAccountDeletion();
      if (_disposed) return;
      _uiState = _uiState.copyWith(isCancelling: false);
    } on NetworkUnavailableException {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isCancelling: false,
        errorMessage: 'No internet connection. Check your connection and try again.',
      );
    } catch (_) {
      if (_disposed) return;
      _uiState = _uiState.copyWith(
        isCancelling: false,
        errorMessage: 'Unable to cancel account deletion. Please try again.',
      );
    }
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
    super.dispose();
  }
}

class DeleteAccountViewModelScope extends StatelessWidget {
  final Widget child;

  const DeleteAccountViewModelScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeleteAccountViewModel(context.read<IAuthService>()),
      child: child,
    );
  }
}
