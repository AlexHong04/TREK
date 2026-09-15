import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/services/i_profile_service.dart';
import '../../utils/network_error.dart';
import '../ui_state/personal_constraint_management_ui_state.dart';

class PersonalConstraintManagementViewModel extends ChangeNotifier {
  final IProfileService _profileService;
  bool _disposed = false;
  bool _loadInProgress = false;

  PersonalConstraintManagementViewModel(this._profileService) {
    final cached = _profileService.currentUser?.personalConstraints
        .map(
          (constraint) => PersonalConstraintOptionData(
        id: constraint.constraintId,
        category: constraint.category,
        name: constraint.constraintName,
        isSelected: true,
      ),
    )
        .toList(growable: false) ??
        const <PersonalConstraintOptionData>[];
    _uiState = PersonalConstraintManagementUiState(
      options: _applyDisabledRules(_buildRequiredOptions(cached)),
      isOffline: _profileService.isOffline,
    );
  }

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

  /// One-way implications: choosing the key already covers the values, so the
  /// values are shown but locked.
  ///
  /// Deliberately NOT part of [_conflicts]. A conflict is mutual exclusion -
  /// picking Halal clears Non-Halal, and picking Non-Halal clears Halal. Halal
  /// and No Alcohol are not mutually exclusive: a halal trip keeps both, but
  /// "No Alcohol" adds nothing once Halal is chosen, so it is locked instead.
  ///
  /// The rule is also one-way. Choosing "No Alcohol" on its own says nothing
  /// about Halal, so Halal stays enabled in that direction. Note the pair spans
  /// categories - Cultural & Religious implies Food Exclusions - which is why
  /// this cannot be expressed with the per-pair [_conflicts] lookup.
  static const Map<String, List<String>> _implies = {
    'Halal': ['No Alcohol'],
  };

  PersonalConstraintManagementUiState _uiState =
  const PersonalConstraintManagementUiState();
  PersonalConstraintManagementUiState get uiState => _uiState;

  Future<void> load() async {
    if (_loadInProgress) return;
    final userId = _profileService.currentUserId;
    if (userId == null) {
      _uiState = _uiState.copyWith(
        errorMessage: 'Your session has expired. Please log in again.',
      );
      notifyListeners();
      return;
    }

    if (_profileService.isOffline) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        isOffline: true,
        clearErrorMessage: true,
      );
      notifyListeners();
      return;
    }

    _loadInProgress = true;
    _uiState = _uiState.copyWith(
      // Cached selections and the fixed option layout are already available,
      // so a refresh must not replace the page with a blocking spinner.
      isLoading: _uiState.options.isEmpty,
      clearErrorMessage: true,
    );
    notifyListeners();
    try {
      final data = await _profileService.loadPersonalConstraintOptions();
      final options = _buildRequiredOptions(data);
      final hasMissingDatabaseRows = options.any((option) => option.id.isEmpty);
      _uiState = _uiState.copyWith(
        options: _applyDisabledRules(options),
        isLoading: false,
        isOffline: _profileService.isOffline,
        errorMessage: hasMissingDatabaseRows
            ? 'Some required constraint choices are missing from Supabase.'
            : null,
        clearErrorMessage: !hasMissingDatabaseRows,
      );
    } on NetworkUnavailableException {
      _uiState = _uiState.copyWith(
        isLoading: false,
        isOffline: true,
        clearErrorMessage: true,
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        options: _buildRequiredOptions(const []),
        isLoading: false,
        errorMessage: 'Unable to load personal constraints.',
      );
    } finally {
      _loadInProgress = false;
    }
    notifyListeners();
  }

  void toggle(String name) {
    if (_uiState.isSaving || _uiState.isOffline) return;
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
    if (_uiState.isOffline) {
      _uiState = _uiState.copyWith(
        errorMessage: 'Saved constraints are view-only while offline.',
      );
      notifyListeners();
      return;
    }
    final userId = _profileService.currentUserId;
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
      await _profileService.savePersonalConstraints(ids);
      _uiState = _uiState.copyWith(
        isSaving: false,
        saveSucceeded: true,
      );
    } on NetworkUnavailableException {
      _uiState = _uiState.copyWith(
        isSaving: false,
        isOffline: true,
        errorMessage: 'No internet connection. Check your connection and try again.',
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

    // Options already covered by a stronger constraint the traveller chose.
    // Derived from the final selection each time, so the lock lifts again as
    // soon as the implying option is deselected.
    final impliedNames = <String>{
      for (final name in finalSelectedNames) ...?_implies[name],
    };

    return sanitized.map((option) {
      final conflict = _conflicts[option.name];
      final disabledByConflict =
          !option.isSelected &&
              conflict != null &&
              finalSelectedNames.contains(conflict);
      // Applied whether or not the option is currently ticked: the implication
      // comes from the other constraint, not from this one's own state. Its
      // selection is left untouched so nothing is silently added to or removed
      // from what gets saved.
      final disabledByImplication = impliedNames.contains(option.name);
      return option.copyWith(
        isDisabled:
            option.id.isEmpty || disabledByConflict || disabledByImplication,
      );
    }).toList(growable: false);
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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
        context.read<IProfileService>(),
      )..load(),
      child: child,
    );
  }
}
