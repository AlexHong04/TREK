import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_auth_service.dart';
import '../ui_state/personal_constraint_management_ui_state.dart';

class PersonalConstraintManagementViewModel extends ChangeNotifier {
  final IAuthService _authService;

  PersonalConstraintManagementViewModel(this._authService);

  static const Map<String, List<String>> requiredOptions = {
    'Cultural & Religious': ['Halal', 'Non-Halal'],
    'Dietary & Nutrition Preferences': ['Vegetarian', 'Vegan'],
    'Food Exclusions': ['No Alcohol', 'No Fast Food'],
  };

  static const Map<String, String> _conflicts = {
    'Halal': 'Non-Halal',
    'Non-Halal': 'Halal',
    'Vegetarian': 'Vegan',
    'Vegan': 'Vegetarian',
  };

  PersonalConstraintManagementUiState _uiState =
  const PersonalConstraintManagementUiState();
  PersonalConstraintManagementUiState get uiState => _uiState;

  Future<void> load() async {
    if (_uiState.isLoading) return;
    final userId = _authService.currentUserId;
    if (userId == null) {
      _uiState = _uiState.copyWith(
        errorMessage: 'Your session has expired. Please log in again.',
      );
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );
    notifyListeners();
    try {
      final data = await _authService.loadPersonalConstraintOptions();
      final options = _buildRequiredOptions(data);
      final hasMissingDatabaseRows = options.any((option) => option.id.isEmpty);
      _uiState = _uiState.copyWith(
        options: _applyDisabledRules(options),
        isLoading: false,
        errorMessage: hasMissingDatabaseRows
            ? 'Some required constraint choices are missing from Supabase.'
            : null,
        clearErrorMessage: !hasMissingDatabaseRows,
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        options: _buildRequiredOptions(const []),
        isLoading: false,
        errorMessage: 'Unable to load personal constraints.',
      );
    }
    notifyListeners();
  }

  void toggle(String name) {
    if (_uiState.isSaving) return;
    final current = _uiState.options.firstWhere((item) => item.name == name);
    if (current.id.isEmpty || current.isDisabled) return;

    final updated = _uiState.options.map((option) {
      if (option.name == name) {
        return option.copyWith(isSelected: !option.isSelected);
      }
      if (!current.isSelected && _conflicts[name] == option.name) {
        return option.copyWith(isSelected: false);
      }
      return option;
    }).toList(growable: false);

    _uiState = _uiState.copyWith(
      options: _applyDisabledRules(updated),
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  Future<void> save() async {
    if (_uiState.isSaving || _uiState.options.any((item) => item.id.isEmpty)) {
      return;
    }
    final userId = _authService.currentUserId;
    if (userId == null) {
      _uiState = _uiState.copyWith(
        errorMessage: 'Your session has expired. Please log in again.',
      );
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      isSaving: true,
      saveSucceeded: false,
      clearErrorMessage: true,
    );
    notifyListeners();
    try {
      final ids = _uiState.options
          .where((option) => option.isSelected)
          .map((option) => option.id)
          .toList()
        ..sort();
      await _authService.savePersonalConstraints(ids);
      _uiState = _uiState.copyWith(
        isSaving: false,
        saveSucceeded: true,
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        isSaving: false,
        errorMessage: 'Unable to save personal constraints.',
      );
    }
    notifyListeners();
  }

  void consumeSaveSuccess() {
    _uiState = _uiState.copyWith(saveSucceeded: false);
  }

  void consumeErrorMessage() {
    _uiState = _uiState.copyWith(clearErrorMessage: true);
  }

  static List<ConstraintOptionUiState> _buildRequiredOptions(
      List<PersonalConstraintOptionData> all,
      ) {
    return requiredOptions.entries.expand((entry) {
      return entry.value.map((requiredName) {
        PersonalConstraintOptionData? match;
        for (final candidate in all) {
          if (_normalize(candidate.name) == _normalize(requiredName)) {
            match = candidate;
            break;
          }
        }
        return ConstraintOptionUiState(
          id: match?.id ?? '',
          category: entry.key,
          name: requiredName,
          isSelected: match?.isSelected ?? false,
          isDisabled: match == null,
        );
      });
    }).toList(growable: false);
  }

  static List<ConstraintOptionUiState> _applyDisabledRules(
      List<ConstraintOptionUiState> options,
      ) {
    final selectedNames = <String>{};
    final sanitized = options.map((option) {
      final conflict = _conflicts[option.name];
      if (option.isSelected &&
          conflict != null &&
          selectedNames.contains(conflict)) {
        return option.copyWith(isSelected: false);
      }
      if (option.isSelected) selectedNames.add(option.name);
      return option;
    }).toList(growable: false);
    final finalSelectedNames = sanitized
        .where((option) => option.isSelected)
        .map((option) => option.name)
        .toSet();
    return sanitized.map((option) {
      final conflict = _conflicts[option.name];
      final disabledByConflict =
          !option.isSelected &&
              conflict != null &&
              finalSelectedNames.contains(conflict);
      return option.copyWith(
        isDisabled: option.id.isEmpty || disabledByConflict,
      );
    }).toList(growable: false);
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}

class PersonalConstraintManagementViewModelScope extends StatelessWidget {
  final Widget child;

  const PersonalConstraintManagementViewModelScope({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PersonalConstraintManagementViewModel(
        context.read<IAuthService>(),
      )..load(),
      child: child,
    );
  }
}
