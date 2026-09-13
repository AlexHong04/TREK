import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../utils/input_validator.dart';
import '../view_models/presentation_logic/edit_profile_view_model.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/currency_picker_field.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  static const int _fullNameMaxLength = InputValidator.maxDisplayNameLength;

  static Widget builder(BuildContext context) {
    return const EditProfileViewModelScope(child: EditProfileScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        final fullNameLength = state.fullName.characters.length;
        if (state.saveSucceeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            const message = 'Profile updated successfully.';
            viewModel.consumeSaveSuccess();
            showThreeSecondMessage(context, message);
          });
        }
        if (state.errorMessage != null) {
          final message = state.errorMessage!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeErrorMessage();
            showThreeSecondMessage(context, message, isError: true);
          });
        }

        return PopScope(
          canPop: !state.isSaving,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Scaffold(
              backgroundColor: appTheme.gray_50_02,
              appBar: CustomAppBar(
                title: 'Edit Profile',
                backEnabled: !state.isSaving,
              ),
              body: state.isLoading
                  ? Center(
                child: CircularProgressIndicator(color: appTheme.teal_A700),
              )
                  : SafeArea(
                top: false,
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                  children: [
                    if (state.isOffline) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: appTheme.wholeAlertBudgetBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'You’re offline. Showing saved information; editing is unavailable.',
                          style: TextStyle(color: appTheme.wholeAlertBudgetText),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Focus(
                      onFocusChange: (focused) {
                        if (!focused) viewModel.onFullNameFocusLost();
                      },
                      child: CustomTextField(
                        sectionTitle: 'FULL NAME',
                        sectionTrailing: Text(
                          '$fullNameLength/$_fullNameMaxLength',
                          style: TextStyle(
                            color: _fullNameCounterColor(fullNameLength),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            height: 1.2,
                          ),
                        ),
                        hintText: 'Enter your full name (optional)',
                        prefixIcon: Icons.badge_outlined,
                        margin: EdgeInsets.zero,
                        initialValue: state.fullName,
                        enabled: !state.isSaving && !state.isOffline,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            _fullNameMaxLength,
                          ),
                        ],
                        onChanged: viewModel.onFullNameChanged,
                        errorText: state.fullNameError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CurrencyPickerField(
                      value: state.currency,
                      currencies: state.availableCurrencies,
                      errorText: state.currencyError,
                      enabled: !state.isSaving && !state.isOffline,
                      onChanged: viewModel.onCurrencyChanged,
                    ),
                    const SizedBox(height: 42),
                    FilledButton.icon(
                      onPressed:
                      state.isSaving || state.isOffline ? null : viewModel.save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: appTheme.teal_A700,
                        foregroundColor: appTheme.white_A700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: state.isSaving
                          ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: appTheme.white_A700,
                        ),
                      )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save'),
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

  static Color _fullNameCounterColor(int length) {
    if (length >= 95) return appTheme.errorRed;
    if (length >= 90) return appTheme.lime_900;
    if (length >= 80) return appTheme.warningPopupHeader;
    return appTheme.teal_A700;
  }

}
