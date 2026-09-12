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

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: appTheme.gray_50_02,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          child: Scaffold(
            extendBody: false,
            backgroundColor: appTheme.gray_50_02,
            appBar: const CustomAppBar(title: 'Profile'),
            body: state.isLoading && state.email.isEmpty
                ? Center(
              child: CircularProgressIndicator(color: appTheme.teal_A700),
            )
                : RefreshIndicator(
              color: appTheme.teal_A700,
              onRefresh: viewModel.load,
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
                              onPressed: state.isSendingVerification ||
                                  state.isOffline
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
                                  : const Text('Verify email'),
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
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.logout_outlined, color: appTheme.teal_A700),
        title: const Text('Log out of TREK?'),
        content: const Text(
          'You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.logout();
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
                  onPressed: state.isUploadingPicture
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
    final renderObject = buttonContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;

    final mediaQuery = MediaQuery.of(buttonContext);
    final screenSize = mediaQuery.size;
    final buttonOffset = renderObject.localToGlobal(Offset.zero);
    final buttonCenter = buttonOffset +
        Offset(renderObject.size.width / 2, renderObject.size.height / 2);

    const preferredWidth = 224.0;
    const horizontalMargin = 16.0;
    final availableWidth = screenSize.width - (horizontalMargin * 2);
    final menuWidth = availableWidth < preferredWidth
        ? availableWidth
        : preferredWidth;
    final menuLeft = (screenSize.width - menuWidth) / 2;
    final menuHeight = canRemove ? 132.0 : 88.0;

    var menuTop = buttonOffset.dy + renderObject.size.height + 6;
    final bottomLimit =
        screenSize.height - mediaQuery.padding.bottom - horizontalMargin;
    if (menuTop + menuHeight > bottomLimit) {
      menuTop = buttonOffset.dy - menuHeight - 6;
    }
    final minimumTop = mediaQuery.padding.top + 8;
    if (menuTop < minimumTop) menuTop = minimumTop;

    final animationAlignment = Alignment(
      ((buttonCenter.dx / screenSize.width) * 2) - 1,
      ((buttonCenter.dy / screenSize.height) * 2) - 1,
    );

    final action = await showGeneralDialog<_ProfilePictureAction>(
      context: buttonContext,
      barrierDismissible: true,
      barrierLabel:
      MaterialLocalizations.of(buttonContext).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) {
        return SizedBox.expand(
          child: Stack(
            children: [
              Positioned(
                left: menuLeft,
                top: menuTop,
                width: menuWidth,
                child: Material(
                  color: appTheme.white_A700,
                  elevation: 7,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: appTheme.teal_A700,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _profilePictureMenuItem(
                        onPressed: () => Navigator.of(dialogContext).pop(
                          _ProfilePictureAction.gallery,
                        ),
                        icon: Icons.photo_library_outlined,
                        label: 'Choose from gallery',
                        color: appTheme.teal_A700,
                      ),
                      _profilePictureMenuItem(
                        onPressed: () => Navigator.of(dialogContext).pop(
                          _ProfilePictureAction.camera,
                        ),
                        icon: Icons.photo_camera_outlined,
                        label: 'Take photo',
                        color: appTheme.teal_A700,
                      ),
                      if (canRemove)
                        _profilePictureMenuItem(
                          onPressed: () => Navigator.of(dialogContext).pop(
                            _ProfilePictureAction.remove,
                          ),
                          icon: Icons.delete_outline,
                          label: 'Remove photo',
                          color: appTheme.errorRed,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: curvedAnimation,
            alignment: animationAlignment,
            child: child,
          ),
        );
      },
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

  MenuItemButton _profilePictureMenuItem({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return MenuItemButton(
      onPressed: onPressed,
      leadingIcon: Icon(icon, size: 20, color: color),
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(color),
        minimumSize: const WidgetStatePropertyAll(Size(224, 44)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
