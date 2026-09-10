import '../../models/entities/activity.dart';
export '../../models/entities/activity.dart';
import '../../models/entities/expense.dart';
import '../../models/entities/expense_item.dart';


class ActivityUiState {
  final bool isLoading;
  final String tripId;
  final String currentActivityId;
  final List<Activity> activities;
  final List<Activity> allActivities;
  final List<DateTime> availableDates;
  final DateTime? filterDate;
  final String tripDestination;

  // Temporary Add Expense form data.
  final Activity? selectedActivity;
  final List<ExpenseItem> draftExpenseItems;
  final double draftTaxAmount;
  final double draftTotalAmount;
  final String originalCurrency;
  final List<String> availableCurrencies;
  final bool isConverting;
  final double? convertedAmount;
  final String? displayCurrency;
  final String? currencyError;
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

  /// One-off message shown to the tourist after a record that makes an activity
  /// nearly / already overspent (paired with a vibration). Empty when none.
  final String budgetAlertMessage;

  const ActivityUiState({
    this.isLoading = false,
    this.tripId = '',
    this.currentActivityId = '',
    this.activities = const [],
    this.allActivities = const [],
    this.availableDates = const [],
    this.filterDate,
    this.tripDestination = '',
    this.selectedActivity,
    this.draftExpenseItems = const [],
    this.draftTaxAmount = 0.0,
    this.draftTotalAmount = 0.0,
    this.originalCurrency = '',
    this.availableCurrencies = const [],
    this.isConverting = false,
    this.convertedAmount,
    this.displayCurrency,
    this.currencyError,
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
    this.budgetAlertMessage = '',

  });

  double get itemsSubtotal =>
      draftExpenseItems.fold(0.0, (total, item) => total + item.subtotal);

  double get usedPercentageValue => totalBudget <= 0 ? 0.0 : (spentBudget / totalBudget).clamp(0.0, 1.0);

  String get usedPercentageString => totalBudget <= 0
      ? '0% Used'
      : '${((spentBudget / totalBudget).clamp(0.0, 1.0) * 100).toStringAsFixed(0)}% Used';

  double get remainingBudget => totalBudget - spentBudget;

  int get currentDayIndex {
    if (filterDate == null || availableDates.isEmpty) return -1;
    final target = filterDate!;
    return availableDates.indexWhere((d) =>
    d.year == target.year && d.month == target.month && d.day == target.day);
  }

  bool get canGoToPreviousDay => currentDayIndex > 0;

  bool get canGoToNextDay {
    return currentDayIndex >= 0 && currentDayIndex < availableDates.length - 1;
  }

  String get dayLabel {
    if (availableDates.isEmpty) return '';
    final idx = currentDayIndex;
    if (idx < 0) return '';
    return 'Day ${idx + 1} of ${availableDates.length}';
  }

