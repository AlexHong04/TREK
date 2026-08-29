import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/profile_view_model.dart';
import '../widgets/custom_app_bar.dart';
import 'change_password_screen.dart';
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
                  _ProfilePicture(viewModel: viewModel),
                  const SizedBox(height: 14),
                  Text(
                    state.fullName.isEmpty ? 'Tourist' : state.fullName,
                    style: TextStyle(
                      color: appTheme.gray_900,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InformationCard(
                    label: 'EMAIL ADDRESS',
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
                            onPressed: state.isSendingVerification
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
                                : const Text('Click here to verify'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InformationCard(
                    label: 'PREFERRED CURRENCY',
                    child: Row(
                      children: [
                        Text(
                          _currencyFlag(state.currency),
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          state.currency,
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
                        Navigator.pushNamed(context, '/viewAllPlans');
                      }
                    },
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
                    label: 'Change Password',
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
                    onPressed: state.isBusy ? null : viewModel.logout,
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
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: builder),
    );
    if (changed == true) await profileViewModel.load();
  }

  static String _currencyFlag(String code) {
    return switch (code) {
      'MYR' => '🇲🇾',
      'USD' => '🇺🇸',
      'SGD' => '🇸🇬',
      'GBP' => '🇬🇧',
      'JPY' => '🇯🇵',
      'EUR' => '🇪🇺',
      _ => '💱',
    };
  }
}

class _ProfilePicture extends StatelessWidget {
  final ProfileViewModel viewModel;

  const _ProfilePicture({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final state = viewModel.uiState;
    final hasPicture = state.profilePictureUrl?.isNotEmpty == true;
    final initial = state.fullName.trim().isEmpty
        ? '?'
        : state.fullName.trim()[0].toUpperCase();

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
              foregroundImage:
              hasPicture ? NetworkImage(state.profilePictureUrl!) : null,
              onForegroundImageError: hasPicture ? (_, __) {} : null,
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
              child: MenuAnchor(
                alignmentOffset: const Offset(-152, 6),
                menuChildren: [
                  MenuItemButton(
                    onPressed: viewModel.chooseFromGallery,
                    child: const SizedBox(
                      width: 150,
                      child: Text('Choose from gallery'),
                    ),
                  ),
                  MenuItemButton(
                    onPressed: viewModel.takePhoto,
                    child: const SizedBox(
                      width: 150,
                      child: Text('Take photo'),
                    ),
                  ),
                  if (hasPicture)
                    MenuItemButton(
                      onPressed: viewModel.removePhoto,
                      leadingIcon: Icon(
                        Icons.delete_outline,
                        color: appTheme.errorRed,
                      ),
                      child: Text(
                        'Remove photo',
                        style: TextStyle(color: appTheme.errorRed),
                      ),
                    ),
                ],
                builder: (context, controller, _) {
                  return IconButton(
                    tooltip: 'Edit profile picture',
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    padding: const EdgeInsets.all(5),
                    visualDensity: VisualDensity.compact,
                    onPressed:
                    state.isUploadingPicture ? null : controller.open,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _InformationCard({required this.label, required this.child});

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
          Text(
            label,
            style: TextStyle(
              color: appTheme.blue_gray_300,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
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
