import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/entities/activity.dart';
import '../../models/entities/expense_item.dart';
import '../../models/local_data_source/camera_source.dart';
import '../../models/local_data_source/notification_source.dart';
import '../../models/repository/expense_repository.dart';
import '../../models/repository/i_expense_repository.dart';
import '../../models/services/budget_service.dart';
import '../../models/services/i_budget_service.dart';
import '../../models/services/expense_tracking_service.dart';
import '../../models/services/i_expense_tracking_service.dart';
import '../../models/services/itinerary_service.dart';
import '../../models/services/i_itinerary_service.dart';
import '../ui_state/activity_ui_state.dart';

class ActivityViewModel extends ChangeNotifier {
  static const int _eveningExpenseReviewReminderId = 200000;
  static const int _eveningReviewHour = 20;

  final IItineraryService _itineraryService;
  final IBudgetService _budgetService;
  final IExpenseTrackingService _expenseTrackingService;
  final IExpenseRepository _expenseRepository;
  final CameraSource _cameraSource = CameraSource();
  final NotificationSource _notificationSource = NotificationSource();

  ActivityViewModel({
    IItineraryService? itineraryService,
    IBudgetService? budgetService,
    IExpenseTrackingService? expenseTrackingService,
    IExpenseRepository? expenseRepository,
  }) : _itineraryService = itineraryService ?? ItineraryService(),
       _budgetService = budgetService ?? BudgetService(),
       _expenseTrackingService =
           expenseTrackingService ?? ExpenseTrackingService(),
       _expenseRepository = expenseRepository ?? ExpenseRepository() {
    initialize();
  }

  ActivityUiState _uiState = const ActivityUiState();

  ActivityUiState get uiState => _uiState;

  void selectActivityForExpense(Activity activity) {
    _uiState = _uiState.copyWith(
      selectedActivity: activity,
      currentActivityId: activity.activitiesId,
      draftExpenseItems: const [],
      draftTotalAmount: 0.0,
      paymentMethod: '',
      receiptLocalPath: '',
      clearOcrData: true,
      errorMessage: '',
      successMessage: '',
      recordedExpenses: const [],
      isLoadingRecordedExpenses: true,
      selectedRecordedExpenseItems: const [],
      isLoadingRecordedExpenseItems: false,
    );
    notifyListeners();

    loadRecordedExpensesForSelectedActivity();
  }

  /// Loads the confirmed Expense records for the currently selected Activity.
  Future<void> loadRecordedExpensesForSelectedActivity() async {
    final selectedActivity = _uiState.selectedActivity;
    if (selectedActivity == null) {
      _uiState = _uiState.copyWith(
        recordedExpenses: const [],
        isLoadingRecordedExpenses: false,
      );
      notifyListeners();
      return;
    }

    _uiState = _uiState.copyWith(
      isLoadingRecordedExpenses: true,
      errorMessage: '',
    );
    notifyListeners();

    try {
      final recordedExpenses = await _expenseRepository.getExpensesByActivityId(
        selectedActivity.activitiesId,
      );

      _uiState = _uiState.copyWith(
        recordedExpenses: recordedExpenses,
        isLoadingRecordedExpenses: false,
      );
    } catch (error) {
      _uiState = _uiState.copyWith(
        recordedExpenses: const [],
        isLoadingRecordedExpenses: false,
        errorMessage: _readableError(error),
      );
    }
    notifyListeners();
  }

  /// Loads the child items of one confirmed Expense for read-only display.
  Future<void> loadRecordedExpenseItems(String expenseId) async {
    _uiState = _uiState.copyWith(
      selectedRecordedExpenseItems: const [],
      isLoadingRecordedExpenseItems: true,
      errorMessage: '',
    );
    notifyListeners();

    try {
      final expenseItems = await _expenseRepository.getExpenseItemsByExpenseId(
        expenseId,
      );

      _uiState = _uiState.copyWith(
        selectedRecordedExpenseItems: expenseItems,
        isLoadingRecordedExpenseItems: false,
      );
    } catch (error) {
      _uiState = _uiState.copyWith(
        selectedRecordedExpenseItems: const [],
        isLoadingRecordedExpenseItems: false,
        errorMessage: _readableError(error),
      );
    }
    notifyListeners();
  }

  void addExpenseItem(ExpenseItem item) {
    _updateDraftExpenseItems([..._uiState.draftExpenseItems, item]);
  }