  // Computed Getter automatically filters activities
  List<Activity> get displayActivities {
    final target = filterDate?.toLocal();

    final filtered = target == null
        ? List<Activity>.from(activities)
        : activities.where((a) {
      final localActDate = a.date.toLocal();
      return localActDate.year == target.year &&
          localActDate.month == target.month &&
          localActDate.day == target.day;
    }).toList();

    filtered.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;

      final aTime = a.startTime ?? '00:00';
      final bTime = b.startTime ?? '00:00';
      return aTime.compareTo(bTime);
    });

    return filtered;
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'currentActivityId': currentActivityId,
      'tripDestination': tripDestination,
      'filterDate': filterDate?.toIso8601String(),
      'totalBudget': totalBudget,
      'spentBudget': spentBudget,
      'overspentBudget': overspentBudget,
      'sufficientDays': sufficientDays,
      'shortageAmount': shortageAmount,
      'exceededAmount': exceededAmount,
      'activitySpentMap': activitySpentMap,
      // Use .toMap() to mirror .fromMap()
      'activities': activities.map((a) => a.toJson()).toList(),
      'allActivities': allActivities.map((a) => a.toJson()).toList(),
      'availableDates': availableDates.map((d) => d.toIso8601String()).toList(),
      'recordedExpenses': recordedExpenses.map((e) => e.toJson()).toList(),
    };
  }

  factory ActivityUiState.fromMap(Map<String, dynamic> map) {
    return ActivityUiState(
      tripId: map['tripId'] ?? '',
      currentActivityId: map['currentActivityId'] ?? '',
      tripDestination: map['tripDestination'] ?? '',
      filterDate: map['filterDate'] != null
          ? DateTime.tryParse(map['filterDate'])
          : null,
      totalBudget: (map['totalBudget'] as num?)?.toDouble() ?? 0.0,
      spentBudget: (map['spentBudget'] as num?)?.toDouble() ?? 0.0,
      overspentBudget: (map['overspentBudget'] as num?)?.toDouble() ?? 0.0,
      sufficientDays: (map['sufficientDays'] as num?)?.toInt() ?? 0,
      shortageAmount: (map['shortageAmount'] as num?)?.toDouble() ?? 0.0,
      exceededAmount: (map['exceededAmount'] as num?)?.toDouble() ?? 0.0,
      activitySpentMap: (map['activitySpentMap'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
      ) ??
          const {},
      activities: (map['activities'] as List<dynamic>?)
          ?.map((item) => Activity.fromJson(item as Map<String, dynamic>))
          .toList() ??
          const [],
      allActivities: (map['allActivities'] as List<dynamic>?)
          ?.map((item) => Activity.fromJson(item as Map<String, dynamic>))
          .toList() ??
          const [],
      availableDates: (map['availableDates'] as List<dynamic>?)
          ?.map((item) => DateTime.parse(item as String))
          .toList() ??
          const [],
      recordedExpenses: (map['recordedExpenses'] as List<dynamic>?)
          ?.map((item) => Expense.fromJson(item as Map<String, dynamic>))
          .toList() ??
          const [],
    );
  }

  ActivityUiState copyWith({
    bool? isLoading,
    String? tripId,
    String? currentActivityId,
    List<Activity>? activities,
    List<Activity>? allActivities,
    List<DateTime>? availableDates,
    DateTime? filterDate,
    String? tripDestination,
    bool clearFilterDate = false,
    Activity? selectedActivity,
    List<ExpenseItem>? draftExpenseItems,
    double? draftTaxAmount,
    double? draftTotalAmount,
    String? originalCurrency,
    List<String>? availableCurrencies,
    bool? isConverting,
    double? convertedAmount,
    String? displayCurrency,
    String? currencyError,
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
    String? budgetAlertMessage,
  }) {
    return ActivityUiState(
      isLoading: isLoading ?? this.isLoading,
      tripId: tripId ?? this.tripId,
      currentActivityId: currentActivityId ?? this.currentActivityId,
      activities: activities ?? this.activities,
      allActivities: allActivities ?? this.allActivities,
      availableDates: availableDates ?? this.availableDates,
      filterDate: clearFilterDate ? null : (filterDate ?? this.filterDate),
      tripDestination: tripDestination ?? this.tripDestination,
      selectedActivity: selectedActivity ?? this.selectedActivity,
      draftExpenseItems: draftExpenseItems ?? this.draftExpenseItems,
      draftTaxAmount: draftTaxAmount ?? this.draftTaxAmount,
      draftTotalAmount: draftTotalAmount ?? this.draftTotalAmount,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      availableCurrencies: availableCurrencies ?? this.availableCurrencies,
      isConverting: isConverting ?? this.isConverting,
      convertedAmount: convertedAmount ?? this.convertedAmount,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      currencyError: currencyError ?? this.currencyError,
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
      budgetAlertMessage: budgetAlertMessage ?? this.budgetAlertMessage,
    );
  }
}