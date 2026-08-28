import 'package:flutter/material.dart';

import '../../models/entities/activity.dart';
import '../../models/entities/expense_item.dart';
import '../../models/local_data_source/camera_source.dart';
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
  final IItineraryService _itineraryService;
  final IBudgetService _budgetService;
  final IExpenseTrackingService _expenseTrackingService;
  final IExpenseRepository _expenseRepository;
  final CameraSource _cameraSource = CameraSource();

  ActivityViewModel({
    IItineraryService? itineraryService,
    IBudgetService? budgetService,
    IExpenseTrackingService? expenseTrackingService,
    IExpenseRepository? expenseRepository,
  })
      : _itineraryService = itineraryService ?? ItineraryService(),
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

      _uiState = _uiState.copyWith(
        isSavingExpense: false,
        draftExpenseItems: const [],
        draftTotalAmount: 0.0,
        paymentMethod: '',
        receiptLocalPath: '',
        clearOcrData: true,
        successMessage: 'The expense record has been successfully saved.',
        spentBudget:
        _uiState.spentBudget +
            expenseAmount, // remainingBudget updates automatically
      );
      await loadRecordedExpensesForSelectedActivity();

      // detect overspend
      await handleExpenseSubmission(expenseAmount);
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
          (item) =>
          item.copyWith(
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
        _uiState = _uiState.copyWith(
          isLoading: false,
          tripId: result.trip.tripId,
          activities: result.activities,
          totalBudget: result.trip.totalBudget,
        );
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
    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final allActivities = await _itineraryService.fetchAllActivitiesByTrip(
        tripId,
      );
      final tripResult = await _itineraryService.fetchLatestTrip();

      final now = DateTime.now();
      final targetDate = filterDate ?? DateTime(now.year, now.month, now.day);

      _uiState = _uiState.copyWith(
        isLoading: false,
        activities: allActivities,
        totalBudget: tripResult?.trip.totalBudget ?? _uiState.totalBudget,
        filterDate: targetDate,
        tripId: tripId,
      );
    } catch (e) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
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
    if (additionalAmount <= 0) {
      _uiState = _uiState.copyWith(
        isLoading: false,
        errorMessage: 'Please enter a top-up amount greater than RM0.00.',
      );
      notifyListeners();
      return false;
    }

    final id = _uiState.tripId;
    final activityId = _uiState.currentActivityId;

    _uiState = _uiState.copyWith(isLoading: true, errorMessage: '');
    notifyListeners();

    try {
      final updatedTrip = await _budgetService.topUpBudget(
        tripId: id,
        currentActivityId: activityId,
        topupAmount: additionalAmount,
      );

      if (updatedTrip != null) {
        final days = await _budgetService.calculateSufficientDays(
          updatedTrip,
          activityId,
        );

        _uiState = _uiState.copyWith(
          isLoading: false,
          totalBudget: updatedTrip.totalBudget,
          overspentBudget: (_uiState.overspentBudget - additionalAmount).clamp(
            0.0,
            double.infinity,
          ),
          sufficientDays: days.toInt(),
          errorMessage: '',
        );

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

  Future<void> handleExpenseSubmission(double expense) async {
    debugPrint("zq handleExpenseSubmission");

    _uiState = _uiState.copyWith(isLoading: true);
    notifyListeners();

    try {
      final response = await _expenseTrackingService.processExpense(
        tripId: _uiState.tripId,
        currentActivityId: _uiState.currentActivityId,
        expense: expense,
      );

      debugPrint("result: ${response}");

      final days = await _itineraryService.getDaysByTripId(_uiState.tripId);

      double overspend = 0.00;

      for (var day in days) {
        overspend += day.overspendAmount!;
      }

      _uiState = _uiState.copyWith(
        overspentBudget: overspend,
        shortageAmount: overspend
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
}
