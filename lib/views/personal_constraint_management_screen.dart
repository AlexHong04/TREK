import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/personal_constraint_management_view_model.dart';
import '../widgets/custom_app_bar.dart';

class PersonalConstraintManagementScreen extends StatelessWidget {
  const PersonalConstraintManagementScreen({super.key});

  static Widget builder(BuildContext context) {
    return const PersonalConstraintManagementViewModelScope(
      child: PersonalConstraintManagementScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PersonalConstraintManagementViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.uiState;
        if (state.saveSucceeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.consumeSaveSuccess();
            showThreeSecondMessage(
              context,
              'Personal constraints updated successfully.',
            );
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
          child: Scaffold(
            backgroundColor: appTheme.gray_50_02,
            appBar: CustomAppBar(
              title: 'Personal Constraints',
              backEnabled: !state.isSaving,
            ),
            body: state.isLoading
                ? Center(
              child: CircularProgressIndicator(color: appTheme.teal_A700),
            )
                : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
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
                  for (final category in
                  PersonalConstraintManagementViewModel
                      .requiredOptions.keys) ...[
                    _ConstraintCard(
                      title: category.toUpperCase(),
                      optionWidgets: state.options
                          .where((option) => option.category == category)
                          .map(
                            (option) => _ConstraintChip(
                          name: option.name,
                          isSelected: option.isSelected,
                          isDisabled: option.isDisabled ||
                              state.isSaving ||
                              state.isOffline,
                          onToggle: viewModel.toggle,
                        ),
                      )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: state.isSaving ||
                        state.isOffline ||
                        state.options.any((option) => option.id.isEmpty)
                        ? null
                        : viewModel.save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: appTheme.teal_A700,
                      foregroundColor: appTheme.white_A700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(state.isSaving ? 'Saving…' : 'Save'),
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

class _ConstraintCard extends StatelessWidget {
  final String title;
  final List<Widget> optionWidgets;

  const _ConstraintCard({
    required this.title,
    required this.optionWidgets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: appTheme.gray_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: appTheme.blue_gray_300,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: optionWidgets,
          ),
        ],
      ),
    );
  }
}

class _ConstraintChip extends StatelessWidget {
  final String name;
  final bool isSelected;
  final bool isDisabled;
  final ValueChanged<String> onToggle;

  const _ConstraintChip({
    required this.name,
    required this.isSelected,
    required this.isDisabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ChoiceChip(
          label: SizedBox(
            width: double.infinity,
            child: Text(name, textAlign: TextAlign.center),
          ),
          selected: isSelected,
          onSelected: isDisabled ? null : (_) => onToggle(name),
          selectedColor: appTheme.gray_50_01,
          disabledColor: appTheme.gray_200,
          backgroundColor: appTheme.white_A700,
          side: BorderSide(
            color: isSelected ? appTheme.teal_A700 : appTheme.gray_200,
          ),
          labelStyle: TextStyle(
            color: isDisabled
                ? appTheme.blue_gray_300
                : isSelected
                ? appTheme.teal_700
                : appTheme.blue_gray_700,
            fontSize: 12,
          ),
          showCheckmark: false,
        ),
      ),
    );
  }
}
