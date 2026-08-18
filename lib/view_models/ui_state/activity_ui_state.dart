import '../../models/entities/activity.dart';

class ActivityUiState {
  final bool isLoading;
  final List<Activity> activities;
  final double totalBudget;
  final double spentBudget;
  final double remainingBudget;
  final double overspentBudget;
  final int sufficientDays;
  final String usedPercentageString;
  final double usedPercentageValue;

  const ActivityUiState({
    this.isLoading = false,
    this.activities = const [],
    this.totalBudget = 0.0,
    this.spentBudget = 0.0,
    this.remainingBudget = 0.0,
    this.overspentBudget = 0.0,
    this.sufficientDays = 0,
    this.usedPercentageString = '0% Used',
    this.usedPercentageValue = 0.0,
  });

  ActivityUiState copyWith({
    bool? isLoading,
    List<Activity>? activities,
    double? totalBudget,
    double? spentBudget,
    double? remainingBudget,
    double? overspentBudget,
    int? sufficientDays,
    String? usedPercentageString,
    double? usedPercentageValue,
  }) {
    return ActivityUiState(
      isLoading: isLoading ?? this.isLoading,
      activities: activities ?? this.activities,
      totalBudget: totalBudget ?? this.totalBudget,
      spentBudget: spentBudget ?? this.spentBudget,
      remainingBudget: remainingBudget ?? this.remainingBudget,
      overspentBudget: overspentBudget ?? this.overspentBudget,
      sufficientDays: sufficientDays ?? this.sufficientDays,
      usedPercentageString: usedPercentageString ?? this.usedPercentageString,
      usedPercentageValue: usedPercentageValue ?? this.usedPercentageValue,
    );
  }
}
