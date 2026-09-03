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
  final String tripDestination;

  // Temporary Add Expense form data.
  final Activity? selectedActivity;
  final List<ExpenseItem> draftExpenseItems;
  final double draftTaxAmount;
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
  final double? ocrExtractedTax;
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
  final double shortageAmount;
  final double exceededAmount;
  final Map<String, double> activitySpentMap;
  final String popupAction;

  const ActivityUiState({
    this.isLoading = false,
    this.tripId = '',
    this.currentActivityId = '',
    this.activities = const [],
    this.filterDate,
    this.tripDestination = '',
    this.selectedActivity,
    this.draftExpenseItems = const [],
    this.draftTaxAmount = 0.0,
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
    this.ocrExtractedTax,
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
    this.shortageAmount = 0.00,
    this.exceededAmount = 0.00,
    this.activitySpentMap = const {},
    this.popupAction = '',

  });

  double get itemsSubtotal =>
      draftExpenseItems.fold(0.0, (total, item) => total + item.subtotal);

  double get usedPercentageValue => totalBudget <= 0 ? 0.0 : (spentBudget / totalBudget).clamp(0.0, 1.0);

  String get usedPercentageString => totalBudget <= 0
      ? '0% Used'
      : '${((spentBudget / totalBudget).clamp(0.0, 1.0) * 100).toStringAsFixed(0)}% Used';

  double get remainingBudget => totalBudget - spentBudget;

  // Computed Getter automatically filters activities
  List<Activity> get displayActivities {
    final filtered = filterDate == null
        ? List<Activity>.from(activities)
        : activities.where((a) {
      return a.date.year == filterDate!.year &&
          a.date.month == filterDate!.month &&
          a.date.day == filterDate!.day;
    }).toList();

    // Sort chronologically by date and startTime
    filtered.sort((a, b) {
      // 1. Primary sort: Date
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;

      // 2. Secondary sort: startTime (e.g. "09:00", "10:30", "17:00")
      final aTime = a.startTime ?? '00:00';
      final bTime = b.startTime ?? '00:00';
      return aTime.compareTo(bTime);
    });

    return filtered;
  }


  ActivityUiState copyWith({
    bool? isLoading,
    String? tripId,
    String? currentActivityId,
    List<Activity>? activities,
    DateTime? filterDate,
    String? tripDestination,
    bool clearFilterDate = false,
    Activity? selectedActivity,
    List<ExpenseItem>? draftExpenseItems,
    double? draftTaxAmount,
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
    double? ocrExtractedTax,
    List<String>? ocrItemLines,
    bool clearOcrData = false,
    bool clearOcrTransactionDateTime = false,
    bool clearOcrExtractedTotal = false,
    bool clearOcrExtractedTax = false,
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
    Map<String, double>? activitySpentMap,
    String? popupAction,
  }) {
    return ActivityUiState(
      isLoading: isLoading ?? this.isLoading,
      tripId: tripId ?? this.tripId,
      currentActivityId: currentActivityId ?? this.currentActivityId,
      activities: activities ?? this.activities,
      filterDate: clearFilterDate ? null : (filterDate ?? this.filterDate),
      tripDestination: tripDestination ?? this.tripDestination,
      selectedActivity: selectedActivity ?? this.selectedActivity,
      draftExpenseItems: draftExpenseItems ?? this.draftExpenseItems,
      draftTaxAmount: draftTaxAmount ?? this.draftTaxAmount,
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
      ocrExtractedTax: clearOcrData || clearOcrExtractedTax
          ? null
          : ocrExtractedTax ?? this.ocrExtractedTax,
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
      shortageAmount: shortageAmount ?? this.shortageAmount,
      exceededAmount: exceededAmount ?? this.exceededAmount,
      activitySpentMap: activitySpentMap ?? this.activitySpentMap,
      popupAction: popupAction ?? this.popupAction,
    );
  }
}