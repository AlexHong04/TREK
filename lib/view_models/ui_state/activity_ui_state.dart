import '../../models/entities/activity.dart';
import '../../models/entities/expense_item.dart';

class ActivityUiState {
  final bool isLoading;
  final String tripId;
  final String currentActivityId;
  final List<Activity> activities;

  // Temporary Add Expense form data.
  final Activity? selectedActivity;
  final List<ExpenseItem> draftExpenseItems;
  final double draftTotalAmount;
  final String paymentMethod;
  final String receiptLocalPath;
  final bool isSavingExpense;
  final bool isPickingReceipt;
  final String errorMessage;
  final String successMessage;

  final double totalBudget;
  final double spentBudget;
  final double remainingBudget;
  final double overspentBudget;
  final int sufficientDays;
  final String usedPercentageString;
  final double usedPercentageValue;
  final double shortageAmount;

  final String popupAction;

  const ActivityUiState({
    this.isLoading = false,
    this.tripId = '',
    this.currentActivityId = '',
    this.activities = const [],
    this.selectedActivity,
    this.draftExpenseItems = const [],
    this.draftTotalAmount = 0.0,
    this.paymentMethod = '',
    this.receiptLocalPath = '',
    this.isSavingExpense = false,
    this.isPickingReceipt = false,
    this.errorMessage = '',
    this.successMessage = '',
    this.totalBudget = 0.0,
    this.spentBudget = 0.0,
    this.remainingBudget = 0.0,
    this.overspentBudget = 0.0,
    this.sufficientDays = 0,
    this.usedPercentageString = '0% Used',
    this.usedPercentageValue = 0.0,
    this.shortageAmount = 0.0,
    this.popupAction = '',
  });

  ActivityUiState copyWith({
    bool? isLoading,
    String? tripId,
    String? currentActivityId,
    List<Activity>? activities,
    Activity? selectedActivity,
    List<ExpenseItem>? draftExpenseItems,
    double? draftTotalAmount,
    String? paymentMethod,
    String? receiptLocalPath,
    bool? isSavingExpense,
    bool? isPickingReceipt,
    String? errorMessage,
    String? successMessage,
    double? totalBudget,
    double? spentBudget,
    double? remainingBudget,
    double? overspentBudget,
    int? sufficientDays,
    String? usedPercentageString,
    double? usedPercentageValue,
    double? shortageAmount,
    String? popupAction,
  }) {
    return ActivityUiState(
      isLoading: isLoading ?? this.isLoading,
      tripId: tripId ?? this.tripId,
      currentActivityId: currentActivityId ?? this.currentActivityId,
      activities: activities ?? this.activities,
      selectedActivity: selectedActivity ?? this.selectedActivity,
      draftExpenseItems: draftExpenseItems ?? this.draftExpenseItems,
      draftTotalAmount: draftTotalAmount ?? this.draftTotalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptLocalPath: receiptLocalPath ?? this.receiptLocalPath,
      isSavingExpense: isSavingExpense ?? this.isSavingExpense,
      isPickingReceipt: isPickingReceipt ?? this.isPickingReceipt,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
      totalBudget: totalBudget ?? this.totalBudget,
      spentBudget: spentBudget ?? this.spentBudget,
      remainingBudget: remainingBudget ?? this.remainingBudget,
      overspentBudget: overspentBudget ?? this.overspentBudget,
      sufficientDays: sufficientDays ?? this.sufficientDays,
      usedPercentageString: usedPercentageString ?? this.usedPercentageString,
      usedPercentageValue: usedPercentageValue ?? this.usedPercentageValue,
      shortageAmount: shortageAmount ?? this.shortageAmount,
      popupAction: popupAction ?? this.popupAction,
    );
  }
}