  void updateExpenseItem(int index, ExpenseItem item) {
    if (index < 0 || index >= _uiState.draftExpenseItems.length) {
      _setExpenseError('The expense item could not be found.');
      return;
    }

    final updatedItems = [..._uiState.draftExpenseItems];
    updatedItems[index] = item;
    _updateDraftExpenseItems(updatedItems);
  }

  void removeExpenseItem(int index) {
    if (index < 0 || index >= _uiState.draftExpenseItems.length) {
      _setExpenseError('The expense item could not be found.');
      return;
    }

    final updatedItems = [..._uiState.draftExpenseItems]..removeAt(index);
    _updateDraftExpenseItems(updatedItems);
  }

  /// Removes only unsaved draft items after the tourist agrees to replace them
  /// with OCR results. Confirmed Expense records are never changed here.
  void clearDraftExpenseItemsForOcr() {
    _uiState = _uiState.copyWith(
      draftExpenseItems: const [],
      draftTotalAmount: 0.0,
      errorMessage: '',
      successMessage: '',
    );
    notifyListeners();
  }

  void setPaymentMethod(String paymentMethod) {
    _uiState = _uiState.copyWith(
      paymentMethod: paymentMethod,
      errorMessage: '',
      successMessage: '',
    );
    notifyListeners();
  }

