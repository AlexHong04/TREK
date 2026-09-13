import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/profile_view_model.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/currency_picker_field.dart';
import '../views/all_plans_screen.dart';
import 'change_password_screen.dart';
import 'edit_account_screen.dart';
import 'edit_profile_screen.dart';
import 'personal_constraint_management_screen.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback? onViewAllPlans;
  final VoidCallback? onSessionEnded;

  const ProfileScreen({
    super.key,
    this.onViewAllPlans,
    this.onSessionEnded,
  });

  static Widget builder(
      BuildContext context, {
        VoidCallback? onViewAllPlans,
        VoidCallback? onSessionEnded,
      }) {
    return ProfileViewModelScope(
      child: ProfileScreen(
        onViewAllPlans: onViewAllPlans,
        onSessionEnded: onSessionEnded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        final currencyCode = state.currency.trim().toUpperCase();
        final statusMessage = state.successMessage ?? state.errorMessage;
        if (statusMessage != null) {
          final isError = state.errorMessage != null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeMessages();
            showThreeSecondMessage(
              context,
              statusMessage,
              isError: isError,
            );
          });
        }
        if (state.logoutSucceeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeLogoutSuccess();
            if (onSessionEnded != null) {
              onSessionEnded!();
            }
            // MyApp owns the normal logout-to-Login route transition.
          });
        }

        final isProfileOperationInProgress = state.isUploadingPicture ||
            state.isSendingVerification ||
            state.isLoggingOut;
        return PopScope(
          canPop: !isProfileOperationInProgress,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              systemNavigationBarColor: appTheme.gray_50_02,
              systemNavigationBarIconBrightness: Brightness.dark,
              systemNavigationBarContrastEnforced: false,
            ),
            child: Scaffold(
              extendBody: false,
              backgroundColor: appTheme.gray_50_02,
              appBar: CustomAppBar(
                title: 'Profile',
                backEnabled: !isProfileOperationInProgress,
              ),
              body: state.isLoading && state.email.isEmpty
                  ? Center(
                child: CircularProgressIndicator(color: appTheme.teal_A700),
              )
                  : RefreshIndicator(
                color: appTheme.teal_A700,
                onRefresh: isProfileOperationInProgress
                    ? () async {}
                    : viewModel.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    32 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  children: [
                    if (state.isOffline) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: appTheme.wholeAlertBudgetBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              color: appTheme.wholeAlertBudgetText,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'You’re offline. Showing saved information.',
                                style: TextStyle(
                                  color: appTheme.wholeAlertBudgetText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _ProfilePicture(viewModel: viewModel),
                    const SizedBox(height: 14),
                    Text(
                      state.fullName.isEmpty ? 'Trekker' : state.fullName,
                      style: TextStyle(
                        color: appTheme.gray_900,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InformationCard(
                      label: 'EMAIL ADDRESS',
                      headerTrailing: !state.isEmailVerified &&
                          state.verificationDaysRemaining > 0
                          ? Text(
                        '${state.verificationDaysRemaining} day${state.verificationDaysRemaining == 1 ? '' : 's'} left',
                        style: TextStyle(
                          color: appTheme.blue_gray_700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                          : null,
                      child: SizedBox(
                        height: 28,
                        child: Row(
                          children: [
                            Icon(
                              Icons.mark_email_read_outlined,
                              size: 17,
                              color: appTheme.blue_gray_300,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Text(
                                  state.email,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: appTheme.gray_800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (state.isEmailVerified)
                              Text(
                                'Verified',
                                style: TextStyle(
                                  color: appTheme.teal_700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: state.isBusy ||
                                    state.isOffline ||
                                    state.verificationCooldownSeconds > 0
                                    ? null
                                    : viewModel.sendVerificationEmail,
                                child: state.isSendingVerification
                                    ? SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: appTheme.teal_A700,
                                  ),
                                )
                                    : Text(
                                  state.verificationCooldownSeconds > 0
                                      ? '${state.verificationCooldownSeconds}s'
                                      : 'Verify email',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InformationCard(
                      label: 'PREFERRED CURRENCY',
                      child: Row(
                        children: [
                          Text(
                            currencyFlag(currencyCode),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            currencyCode,
                            style: TextStyle(
                              color: appTheme.gray_800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ProfileButton(
                      label: 'View All Plan',
                      onPressed: state.isBusy
                          ? null
                          : () {
                        if (onViewAllPlans != null) {
                          onViewAllPlans!();
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: AllPlansScreen.builder,
                            ),
                          );
                        }
                      },
                    ),
                    _ProfileButton(
                      label: 'Edit Personal Constraints',
                      onPressed: state.isBusy
                          ? null
                          : () => _openPage(
                        context,
                        PersonalConstraintManagementScreen.builder,
                        viewModel,
                      ),
                    ),
                    _ProfileButton(
                      label: 'Edit Profile',
                      onPressed: state.isBusy
                          ? null
                          : () => _openPage(
                        context,
                        EditProfileScreen.builder,
                        viewModel,
                      ),
                    ),
                    _ProfileButton(
                      label: 'Edit Account',
                      onPressed: state.isBusy
                          ? null
                          : () => _openPage(
                        context,
                        EditAccountScreen.builder,
                        viewModel,
                      ),
                    ),
                    _ProfileButton(
                      label: state.passwordActionLabel,
                      onPressed: state.isBusy
                          ? null
                          : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: ChangePasswordScreen.builder,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FilledButton.icon(
                      onPressed: state.isBusy
                          ? null
                          : () => _confirmLogout(context, viewModel),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: appTheme.errorRed,
                        foregroundColor: appTheme.white_A700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: state.isLoggingOut
                          ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: appTheme.white_A700,
                        ),
                      )
                          : const Icon(Icons.logout_outlined),
                      label: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _openPage(
      BuildContext context,
      Widget Function(BuildContext) builder,
      ProfileViewModel profileViewModel,
      ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: builder),
    );
    await profileViewModel.load();
  }

  static Future<void> _confirmLogout(
      BuildContext context,
      ProfileViewModel viewModel,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.logout_outlined, color: appTheme.teal_A700),
        title: const Text('Log out of TREK?'),
        content: const Text(
          'You will need to sign in again to access your account.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.maxFinite,
            child: Row(
              children: [
                Expanded(
                  child: _LogoutDialogButton(
                    text: 'Cancel',
                    backgroundColor: appTheme.teal_A700,
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LogoutDialogButton(
                    text: 'Confirm',
                    backgroundColor: appTheme.errorRed,
                    onPressed: () => Navigator.pop(dialogContext, true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.logout();
  }

}

class _LogoutDialogButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _LogoutDialogButton({
    required this.text,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: appTheme.white_A700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}

class _ProfilePicture extends StatelessWidget {
  final ProfileViewModel viewModel;

  const _ProfilePicture({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final state = viewModel.uiState;
    final hasPicture = state.profilePictureUrl?.isNotEmpty == true;
    final cachedPath = state.cachedProfilePicturePath;
    final hasCachedPicture = cachedPath?.isNotEmpty == true &&
        File(cachedPath!).existsSync();
    final initial = state.fullName.trim().isEmpty
        ? 'T'
        : state.fullName.trim()[0].toUpperCase();

    final ImageProvider<Object>? pictureProvider = hasCachedPicture
        ? FileImage(File(cachedPath!))
        : hasPicture
        ? NetworkImage(state.profilePictureUrl!)
        : null;

    return Center(
      child: SizedBox(
        width: 140,
        height: 128,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: appTheme.teal_50,
              foregroundImage: pictureProvider,
              onForegroundImageError:
              pictureProvider == null ? null : (_, __) {},
              child: Text(
                initial,
                style: TextStyle(
                  color: appTheme.teal_800,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: 'Edit profile picture',
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  padding: const EdgeInsets.all(5),
                  visualDensity: VisualDensity.compact,
                  onPressed: state.isBusy
                      ? null
                      : () => _showProfilePictureMenu(
                    buttonContext,
                    viewModel,
                    canRemove: hasPicture || hasCachedPicture,
                  ),
                  icon: state.isUploadingPicture
                      ? SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: appTheme.teal_A700,
                    ),
                  )
                      : Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: appTheme.gray_800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProfilePictureMenu(
      BuildContext buttonContext,
      ProfileViewModel viewModel, {
        required bool canRemove,
      }) async {
    final action = await showModalBottomSheet<_ProfilePictureAction>(
      context: buttonContext,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(sheetContext).pop(
                _ProfilePictureAction.camera,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(
                _ProfilePictureAction.gallery,
              ),
            ),
            if (canRemove)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.of(sheetContext).pop(
                  _ProfilePictureAction.remove,
                ),
              ),
          ],
        ),
      ),
    );

    if (!buttonContext.mounted) return;
    switch (action) {
      case _ProfilePictureAction.gallery:
        await viewModel.chooseFromGallery();
        break;
      case _ProfilePictureAction.camera:
        await viewModel.takePhoto();
        break;
      case _ProfilePictureAction.remove:
        await viewModel.removePhoto();
        break;
      case null:
        break;
    }
  }
}

enum _ProfilePictureAction { gallery, camera, remove }

class _InformationCard extends StatelessWidget {
  final String label;
  final Widget? headerTrailing;
  final Widget child;

  const _InformationCard({
    required this.label,
    this.headerTrailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appTheme.gray_100),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: appTheme.blue_gray_300,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              if (headerTrailing != null) headerTrailing!,
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: appTheme.white_A700,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: appTheme.gray_200),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _ProfileButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          foregroundColor: appTheme.teal_A700,
          side: BorderSide(color: appTheme.teal_A700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageCard({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? appTheme.wholeAlertBudgetBg : appTheme.wholeGoodBudgetBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError
              ? appTheme.wholeAlertBudgetStroke
              : appTheme.wholeGoodBudgetStroke,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError
              ? appTheme.wholeAlertBudgetText
              : appTheme.wholeGoodBudgetText,
        ),
      ),
    );
  }
}
