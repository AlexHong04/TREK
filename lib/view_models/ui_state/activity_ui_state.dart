import '../../models/entities/activity.dart';
export '../../models/entities/activity.dart';
import '../../models/entities/expense.dart';
import '../../models/entities/expense_item.dart';

class ActivityUiState {
  final bool isLoading;
  final String tripId;
  final String currentActivityId;
  final List<Activity> activities;
  final DateTime? filterDate;

  // Temporary Add Expense form data.
  final Activity? selectedActivity;
  final List<ExpenseItem> draftExpenseItems;
  final double draftTotalAmount;
  final String paymentMethod;
  final String receiptLocalPath;
  final bool isSavingExpense;
  final bool isPickingReceipt;
  final bool isScanningReceipt;
  final String ocrRawText;
  final String ocrMerchantName;
  final DateTime? ocrTransactionDateTime;
  final double? ocrExtractedTotal;
  final List<String> ocrItemLines;
  final String errorMessage;
  final String successMessage;

  // Confirmed expenses already saved for the selected Activity.
  final List<Expense> recordedExpenses;
  final bool isLoadingRecordedExpenses;
  final List<ExpenseItem> selectedRecordedExpenseItems;
  final bool isLoadingRecordedExpenseItems;

  final double totalBudget;
  final double spentBudget;
  final double overspentBudget;
  final int sufficientDays;
  final String usedPercentageString;
  final double usedPercentageValue;
  final double shortageAmount;
  final double exceededAmount;

  final String popupAction;

  const ActivityUiState({
    this.isLoading = false,
    this.tripId = '',
    this.currentActivityId = '',
    this.activities = const [],
    this.filterDate,
    this.selectedActivity,
    this.draftExpenseItems = const [],
    this.draftTotalAmount = 0.0,
    this.paymentMethod = '',
    this.receiptLocalPath = '',
    this.isSavingExpense = false,
    this.isPickingReceipt = false,
    this.isScanningReceipt = false,
    this.ocrRawText = '',
    this.ocrMerchantName = '',
    this.ocrTransactionDateTime,
    this.ocrExtractedTotal,
    this.ocrItemLines = const [],
    this.errorMessage = '',
    this.successMessage = '',
    this.recordedExpenses = const [],
    this.isLoadingRecordedExpenses = false,
    this.selectedRecordedExpenseItems = const [],
    this.isLoadingRecordedExpenseItems = false,
    this.totalBudget = 0.0,
    this.spentBudget = 0.0,
    this.overspentBudget = 0.0,
    this.sufficientDays = 0,
    this.usedPercentageString = '0% Used',
    this.usedPercentageValue = 0.00,
    this.shortageAmount = 0.00,
    this.exceededAmount = 0.00,
    this.popupAction = '',
  });

  double get remainingBudget => totalBudget - spentBudget;

  double get usedPercentageValues => totalBudget <= 0 ? 0.0 : (spentBudget / totalBudget).clamp(0.0, 1.0);

  // Computed Getter automatically filters activities
  List<Activity> get displayActivities {
    if (filterDate == null) {
      return activities;
    }

    return activities.where((activity) {
      final actDate = activity.date;
      return actDate.year == filterDate!.year &&
          actDate.month == filterDate!.month &&
          actDate.day == filterDate!.day;
    }).toList();
  }

  ActivityUiState copyWith({
    bool? isLoading,
    String? tripId,
    String? currentActivityId,
    List<Activity>? activities,
    DateTime? filterDate,
    bool clearFilterDate = false,
    Activity? selectedActivity,
    List<ExpenseItem>? draftExpenseItems,
    double? draftTotalAmount,
    String? paymentMethod,
    String? receiptLocalPath,
    bool? isSavingExpense,
    bool? isPickingReceipt,
    bool? isScanningReceipt,
    String? ocrRawText,
    String? ocrMerchantName,
    DateTime? ocrTransactionDateTime,
    double? ocrExtractedTotal,
    List<String>? ocrItemLines,
    bool clearOcrData = false,
    bool clearOcrTransactionDateTime = false,
    bool clearOcrExtractedTotal = false,
    String? errorMessage,
    String? successMessage,
    List<Expense>? recordedExpenses,
    bool? isLoadingRecordedExpenses,
    List<ExpenseItem>? selectedRecordedExpenseItems,
    bool? isLoadingRecordedExpenseItems,
    double? totalBudget,
    double? spentBudget,
    double? overspentBudget,
    int? sufficientDays,
    String? usedPercentageString,
    double? usedPercentageValue,
    double? shortageAmount,
    double? exceededAmount,
    String? popupAction,
  }) {
    return ActivityUiState(
      isLoading: isLoading ?? this.isLoading,
      tripId: tripId ?? this.tripId,
      currentActivityId: currentActivityId ?? this.currentActivityId,
      activities: activities ?? this.activities,
      filterDate: clearFilterDate ? null : (filterDate ?? this.filterDate),
      selectedActivity: selectedActivity ?? this.selectedActivity,
      draftExpenseItems: draftExpenseItems ?? this.draftExpenseItems,
      draftTotalAmount: draftTotalAmount ?? this.draftTotalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptLocalPath: receiptLocalPath ?? this.receiptLocalPath,
      isSavingExpense: isSavingExpense ?? this.isSavingExpense,
      isPickingReceipt: isPickingReceipt ?? this.isPickingReceipt,
      isScanningReceipt: isScanningReceipt ?? this.isScanningReceipt,
      ocrRawText: clearOcrData ? '' : ocrRawText ?? this.ocrRawText,
      ocrMerchantName: clearOcrData
          ? ''
          : ocrMerchantName ?? this.ocrMerchantName,
      ocrTransactionDateTime: clearOcrData || clearOcrTransactionDateTime
          ? null
          : ocrTransactionDateTime ?? this.ocrTransactionDateTime,
      ocrExtractedTotal: clearOcrData || clearOcrExtractedTotal
          ? null
          : ocrExtractedTotal ?? this.ocrExtractedTotal,
      ocrItemLines: clearOcrData ? const [] : ocrItemLines ?? this.ocrItemLines,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
      recordedExpenses: recordedExpenses ?? this.recordedExpenses,
      isLoadingRecordedExpenses:
      isLoadingRecordedExpenses ?? this.isLoadingRecordedExpenses,
      selectedRecordedExpenseItems:
      selectedRecordedExpenseItems ?? this.selectedRecordedExpenseItems,
      isLoadingRecordedExpenseItems:
      isLoadingRecordedExpenseItems ?? this.isLoadingRecordedExpenseItems,
      totalBudget: totalBudget ?? this.totalBudget,
      spentBudget: spentBudget ?? this.spentBudget,
      overspentBudget: overspentBudget ?? this.overspentBudget,
      sufficientDays: sufficientDays ?? this.sufficientDays,
      usedPercentageString: usedPercentageString ?? this.usedPercentageString,
      usedPercentageValue: usedPercentageValue ?? this.usedPercentageValue,
      shortageAmount: shortageAmount ?? this.shortageAmount,
      exceededAmount: exceededAmount ?? this.exceededAmount,
      popupAction: popupAction ?? this.popupAction,
    );
  }
}