  Future<bool> takeReceiptPhoto() async {
    _uiState = _uiState.copyWith(
      isPickingReceipt: true,
      errorMessage: '',
      successMessage: '',
    );
    notifyListeners();

    try {
      final localPath = await _cameraSource.takePhoto();
      if (localPath == null) {
        _uiState = _uiState.copyWith(isPickingReceipt: false);
        notifyListeners();
        return false;
      }

      await _expenseTrackingService.validateReceiptImage(localPath);
      _uiState = _uiState.copyWith(
        isPickingReceipt: false,
        receiptLocalPath: localPath,
        clearOcrData: true,
      );
      notifyListeners();
      return true;
    } catch (error) {
      _uiState = _uiState.copyWith(
        isPickingReceipt: false,
        errorMessage: _readableError(error),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> chooseReceiptFromGallery() async {
    _uiState = _uiState.copyWith(
      isPickingReceipt: true,
      errorMessage: '',
      successMessage: '',
    );
    notifyListeners();

    try {
      final localPath = await _cameraSource.pickPhotoFromGallery();
      if (localPath == null) {
        _uiState = _uiState.copyWith(isPickingReceipt: false);
        notifyListeners();
        return false;
      }

      await _expenseTrackingService.validateReceiptImage(localPath);
      _uiState = _uiState.copyWith(
        isPickingReceipt: false,
        receiptLocalPath: localPath,
        clearOcrData: true,
      );
      notifyListeners();
      return true;
    } catch (error) {
      _uiState = _uiState.copyWith(
        isPickingReceipt: false,
        errorMessage: _readableError(error),
      );
      notifyListeners();
      return false;
    }
  }

  /// Replaces the temporary receipt path only when the tourist finishes the
  /// device crop flow. Cancelling leaves the validated original image in use.
  Future<void> cropSelectedReceipt() async {
    final originalPath = _uiState.receiptLocalPath;
    if (originalPath.isEmpty) {
      _setExpenseError('Choose a receipt image before cropping it.');
      return;
    }

    _uiState = _uiState.copyWith(isPickingReceipt: true, errorMessage: '');
    notifyListeners();

    try {
      final croppedPath = await _cameraSource.cropReceiptImage(originalPath);
      if (croppedPath != null) {
        await _expenseTrackingService.validateReceiptImage(croppedPath);
      }
      _uiState = _uiState.copyWith(
        isPickingReceipt: false,
        receiptLocalPath: croppedPath ?? originalPath,
        clearOcrData: croppedPath != null,
      );
    } catch (error) {
      _uiState = _uiState.copyWith(
        isPickingReceipt: false,
        errorMessage: _readableError(error),
      );
    }
    notifyListeners();
  }

  void removeReceipt() {
    _uiState = _uiState.copyWith(receiptLocalPath: '', clearOcrData: true);
    notifyListeners();
  }

  /// Replaces the current unsaved items with all item rows detected by OCR.
  /// These remain editable drafts until the tourist confirms the Expense.
  int applyOcrItemsToDraft() {
    if (_uiState.ocrRawText.isEmpty) {
      return 0;
    }

    final expenseItems = _expenseTrackingService.buildDraftExpenseItemsFromReceipt(
      receiptText: _uiState.ocrRawText,
      merchantName: _uiState.ocrMerchantName,
      transactionDateTime: _uiState.ocrTransactionDateTime,
    );
    if (expenseItems.isEmpty) {
      return 0;
    }

    _updateDraftExpenseItems(expenseItems);
    return expenseItems.length;
  }

  /// Scans the selected receipt and keeps the extracted values temporary until
  /// the tourist has reviewed and confirmed the whole expense.
  Future<void> scanReceipt() async {
    final receiptLocalPath = _uiState.receiptLocalPath;
    if (receiptLocalPath.isEmpty) {
      _setExpenseError('Choose a receipt image before scanning it.');
      return;
    }

    _uiState = _uiState.copyWith(
      isScanningReceipt: true,
      errorMessage: '',
      successMessage: '',
    );
    notifyListeners();

    try {
      final receiptText = await _expenseTrackingService.readReceiptText(
        receiptLocalPath,
      );
      debugPrint('Receipt OCR raw text:\n$receiptText');
      final extractedTotal = _expenseTrackingService.extractReceiptTotal(
        receiptText,
      );
      final extractedDateTime = _expenseTrackingService.extractReceiptDateTime(
        receiptText,
      );
      String extractedTotalError = '';

      if (extractedTotal != null) {
        try {
          _expenseTrackingService.validateTotalAmount(extractedTotal);
        } on ArgumentError {
          extractedTotalError =
              'The extracted amount is invalid. Please correct it.';
        }
      }

      _uiState = _uiState.copyWith(
        isScanningReceipt: false,
        ocrRawText: receiptText,
        ocrMerchantName:
            _expenseTrackingService.extractMerchantName(receiptText) ?? '',
        ocrTransactionDateTime: extractedDateTime,
        clearOcrTransactionDateTime: extractedDateTime == null,
        ocrExtractedTotal: extractedTotal,
        clearOcrExtractedTotal: extractedTotal == null,
        ocrItemLines: _expenseTrackingService.extractReceiptItemLines(
          receiptText,
        ),
        errorMessage: extractedTotalError,
      );
    } catch (error) {
      _uiState = _uiState.copyWith(
        isScanningReceipt: false,
        errorMessage: _readableError(error),
      );
    }
    notifyListeners();
  }

  void clearExpenseMessage() {
    _uiState = _uiState.copyWith(errorMessage: '', successMessage: '');
    notifyListeners();
  }

  /// Validates the current draft before the View displays the final
  /// confirmation dialog. Invalid drafts must not ask the tourist to confirm.
  bool validateExpenseDraftBeforeConfirmation() {
    try {
      _expenseTrackingService.validateExpenseItems(_uiState.draftExpenseItems);
      _expenseTrackingService.validateTotalAmount(_uiState.draftTotalAmount);
      return true;
    } catch (error) {
      _setExpenseError(_readableError(error));
      return false;
    }
  }

  Future<void> confirmExpense() async {
    final selectedActivity = _uiState.selectedActivity;
    if (selectedActivity == null) {
      _setExpenseError('Select an activity before recording an expense.');
      return;
    }

    _uiState = _uiState.copyWith(
      isSavingExpense: true,
      errorMessage: '',
      successMessage: '',
    );
    notifyListeners();

    final expenseAmount = _uiState.draftTotalAmount;

    try {
      await _expenseTrackingService.recordExpense(
        activitiesId: selectedActivity.activitiesId,
        expenseItems: _uiState.draftExpenseItems,
        paymentMethod: _uiState.paymentMethod.isEmpty
            ? null
            : _uiState.paymentMethod,
        receiptLocalPath: _uiState.receiptLocalPath.isEmpty
            ? null
            : _uiState.receiptLocalPath,
      );

      final updatedTrip = await _budgetService.deductRemainingBudget(
        tripId: _uiState.tripId,
        expenseAmount: expenseAmount,
      );

      await _cancelActivityExpenseReminder(selectedActivity);
      unawaited(_scheduleEveningExpenseReviewReminder(_uiState.activities));

      _uiState = _uiState.copyWith(
        isSavingExpense: false,
        draftExpenseItems: const [],
        draftTotalAmount: 0.0,
        paymentMethod: '',
        receiptLocalPath: '',
        clearOcrData: true,
        successMessage: 'The expense record has been successfully saved.',
        totalBudget: updatedTrip.totalBudget,
        spentBudget:
            updatedTrip.totalBudget - (updatedTrip.remainingBalance ?? 0.0),
      );
      await loadRecordedExpensesForSelectedActivity();

      // detect overspend
      await handleExpenseSubmission();
    } catch (error) {
      _uiState = _uiState.copyWith(
        isSavingExpense: false,
        errorMessage: _readableError(error),
      );
    }
    notifyListeners();
  }

  void _updateDraftExpenseItems(List<ExpenseItem> items) {
    final itemsWithCalculatedSubtotals = items
        .map(
          (item) => item.copyWith(
            subtotal: _expenseTrackingService.calculateItemSubtotal(
              item.quantity,
              item.unitPrice,
            ),
          ),
        )
        .toList();

    _uiState = _uiState.copyWith(
      draftExpenseItems: itemsWithCalculatedSubtotals,
      draftTotalAmount: _expenseTrackingService.calculateTotalExpense(
        itemsWithCalculatedSubtotals,
      ),
      errorMessage: '',
      successMessage: '',
    );
    notifyListeners();
  }

  void _setExpenseError(String message) {
    _uiState = _uiState.copyWith(errorMessage: message, successMessage: '');
    notifyListeners();
  }

  String _readableError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }

  Future<void> initialize({DateTime? filterDate}) async {
    _uiState = _uiState.copyWith(
      isLoading: true,
      filterDate: filterDate,
      clearFilterDate: filterDate == null,
    );
    notifyListeners();

    try {
      final result = await _itineraryService.fetchLatestTrip();

      if (result != null) {
        final days = await _budgetService.calculateSufficientDays(
          result.trip.tripId!,
          result.activities.first.activitiesId,
        );

        debugPrint("days ${days}");

        _uiState = _uiState.copyWith(
          isLoading: false,
          tripId: result.trip.tripId,
          activities: result.activities,
          totalBudget: result.trip.totalBudget,
          sufficientDays: days,
        );
        unawaited(_prepareExpenseReminders(result.activities));
      } else {
        _uiState = _uiState.copyWith(isLoading: false);
      }
    } catch (e) {
      _uiState = _uiState.copyWith(isLoading: false);
      debugPrint('Error in ActivityViewModel.initialize: $e');
    }
    notifyListeners();
  }

  Future<void> loadTripItinerary(String tripId, {DateTime? filterDate}) async {

    final now = DateTime.now();
    final targetDate = filterDate ?? DateTime(now.year, now.month, now.day);
    _uiState = _uiState.copyWith(
      isLoading: true,
      tripId: tripId,
      filterDate: targetDate,
      activities: const [],
      spentBudget: 0.0,
      totalBudget: 0.0,
      overspentBudget: 0.0,
      sufficientDays: 0,
      errorMessage: '',
    );
    notifyListeners();

    try {
      final allActivities = await _itineraryService.fetchAllActivitiesByTrip(tripId);
      final tripResult = await _itineraryService.fetchLatestTrip();

      // 1. Calculate the initial spent budget across all activities
      double totalSpent = 0.0;
      for(final act in allActivities) {
        final expenses = await _expenseRepository.getExpensesByActivityId(act.activitiesId);
        for (final exp in expenses) {
          totalSpent += exp.totalAmount;
        }
      }

      // 2. Calculate initial overspent amount from trip days
      final days = await _itineraryService.getDaysByTripId(tripId);
      double totalOverspend = 0.0;
      for (final day in days) {
        totalOverspend += (day.overspendAmount ?? 0.0);
      }

      // 3. Calculate initial sufficient days
      int initialSufficientDays = 0;
      if(allActivities.isNotEmpty) {
        initialSufficientDays = await _budgetService.calculateSufficientDays(tripId, allActivities.first.activitiesId);
      }

      _uiState = _uiState.copyWith(
        isLoading: false,
        activities: allActivities,
        totalBudget: tripResult?.trip.totalBudget ?? _uiState.totalBudget,
        spentBudget: totalSpent,
        overspentBudget: totalOverspend,
        sufficientDays: initialSufficientDays,
        filterDate: targetDate,
        tripId: tripId,
      );
      unawaited(_prepareExpenseReminders(allActivities));
    } catch (e) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  /// Requests notification and exact-alarm permission, then prepares the
  /// activity-end and evening expense-review reminders.
  Future<void> _prepareExpenseReminders(List<Activity> activities) async {
    try {
      final hasNotificationPermission = await _notificationSource
          .requestPermission();
      if (!hasNotificationPermission) {
        debugPrint(
          '[Expense reminder] Notification permission was not granted.',
        );
        return;
      }

      final hasExactAlarmPermission = await _notificationSource
          .requestExactAlarmPermission();
      if (!hasExactAlarmPermission) {
        debugPrint(
          '[Expense reminder] Exact-alarm permission was not granted.',
        );
        return;
      }

      await _scheduleActivityEndExpenseReminders(activities);
      await _scheduleEveningExpenseReviewReminder(activities);
    } catch (error) {
      debugPrint('[Expense reminder] Unable to prepare reminders: $error');
    }
  }

  /// Schedules one reminder for each future activity that has no confirmed
  /// expense yet. This method is intentionally best-effort: notification
  /// setup must never stop the daily plan from loading.
  Future<void> _scheduleActivityEndExpenseReminders(
    List<Activity> activities,
  ) async {
    for (final activity in activities) {
      final reminderTime = _activityEndDateTime(activity);
      if (reminderTime == null || !reminderTime.isAfter(DateTime.now())) {
        continue;
      }

      try {
        final recordedExpenses = await _expenseRepository
            .getExpensesByActivityId(activity.activitiesId);
        final reminderId = _activityReminderId(activity.activitiesId);

        if (recordedExpenses.isNotEmpty) {
          await _notificationSource.cancelExpenseReminder(reminderId);
          continue;
        }

        await _notificationSource.scheduleExpenseReminder(
          id: reminderId,
          scheduledAt: reminderTime,
          title: 'Expense reminder',
          body:
              'Did you spend at ${activity.destination}? '
              'Record your expense now.',
          payload: activity.activitiesId,
        );
      } catch (error) {
        debugPrint(
          'Unable to schedule the expense reminder for '
          '${activity.activitiesId}: $error',
        );
      }
    }
  }

  /// Schedules one 8 PM summary for today's completed activities that still
  /// have no confirmed expense. The count is refreshed after every successful
  /// expense record so the reminder does not use a stale number.
  Future<void> _scheduleEveningExpenseReviewReminder(
    List<Activity> activities,
  ) async {
    final now = DateTime.now();
    final reviewTime = DateTime(
      now.year,
      now.month,
      now.day,
      _eveningReviewHour,
    );

    if (!reviewTime.isAfter(now)) {
      return;
    }

    var activitiesWithoutExpenses = 0;
    for (final activity in activities) {
      final activityEnd = _activityEndDateTime(activity);
      final isToday = _isSameDate(activity.date, now);
      if (!isToday || activityEnd == null || activityEnd.isAfter(reviewTime)) {
        continue;
      }

      try {
        final recordedExpenses = await _expenseRepository
            .getExpensesByActivityId(activity.activitiesId);
        if (recordedExpenses.isEmpty) {
          activitiesWithoutExpenses++;
        }
      } catch (error) {
        debugPrint(
          'Unable to check the evening expense reminder for '
          '${activity.activitiesId}: $error',
        );
      }
    }

    try {
      if (activitiesWithoutExpenses == 0) {
        await _notificationSource.cancelExpenseReminder(
          _eveningExpenseReviewReminderId,
        );
        return;
      }

      final activityLabel = activitiesWithoutExpenses == 1
          ? 'activity'
          : 'activities';
      await _notificationSource.scheduleExpenseReminder(
        id: _eveningExpenseReviewReminderId,
        scheduledAt: reviewTime,
        title: 'Expense review reminder',
        body:
            'You have $activitiesWithoutExpenses $activityLabel without '
            'recorded expenses today. Today ends in 4 hours. '
            'Review your expenses.',
        payload: 'evening_expense_review',
      );
    } catch (error) {
      debugPrint('Unable to schedule the evening expense reminder: $error');
    }
  }

  /// Cancels the selected activity's future reminder after persistence succeeds.
  Future<void> _cancelActivityExpenseReminder(Activity activity) async {
    try {
      await _notificationSource.cancelExpenseReminder(
        _activityReminderId(activity.activitiesId),
      );
    } catch (error) {
      debugPrint(
        'Unable to cancel the expense reminder for '
        '${activity.activitiesId}: $error',
      );
    }
  }

  /// Combines the database activity date with a stored HH:mm end time.
  /// Activities without a valid end time cannot have an end-time reminder.
  DateTime? _activityEndDateTime(Activity activity) {
    final endTime = activity.endTime;
    if (endTime == null || endTime.trim().isEmpty) {
      return null;
    }

    final timeParts = endTime.trim().split(':');
    if (timeParts.length < 2) {
      return null;
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return DateTime(
      activity.date.year,
      activity.date.month,
      activity.date.day,
      hour,
      minute,
    );
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  /// Produces a stable device notification ID from the team's AC#### ID.
  int _activityReminderId(String activityId) {
    final numericPart = activityId.replaceAll(RegExp(r'[^0-9]'), '');
    final activityNumber = int.tryParse(numericPart) ?? 0;
    return 100000 + activityNumber;
  }

  void setDateFilter(DateTime? filterDate) {
    _uiState = _uiState.copyWith(
      filterDate: filterDate,
      clearFilterDate: filterDate == null,
    );
    notifyListeners();
  }

  void clearDateFilter() {
    _uiState = _uiState.copyWith(clearFilterDate: true);
    notifyListeners();
  }

  Future<void> endTrip() async {
    final id = _uiState.tripId;

    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final update = await _itineraryService.endTrip(id);

      if (update) {
        _uiState = _uiState.copyWith(isLoading: false, tripId: '');
      }
    } catch (e) {
      _uiState = _uiState.copyWith(isLoading: false);
    }

    notifyListeners();
  }

  Future<bool> topUpBudget(double additionalAmount) async {
    debugPrint("Top up Budget");
    if (additionalAmount <= 0) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Please enter a top-up amount greater than RM0.00.',
      );
      notifyListeners();
      return false;
    }

    final tripId = _uiState.tripId;
    final activityId = _uiState.currentActivityId;

    _uiState = _uiState.copyWith(
      isLoading: true,
      errorMessage: '',
    );
    notifyListeners();

    try {
      final updatedTrip = await _budgetService.topUpBudget(
        tripId: tripId,
        currentActivityId: activityId,
        topupAmount: additionalAmount,
      );

      debugPrint('updated trip ${updatedTrip}');

      if (updatedTrip != null) {
        // Recalculate sufficient days after top-up.
        final days = await _budgetService.calculateSufficientDays(
          updatedTrip.tripId!,
          activityId,
        );

        // Calculate the NEW shortage.
        final double newShortageAmount =
        (_uiState.shortageAmount - additionalAmount)
            .clamp(0.0, double.infinity);

        debugPrint('========== TOP UP ==========');
        debugPrint('Previous shortage: ${_uiState.shortageAmount}');
        debugPrint('Top-up amount: $additionalAmount');
        debugPrint('New shortage: $newShortageAmount');
        debugPrint('Sufficient days: $days');
        debugPrint('============================');

        _uiState = _uiState.copyWith(
          isLoading: false,
          totalBudget: updatedTrip.totalBudget,
          shortageAmount: newShortageAmount,
          sufficientDays: days,
          errorMessage: '',
        );

        // // Top-up is still insufficient.
        // if (newShortageAmount > 0.00) {
        //   _uiState = _uiState.copyWith(
        //     popupAction: 'insufficientTopUp',
        //   );
        //
        //   debugPrint(
        //     'Top-up insufficient. Remaining shortage: $newShortageAmount',
        //   );
        // } else {
        //   // Shortage has been fully covered.
        //   _uiState = _uiState.copyWith(
        //     popupAction: '',
        //   );
        //
        //   debugPrint('Shortage fully covered.');
        // }

        notifyListeners();
        return true;
      }

      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to top up budget. Please try again.',
      );

      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Top-up error: $e');

      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Unable to top up budget. Please try again.',
      );

      notifyListeners();
      return false;
    }
  }

