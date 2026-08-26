import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/entities/personal_constraint.dart';
import '../models/services/i_auth_service.dart';
import '../models/services/profile_service.dart';
import '../theme/app_colors.dart';
import '../view_models/presentation_logic/edit_profile_view_model.dart';
import '../view_models/presentation_logic/registration_view_model.dart';
import '../widgets/custom_app_bar.dart';

class EditProfileScreen extends StatelessWidget {
  final VoidCallback? onViewAllPlans;
  final VoidCallback? onSessionEnded;

  const EditProfileScreen({
    super.key,
    this.onViewAllPlans,
    this.onSessionEnded,
  });

  static Widget builder(
      BuildContext context, {
        VoidCallback? onViewAllPlans,
        VoidCallback? onSessionEnded,
      }) {
    return ChangeNotifierProvider(
      create: (_) => EditProfileViewModel(
        context.read<IAuthService>(),
        context.read<ProfileService>(),
      )..load(),
      child: EditProfileScreen(
        onViewAllPlans: onViewAllPlans,
        onSessionEnded: onSessionEnded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        if (state.logoutSucceeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeSessionEnd();
            if (onSessionEnded != null) {
              onSessionEnded!();
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                    (route) => false,
              );
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.gray50_02,
          appBar: const CustomAppBar(title: 'My Profile'),
          body: state.isLoading && state.user == null
              ? const Center(
            child: CircularProgressIndicator(color: AppColors.tealA700),
          )
              : RefreshIndicator(
            onRefresh: viewModel.load,
            color: AppColors.tealA700,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: [
                _ProfileHeader(viewModel: viewModel),
                if (state.successMessage != null) ...[
                  const SizedBox(height: 16),
                  _StatusCard(message: state.successMessage!),
                ],
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _StatusCard(
                    message: state.errorMessage!,
                    isError: true,
                  ),
                ],
                const SizedBox(height: 24),
                _ProfileAction(
                  icon: Icons.route_outlined,
                  title: 'View All Plans',
                  subtitle: 'Open your saved and generated itineraries',
                  onTap: state.isBusy
                      ? null
                      : () {
                    if (onViewAllPlans != null) {
                      onViewAllPlans!();
                    } else {
                      Navigator.pushNamed(context, '/viewAllPlans');
                    }
                  },
                ),
                _ProfileAction(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Edit Profile',
                  subtitle: 'Update your full name and currency',
                  onTap: state.isBusy
                      ? null
                      : () => _showSheet(
                    context,
                    viewModel,
                    const _EditDetailsSheet(),
                  ),
                ),
                _ProfileAction(
                  icon: Icons.tune_outlined,
                  title: 'Edit Personal Constraints',
                  subtitle:
                  'Manage dietary, mobility, and travel preferences',
                  onTap: state.isBusy
                      ? null
                      : () => _showSheet(
                    context,
                    viewModel,
                    const _ConstraintsSheet(),
                  ),
                ),
                _ProfileAction(
                  icon: Icons.password_outlined,
                  title: 'Change Password',
                  subtitle: 'Secure your account with a new password',
                  onTap: state.isBusy
                      ? null
                      : () => _showSheet(
                    context,
                    viewModel,
                    const _ChangePasswordSheet(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => _confirmLogout(context, viewModel),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: AppColors.errorRed,
                    side: const BorderSide(color: AppColors.errorRed),
                  ),
                  icon: state.isLoggingOut
                      ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.errorRed,
                    ),
                  )
                      : const Icon(Icons.logout),
                  label: const Text('Log Out'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _showSheet(
      BuildContext context,
      EditProfileViewModel viewModel,
      Widget child,
      ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: child,
      ),
    );
  }

  static Future<void> _confirmLogout(
      BuildContext context,
      EditProfileViewModel viewModel,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to enter your credentials to access your account again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.logout();
  }
}

class _ProfileHeader extends StatelessWidget {
  final EditProfileViewModel viewModel;

  const _ProfileHeader({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final state = viewModel.uiState;
    final user = state.user;
    final picture = user?.profilePicture;
    final initial = user == null || user.fullName.trim().isEmpty
        ? '?'
        : user.fullName.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gray100),
        boxShadow: const [
          BoxShadow(
            color: AppColors.black900_0c,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.teal50,
                foregroundImage: picture == null || picture.isEmpty
                    ? null
                    : NetworkImage(picture),
                child: picture == null || picture.isEmpty
                    ? Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.teal800,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                )
                    : null,
              ),
              Positioned(
                right: -8,
                bottom: -4,
                child: Material(
                  color: AppColors.tealA700,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Edit profile picture',
                    color: AppColors.white,
                    iconSize: 20,
                    onPressed: state.isBusy
                        ? null
                        : () => _selectPicture(context, viewModel),
                    icon: state.isUploadingPicture
                        ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                        : const Icon(Icons.camera_alt_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user?.fullName ?? 'Tourist',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.blueGray900,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.blueGray700),
          ),
          const SizedBox(height: 8),
          Chip(
            avatar: const Icon(Icons.payments_outlined, size: 18),
            label: Text(user?.currency ?? 'MYR'),
            backgroundColor: AppColors.gray50_01,
            side: const BorderSide(color: AppColors.teal50),
          ),
        ],
      ),
    );
  }

  static Future<void> _selectPicture(
      BuildContext context,
      EditProfileViewModel viewModel,
      ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final selected = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1440,
    );
    if (selected == null) return;
    await viewModel.saveProfilePicture(File(selected.path));
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.gray100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.gray50_01,
          child: Icon(icon, color: AppColors.tealA700),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.blueGray900,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EditDetailsSheet extends StatelessWidget {
  const _EditDetailsSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetTitle(title: 'Edit Profile'),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: state.fullName,
                  enabled: !state.isSavingProfile,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: viewModel.onFullNameChanged,
                  decoration: _fieldDecoration(
                    label: 'Full name',
                    icon: Icons.person_outline,
                    errorText: state.fullNameError,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue:
                  state.currency.isEmpty ? null : state.currency,
                  decoration: _fieldDecoration(
                    label: 'Preferred currency',
                    icon: Icons.payments_outlined,
                    errorText: state.currencyError,
                  ),
                  items: RegistrationViewModel.supportedCurrencies
                      .map(
                        (currency) => DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    ),
                  )
                      .toList(growable: false),
                  onChanged: state.isSavingProfile
                      ? null
                      : viewModel.onCurrencyChanged,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed:
                  state.isSavingProfile ? null : viewModel.saveProfile,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.tealA700,
                  ),
                  child: state.isSavingProfile
                      ? const _ButtonLoader()
                      : const Text('Save Profile'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConstraintsSheet extends StatelessWidget {
  const _ConstraintsSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        final groups = <String, List<PersonalConstraint>>{};
        for (final constraint in state.availableConstraints) {
          groups.putIfAbsent(constraint.category, () => []).add(constraint);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetTitle(title: 'Personal Constraints'),
              const SizedBox(height: 8),
              const Text(
                'Select every constraint TREK should consider when planning your itinerary.',
                style: TextStyle(color: AppColors.blueGray700),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: groups.isEmpty
                    ? const Center(
                  child: Text('No personal constraints are available.'),
                )
                    : ListView(
                  children: groups.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: AppColors.blueGray900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.value.map((constraint) {
                              final selected = state.selectedConstraintIds
                                  .contains(constraint.constraintId);
                              return FilterChip(
                                selected: selected,
                                label: Text(constraint.constraintName),
                                onSelected: state.isSavingConstraints
                                    ? null
                                    : (_) => viewModel
                                    .toggleConstraint(constraint),
                                selectedColor: AppColors.teal50,
                                checkmarkColor: AppColors.teal800,
                              );
                            }).toList(growable: false),
                          ),
                        ],
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: state.isSavingConstraints
                    ? null
                    : viewModel.saveConstraints,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.tealA700,
                ),
                child: state.isSavingConstraints
                    ? const _ButtonLoader()
                    : const Text('Save Constraints'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChangePasswordSheet extends StatelessWidget {
  const _ChangePasswordSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetTitle(title: 'Change Password'),
                  const SizedBox(height: 8),
                  const Text(
                    'Changing your password signs you out on every device.',
                    style: TextStyle(color: AppColors.blueGray700),
                  ),
                  const SizedBox(height: 20),
                  _PasswordField(
                    label: 'Current password',
                    obscure: state.obscureCurrentPassword,
                    errorText: state.currentPasswordError,
                    enabled: !state.isChangingPassword,
                    autofillHint: AutofillHints.password,
                    onChanged: viewModel.onCurrentPasswordChanged,
                    onToggleVisibility:
                    viewModel.toggleCurrentPasswordVisibility,
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    label: 'New password',
                    obscure: state.obscureNewPassword,
                    errorText: state.newPasswordError,
                    enabled: !state.isChangingPassword,
                    autofillHint: AutofillHints.newPassword,
                    onChanged: viewModel.onNewPasswordChanged,
                    onToggleVisibility: viewModel.toggleNewPasswordVisibility,
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    label: 'Confirm new password',
                    obscure: state.obscureConfirmPassword,
                    errorText: state.confirmPasswordError,
                    enabled: !state.isChangingPassword,
                    autofillHint: AutofillHints.newPassword,
                    textInputAction: TextInputAction.done,
                    onChanged: viewModel.onConfirmPasswordChanged,
                    onToggleVisibility:
                    viewModel.toggleConfirmPasswordVisibility,
                    onSubmitted: (_) => viewModel.changePassword(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: state.isChangingPassword
                        ? null
                        : viewModel.changePassword,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.tealA700,
                    ),
                    child: state.isChangingPassword
                        ? const _ButtonLoader()
                        : const Text('Change Password'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final bool obscure;
  final String? errorText;
  final bool enabled;
  final String autofillHint;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggleVisibility;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _PasswordField({
    required this.label,
    required this.obscure,
    required this.errorText,
    required this.enabled,
    required this.autofillHint,
    required this.onChanged,
    required this.onToggleVisibility,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: enabled,
      obscureText: obscure,
      autofillHints: [autofillHint],
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      decoration: _fieldDecoration(
        label: label,
        icon: Icons.lock_outline,
        errorText: errorText,
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show password' : 'Hide password',
          onPressed: enabled ? onToggleVisibility : null,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String title;

  const _SheetTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.blueGray900,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String message;
  final bool isError;

  const _StatusCard({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? AppColors.budgetAlertBg : AppColors.goodPercentageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? AppColors.budgetAlertStroke
              : AppColors.goodPercentageStroke,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError
              ? AppColors.budgetAlertText
              : AppColors.goodPercentageText,
        ),
      ),
    );
  }
}

class _ButtonLoader extends StatelessWidget {
  const _ButtonLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppColors.white,
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
  String? errorText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    suffixIcon: suffixIcon,
    errorText: errorText,
    filled: true,
    fillColor: AppColors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.gray200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.tealA700, width: 1.5),
    ),
  );
}
