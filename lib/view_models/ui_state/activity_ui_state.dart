import '../../models/entities/activity.dart';

class ActivityUiState {
  final bool isLoading;
  final String tripId;
  final String currentActivityId;
  final List<Activity> activities;
  final double totalBudget;
  final double spentBudget;
  final double remainingBudget;
  final double overspentBudget;
  final int sufficientDays;
  final String usedPercentageString;
  final double usedPercentageValue;
  final double shortageAmount;

  const ActivityUiState({
    this.isLoading = false,
    this.tripId = '',
    this.currentActivityId = '',
    this.activities = const [],
    this.totalBudget = 0.0,
    this.spentBudget = 0.0,
    this.remainingBudget = 0.0,
    this.overspentBudget = 0.0,
    this.sufficientDays = 0,
    this.usedPercentageString = '0% Used',
    this.usedPercentageValue = 0.0,
    this.shortageAmount = 0.0,
  });

  ActivityUiState copyWith({
    bool? isLoading,
    String? tripId,
    String? currentActivityId,
    List<Activity>? activities,
    double? totalBudget,
    double? spentBudget,
    double? remainingBudget,
    double? overspentBudget,
    int? sufficientDays,
    String? usedPercentageString,
    double? usedPercentageValue,
    double? shortageAmount
  }) {
    return ActivityUiState(
      isLoading: isLoading ?? this.isLoading,
      tripId: tripId ?? this.tripId,
      currentActivityId: currentActivityId ?? this.currentActivityId,
      activities: activities ?? this.activities,
      totalBudget: totalBudget ?? this.totalBudget,
      spentBudget: spentBudget ?? this.spentBudget,
      remainingBudget: remainingBudget ?? this.remainingBudget,
      overspentBudget: overspentBudget ?? this.overspentBudget,
      sufficientDays: sufficientDays ?? this.sufficientDays,
      usedPercentageString: usedPercentageString ?? this.usedPercentageString,
      usedPercentageValue: usedPercentageValue ?? this.usedPercentageValue,
      shortageAmount: shortageAmount ?? this.shortageAmount,
    );
  }
}