  Future<void> handleExpenseSubmission() async {
    debugPrint("zq handleExpenseSubmission");

    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final response = await _expenseTrackingService.processExpense(
        tripId: _uiState.tripId,
        currentActivityId: _uiState.currentActivityId,
      );

      debugPrint("result: ${response}");

      final days = await _itineraryService.getDaysByTripId(_uiState.tripId);

      double overspend = 0.00;

      for (var day in days) {
        overspend += day.overspendAmount!;
      }

      final activities = await _itineraryService.getRemainingActivities(
        _uiState.tripId,
        DateTime.now(),
      );

      var shortageAmount = 0.0;
      for (var ad in activities) {
        shortageAmount += ad.allocatedBudget;
      }

      final sufficientDays = await _budgetService.calculateSufficientDays(
        _uiState.tripId,
        _uiState.currentActivityId,
      );

      final exceededAmount = await _expenseTrackingService.getExceededAmount(_uiState.tripId, _uiState.currentActivityId);

      _uiState = _uiState.copyWith(
        overspentBudget: overspend,
        shortageAmount: shortageAmount,
        sufficientDays: sufficientDays,
        exceededAmount: exceededAmount
      );

      switch (response) {
        case ExpenseProcessingResult.withinBudget:
          _uiState = _uiState.copyWith(popupAction: '');
          break;

        case ExpenseProcessingResult.reallocatedSuccessfully:
          _uiState = _uiState.copyWith(popupAction: 'successful');
          break;

        case ExpenseProcessingResult.reallocatedFailed:
          _uiState = _uiState.copyWith(popupAction: 'fail');
          break;

        case ExpenseProcessingResult.exceedsThresholdTriggerRecommendation:
          _uiState = _uiState.copyWith(popupAction: 'recommendation');
          break;

        case ExpenseProcessingResult.critical:
          _uiState = _uiState.copyWith(popupAction: 'critical');
          break;
      }
    } catch (e) {
      debugPrint("Error handling expense submission: $e");

      _uiState = _uiState.copyWith(isLoading: false);
    } finally {
      _uiState = _uiState.copyWith(isLoading: false);

      notifyListeners();
    }
  }

  void clearPopupAction() {
    _uiState = _uiState.copyWith(popupAction: '');
    notifyListeners();
  }

  Future<bool> generateBudgetRecoveryPlan({
    String? dayTripId,
    double? availableBudget,
  }) async {
    final tripId = _uiState.tripId;
    if (tripId.isEmpty) {
      _uiState = _uiState.copyWith(
        errorMessage: 'Cannot generate recovery plan without an active trip.',
      );
      notifyListeners();
      return false;
    }

    _uiState = _uiState.copyWith(
      isLoading: true,
      errorMessage: '',
      popupAction: '',
    );
    notifyListeners();

    try {
      // 1. Filter remaining activities for today and future days
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final remainingActivities = _uiState.activities.where((act) {
        final actDate = DateTime(act.date.year, act.date.month, act.date.day);
        return actDate.isAtSameMomentAs(today) || actDate.isAfter(today);
      }).toList();

      // 2. Call itinerary service to generate budget recovery plan
      final recoveryActivities =
      await _itineraryService.generateBudgetRecoveryItinerary(
        tripId: tripId,
        newTotalBudget: availableBudget ?? _uiState.totalBudget,
        currentSpentBudget: _uiState.spentBudget,
        topUpAmount: _uiState.exceededAmount ?? 0.0,
        remainingActivities: remainingActivities,
        tripDestination: _uiState.selectedActivity?.destination ?? '',
        currentDate: _uiState.filterDate ?? today,
      );

      // 3. Recalculate trip status & budget indicators
      final allActivities =
      await _itineraryService.fetchAllActivitiesByTrip(tripId);
      final days = await _itineraryService.getDaysByTripId(tripId);

      double totalOverspend = 0.0;
      for (final day in days) {
        totalOverspend += (day.overspendAmount ?? 0.0);
      }

      int recalculatedSufficientDays = 0;
      final activeList =
      allActivities.isNotEmpty ? allActivities : recoveryActivities;
      if (activeList.isNotEmpty) {
        recalculatedSufficientDays = await _budgetService.calculateSufficientDays(
          tripId,
          activeList.first.activitiesId,
        );
      }

      // 4. Update ActivityUiState using only its valid fields
      _uiState = _uiState.copyWith(
        isLoading: false,
        activities: activeList,
        totalBudget: availableBudget ?? _uiState.totalBudget,
        overspentBudget: totalOverspend,
        shortageAmount: 0.0,
        sufficientDays: recalculatedSufficientDays,
        popupAction: '',
        errorMessage: '',
      );

      // 5. Reschedule local reminders for newly adjusted activities
      unawaited(_prepareExpenseReminders(_uiState.activities));

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in generateBudgetRecoveryPlan: $e');
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Failed to generate recovery plan: ${_readableError(e)}',
      );
      notifyListeners();
      return false;
    }
  }
}
