import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/edit_profile_view_model.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/currency_picker_field.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  static Widget builder(BuildContext context) {
    return const EditProfileViewModelScope(child: EditProfileScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        if (state.saveSucceeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeSaveSuccess();
            showThreeSecondMessage(context, 'Profile updated successfully.');
            Navigator.pop(context, true);
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

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Scaffold(
            backgroundColor: appTheme.gray_50_02,
            appBar: const CustomAppBar(title: 'Edit Profile'),
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
                  CustomTextField(
                    sectionTitle: 'FULL NAME (OPTIONAL)',
                    hintText: 'Enter your full name',
                    prefixIcon: Icons.badge_outlined,
                    margin: EdgeInsets.zero,
                    initialValue: state.fullName,
                    enabled: !state.isSaving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    onChanged: viewModel.onFullNameChanged,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    sectionTitle: 'EMAIL ADDRESS',
                    hintText: '',
                    prefixIcon: Icons.mark_email_read_outlined,
                    margin: EdgeInsets.zero,
                    initialValue: state.email,
                    enabled: false,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _FieldCard(
                    label: 'PREFERRED CURRENCY',
                    child: CurrencyPickerField(
                      value: state.currency,
                      currencies: state.availableCurrencies,
                      errorText: state.currencyError,
                      enabled: !state.isSaving,
                      onChanged: viewModel.onCurrencyChanged,
                    ),
                  ),
                  const SizedBox(height: 42),
                  FilledButton.icon(
                    onPressed: state.isSaving ? null : viewModel.save,
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
                  TextButton(
                    onPressed:
                    state.isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
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

class _FieldCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
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
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }
}
