import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entities/activity.dart';
import '../models/entities/expense.dart';
import '../models/entities/expense_item.dart';
import '../theme/app_theme.dart';
import '../utils/explicit_word_validation.dart';
import '../view_models/presentation_logic/activity_view_model.dart';
import '../view_models/ui_state/activity_ui_state.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/app_time_picker.dart';
import '../widgets/converted_amount_text.dart';

String _formatExpenseCurrencyAmount(String currency, double amount) =>
    formatCurrencyAmount(currency, amount, displayMyrAsCode: true);

String? _validateExpenseText(String fieldName, String value) {
  if (!containsProhibitedPlaceLanguage(value)) return null;
  return '$fieldName contains inappropriate language. Please remove it.';
}

String? _validateExpenseItemName(String value) {
  final trimmed = value.trim();
  if (trimmed.length > 30) {
    return 'Item name cannot exceed 30 characters.';
  }
  if (!RegExp(r'^[A-Za-z0-9 -]+$').hasMatch(trimmed)) {
    return 'Item name may only contain letters, numbers, spaces, and dashes.';
  }
  return _validateExpenseText('Item name', trimmed);
}

String? _validateExpenseDescription(String value) {
  final trimmed = value.trim();
  if (trimmed.length > 60) {
    return 'Item description cannot exceed 60 characters.';
  }
  final symbolError = _validateOptionalExpenseTextSymbols(
    'Item description',
    trimmed,
  );
  if (symbolError != null) return symbolError;
  return _validateExpenseText('Item description', trimmed);
}

String? _validateExpenseMerchantName(String value) {
  final trimmed = value.trim();
  if (trimmed.length > 50) {
    return 'Merchant name cannot exceed 50 characters.';
  }
  final symbolError = _validateOptionalExpenseTextSymbols(
    'Merchant name',
    trimmed,
  );
  if (symbolError != null) return symbolError;
  return _validateExpenseText('Merchant name', trimmed);
}

String? _validateOptionalExpenseTextSymbols(String fieldName, String value) {
  if (value.isEmpty) return null;
  if (!RegExp(r'[A-Za-z0-9]').hasMatch(value)) {
    return '$fieldName must contain at least one letter or number.';
  }
  if (!RegExp(r"^[A-Za-z0-9 .,!?&'()/-]+$").hasMatch(value)) {
    return "$fieldName contains an unsupported symbol. Use only . , ! ? & ' ( ) / or -.";
  }
  if (RegExp(r"([^A-Za-z0-9\s])\1{3,}").hasMatch(value)) {
    return '$fieldName cannot contain the same symbol more than 3 times in a row.';
  }
  return null;
}

/// Opens the Expense form for the Activity selected from the itinerary.
Future<void> showExpenseBottomSheet({
  required BuildContext context,
  required Activity activity,
  required ActivityViewModel viewModel,
  bool viewOnly = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    barrierColor: appTheme.black.withOpacity(0.20),
    backgroundColor: appTheme.transparentCustom,
    builder: (_) => ChangeNotifierProvider.value(
      value: viewModel,
      child: ExpenseBottomSheet(activity: activity, viewOnly: viewOnly),
    ),
  );
}

class ExpenseBottomSheet extends StatefulWidget {
  final Activity activity;
  final bool viewOnly;

  ExpenseBottomSheet({required this.activity, this.viewOnly = false});

  @override
  State<ExpenseBottomSheet> createState() => _ExpenseBottomSheetState();
}

class _ExpenseBottomSheetState extends State<ExpenseBottomSheet> {
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _roundingController = TextEditingController();
  String _manualRoundingText = '';
  bool _showAdjustments = false;
  int? _editingItemIndex;
  bool _showItemForm = false;
  bool _isRecordingNewExpense = false;
  bool _hasAppliedOcrValues = false;
  bool _hasUnfinishedItemFormChanges = false;
  bool _showUnknownItemPlaceholder = false;
  String? _topMessage;
  Timer? _topMessageTimer;

