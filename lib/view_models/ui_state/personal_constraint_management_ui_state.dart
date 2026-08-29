import 'package:flutter/foundation.dart';

@immutable
class ConstraintOptionUiState {
  final String id;
  final String category;
  final String name;
  final bool isSelected;
  final bool isDisabled;

  const ConstraintOptionUiState({
    required this.id,
    required this.category,
    required this.name,
    this.isSelected = false,
    this.isDisabled = false,
  });

  ConstraintOptionUiState copyWith({
    bool? isSelected,
    bool? isDisabled,
  }) {
    return ConstraintOptionUiState(
      id: id,
      category: category,
      name: name,
      isSelected: isSelected ?? this.isSelected,
      isDisabled: isDisabled ?? this.isDisabled,
    );
  }
}

@immutable
class PersonalConstraintManagementUiState {
  final List<ConstraintOptionUiState> options;
  final bool isLoading;
  final bool isSaving;
  final bool saveSucceeded;
  final String? errorMessage;

  const PersonalConstraintManagementUiState({
    this.options = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.saveSucceeded = false,
    this.errorMessage,
  });

  PersonalConstraintManagementUiState copyWith({
    List<ConstraintOptionUiState>? options,
    bool? isLoading,
    bool? isSaving,
    bool? saveSucceeded,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PersonalConstraintManagementUiState(
      options: options ?? this.options,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      saveSucceeded: saveSucceeded ?? this.saveSucceeded,
      errorMessage:
      clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
