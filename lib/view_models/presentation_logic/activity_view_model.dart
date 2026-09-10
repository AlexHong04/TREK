import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/entities/expense_item.dart';
import '../../models/local_data_source/camera_source.dart';
import '../../models/local_data_source/gallery_source.dart';
import '../../models/local_data_source/notification_source.dart';
import '../../models/repository/expense_repository.dart';
import '../../models/repository/i_itinerary_repository.dart';
import '../../models/services/budget_service.dart';
import '../../models/services/i_auth_service.dart';
import '../../models/services/expense_tracking_service.dart';
import '../../models/services/itinerary_service.dart';
import '../../models/services/i_itinerary_service.dart';
import '../../models/local_data_source/location_source.dart';
import '../ui_state/activity_ui_state.dart';

class ActivityViewModel extends ChangeNotifier {
  static const String _expenseCurrency = 'MYR';
  static const int _eveningExpenseReviewReminderId = 200000;
  static const int _eveningReviewHour = 20;

  final IItineraryService _itineraryService;
  final IBudgetService _budgetService;
  final IExpenseTrackingService _expenseTrackingService;
  final IExpenseRepository _expenseRepository;
  final IAuthService _authService;
  final ICachedActivity _cachedActivity;
  final CameraSource _cameraSource = CameraSource();
  final GallerySource _gallerySource = GallerySource();
  final NotificationSource _notificationSource = NotificationSource();
  final LocationSource _locationSource = LocationSource();

  ActivityViewModel({
    IItineraryService? itineraryService,
    IBudgetService? budgetService,
    IExpenseTrackingService? expenseTrackingService,
    IExpenseRepository? expenseRepository,
    ICachedActivity? cachedActivity,
    required IAuthService authService,
  }) : _itineraryService = itineraryService ?? ItineraryService(),
       _budgetService =
           budgetService ?? BudgetService(authService: authService),
       _expenseTrackingService =
           expenseTrackingService ??
           ExpenseTrackingService(authService: authService),
       _expenseRepository = expenseRepository ?? ExpenseRepository(),
       _authService = authService,
       _cachedActivity = cachedActivity ?? GetCachedActivities() {
    _uiState = _uiState.copyWith(
      originalCurrency: _expenseCurrency,
      displayCurrency: _authService.preferredCurrency,
    );
    _loadAvailableCurrencies();
    _authService.addListener(_handleAuthChanged);
  }

  ActivityUiState _uiState = const ActivityUiState();

  ActivityUiState get uiState => _uiState;