  @override
  void dispose() {
    _topMessageTimer?.cancel();
    _taxController.dispose();
    _discountController.dispose();
    _roundingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final timeText = activity.startTime?.isNotEmpty == true
        ? activity.startTime!
        : DateFormat.jm().format(activity.date);
    final uiState = context.watch<ActivityViewModel>().uiState;
    final showRecordedExpenses =
        !uiState.isLoadingRecordedExpenses &&
        uiState.recordedExpenses.isNotEmpty &&
        !_isRecordingNewExpense;
    final isExpenseFormMode =
        !uiState.isLoadingRecordedExpenses && !showRecordedExpenses;
    final hasMoreRecordedExpensesThanFit = uiState.recordedExpenses.length >= 3;
    final canExpandSheet = isExpenseFormMode || hasMoreRecordedExpensesThanFit;
    final recordedExpensesHeight = 0.80;

    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: DraggableScrollableSheet(
        key: ValueKey(
          widget.viewOnly
              ? 'view-only'
              : isExpenseFormMode
              ? 'new-expense'
              : 'history',
        ),
        expand: widget.viewOnly || showRecordedExpenses,
        initialChildSize: isExpenseFormMode ? 0.88 : recordedExpensesHeight,
        minChildSize: 0.10,
        maxChildSize: canExpandSheet ? 0.90 : recordedExpensesHeight,
        snap: !isExpenseFormMode,
        snapSizes: isExpenseFormMode
            ? null
            : hasMoreRecordedExpensesThanFit
            ? [0.50, 0.80, 0.90]
            : [0.50, 0.80],
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) => Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              child: Material(
                color: appTheme.white_A700,
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 64,
                            height: 6,
                            decoration: BoxDecoration(
                              color: appTheme.gray_200,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          widget.viewOnly
                              ? 'Expense History'
                              : showRecordedExpenses
                              ? 'Recorded Expenses'
                              : 'Add Expense',
                          style: TextStyle(
                            color: appTheme.blueGray900,
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 20),
                        _ExpenseActivitySummary(
                          activity: activity,
                          timeText: timeText,
                        ),
                        SizedBox(height: 10),
                        _ExpenseCategoryCard(
                          category: activity.activityCategory,
                        ),
                        SizedBox(height: 10),
                        if (uiState.isLoadingRecordedExpenses)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (showRecordedExpenses)
                          _buildRecordedExpensesSection(uiState)
                        else if (widget.viewOnly)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: appTheme.blue_gray_300,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No expenses recorded for this activity.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: appTheme.blue_gray_300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          _buildNewExpenseForm(uiState),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_topMessage != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _TopMessageAlert(
                  message: _topMessage!,
                  onClose: _dismissTopMessage,
                ),
              ),
            if (uiState.isScanningReceipt) _buildScanningReceiptOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewExpenseForm(ActivityUiState uiState) {
    return Column(
      children: [
        _buildExpenseItemsSection(uiState),
        SizedBox(height: 10),
        _buildAdjustmentsSection(uiState),
        SizedBox(height: 10),
        _buildTotalAmountSection(uiState),
        SizedBox(height: 10),
        _buildPaymentMethodSection(uiState),
        SizedBox(height: 10),
        _buildReceiptSection(uiState),
        if (_hasAppliedOcrValues && uiState.ocrRawText.isNotEmpty) ...[
          SizedBox(height: 10),
          _buildOcrReviewSection(uiState),
        ],
        if (uiState.errorMessage.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildMessage(uiState.errorMessage, true),
        ],
        if (uiState.successMessage.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildMessage(uiState.successMessage, false),
        ],
        SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: uiState.isSavingExpense
                ? null
                : _showConfirmExpenseDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.teal_A700,
              foregroundColor: appTheme.white_A700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              uiState.isSavingExpense ? 'Saving Expense...' : 'Confirm Expense',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _activeExpenseCurrency(ActivityUiState uiState) {
    final originalCurrency = uiState.originalCurrency.trim().toUpperCase();
    if (originalCurrency.isNotEmpty) return originalCurrency;
    return 'MYR';
  }

  String _savedExpenseCurrency(Expense expense) {
    final currency = expense.currency.trim().toUpperCase();
    if (currency.isNotEmpty) return currency;
    return 'MYR';
  }

  TextStyle get _moneyTextStyle => TextStyle(
    color: appTheme.gray_900,
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  Widget _buildRecordedExpensesSection(ActivityUiState uiState) {
    final expenses = uiState.recordedExpenses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Previously Recorded',
          style: TextStyle(
            color: appTheme.gray_400,
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 10),
        for (var index = 0; index < expenses.length; index++) ...[
          _buildRecordedExpenseCard(expenses[index], index + 1),
          SizedBox(height: 10),
        ],
        if (uiState.isLoadingRecordedExpenseItems)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!widget.viewOnly) ...[
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isRecordingNewExpense = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: appTheme.teal_A700,
                foregroundColor: appTheme.white_A700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(Icons.add),
              label: Text(
                'Record New Expense',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordedExpenseCard(Expense expense, int expenseNumber) {
    final currency = _savedExpenseCurrency(expense);
    final recordedOn = expense.createdAt == null
        ? 'Recorded expense'
        : DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(expense.createdAt!.toLocal());

    return Material(
      color: appTheme.transparentCustom,
      child: InkWell(
        onTap: () => _showRecordedExpenseDetails(expense, expenseNumber),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appTheme.white_A700,
            border: Border.all(color: appTheme.gray_200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: appTheme.teal_A700),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense #$expenseNumber',
                      style: TextStyle(
                        color: appTheme.blueGray900,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      recordedOn,
                      style: TextStyle(
                        color: appTheme.gray_400,
                        fontFamily: 'Inter',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 126,
                child: ConvertedAmountText(
                  amount: expense.totalAmount,
                  originalCurrency: currency,
                  displayMyrAsCode: true,
                  primaryStyle: TextStyle(
                    color: appTheme.blueGray900,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                  secondaryStyle: TextStyle(
                    color: appTheme.blue_gray_700,
                    fontFamily: 'Inter',
                    fontSize: 11,
                  ),
                  crossAxisAlignment: CrossAxisAlignment.end,
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, color: appTheme.gray_400),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRecordedExpenseDetails(
    Expense expense,
    int expenseNumber,
  ) async {
    final expenseId = expense.expenseId;
    if (expenseId == null || expenseId.isEmpty) {
      _showValidationMessage('The selected expense could not be found.');
      return;
    }

    final viewModel = context.read<ActivityViewModel>();
    final currency = _savedExpenseCurrency(expense);
    await viewModel.loadRecordedExpenseItems(expenseId);
    if (!mounted) return;

    if (viewModel.uiState.errorMessage.isNotEmpty) {
      _showValidationMessage(viewModel.uiState.errorMessage);
      return;
    }

    final expenseItems = viewModel.uiState.selectedRecordedExpenseItems;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: appTheme.white_A700,
        insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: SizedBox(
          width: MediaQuery.sizeOf(dialogContext).width * 0.92,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailDialogHeader(
                  title: 'Expense #$expenseNumber',
                  icon: Icons.receipt_long_outlined,
                ),
                SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: appTheme.teal_50,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDialogSectionLabel('TOTAL EXPENSE'),
                              SizedBox(height: 8),
                              ConvertedAmountText(
                                amount: expense.totalAmount,
                                originalCurrency: currency,
                                displayMyrAsCode: true,
                                primaryStyle: TextStyle(
                                  color: appTheme.gray_900,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 8),
                              if (expense.taxAmount != 0 ||
                                  expense.discountAmount != 0 ||
                                  expense.roundingAmount != 0) ...[
                                _buildRecordedAdjustmentLine(
                                  'Tax',
                                  _formatExpenseCurrencyAmount(
                                    currency,
                                    expense.taxAmount,
                                  ),
                                ),
                                if (expense.discountAmount != 0)
                                  _buildRecordedAdjustmentLine(
                                    'Discount',
                                    '-${_formatExpenseCurrencyAmount(currency, expense.discountAmount)}',
                                  ),
                                if (expense.roundingAmount != 0)
                                  _buildRecordedAdjustmentLine(
                                    'Rounding',
                                    '${expense.roundingAmount > 0 ? '+' : ''}${_formatExpenseCurrencyAmount(currency, expense.roundingAmount)}',
                                  ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 14),
                        Container(
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: appTheme.gray_200),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _buildExpenseInfoRow(
                                Icons.credit_card_outlined,
                                'Payment Method',
                                expense.paymentMethod ?? 'Not specified',
                              ),
                              _buildExpenseInfoRow(
                                Icons.schedule_outlined,
                                'Recorded',
                                expense.createdAt == null
                                    ? 'Date and time unavailable'
                                    : DateFormat(
                                        'dd MMM yyyy, hh:mm a',
                                      ).format(expense.createdAt!.toLocal()),
                              ),
                              if (expense.receiptImageUrl?.trim().isNotEmpty ==
                                  true)
                                _buildReceiptThumbnailRow(
                                  expense.receiptImageUrl!,
                                )
                              else
                                _buildExpenseInfoRow(
                                  Icons.attach_file,
                                  'Receipt',
                                  'Not attached',
                                  showDivider: false,
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 18),
                        _buildDialogSectionLabel('EXPENSE ITEMS'),
                        SizedBox(height: 10),
                        if (expenseItems.isEmpty)
                          Text('No expense items were found.')
                        else
                          for (final item in expenseItems)
                            _buildRecordedItemDetailCard(item, currency),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 18),
                _buildDialogCancelButton(dialogContext),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseItemsSection(ActivityUiState uiState) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.gray_100),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EXPENSE ITEMS',
            style: TextStyle(
              color: appTheme.blue_gray_300,
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 14),
          for (var index = 0; index < uiState.draftExpenseItems.length; index++)
            _buildSavedItemCard(
              uiState.draftExpenseItems[index],
              index,
              _activeExpenseCurrency(uiState),
            ),
          if (_showItemForm)
            _ExpenseItemForm(
              key: ValueKey(
                '${_editingItemIndex ?? 'new-item'}-$_showUnknownItemPlaceholder',
              ),
              currency: _activeExpenseCurrency(uiState),
              itemNameHint: _showUnknownItemPlaceholder ? 'Unknown' : 'Item',
              initialItem:
                  _editingItemIndex == null ||
                      _editingItemIndex! >= uiState.draftExpenseItems.length
                  ? null
                  : uiState.draftExpenseItems[_editingItemIndex!],
              onChanged: (hasChanges) {
                _hasUnfinishedItemFormChanges = hasChanges;
              },
              onSave: _saveItem,
              onDiscard: _discardItem,
              onValidationError: _showValidationMessage,
            ),
          SizedBox(height: 14),
          InkWell(
            onTap: _startNewItem,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: appTheme.gray_200,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: appTheme.blue_gray_300, size: 18),
                  SizedBox(width: 6),
                  Text(
                    uiState.draftExpenseItems.isEmpty
                        ? 'Add Item'
                        : 'Add Another Item',
                    style: TextStyle(
                      color: appTheme.blue_gray_300,
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedItemCard(ExpenseItem item, int index, String currency) {
    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: appTheme.gray_200),
        ),
        child: ListTile(
          onTap: () => _showExpenseItemDetails(item, currency),
          leading: CircleAvatar(
            backgroundColor: appTheme.teal_A700,
            child: Icon(
              Icons.receipt_long_outlined,
              color: appTheme.white_A700,
            ),
          ),
          title: Text(
            item.itemName,
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${item.quantity} × ${_formatExpenseCurrencyAmount(currency, item.unitPrice)}'
            ' = ${_formatExpenseCurrencyAmount(currency, item.subtotal)}',
          ),
          trailing: Wrap(
            children: [
              IconButton(
                onPressed: () => _editItem(item, index),
                icon: Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: () => _confirmDeleteItem(index),
                icon: Icon(Icons.delete_outline, color: appTheme.errorRed),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExpenseItemDetails(
    ExpenseItem item,
    String currency,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding: EdgeInsets.fromLTRB(20, 18, 12, 0),
        title: _buildDetailDialogHeader(
          title: item.itemName,
          icon: Icons.inventory_2_outlined,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: appTheme.teal_50,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogSectionLabel('ITEM SUBTOTAL'),
                    SizedBox(height: 8),
                    ConvertedAmountText(
                      amount: item.subtotal,
                      originalCurrency: currency,
                      displayMyrAsCode: true,
                      primaryStyle: TextStyle(
                        color: appTheme.gray_900,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: appTheme.gray_200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildExpenseInfoRow(
                      Icons.notes_outlined,
                      'Description',
                      item.itemDescription?.trim().isNotEmpty == true
                          ? item.itemDescription!
                          : 'Not provided',
                    ),
                    _buildExpenseInfoRow(
                      Icons.storefront_outlined,
                      'Merchant',
                      item.merchantName?.trim().isNotEmpty == true
                          ? item.merchantName!
                          : 'Not provided',
                    ),
                    _buildExpenseInfoRow(
                      Icons.event_outlined,
                      'Spent at',
                      DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(item.expenseDateTime),
                    ),
                    _buildExpenseInfoRow(
                      Icons.numbers_outlined,
                      'Quantity',
                      item.quantity.toString(),
                    ),
                    _buildExpenseInfoRow(
                      Icons.payments_outlined,
                      'Unit price',
                      _formatExpenseCurrencyAmount(currency, item.unitPrice),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [_buildDialogCancelButton(dialogContext)],
      ),
    );
  }

  Widget _buildDetailDialogHeader({
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: appTheme.teal_50,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: appTheme.teal_A700, size: 22),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: appTheme.gray_900,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: appTheme.blue_gray_300,
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildExpenseInfoRow(
    IconData icon,
    String label,
    String value, {
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: appTheme.teal_A700, size: 19),
              SizedBox(width: 10),
              SizedBox(
                width: 86,
                child: Text(
                  label,
                  style: TextStyle(
                    color: appTheme.blue_gray_300,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: appTheme.gray_900,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: appTheme.gray_200),
      ],
    );
  }

  Widget _buildReceiptThumbnailRow(String receiptImageUrl) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.attach_file, color: appTheme.teal_A700, size: 19),
          SizedBox(width: 10),
          SizedBox(
            width: 86,
            child: Text(
              'Receipt',
              style: TextStyle(
                color: appTheme.blue_gray_300,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Spacer(),
          Text(
            'Attached',
            style: TextStyle(
              color: appTheme.gray_900,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 6),
          IconButton(
            tooltip: 'View receipt',
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: () => _showSavedReceiptPreview(receiptImageUrl),
            icon: Icon(Icons.open_in_full, color: appTheme.teal_A700, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _showSavedReceiptPreview(String receiptImageUrl) async {
    await _showReceiptImagePopup(
      Image.network(
        receiptImageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(color: appTheme.teal_A700),
          );
        },
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(
            'Unable to load this receipt image.',
            textAlign: TextAlign.center,
            style: TextStyle(color: appTheme.blue_gray_700),
          ),
        ),
      ),
    );
  }

  Future<void> _showReceiptImagePopup(Widget receiptImage) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: appTheme.white_A700,
        insetPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: SizedBox(
          width: MediaQuery.sizeOf(dialogContext).width * 0.92,
          height: MediaQuery.sizeOf(dialogContext).height * 0.84,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              children: [
                _buildDetailDialogHeader(
                  title: 'Receipt Image',
                  icon: Icons.image_outlined,
                ),
                SizedBox(height: 14),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: appTheme.gray_50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(child: receiptImage),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                _buildDialogCancelButton(dialogContext),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordedItemDetailCard(ExpenseItem item, String currency) {
    final subtotal = _formatExpenseCurrencyAmount(currency, item.subtotal);
    return InkWell(
      onTap: () => _showExpenseItemDetails(item, currency),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: appTheme.white_A700,
          border: Border.all(color: appTheme.gray_200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: appTheme.teal_50,
              child: Icon(
                Icons.receipt_long_outlined,
                color: appTheme.teal_A700,
                size: 19,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.itemName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: appTheme.gray_900,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.18,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        subtotal,
                        style: TextStyle(
                          color: appTheme.gray_900,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        color: appTheme.gray_400,
                        size: 20,
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${item.quantity} x ${_formatExpenseCurrencyAmount(currency, item.unitPrice)}',
                        style: TextStyle(
                          color: appTheme.blue_gray_300,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(item.expenseDateTime),
                        style: TextStyle(
                          color: appTheme.blue_gray_300,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (item.itemDescription?.trim().isNotEmpty == true) ...[
                    SizedBox(height: 4),
                    Text(
                      item.itemDescription!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: appTheme.blue_gray_300,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordedAdjustmentLine(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.receipt_outlined, color: appTheme.teal_700, size: 15),
          SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              color: appTheme.teal_800,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogCancelButton(BuildContext dialogContext) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(dialogContext),
        style: ElevatedButton.styleFrom(
          backgroundColor: appTheme.teal_A700,
          foregroundColor: appTheme.white_A700,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'Cancel',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildItemDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildAdjustmentsSection(ActivityUiState uiState) {
    final currency = _activeExpenseCurrency(uiState);
    if (uiState.draftAutoRounding) {
      final autoAmount = uiState.draftRoundingAmount.toStringAsFixed(2);
      if (_roundingController.text != autoAmount) {
        _roundingController.text = autoAmount;
      }
    }
    if (_taxController.text.isEmpty && uiState.draftTaxAmount > 0) {
      _taxController.text = uiState.draftTaxAmount.toStringAsFixed(2);
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.gray_200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showAdjustments = !_showAdjustments),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showAdjustments
                      ? 'ADJUSTMENTS (OPTIONAL)'
                      : 'ADD ADJUSTMENTS (OPTIONAL)',
                  style: TextStyle(
                    color: appTheme.blue_gray_300,
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Icon(
                  _showAdjustments ? Icons.expand_less : Icons.expand_more,
                  color: appTheme.teal_A700,
                ),
              ],
            ),
          ),
          if (_showAdjustments) ...[
            SizedBox(height: 12),
            Text('TAX', style: _fieldLabelStyle),
            SizedBox(height: 6),
            TextField(
              controller: _taxController,
              style: TextStyle(color: appTheme.gray_900),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                _ThousandsSeparatorInputFormatter(
                  maximumIntegerDigits: 5,
                  decimalDigits: 2,
                  allowZero: true,
                  maximumValue: 99999,
                ),
              ],
              onChanged: (_) => _updateDraftAdjustments(),
              onSubmitted: (_) => _confirmAdjustments(),
              decoration: _fieldDecoration('0.00').copyWith(
                prefixIcon: _adjustmentCurrencyPrefix(currency),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text('DISCOUNT', style: _fieldLabelStyle),
            SizedBox(height: 6),
            TextField(
              controller: _discountController,
              style: TextStyle(color: appTheme.gray_900),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                _ThousandsSeparatorInputFormatter(
                  maximumIntegerDigits: 5,
                  decimalDigits: 2,
                  allowZero: true,
                  maximumValue: 99999,
                ),
              ],
              onChanged: (_) => _updateDraftAdjustments(),
              onSubmitted: (_) => _confirmAdjustments(),
              decoration: _fieldDecoration('0.00').copyWith(
                prefixIcon: _adjustmentCurrencyPrefix(currency),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text('ROUNDING', style: _fieldLabelStyle),
            SizedBox(height: 6),
            TextField(
              controller: _roundingController,
              readOnly: uiState.draftAutoRounding,
              style: TextStyle(color: appTheme.gray_900),
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      RegExp(
                        r'^-?(?:0(?:\.\d{0,2})?|1(?:\.0{0,2})?)?$',
                      ).hasMatch(newValue.text)
                      ? newValue
                      : oldValue,
                ),
              ],
              onChanged: (_) => _updateDraftAdjustments(),
              onSubmitted: (_) => _confirmAdjustments(),
              decoration: _fieldDecoration('0.00').copyWith(
                prefixIcon: _adjustmentCurrencyPrefix(currency),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                suffixIcon: Switch(
                  value: uiState.draftAutoRounding,
                  onChanged: _toggleAutoRounding,
                  activeColor: appTheme.teal_A700,
                ),
              ),
            ),
            SizedBox(height: 4),
            Text(
              uiState.draftAutoRounding
                  ? 'Auto: nearest 5 sen on the final total'
                  : 'Auto off · enter receipt rounding manually',
              style: TextStyle(color: appTheme.blue_gray_300, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _adjustmentCurrencyPrefix(String currency) {
    return Padding(
      padding: EdgeInsets.only(left: 12, right: 6),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          currency,
          style: TextStyle(
            color: appTheme.gray_900,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTotalAmountSection(ActivityUiState uiState) {
    final currency = _activeExpenseCurrency(uiState);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border.all(color: appTheme.gray_200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL (AFTER ADJUSTMENTS)',
            style: TextStyle(
              color: appTheme.blue_gray_300,
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 4),
          ConvertedAmountText(
            amount: uiState.draftTotalAmount,
            originalCurrency: currency,
            displayMyrAsCode: true,
            primaryStyle: TextStyle(
              color: appTheme.gray_900,
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
            secondaryStyle: TextStyle(
              color: appTheme.blue_gray_300,
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(ActivityUiState uiState) {
    final methods = ['Debit/Credit Card', 'Cash', 'E-wallet', 'Bank Transfer'];
    return _ExpenseSectionCard(
      title: 'PAYMENT METHOD (REQUIRED)',
      child: DropdownButtonFormField<String>(
        value: uiState.paymentMethod.isEmpty ? null : uiState.paymentMethod,
        decoration: _fieldDecoration(
          'Select Payment Method',
        ).copyWith(prefixIcon: Icon(Icons.credit_card_outlined)),
        items: methods
            .map(
              (method) => DropdownMenuItem(value: method, child: Text(method)),
            )
            .toList(),
        onChanged: (method) =>
            context.read<ActivityViewModel>().setPaymentMethod(method ?? ''),
      ),
    );
  }

  Widget _buildReceiptSection(ActivityUiState uiState) {
    final hasReceipt = uiState.receiptLocalPath.isNotEmpty;
    return _ExpenseSectionCard(
      title: 'UPLOAD RECEIPT',
      child: hasReceipt
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          _showReceiptPreview(uiState.receiptLocalPath),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(uiState.receiptLocalPath),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text('Receipt selected')),
                    IconButton(
                      onPressed: uiState.isScanningReceipt
                          ? null
                          : () => _removeReceipt(uiState),
                      icon: Icon(Icons.close, color: appTheme.errorRed),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: uiState.isScanningReceipt ? null : _scanReceipt,
                  icon: uiState.isScanningReceipt
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.document_scanner_outlined),
                  label: Text(
                    uiState.isScanningReceipt
                        ? 'Scanning receipt...'
                        : 'Scan Receipt',
                  ),
                ),
              ],
            )
          : OutlinedButton.icon(
              onPressed: uiState.isPickingReceipt ? null : _chooseReceipt,
              icon: uiState.isPickingReceipt
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.upload_outlined),
              label: Text(
                uiState.isPickingReceipt
                    ? 'Opening...'
                    : 'Scan or upload receipt',
              ),
            ),
    );
  }

  Future<void> _showReceiptPreview(String receiptLocalPath) async {
    await _showReceiptImagePopup(
      Image.file(
        File(receiptLocalPath),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Center(
          child: Text(
            'Unable to display receipt image.',
            textAlign: TextAlign.center,
            style: TextStyle(color: appTheme.blue_gray_700),
          ),
        ),
      ),
    );
  }

  Widget _buildOcrReviewSection(ActivityUiState uiState) {
    if (!_hasAppliedOcrValues) return SizedBox.shrink();

    final hasOcrDateTime = uiState.ocrTransactionDateTime != null;
    final hasOcrTotal = uiState.ocrExtractedTotal != null;
    final currency = _activeExpenseCurrency(uiState);
    final detectedItemCount = uiState.ocrDraftItemIndexes.where((index) {
      return index >= 0 &&
          index < uiState.draftExpenseItems.length &&
          uiState.draftExpenseItems[index].itemName.trim().toLowerCase() !=
              'unknown';
    }).length;
    final merchant = uiState.ocrMerchantName.isEmpty
        ? 'Merchant not detected'
        : uiState.ocrMerchantName;
    final dateAndTime = hasOcrDateTime
        ? DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(uiState.ocrTransactionDateTime!)
        : 'Date and time not detected';
    final total = hasOcrTotal
        ? _formatExpenseCurrencyAmount(currency, uiState.ocrExtractedTotal!)
        : 'Not detected';
    final tax = uiState.ocrExtractedTax == null
        ? 'Not detected'
        : _formatExpenseCurrencyAmount(currency, uiState.ocrExtractedTax!);
    final hasMeaningfulMismatch =
        uiState.hasOcrTotalMismatch && uiState.ocrTotalDifference.abs() > 0.05;

    return _ExpenseSectionCard(
      title: 'RECEIPT OCR REVIEW',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: appTheme.teal_A700,
                size: 17,
              ),
              SizedBox(width: 6),
              Text(
                'Receipt scanned',
                style: TextStyle(
                  color: appTheme.teal_A700,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'OCR may make mistakes. Use a clear, well-lit receipt and review the results.',
            style: TextStyle(
              color: appTheme.blue_gray_300,
              fontSize: 11,
              height: 1.3,
            ),
          ),
          SizedBox(height: 7),
          Text(
            '$merchant | $dateAndTime',
            style: TextStyle(color: appTheme.gray_900, fontSize: 13),
          ),
          SizedBox(height: 7),
          Text(
            'Total: $total | Tax: $tax',
            style: TextStyle(
              color: appTheme.gray_900,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 7),
          Text(
            '$detectedItemCount ${detectedItemCount == 1 ? 'item' : 'items'} added - review them above.',
            style: TextStyle(
              color: appTheme.teal_800,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasMeaningfulMismatch) ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xFFFFB74D)),
              ),
              child: Text(
                'The receipt total differs by '
                '${_formatExpenseCurrencyAmount(currency, uiState.ocrTotalDifference.abs())}. '
                'Please review the detected items.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessage(String message, bool isError) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Color(0xFFFFE4E6) : appTheme.teal_50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }

  Widget _buildScanningReceiptOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: appTheme.black.withValues(alpha: 0.28),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Transform.translate(
                offset: Offset(0, -MediaQuery.sizeOf(context).height * 0.13),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: 330),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: appTheme.white_A700,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: appTheme.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: appTheme.teal_50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.document_scanner_outlined,
                              color: appTheme.teal_A700,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Scanning receipt',
                              style: TextStyle(
                                color: appTheme.gray_900,
                                fontFamily: 'Inter',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Please wait while OCR and AI read the receipt.',
                        style: TextStyle(
                          color: appTheme.blue_gray_700,
                          fontFamily: 'Inter',
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          backgroundColor: appTheme.gray_100,
                          color: appTheme.teal_A700,
                        ),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: context
                              .read<ActivityViewModel>()
                              .cancelReceiptScan,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: appTheme.white_A700,
                            backgroundColor: appTheme.errorRed,
                            side: BorderSide(color: appTheme.errorRed),
                            shape: StadiumBorder(),
                            textStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveItem(ExpenseItem item) {
    final viewModel = context.read<ActivityViewModel>();
    final currentIndex = _editingItemIndex;
    if (currentIndex == null) {
      final newItemIndex = viewModel.uiState.draftExpenseItems.length;
      viewModel.addExpenseItem(item);
      setState(() {
        _editingItemIndex = newItemIndex;
        _showItemForm = false;
        _hasUnfinishedItemFormChanges = false;
      });
    } else {
      viewModel.updateExpenseItem(currentIndex, item);
      setState(() {
        _showItemForm = false;
        _hasUnfinishedItemFormChanges = false;
      });
    }
  }

  void _updateDraftAdjustments() {
    final tax = _parsePrice(_taxController.text) ?? 0.0;
    final discount = _parsePrice(_discountController.text) ?? 0.0;
    final rounding = _parsePrice(_roundingController.text) ?? 0.0;
    if (tax > 99999 || discount > 99999 || rounding.abs() > 1) return;
    context.read<ActivityViewModel>().setDraftAdjustments(
      tax,
      discount,
      rounding,
    );
  }

  void _toggleAutoRounding(bool enabled) {
    final viewModel = context.read<ActivityViewModel>();
    if (enabled) {
      _manualRoundingText = _roundingController.text;
      viewModel.setDraftAutoRounding(true);
    } else {
      _roundingController.text = _manualRoundingText;
      viewModel.setDraftAutoRounding(
        false,
        manualRounding: _parsePrice(_manualRoundingText) ?? 0.0,
      );
    }
  }

  void _confirmAdjustments() {
    final tax = _parsePrice(_taxController.text) ?? 0.0;
    final discount = _parsePrice(_discountController.text) ?? 0.0;
    final rounding = _parsePrice(_roundingController.text) ?? 0.0;
    if (tax > 99999 || discount > 99999 || rounding.abs() > 1) {
      _showValidationMessage(
        'Tax and discount must be at most 99,999; rounding must be within -1.00 to 1.00.',
      );
      return;
    }
    _taxController.text = tax > 0 ? tax.toStringAsFixed(2) : '';
    _discountController.text = discount > 0 ? discount.toStringAsFixed(2) : '';
    _roundingController.text = rounding != 0 ? rounding.toStringAsFixed(2) : '';
    context.read<ActivityViewModel>().setDraftAdjustments(
      tax,
      discount,
      rounding,
    );
    FocusScope.of(context).unfocus();
  }

  double? _parsePrice(String value) {
    return double.tryParse(value.trim().replaceAll(',', ''));
  }

  void _showValidationMessage(String message) {
    _topMessageTimer?.cancel();
    setState(() => _topMessage = message);
    _topMessageTimer = Timer(Duration(seconds: 5), _dismissTopMessage);
  }

  void _dismissTopMessage() {
    _topMessageTimer?.cancel();
    if (mounted) setState(() => _topMessage = null);
  }

  void _editItem(ExpenseItem item, int index) {
    setState(() {
      _showUnknownItemPlaceholder = false;
      _editingItemIndex = index;
      _showItemForm = true;
      _hasUnfinishedItemFormChanges = false;
    });
  }

  void _discardItem() {
    setState(() {
      _showUnknownItemPlaceholder = false;
      _editingItemIndex = null;
      _showItemForm = false;
      _hasUnfinishedItemFormChanges = false;
    });
  }

  void _startNewItem() {
    if (_showItemForm && _hasUnfinishedItem()) {
      _showValidationMessage(
        'Save or discard the current item before adding another item.',
      );
      return;
    }
    setState(() {
      _showUnknownItemPlaceholder = false;
      _editingItemIndex = null;
      _showItemForm = true;
      _hasUnfinishedItemFormChanges = false;
    });
  }

  bool _hasUnfinishedItem() {
    return _hasUnfinishedItemFormChanges;
  }

  Future<void> _scanReceipt() async {
    final viewModel = context.read<ActivityViewModel>();
    final hasUnsavedManualItems =
        viewModel.uiState.draftExpenseItems.isNotEmpty || _hasUnfinishedItem();

    if (hasUnsavedManualItems) {
      final replaceManualItems = await _showConfirmationDialog(
        title: 'Replace Unsaved Expense Items?',
        message:
            'Scanning this receipt will remove the current unsaved manual expense items. Do you want to continue?',
        confirmLabel: 'Replace and Scan',
      );

      if (!replaceManualItems || !mounted) {
        return;
      }

      viewModel.clearDraftExpenseItemsForOcr();
      _discardItem();
    }

    await viewModel.scanReceipt();
    if (!mounted) return;

    setState(() => _hasAppliedOcrValues = false);

    final uiState = viewModel.uiState;
    if (uiState.errorMessage.isNotEmpty) {
      _showValidationMessage(uiState.errorMessage);
      return;
    }

    if (uiState.ocrRawText.isNotEmpty) {
      final shouldApplyOcr = await _showOcrApplyDialog(uiState);
      if (!shouldApplyOcr || !mounted) {
        viewModel.removeReceiptAndOcrData();
        _taxController.clear();
        _discountController.clear();
        _roundingController.clear();
        _manualRoundingText = '';
        setState(() {
          _showAdjustments = false;
          _hasAppliedOcrValues = false;
          _showUnknownItemPlaceholder = false;
          _editingItemIndex = null;
          _showItemForm = false;
        });
        return;
      }

      var reviewReceiptDate = false;
      if (viewModel.ocrDateDiffersFromSelectedActivity) {
        final useReceiptDate = await _showConfirmationDialog(
          title: 'Receipt Date Differs from Activity',
          message:
              'This receipt date does not match the selected activity date. Do you want to use it anyway?',
          confirmLabel: 'Use Receipt Date',
          cancelLabel: 'Review Date',
        );
        if (!mounted) return;
        reviewReceiptDate = !useReceiptDate;
      }
      final itemCount = viewModel.applyOcrItemsToDraft();
      final updatedState = viewModel.uiState;
      final detectedTax = updatedState.draftTaxAmount;
      final hasUnknownItem =
          updatedState.draftExpenseItems.length == 1 &&
          updatedState.draftExpenseItems.first.itemName == 'Unknown';
      _taxController.text = detectedTax > 0
          ? detectedTax.toStringAsFixed(2)
          : '';
      _discountController.text = updatedState.draftDiscountAmount > 0
          ? updatedState.draftDiscountAmount.toStringAsFixed(2)
          : '';
      _roundingController.text = updatedState.draftRoundingAmount != 0
          ? updatedState.draftRoundingAmount.toStringAsFixed(2)
          : '';
      _manualRoundingText = _roundingController.text;
      if (_taxController.text.isNotEmpty ||
          _discountController.text.isNotEmpty ||
          _roundingController.text.isNotEmpty) {
        setState(() => _showAdjustments = true);
      }
      if (itemCount > 0) {
        setState(() {
          _editingItemIndex = reviewReceiptDate || hasUnknownItem ? 0 : null;
          _showItemForm = reviewReceiptDate || hasUnknownItem;
          _hasAppliedOcrValues = true;
          _hasUnfinishedItemFormChanges = false;
        });
      } else {
        setState(() {
          _editingItemIndex = null;
          _showItemForm = true;
          _showUnknownItemPlaceholder = true;
          _hasUnfinishedItemFormChanges = false;
        });
        _showValidationMessage(
          'No item details were detected. "Unknown" was added temporarily; please replace it with the actual item name.',
        );
      }
    }
  }

  Future<bool> _showOcrApplyDialog(ActivityUiState uiState) async {
    final currency = _activeExpenseCurrency(uiState);
    final itemCount = uiState.ocrParsedItems.isNotEmpty
        ? uiState.ocrParsedItems.length
        : uiState.ocrItemLines.length;
    final merchant = uiState.ocrMerchantName.isEmpty
        ? 'Merchant not detected'
        : uiState.ocrMerchantName;
    final dateText = uiState.ocrTransactionDateTime == null
        ? 'Date not detected'
        : DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(uiState.ocrTransactionDateTime!);
    final totalText = uiState.ocrExtractedTotal == null
        ? 'Total not detected'
        : _formatExpenseCurrencyAmount(currency, uiState.ocrExtractedTotal!);
    final taxText = uiState.ocrExtractedTax == null
        ? 'Not detected'
        : _formatExpenseCurrencyAmount(currency, uiState.ocrExtractedTax!);
    final discountText = uiState.ocrExtractedDiscount == null
        ? 'Not detected'
        : _formatExpenseCurrencyAmount(currency, uiState.ocrExtractedDiscount!);
    final roundingText = uiState.ocrExtractedRounding == null
        ? 'Not detected'
        : _formatExpenseCurrencyAmount(currency, uiState.ocrExtractedRounding!);
    final detectedItemNames = uiState.ocrParsedItems.isNotEmpty
        ? uiState.ocrParsedItems
              .map((item) => item.itemName.trim())
              .where((name) => name.isNotEmpty)
              .toList()
        : uiState.ocrItemLines
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList();
    final visibleItemNames = detectedItemNames.take(4).toList();
    final hiddenItemCount = detectedItemNames.length - visibleItemNames.length;

    final shouldApply = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: appTheme.white_A700,
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt Scanned',
                  style: TextStyle(
                    color: appTheme.black,
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: appTheme.teal_50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: appTheme.teal_A200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOcrSummaryLine('Merchant', merchant),
                      _buildOcrSummaryLine('Date', dateText),
                      _buildOcrSummaryLine('Total', totalText),
                      _buildOcrSummaryLine('Items', '$itemCount detected'),
                      _buildOcrSummaryLine('Tax', taxText),
                      _buildOcrSummaryLine('Discount', discountText),
                      _buildOcrSummaryLine('Rounding', roundingText),
                      if (visibleItemNames.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          'Detected items',
                          style: TextStyle(
                            color: appTheme.blue_gray_300,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        ...visibleItemNames.map(
                          (name) => Padding(
                            padding: EdgeInsets.only(bottom: 3),
                            child: Text(
                              '- $name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: appTheme.gray_900,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        if (hiddenItemCount > 0)
                          Text(
                            '+ $hiddenItemCount more',
                            style: TextStyle(
                              color: appTheme.teal_A700,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'OCR/AI may make mistakes. Please review before applying.',
                  style: TextStyle(
                    color: appTheme.blue_gray_300,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: appTheme.white_A700,
                          backgroundColor: appTheme.errorRed,
                          minimumSize: Size.fromHeight(48),
                          side: BorderSide(color: appTheme.errorRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appTheme.teal_A700,
                          foregroundColor: appTheme.white_A700,
                          minimumSize: Size.fromHeight(48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          'Apply',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return shouldApply ?? false;
  }

  Widget _buildOcrSummaryLine(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                color: appTheme.blue_gray_300,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: appTheme.gray_900,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseReceipt() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_outlined),
              title: Text('Take photo'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final didSelectReceipt = await context
                    .read<ActivityViewModel>()
                    .takeReceiptPhoto();
                if (didSelectReceipt && mounted) {
                  await _scanReceipt();
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined),
              title: Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final didSelectReceipt = await context
                    .read<ActivityViewModel>()
                    .chooseReceiptFromGallery();
                if (didSelectReceipt && mounted) {
                  await _scanReceipt();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeReceipt(ActivityUiState uiState) async {
    if (uiState.hasOcrDraftData) {
      final shouldRemove = await _showConfirmationDialog(
        title: 'Remove Receipt and OCR Items?',
        message:
            'Removing this receipt will clear all current expense items and adjustments for this draft.',
        confirmLabel: 'Remove',
        isDestructive: true,
      );
      if (!shouldRemove || !mounted) return;
    }

    context.read<ActivityViewModel>().removeReceiptAndOcrData();
    _taxController.clear();
    _discountController.clear();
    _roundingController.clear();
    _manualRoundingText = '';
    setState(() => _showAdjustments = false);
    if (mounted) {
      setState(() => _hasAppliedOcrValues = false);
    }
  }

  Future<void> _confirmExpense() async {
    debugPrint('DEBUG: [_confirmExpense] Button action reached');
    final viewModel = context.read<ActivityViewModel>();
    await viewModel.confirmExpense();
    if (!mounted) return;

    debugPrint(
      'DEBUG: confirmExpense done. Error: "${viewModel.uiState.errorMessage}", Success: "${viewModel.uiState.successMessage}"',
    );

    if (viewModel.uiState.errorMessage.isNotEmpty) {
      _showValidationMessage(viewModel.uiState.errorMessage);
      return;
    }

    if (viewModel.uiState.successMessage.isEmpty) return;

    // Haptic feedback on successful expense save.
    HapticFeedback.mediumImpact();

    final expenseNumber = viewModel.uiState.recordedExpenses.length;
    viewModel.clearExpenseMessage();
    final recordAnotherExpense = await _showConfirmationDialog(
      title: 'Expense #$expenseNumber Saved',
      message:
          'Expense #$expenseNumber has been successfully recorded. Would you like to record another expense for this activity?',
      confirmLabel: 'Yes, Record Another',
    );
    await viewModel.refreshSpentAmounts();
    if (!mounted) return;

    if (recordAnotherExpense) {
      _startAnotherExpenseForActivity();
    } else {
      Navigator.pop(context);
    }
  }

  void _startAnotherExpenseForActivity() {
    setState(() {
      _isRecordingNewExpense = true;
      _editingItemIndex = null;
      _showItemForm = false;
      _hasUnfinishedItemFormChanges = false;
    });
  }

  Future<void> _showConfirmExpenseDialog() async {
    if (_showItemForm && _hasUnfinishedItemFormChanges) {
      _showValidationMessage(
        _editingItemIndex == null
            ? 'Tap Save Item before confirming the expense.'
            : 'Tap Update Item before confirming the expense.',
      );
      return;
    }
    final viewModel = context.read<ActivityViewModel>();
    if (!viewModel.validateExpenseDraftBeforeConfirmation()) {
      _showValidationMessage(viewModel.uiState.errorMessage);
      return;
    }

    final totalAmount = viewModel.uiState.draftTotalAmount;
    final currency = _activeExpenseCurrency(viewModel.uiState);
    final isConfirmed = await _showConfirmationDialog(
      title: 'Confirm Expense',
      message:
          'Are you sure you want to record this expense of '
          '${_formatExpenseCurrencyAmount(currency, totalAmount)}?',
      confirmLabel: 'Confirm',
    );

    if (isConfirmed && mounted) {
      await _confirmExpense();
    }
  }

  Future<void> _confirmDeleteItem(int index, {bool clearEditor = false}) async {
    final isConfirmed = await _showConfirmationDialog(
      title: 'Delete Expense Item',
      message: 'Are you sure you want to delete this expense item?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!isConfirmed || !mounted) return;

    context.read<ActivityViewModel>().removeExpenseItem(index);
    if (clearEditor || _editingItemIndex == index) {
      _discardItem();
    } else if (_editingItemIndex != null && _editingItemIndex! > index) {
      setState(() => _editingItemIndex = _editingItemIndex! - 1);
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: appTheme.white_A700,
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: appTheme.black,
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDestructive ? Color(0xFFFFF1F2) : appTheme.teal_50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDestructive
                          ? appTheme.errorRed
                          : appTheme.teal_A200,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isDestructive
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline_rounded,
                        color: isDestructive
                            ? appTheme.errorRed
                            : appTheme.teal_A700,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: appTheme.gray_800,
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDestructive
                              ? appTheme.blue_gray_700
                              : appTheme.white_A700,
                          backgroundColor: isDestructive
                              ? null
                              : appTheme.errorRed,
                          minimumSize: Size.fromHeight(48),
                          side: BorderSide(
                            color: isDestructive
                                ? appTheme.gray_200
                                : appTheme.errorRed,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          cancelLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDestructive
                              ? appTheme.errorRed
                              : appTheme.teal_A700,
                          foregroundColor: appTheme.white_A700,
                          minimumSize: Size.fromHeight(48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          confirmLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return isConfirmed ?? false;
  }

  static final _fieldLabelStyle = TextStyle(
    color: appTheme.blue_gray_300,
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static final _dateTimeButtonStyle = OutlinedButton.styleFrom(
    alignment: Alignment.centerLeft,
    foregroundColor: appTheme.gray_900,
    backgroundColor: appTheme.gray_50,
    padding: EdgeInsets.symmetric(horizontal: 12),
    side: BorderSide(color: appTheme.gray_100),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  InputDecoration _fieldDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: appTheme.blue_gray_300),
      filled: true,
      fillColor: appTheme.gray_50,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: appTheme.gray_100),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: appTheme.gray_100),
      ),
    );
  }
}

class _ExpenseItemForm extends StatefulWidget {
  final String currency;
  final String itemNameHint;
  final ExpenseItem? initialItem;
  final ValueChanged<bool> onChanged;
  final ValueChanged<ExpenseItem> onSave;
  final VoidCallback onDiscard;
  final ValueChanged<String> onValidationError;

  const _ExpenseItemForm({
    super.key,
    required this.currency,
    required this.itemNameHint,
    required this.initialItem,
    required this.onChanged,
    required this.onSave,
    required this.onDiscard,
    required this.onValidationError,
  });

  @override
  State<_ExpenseItemForm> createState() => _ExpenseItemFormState();
}

class _ExpenseItemFormState extends State<_ExpenseItemForm> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  final ValueNotifier<double> _subtotalNotifier = ValueNotifier(0.0);
  final FocusNode _itemNameFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  final FocusNode _merchantFocus = FocusNode();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final initialItem = widget.initialItem;
    _selectedDate = initialItem?.expenseDateTime ?? DateTime.now();
    _selectedTime = TimeOfDay.fromDateTime(
      initialItem?.expenseDateTime ?? DateTime.now(),
    );
    _itemNameController.text =
        initialItem?.itemName ??
        (widget.itemNameHint == 'Unknown' ? 'Unknown' : '');
    _descriptionController.text = initialItem?.itemDescription ?? '';
    _merchantController.text = initialItem?.merchantName ?? '';
    _quantityController.text = initialItem == null
        ? ''
        : NumberFormat.decimalPattern('en_US').format(initialItem.quantity);
    _unitPriceController.text = initialItem == null
        ? ''
        : initialItem.unitPrice.toStringAsFixed(2);

    for (final controller in [
      _itemNameController,
      _descriptionController,
      _merchantController,
      _quantityController,
      _unitPriceController,
    ]) {
      controller.addListener(_handleFieldChanged);
    }
    _refreshSubtotal();
  }

  @override
  void didUpdateWidget(covariant _ExpenseItemForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemNameHint == 'Unknown' &&
        oldWidget.itemNameHint != 'Unknown' &&
        _itemNameController.text.trim().isEmpty) {
      _itemNameController.text = 'Unknown';
      _itemNameController.selection = TextSelection.collapsed(
        offset: _itemNameController.text.length,
      );
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _descriptionController.dispose();
    _merchantController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _subtotalNotifier.dispose();
    _itemNameFocus.dispose();
    _descriptionFocus.dispose();
    _merchantFocus.dispose();
    super.dispose();
  }

  void _handleFieldChanged() {
    _refreshSubtotal();
    widget.onChanged(_hasUnfinishedItem());
  }

  void _refreshSubtotal() {
    final quantity =
        int.tryParse(_quantityController.text.replaceAll(',', '')) ?? 0;
    final unitPrice = _parsePrice(_unitPriceController.text) ?? 0.0;
    _subtotalNotifier.value = quantity * unitPrice;
  }

  bool _hasUnfinishedItem() {
    return _itemNameController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _merchantController.text.trim().isNotEmpty ||
        _quantityController.text.trim().isNotEmpty ||
        _unitPriceController.text.trim().isNotEmpty;
  }

  Future<void> _dismissKeyboardBeforePicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    for (var attempt = 0; attempt < 8; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted || MediaQuery.viewInsetsOf(context).bottom == 0) return;
    }
  }

  Future<void> _pickDate() async {
    final viewModel = context.read<ActivityViewModel>();
    final uiState = viewModel.uiState;
    DateTime dateOnly(DateTime date) =>
        DateTime(date.year, date.month, date.day);
    final activityDate = uiState.selectedActivity?.date;
    var firstDate = dateOnly(
      activityDate ?? uiState.tripStartDate ?? DateTime(2020),
    );
    final tripStartDate = uiState.tripStartDate;
    if (tripStartDate != null && dateOnly(tripStartDate).isAfter(firstDate)) {
      firstDate = dateOnly(tripStartDate);
    }
    var lastDate = dateOnly(DateTime.now());
    final tripEndDate = uiState.tripEndDate;
    if (tripEndDate != null && dateOnly(tripEndDate).isBefore(lastDate)) {
      lastDate = dateOnly(tripEndDate);
    }
    final nextStart = viewModel.selectedExpenseTimeWindow?.nextStart;
    if (nextStart != null) {
      final lastBeforeNext = dateOnly(
        nextStart.subtract(const Duration(microseconds: 1)),
      );
      if (lastBeforeNext.isBefore(lastDate)) lastDate = lastBeforeNext;
    }
    if (firstDate.isAfter(lastDate)) {
      widget.onValidationError(
        'No expense dates are available for this activity yet.',
      );
      return;
    }
    final selectedDate = dateOnly(_selectedDate);
    final initialDate = selectedDate.isBefore(firstDate)
        ? firstDate
        : selectedDate.isAfter(lastDate)
        ? lastDate
        : selectedDate;
    await _dismissKeyboardBeforePicker();
    if (!mounted) return;
    final date = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = date);
      widget.onChanged(true);
    }
  }

  Future<void> _pickTime() async {
    final window = context.read<ActivityViewModel>().selectedExpenseTimeWindow;
    if (window == null) return;
    final now = DateTime.now();
    bool isSelectable(TimeOfDay time) {
      final candidate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        time.hour,
        time.minute,
      );
      return !candidate.isBefore(window.start) &&
          (window.nextStart == null || candidate.isBefore(window.nextStart!)) &&
          !candidate.isAfter(now);
    }

    if (!List.generate(
      1440,
      (index) => TimeOfDay(hour: index ~/ 60, minute: index % 60),
    ).any(isSelectable)) {
      widget.onValidationError(
        'No times are available for this activity on the selected date.',
      );
      return;
    }
    await _dismissKeyboardBeforePicker();
    if (!mounted) return;
    final time = await showAppTimePicker(
      context: context,
      initialTime: _selectedTime,
      isSelectable: isSelectable,
    );
    if (time != null && mounted) {
      setState(() => _selectedTime = time);
      widget.onChanged(true);
    }
  }

  void _saveItem() {
    final name = _itemNameController.text.trim();
    final description = _descriptionController.text.trim();
    final merchantName = _merchantController.text.trim();
    final quantity = int.tryParse(
      _quantityController.text.trim().replaceAll(',', ''),
    );
    final price = _parsePrice(_unitPriceController.text);
    if (name.isEmpty) {
      widget.onValidationError('Item name cannot be empty.');
      return;
    }
    for (final validationMessage in <String?>[
      _validateExpenseItemName(name),
      _validateExpenseDescription(description),
      _validateExpenseMerchantName(merchantName),
    ]) {
      if (validationMessage != null) {
        widget.onValidationError(validationMessage);
        return;
      }
    }
    if (quantity == null || quantity <= 0) {
      widget.onValidationError('Item quantity must be greater than zero.');
      return;
    }
    if (quantity > 9999) {
      widget.onValidationError('Item quantity cannot exceed 9,999.');
      return;
    }
    if (price == null || price <= 0) {
      widget.onValidationError('Unit price must be greater than zero.');
      return;
    }
    if (price > 99999) {
      widget.onValidationError('Unit price cannot exceed 99,999.');
      return;
    }
    if (quantity * price > 999999) {
      widget.onValidationError('Item subtotal cannot exceed 999,999.');
      return;
    }

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final dateError = context.read<ActivityViewModel>().expenseDateTimeError(
      dateTime,
    );
    if (dateError != null) {
      widget.onValidationError(dateError);
      return;
    }

    widget.onSave(
      ExpenseItem(
        itemName: name,
        itemDescription: _nullIfEmpty(description),
        merchantName: _nullIfEmpty(merchantName),
        expenseDateTime: dateTime,
        quantity: quantity,
        unitPrice: price,
        subtotal: quantity * price,
      ),
    );
  }

  String? _nullIfEmpty(String value) {
    return value.trim().isEmpty ? null : value.trim();
  }

  double? _parsePrice(String value) {
    return double.tryParse(value.trim().replaceAll(',', ''));
  }

  List<TextInputFormatter>? _inputFormattersFor(
    TextEditingController controller,
  ) {
    if (controller == _quantityController) {
      return [
        _ThousandsSeparatorInputFormatter(
          maximumIntegerDigits: 4,
          decimalDigits: 0,
        ),
      ];
    }
    if (controller == _unitPriceController) {
      return [
        _ThousandsSeparatorInputFormatter(
          maximumIntegerDigits: 5,
          decimalDigits: 2,
        ),
      ];
    }
    if (controller == _descriptionController) {
      return [LengthLimitingTextInputFormatter(60)];
    }
    if (controller == _merchantController) {
      return [LengthLimitingTextInputFormatter(50)];
    }
    return null;
  }

  Widget _buildLimitedFieldLabel({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required int limit,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final count = controller.text.characters.length;
        final showCounter = focusNode.hasFocus && count > 0;
        final warningStart = (limit * 0.8).ceil();
        final counterColor = count >= limit
            ? appTheme.errorRed
            : count >= warningStart
            ? appTheme.wholeBudgetProgress
            : appTheme.teal_A700;
        return Row(
          children: [
            Text(label.toUpperCase(), style: _fieldLabelStyle),
            Spacer(),
            if (showCounter)
              Text(
                '$count/$limit',
                style: _fieldLabelStyle.copyWith(color: counterColor),
              ),
          ],
        );
      },
    );
  }

  FocusNode? _focusNodeFor(TextEditingController controller) {
    if (controller == _descriptionController) return _descriptionFocus;
    if (controller == _merchantController) return _merchantFocus;
    return null;
  }

  int? _characterLimitFor(TextEditingController controller) {
    if (controller == _descriptionController) return 60;
    if (controller == _merchantController) return 50;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final itemNameTextStyle = Theme.of(
      context,
    ).textTheme.bodyLarge!.copyWith(color: appTheme.gray_900);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: appTheme.gray_200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0x08F9FAFB),
              border: Border(bottom: BorderSide(color: appTheme.gray_100)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: appTheme.teal_A700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: appTheme.white_A700,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLimitedFieldLabel(
                        label: 'Item Name',
                        controller: _itemNameController,
                        focusNode: _itemNameFocus,
                        limit: 30,
                      ),
                      SizedBox(height: 6),
                      TextField(
                        controller: _itemNameController,
                        focusNode: _itemNameFocus,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9 -]'),
                          ),
                          LengthLimitingTextInputFormatter(30),
                        ],
                        decoration: _fieldDecoration('Item'),
                        style: itemNameTextStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  'Item Description (Optional)',
                  _descriptionController,
                  '',
                ),
                SizedBox(height: 14),
                _buildTextField(
                  'Merchant Name (Optional)',
                  _merchantController,
                  '',
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildDatePicker()),
                    SizedBox(width: 12),
                    Expanded(child: _buildTimePicker()),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Quantity',
                        _quantityController,
                        '1',
                        TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'Unit Price (${widget.currency})',
                        _unitPriceController,
                        '0.00',
                        TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ValueListenableBuilder<double>(
                  valueListenable: _subtotalNotifier,
                  builder: (context, subtotal, _) {
                    return Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: appTheme.teal_50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal',
                            style: TextStyle(
                              color: appTheme.blue_gray_300,
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'AMOUNT',
                                style: TextStyle(
                                  color: appTheme.blue_gray_300,
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                _formatExpenseCurrencyAmount(
                                  widget.currency,
                                  subtotal,
                                ),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: widget.onDiscard,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: appTheme.blue_gray_300,
                        side: BorderSide(color: appTheme.gray_200),
                        minimumSize: Size(100, 44),
                      ),
                      child: Text('Discard'),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saveItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appTheme.teal_A700,
                        foregroundColor: appTheme.white_A700,
                        minimumSize: Size(98, 44),
                      ),
                      child: Text(
                        widget.initialItem == null
                            ? 'Save Item'
                            : 'Update Item',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String? hint, [
    TextInputType? keyboardType,
  ]) {
    final focusNode = _focusNodeFor(controller);
    final characterLimit = _characterLimitFor(controller);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (focusNode != null && characterLimit != null)
          _buildLimitedFieldLabel(
            label: label,
            controller: controller,
            focusNode: focusNode,
            limit: characterLimit,
          )
        else
          Text(label.toUpperCase(), style: _fieldLabelStyle),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          inputFormatters: _inputFormattersFor(controller),
          decoration: _fieldDecoration(hint),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DATE', style: _fieldLabelStyle),
        SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 43,
          child: OutlinedButton.icon(
            onPressed: _pickDate,
            style: _dateTimeButtonStyle,
            icon: Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TIME', style: _fieldLabelStyle),
        SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 43,
          child: OutlinedButton.icon(
            onPressed: _pickTime,
            style: _dateTimeButtonStyle,
            icon: Icon(Icons.access_time_outlined, size: 18),
            label: Text(_selectedTime.format(context)),
          ),
        ),
      ],
    );
  }

  static final _fieldLabelStyle = TextStyle(
    color: appTheme.blue_gray_300,
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static final _dateTimeButtonStyle = OutlinedButton.styleFrom(
    alignment: Alignment.centerLeft,
    foregroundColor: appTheme.gray_900,
    backgroundColor: appTheme.gray_50,
    padding: EdgeInsets.symmetric(horizontal: 12),
    side: BorderSide(color: appTheme.gray_100),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  InputDecoration _fieldDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Color(0xFFBFC4CC)),
      filled: true,
      fillColor: appTheme.gray_50,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: appTheme.gray_100),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: appTheme.gray_100),
      ),
    );
  }
}

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final int maximumIntegerDigits;
  final int decimalDigits;
  final bool allowZero;
  final double? maximumValue;

  const _ThousandsSeparatorInputFormatter({
    required this.maximumIntegerDigits,
    required this.decimalDigits,
    this.allowZero = false,
    this.maximumValue,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    final validPattern = decimalDigits == 0
        ? RegExp(r'^\d+$')
        : RegExp('^\\d+(?:\\.\\d{0,$decimalDigits})?\$');
    if (!validPattern.hasMatch(raw)) return oldValue;

    final parts = raw.split('.');
    final integerPart = parts.first;
    if (integerPart.length > maximumIntegerDigits) return oldValue;
    if (integerPart.startsWith('0') && (!allowZero || integerPart.length > 1)) {
      return oldValue;
    }
    if (maximumValue != null && (double.tryParse(raw) ?? 0) > maximumValue!) {
      return oldValue;
    }

    final groupedInteger = NumberFormat.decimalPattern(
      'en_US',
    ).format(int.parse(integerPart));
    final hasDecimalPoint = decimalDigits > 0 && raw.contains('.');
    final formatted = hasDecimalPoint
        ? '$groupedInteger.${parts.length > 1 ? parts[1] : ''}'
        : groupedInteger;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _TopMessageAlert extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  _TopMessageAlert({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 250),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, -36 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Material(
        color: appTheme.transparentCustom,
        child: Container(
          padding: EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            color: Color(0xFFFFE4E6),
            border: Border.all(color: appTheme.errorRed),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: appTheme.errorRed),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Color(0xFF7F1D1D),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close, color: Color(0xFF7F1D1D)),
                tooltip: 'Close message',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  _ExpenseSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: appTheme.white_A700,
          border: Border.all(color: appTheme.gray_100),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 15,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: appTheme.blue_gray_300,
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ExpenseActivitySummary extends StatelessWidget {
  final Activity activity;
  final String timeText;

  _ExpenseActivitySummary({required this.activity, required this.timeText});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: appTheme.gray_100),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _ExpenseActivityImage(imageUrl: activity.activityImgUrl),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.destination,
                    style: TextStyle(
                      color: appTheme.gray_900,
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  _detail(Icons.access_time_outlined, timeText),
                  SizedBox(height: 6),
                  _detail(
                    Icons.account_balance_wallet_outlined,
                    'MYR ${activity.allocatedBudget.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: appTheme.blue_gray_300),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: appTheme.blue_gray_300,
            fontFamily: 'Inter',
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _ExpenseActivityImage extends StatelessWidget {
  final String imageUrl;

  _ExpenseActivityImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: appTheme.gray_100,
      child: SizedBox(width: 120, height: 90),
    );

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        width: 120,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    if (imageUrl.isNotEmpty) {
      return Image.asset(
        imageUrl,
        width: 120,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    return placeholder;
  }
}

class _ExpenseCategoryCard extends StatelessWidget {
  final String category;

  _ExpenseCategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
        decoration: BoxDecoration(
          color: appTheme.white_A700,
          border: Border.all(color: appTheme.gray_100),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CATEGORY',
              style: TextStyle(
                color: appTheme.blue_gray_300,
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: appTheme.gray_200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.category_outlined, color: appTheme.blueGray900),
                  SizedBox(width: 12),
                  Text(
                    category,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