  void _handleAuthChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthChanged);
    super.dispose();
  }

  void selectActivityForExpense(Activity activity) {
    _uiState = _uiState.copyWith(
      selectedActivity: activity,
      currentActivityId: activity.activitiesId,
      draftExpenseItems: const [],
      draftTotalAmount: 0.0,
      paymentMethod: '',
      originalCurrency: _expenseCurrency,
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
      draftTaxAmount: 0.0,
      draftTotalAmount: 0.0,
      errorMessage: '',
      successMessage: '',
    );
    notifyListeners();
  }

  void setDraftTaxAmount(double taxAmount) {
    final normalizedTax = taxAmount < 0 ? 0.0 : taxAmount;
    final total = _expenseTrackingService.calculateTotalExpense(
      _uiState.draftExpenseItems,
      normalizedTax,
    );
    _uiState = _uiState.copyWith(
      draftTaxAmount: normalizedTax,
      draftTotalAmount: total,
      errorMessage: '',
      successMessage: '',
    );
    notifyListeners();
  }

  void setOriginalCurrency(String currency) {
    _uiState = _uiState.copyWith(
      originalCurrency: currency.trim().toUpperCase(),
      currencyError: null,
    );
    notifyListeners();
  }

  Future<void> _loadAvailableCurrencies() async {
    try {
      final currencies = await _authService.getSupportedCurrencies();
      _uiState = _uiState.copyWith(availableCurrencies: currencies);
      notifyListeners();
    } catch (_) {
      _uiState = _uiState.copyWith(
        currencyError: 'Unable to load available currencies.',
      );
      notifyListeners();
    }
  }

  String get preferredCurrency => _authService.preferredCurrency;

  Future<void> convertAmount({
    required double amount,
    required String originalCurrency,
  }) async {
    _uiState = _uiState.copyWith(isConverting: true, currencyError: null);
    notifyListeners();
    final targetCurrency = _authService.preferredCurrency;
    try {
      final result = await _authService.convertToPreferredCurrency(
        amount: amount,
        fromCurrency: originalCurrency,
      );
      _uiState = _uiState.copyWith(
        convertedAmount: result,
        displayCurrency: result == null ? null : targetCurrency,
        currencyError: result == null
            ? 'The exchange rate is currently unavailable.'
            : null,
      );
    } catch (_) {
      _uiState = _uiState.copyWith(
        convertedAmount: null,
        displayCurrency: null,
        currencyError: 'Unable to convert the amount.',
      );
    } finally {
      _uiState = _uiState.copyWith(isConverting: false);
      notifyListeners();
    }
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
      final localPath = await _gallerySource.pickPhoto();
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

    final expenseItems = _expenseTrackingService
        .buildDraftExpenseItemsFromReceipt(
          receiptText: _uiState.ocrRawText,
          merchantName: _uiState.ocrMerchantName,
          transactionDateTime: _uiState.ocrTransactionDateTime,
        );
    if (expenseItems.isEmpty) {
      return 0;
    }

    final detectedTax =
        _uiState.ocrExtractedTax ?? _inferTaxFromReceiptTotal(expenseItems);
    _updateDraftExpenseItems(expenseItems, detectedTax);
    return expenseItems.length;
  }

  double _inferTaxFromReceiptTotal(List<ExpenseItem> expenseItems) {
    final hasTaxLabel = _uiState.ocrRawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim().toLowerCase())
        .any(
          (line) =>
              RegExp(
                r'\b(?:sales tax|service tax|govt tax|sst|gst)\b',
              ).hasMatch(line) &&
              !line.contains(' id') &&
              !line.contains(' no'),
        );
    if (!hasTaxLabel) {
      return 0.0;
    }

    final receiptTotal = _uiState.ocrExtractedTotal;
    if (receiptTotal == null) {
      return 0.0;
    }

    final itemsSubtotal = expenseItems.fold(
      0.0,
      (total, item) => total + item.subtotal,
    );
    final inferredTax = receiptTotal - itemsSubtotal;
    return inferredTax > 0 ? inferredTax : 0.0;
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
      final extractedTotal = _expenseTrackingService.extractReceiptTotal(
        receiptText,
      );
      final extractedTax = _expenseTrackingService.extractReceiptTax(
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
        originalCurrency: _expenseCurrency,
        ocrExtractedTotal: extractedTotal,
        clearOcrExtractedTotal: extractedTotal == null,
        ocrExtractedTax: extractedTax,
        clearOcrExtractedTax: extractedTax == null,
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
      if (_uiState.paymentMethod.trim().isEmpty) {
        throw ArgumentError('Please select a payment method.');
      }
      if (!RegExp(r'^[A-Z]{3}$').hasMatch(_uiState.originalCurrency)) {
        throw ArgumentError('Please select the original expense currency.');
      }
      _expenseTrackingService.validateTaxAmount(_uiState.draftTaxAmount);
      _expenseTrackingService.validateExpenseItems(_uiState.draftExpenseItems);
      _expenseTrackingService.validateTotalAmount(_uiState.draftTotalAmount);
      _expenseTrackingService.validateExpenseWithinRemainingBudget(
        totalAmount: _uiState.draftTotalAmount,
        remainingBudget: _uiState.remainingBudget,
      );
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

    if (_uiState.paymentMethod.trim().isEmpty) {
      _setExpenseError('Please select a payment method.');
      return;
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(_uiState.originalCurrency)) {
      _setExpenseError('Please select the original expense currency.');
      return;
    }

    try {
      _expenseTrackingService.validateTaxAmount(_uiState.draftTaxAmount);
      _expenseTrackingService.validateExpenseItems(_uiState.draftExpenseItems);
      _expenseTrackingService.validateTotalAmount(_uiState.draftTotalAmount);
      _expenseTrackingService.validateExpenseWithinRemainingBudget(
        totalAmount: _uiState.draftTotalAmount,
        remainingBudget: _uiState.remainingBudget,
      );
    } catch (error) {
      _setExpenseError(_readableError(error));
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
        paymentMethod: _uiState.paymentMethod.trim(),
        currency: _uiState.originalCurrency,
        taxAmount: _uiState.draftTaxAmount,
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
        draftTaxAmount: 0.0,
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

      // Dedicated near/overspent alert: store a message in the state and
      // vibrate, so the tourist is alerted on EVERY such expense record.
      await _alertIfNearOrOverBudget(selectedActivity);
    } catch (error) {
      _uiState = _uiState.copyWith(
        isSavingExpense: false,
        errorMessage: _readableError(error),
      );
    }
    notifyListeners();
  }

  /// Builds the dedicated budget-alert message when the activity is nearly /
  /// already overspent (mirrors the red card rule). Returns null otherwise.
  String? _budgetAlertMessageFor({
    required double spent,
    required double allocated,
  }) {
    if (spent > allocated) {
      return 'Budget exceeded for this activity (over its allocation).';
    }
    if (allocated > 0 && spent >= allocated * 0.80) {
      return 'Nearing your budget for this activity '
          '(${((spent / allocated) * 100).round()}% of allocation used).';
    }
    return null;
  }

  /// Publishes the budget-alert message (if any) and vibrates (double pulse).
  /// Best-effort: vibration failures are ignored so recording is never blocked.
  Future<void> _alertIfNearOrOverBudget(Activity? activity) async {
    if (activity == null) {
      _uiState = _uiState.copyWith(budgetAlertMessage: '');
      notifyListeners();
      return;
    }

    final spent = _uiState.activitySpentMap[activity.activitiesId] ?? 0.0;
    final message = _budgetAlertMessageFor(
      spent: spent,
      allocated: activity.allocatedBudget,
    );
    _uiState = _uiState.copyWith(budgetAlertMessage: message ?? '');
    notifyListeners();

    // Vibrate + play a notice sound on every near/over record so the tourist
    // is alerted without any in-app popup. The sound is delivered through the
    // same flutter_local_notifications channel used by the expense-reminder
    // notifications (which is why SystemSound alone was inaudible on Android).
    // Best-effort: failures are ignored.
    if (message == null) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await HapticFeedback.heavyImpact();

      final alertId = _budgetAlertId(activity.activitiesId);
      await _notificationSource.showBudgetAlert(
        id: alertId,
        title: 'Budget alert',
        body: message,
      );

      // Let the sound play, then remove the alert from the shade so repeated
      // records never leave a pile of notifications behind.
      unawaited(() async {
        await Future<void>.delayed(const Duration(seconds: 4));
        try {
          await _notificationSource.dismissBudgetAlert(alertId);
        } catch (_) {
          // ignore dismiss failures
        }
      }());
    } catch (_) {
      // ignore notification / vibration / sound failures
    }
  }

  /// Clears the one-off budget alert after it has been shown to the tourist.
  void clearBudgetAlert() {
    if (_uiState.budgetAlertMessage.isEmpty) return;
    _uiState = _uiState.copyWith(budgetAlertMessage: '');
    notifyListeners();
  }

  void _updateDraftExpenseItems(
    List<ExpenseItem> items, [
    double? newTaxAmount,
  ]) {
    final tax = newTaxAmount ?? _uiState.draftTaxAmount;
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
      draftTaxAmount: tax,
      draftTotalAmount: _expenseTrackingService.calculateTotalExpense(
        itemsWithCalculatedSubtotals,
        tax,
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

  Future<void> initialize({
    DateTime? filterDate,
    bool forceRefresh = false,
  }) async {
    debugPrint("initialize");
    // try to read the latest trip state from the local storage first
    if (!forceRefresh) {
      try {
        final cachedState = await _cachedActivity.getActivitiesForTrip(
          'latest_ongoing_trip',
        );
        if (cachedState.isNotEmpty) {
          _uiState = _uiState.copyWith(
            isLoading: false,
            activities: cachedState,
            filterDate: filterDate,
            clearFilterDate: filterDate == null,
          );
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Local cache read error: $e');
      }
    }

    final bool hasCachedData = _uiState.activities.isNotEmpty;
    if (!hasCachedData || forceRefresh) {
      _uiState = _uiState.copyWith(
        isLoading: true,
        filterDate: filterDate,
        clearFilterDate: filterDate == null,
      );
      notifyListeners();
    }

    try {
      final result = await _itineraryService.fetchLatestTrip();

      // Verify trip exists, is ongoing, and contains activities
      final bool isTripActive =
          result != null &&
          result.trip.status ==
              'ongoing' && // Check your exact active status string
          result.activities.isNotEmpty;

      if (isTripActive) {
        final tripId = result.trip.tripId!;
        final days = await _budgetService.calculateSufficientDays(
          tripId,
          result.activities.first.activitiesId,
        );

        debugPrint("days $days");

        _uiState = _uiState.copyWith(
          isLoading: false,
          tripId: result.trip.tripId,
          activities: result.activities,
          totalBudget: result.trip.totalBudget,
          tripDestination: result.trip.destination,
          originalCurrency: _expenseCurrency,
          sufficientDays: days,
        );
        await refreshSpentAmounts();

        await _cachedActivity.saveActivitiesLocally(
          'latest_ongoing_trip',
          result.activities,
        );
        await _cachedActivity.saveActivitiesLocally(tripId, result.activities);

        _uiState = _uiState.copyWith(isLoading: false);
        unawaited(_prepareExpenseReminders(result.activities));
      } else {
        // 2. Clear trip state if trip has ended, is not ongoing, or has no activities
        _uiState = _uiState.copyWith(
          isLoading: false,
          tripId: '',
          activities: const [],
          totalBudget: 0.0,
          spentBudget: 0.0,
          sufficientDays: 0,
        );
        await _cachedActivity.clearLocalActivities('latest_ongoing_trip');
      }
    } catch (e) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        tripId: '',
        activities: const [],
        errorMessage: _uiState.activities.isEmpty ? e.toString() : '',
      );
      debugPrint('Error in ActivityViewModel.initialize: $e');
    }
    notifyListeners();
  }

  Future<void> loadTripItinerary(
    String tripId, {
    DateTime? filterDate,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final targetDate = filterDate != null
        ? DateTime(filterDate.year, filterDate.month, filterDate.day)
        : DateTime(now.year, now.month, now.day);

    // 1. Instant Cache Load
    if (!forceRefresh) {
      try {
        final cachedActivities = await _cachedActivity.getActivitiesForTrip(
          tripId.isNotEmpty ? tripId : 'latest_ongoing_trip',
        );
        if (cachedActivities.isNotEmpty) {
          final currentDateCached = cachedActivities
              .where((act) => _isSameDate(act.date, targetDate))
              .toList();
          _uiState = _uiState.copyWith(
            isLoading: false,
            tripId: tripId,
            filterDate: targetDate,
            activities: currentDateCached.isNotEmpty
                ? currentDateCached
                : cachedActivities,
          );
          notifyListeners(); // Renders cache immediately without wiping!
        }
      } catch (e) {
        debugPrint('Cache read error: $e');
      }
    }

    // 2. Only show full loader if we have NO activities loaded
    if (_uiState.activities.isEmpty || forceRefresh) {
      _uiState = _uiState.copyWith(
        isLoading: true,
        tripId: tripId,
        filterDate: targetDate,
      );
      notifyListeners();
    }

    // Fallback: Network Fetch
    try {
      final allActivities = await _itineraryService.fetchAllActivitiesByTrip(
        tripId,
      );
      final tripResult = await _itineraryService.fetchLatestTrip();

      // 1. Calculate the initial spent budget across all activities & populate the map
      final Map<String, double> spentMap = {};
      double totalSpent = 0.0;

      for (final act in allActivities) {
        final expenses = await _expenseRepository.getExpensesByActivityId(
          act.activitiesId,
        );
        double actSpent = 0.0;
        for (final exp in expenses) {
          actSpent += exp.totalAmount;
        }
        spentMap[act.activitiesId] = actSpent;
        totalSpent += actSpent;
      }

      // 2. Calculate initial sufficient days
      int initialSufficientDays = 0;
      if (allActivities.isNotEmpty) {
        initialSufficientDays = await _budgetService.calculateSufficientDays(
          tripId,
          allActivities.first.activitiesId,
        );
      }

      final currentDateActivities = allActivities.where((act) {
        return _isSameDate(act.date, targetDate);
      }).toList();

      // Derive sorted unique day dates from all activities for day navigation
      final dateSet = <String, DateTime>{};
      for (final act in allActivities) {
        final d = act.date.toLocal();
        final key = '${d.year}-${d.month}-${d.day}';
        dateSet.putIfAbsent(key, () => DateTime(d.year, d.month, d.day));
      }
      final sortedDates = dateSet.values.toList()..sort();

      _uiState = _uiState.copyWith(
        isLoading: false,
        activities: currentDateActivities,
        allActivities: allActivities,
        availableDates: sortedDates,
        totalBudget: tripResult?.trip.totalBudget ?? _uiState.totalBudget,
        activitySpentMap: spentMap,
        spentBudget: totalSpent,
        sufficientDays: initialSufficientDays,
        filterDate: targetDate,
        tripId: tripId,
        tripDestination:
            tripResult?.trip.destination ?? _uiState.tripDestination,
        originalCurrency: _expenseCurrency,
      );

      // Save to cache
      await _cachedActivity.saveActivitiesLocally(tripId, allActivities);
      await _cachedActivity.saveActivitiesLocally(
        'latest_ongoing_trip',
        allActivities,
      );

      await refreshSpentAmounts();

      // Clean stale per-day overspend values in the DB and publish the
      // authoritative whole-trip overspentBudget.
      await reconcileTripOverspend();
      unawaited(_prepareExpenseReminders(allActivities));
    } catch (e) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  List<Activity> get currentFilteredActivities {
    final filterDate = _uiState.filterDate ?? DateTime.now();
    return _uiState.activities.where((act) {
      return _isSameDate(act.date, filterDate);
    }).toList();
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

  /// Stable notification ID for the instant near/over-budget alert. Uses a
  /// separate ID space (300000+) so it never collides with the scheduled
  /// activity reminders (100000+) or the evening review reminder (200000).
  int _budgetAlertId(String activityId) {
    final numericPart = activityId.replaceAll(RegExp(r'[^0-9]'), '');
    final activityNumber = int.tryParse(numericPart) ?? 0;
    return 300000 + activityNumber;
  }

  void setDateFilter(DateTime? filterDate) {
    _uiState = _uiState.copyWith(
      filterDate: filterDate,
      clearFilterDate: filterDate == null,
    );
    notifyListeners();
  }

  void goToPreviousDay() {
    if (!_uiState.canGoToPreviousDay) return;
    final prevDate = _uiState.availableDates[_uiState.currentDayIndex - 1];
    _switchToDay(prevDate);
  }

  void goToNextDay() {
    if (!_uiState.canGoToNextDay) return;
    final nextDate = _uiState.availableDates[_uiState.currentDayIndex + 1];
    _switchToDay(nextDate);
  }

  void _switchToDay(DateTime date) {
    final dayActivities = _uiState.allActivities.where((act) {
      return _isSameDate(act.date, date);
    }).toList();

    _uiState = _uiState.copyWith(filterDate: date, activities: dayActivities);
    notifyListeners();
  }

  void clearDateFilter() {
    _uiState = _uiState.copyWith(clearFilterDate: true);
    notifyListeners();
  }

  Future<bool> endTrip() async {
    final id = _uiState.tripId;

    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final update = await _itineraryService.endTrip(id);

      if (update) {
        _uiState = _uiState.copyWith(isLoading: false, tripId: '');
        notifyListeners();
        return true;
      }

      _uiState = _uiState.copyWith(isLoading: false);
      notifyListeners();
      return false;
    } catch (e) {
      _uiState = _uiState.copyWith(isLoading: false);
      notifyListeners();
      return false;
    }
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

    _uiState = _uiState.copyWith(isLoading: true, errorMessage: '');
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
            (_uiState.shortageAmount - additionalAmount).clamp(
              0.0,
              double.infinity,
            );

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
      // Snapshot the original allocated budget BEFORE processExpense() runs
      // the reallocation, which modifies allocatedBudget in the DB.
      final currentActivity = _uiState.activities.firstWhere(
        (a) => a.activitiesId == _uiState.currentActivityId,
        orElse: () => _uiState.selectedActivity ?? _uiState.activities.first,
      );
      final double originalAllocatedBudget = currentActivity.allocatedBudget;

      debugPrint(
        '[handleExpenseSubmission] Original allocated budget for '
        '${currentActivity.activitiesId}: RM${originalAllocatedBudget.toStringAsFixed(2)}',
      );

      final response = await _expenseTrackingService.processExpense(
        tripId: _uiState.tripId,
        currentActivityId: _uiState.currentActivityId,
      );

      debugPrint("result: ${response}");

      await refreshSpentAmounts();

      // Reconciles the current day's budget in the DB and updates the
      // trip-level overspentBudget from the reconciled data (authoritative).
      await evaluateDayOverspend(
        dayTripId: currentActivity.dayTripId,
        date: currentActivity.date,
      );

      final activities = await _itineraryService.getRemainingActivities(
        _uiState.tripId,
        DateTime.now(),
      );

      double shortageAmount = 0.0;
      for (var ad in activities) {
        shortageAmount += ad.allocatedBudget;
      }

      final sufficientDays = await _budgetService.calculateSufficientDays(
        _uiState.tripId,
        _uiState.currentActivityId,
      );

      // Compute exceeded amount using the ORIGINAL allocated budget
      // (before reallocation modified it in the DB), so the figure
      // matches what the user saw on screen.
      final double activitySpent =
          _uiState.activitySpentMap[_uiState.currentActivityId] ?? 0.0;
      var exceededAmount = activitySpent - originalAllocatedBudget;
      if (exceededAmount < 0) exceededAmount = 0.0;

      debugPrint(
        '[handleExpenseSubmission] Exceeded = spent($activitySpent) - '
        'originalBudget($originalAllocatedBudget) = $exceededAmount',
      );
      // final days = await _itineraryService.getDaysByTripId(_uiState.tripId);
      //
      // double overspend = 0.00;
      //
      // for (var day in days) {
      //   overspend += day.overspendAmount!;
      // }

      _uiState = _uiState.copyWith(
        // NOTE: overspentBudget is intentionally left untouched here - it was
        // already set by evaluateDayOverspend() from the reconciled DB days.
        // Re-writing it with a stale/pre-reconcile value caused the OVERSPENT
        // card to jump to an incorrect figure after expense submission.
        // overspentBudget: overspend,
        shortageAmount: shortageAmount,
        sufficientDays: sufficientDays,
        exceededAmount: exceededAmount,
      );

      switch (response) {
        case ExpenseProcessingResult.withinBudget:
          _uiState = _uiState.copyWith(
            popupAction: '',
            selectedActivity: currentActivity,
          );
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

  //weisong
  Future<bool> generateBudgetRecoveryPlan({
    required String? dayTripId,
    required double availableBudget,
    double topUpAmount = 0.0,
  }) async {
    final now = DateTime.now();

    // Our own "upcoming slots" selection for the recovery. We intentionally do
    // NOT call the shared getRemainingActivities() (owned by other teammates)
    // so its behaviour is left untouched. A slot is only optimizable when it
    // has NOT started yet at this moment: past / ongoing activities are
    // excluded even if they have no expense record. Missing or malformed start
    // times are never treated as optimizable.
    final allTripActivities = await _itineraryService.fetchAllActivitiesByTrip(
      _uiState.tripId,
    );

    final remainingActivities = allTripActivities.where((a) {
      if (a.status == 'completed') return false;

      final start = _tryActivityStart(a);
      if (start == null || !start.isAfter(now)) return false;

      // Skip slots that already have money spent on them.
      final spentOnActivity = _uiState.activitySpentMap[a.activitiesId] ?? 0.0;
      final hasRecordedExpense =
          (a.isOverspend == true) ||
          (a.overspendAmount != null && a.overspendAmount! > 0) ||
          spentOnActivity > 0;

      return !hasRecordedExpense;
    }).toList();

    if (dayTripId == null) return false;

    _uiState = _uiState.copyWith(isLoading: true, errorMessage: '');
    notifyListeners();

    try {
      Position? currentPosition;
      try {
        currentPosition = await _locationSource.getCurrentLocation();
      } catch (e) {
        debugPrint('LocationSource error: $e');
      }

      final userCoordinates = currentPosition != null
          ? 'Lat: ${currentPosition.latitude.toStringAsFixed(5)}, Lon: ${currentPosition.longitude.toStringAsFixed(5)}'
          : null;

      final effectiveRemainingBudget =
          _uiState.totalBudget - _uiState.spentBudget;

      // 2. Delegate generation and Supabase updates completely to Service
      final revisedActivities = await _itineraryService
          .generateBudgetRecoveryItinerary(
            tripId: _uiState.tripId,
            effectiveRemainingBudget: effectiveRemainingBudget,
            currentSpentBudget: _uiState.spentBudget,
            topUpAmount: topUpAmount,
            remainingActivities: remainingActivities,
            tripDestination: _uiState.tripDestination,
            userCoordinates: userCoordinates,
            currentDate: DateTime.now(),
          );

      // Nothing was generated (e.g. no slots left to re-plan, or the engine
      // returned no usable plan) - treat it as a failure so the UI can tell
      // the user instead of silently doing nothing.
      if (revisedActivities.isEmpty) {
        _uiState = _uiState.copyWith(
          isLoading: false,
          errorMessage: 'No plan changes could be generated. Please try again.',
        );
        notifyListeners();
        return false;
      }

      // 3. Merge returned domain activities into the state
      final revisedMap = {
        for (final item in revisedActivities) item.activitiesId: item,
      };

      final updatedActivities = _uiState.activities.map((a) {
        return revisedMap[a.activitiesId] ?? a;
      }).toList();

      _uiState = _uiState.copyWith(
        isLoading: false,
        activities: updatedActivities,
      );
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in generateBudgetRecoveryPlan: $e');
      debugPrint('Stack trace: $stackTrace');
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  /// Our own tolerant parser for an activity's scheduled start time. Returns
  /// null when the time is missing or malformed, so such a slot is never
  /// considered "upcoming/optimizable".
  DateTime? _tryActivityStart(Activity activity) {
    final date = activity.date;
    final timeParts = activity.startTime?.split(':');
    if (timeParts == null || timeParts.length < 2) return null;

    final hour = int.tryParse(timeParts[0].trim());
    final minute = int.tryParse(timeParts[1].trim());
    if (hour == null || minute == null) return null;

    try {
      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  // weisong
  Future<void> refreshSpentAmounts() async {
    debugPrint(
      'DEBUG: [refreshSpentAmounts] invoked. Current activityId: "${_uiState.currentActivityId}", All activities count: ${_uiState.allActivities.length}, Day activities count: ${_uiState.activities.length}',
    );

    // 1. Use ALL trip activities (not just the day-filtered list) so that
    //    spentBudget in the top budget card reflects the whole-trip spending.
    final activityIds = _uiState.allActivities
        .map((a) => a.activitiesId)
        .where((id) => id.isNotEmpty)
        .toList();

    if (activityIds.isEmpty) {
      debugPrint(
        'DEBUG: [refreshSpentAmounts] Aborted: No activity IDs found in _uiState.allActivities.',
      );
      return;
    }

    try {
      debugPrint(
        'DEBUG: Calling _itineraryService.getTripSpentSummary for ${activityIds.length} activities (whole trip)...',
      );
      final summary = await _itineraryService.getTripSpentSummary(activityIds);

      // Safely cast num to double to avoid cast exceptions if Supabase returns int
      final double freshSpent =
          (summary['totalSpent'] as num?)?.toDouble() ?? 0.0;
      final Map<String, double> freshActivityMap = Map<String, double>.from(
        summary['activitySpentMap'] ?? {},
      );

      for (final activity in _uiState.activities) {
        final double actSpent = freshActivityMap[activity.activitiesId] ?? 0.0;
        final double actBudget = activity.allocatedBudget;
        final double actDiff = actSpent - actBudget;
        debugPrint(
          '🚨 [OVERSPENT DETECTED] Activity: "${activity.destination}" '
          '(ID: ${activity.activitiesId}) | '
          'Allocated: ${activity.allocatedBudget} | '
          'Spent: $actSpent | '
          'Over by: $actDiff',
        );

        debugPrint(
          '>>> [DEBUG Activity Overspend Check] ID: ${activity.activitiesId} | '
          'Name: "${activity.destination}" | '
          'Spent: $actSpent | '
          'Allocated: $actBudget | '
          'Diff: $actDiff',
        );
      }

      // NOTE: overspentBudget is intentionally NOT set here.
      // The authoritative whole-trip value comes from reconcileTripOverspend().
      // spentBudget now reflects the whole trip (all activities, not just today).
      _uiState = _uiState.copyWith(
        spentBudget: freshSpent,
        activitySpentMap: freshActivityMap,
      );

      debugPrint(
        '>>> [DEBUG refreshSpentAmounts] Spent refresh done (overspentBudget untouched).',
      );
      debugPrint(
        "[refreshSpentAmounts] Success! Total Spent: $freshSpent, Map: $freshActivityMap",
      );
      notifyListeners();
    } catch (e, stack) {
      debugPrint('Error refreshing spent amounts: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  // weisong
  // Reconciles EVERY trip day against real spending, persists each day's net
  // overspend (which clears stale day values), and publishes the authoritative
  // whole-trip overspentBudget to the top card.
  Future<void> reconcileTripOverspend() async {
    if (_uiState.tripId.isEmpty) return;
    try {
      final totalTripOverspent = await _budgetService.reconcileTripOverspend(
        tripId: _uiState.tripId,
      );
      debugPrint(
        '>>> [DEBUG reconcileTripOverspend] Reconciled total overspent: '
        '${totalTripOverspent.toStringAsFixed(2)}',
      );

      _uiState = _uiState.copyWith(overspentBudget: totalTripOverspent);
      notifyListeners();
    } catch (e) {
      debugPrint('Error reconciling trip overspend: $e');
    }
  }

  // Re-evaluates a day's net overspend and updates trip-level overspentBudget.
  // Reconciling the whole trip (not just this day) keeps the OVERSPENT figure
  // consistent and removes phantom leftover amounts from other days.
  Future<void> evaluateDayOverspend({
    required String dayTripId,
    required DateTime date,
  }) async {
    await reconcileTripOverspend();
  }
}
