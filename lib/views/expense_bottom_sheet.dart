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
import '../view_models/presentation_logic/activity_view_model.dart';
import '../view_models/ui_state/activity_ui_state.dart';
import '../widgets/converted_amount_text.dart';

/// Opens the Expense form for the Activity selected from the itinerary.
Future<void> showExpenseBottomSheet({
  required BuildContext context,
  required Activity activity,
  required ActivityViewModel viewModel,
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
      child: ExpenseBottomSheet(activity: activity),
    ),
  );
}

class ExpenseBottomSheet extends StatefulWidget {
  final Activity activity;

  ExpenseBottomSheet({required this.activity});

  @override
  State<ExpenseBottomSheet> createState() => _ExpenseBottomSheetState();
}

class _ExpenseBottomSheetState extends State<ExpenseBottomSheet> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int? _editingItemIndex;
  bool _isEditingItem = false;
  bool _showItemForm = false;
  bool _isRecordingNewExpense = false;
  bool _hasAppliedOcrValues = false;
  String? _topMessage;
  Timer? _topMessageTimer;

  @override
  void dispose() {
    _topMessageTimer?.cancel();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _merchantController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _taxController.dispose();
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
    final hasOneRecordedExpense = uiState.recordedExpenses.length == 1;
    final hasMoreRecordedExpensesThanFit = uiState.recordedExpenses.length >= 3;
    final canExpandSheet = isExpenseFormMode || hasMoreRecordedExpensesThanFit;
    final recordedExpensesHeight = hasOneRecordedExpense ? 0.65 : 0.74;

    return DraggableScrollableSheet(
      initialChildSize: isExpenseFormMode ? 0.78 : recordedExpensesHeight,
      minChildSize: 0.10,
      maxChildSize: canExpandSheet ? 0.90 : recordedExpensesHeight,
      snap: true,
      snapSizes: isExpenseFormMode
          ? [0.50, 0.78, 0.90]
          : hasMoreRecordedExpensesThanFit
          ? [0.50, 0.74, 0.90]
          : hasOneRecordedExpense
          ? [0.50, 0.65]
          : [0.50, 0.74],
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) => Stack(
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
                        showRecordedExpenses
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
                      _ExpenseCategoryCard(category: activity.activityCategory),
                      SizedBox(height: 10),
                      if (uiState.isLoadingRecordedExpenses)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (showRecordedExpenses)
                        _buildRecordedExpensesSection(uiState)
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
        ],
      ),
    );
  }

  Widget _buildNewExpenseForm(ActivityUiState uiState) {
    return Column(
      children: [
        _buildExpenseItemsSection(uiState),
        SizedBox(height: 10),
        _buildTaxSection(uiState),
        SizedBox(height: 10),
        _buildTotalAmountSection(uiState),
        SizedBox(height: 10),
        _buildPaymentMethodSection(uiState),
        SizedBox(height: 10),
        _buildReceiptSection(uiState),
        if (uiState.isScanningReceipt ||
            uiState.ocrRawText.isNotEmpty ||
            uiState.errorMessage.startsWith('Unable to read the receipt.')) ...[
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
          child: ElevatedButton.icon(
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
            icon: uiState.isSavingExpense
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: appTheme.white_A700,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.save_outlined),
            label: Text(
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
    return context.read<ActivityViewModel>().preferredCurrency.trim().toUpperCase();
  }

  String _savedExpenseCurrency(Expense expense) {
    final currency = expense.currency.trim().toUpperCase();
    if (currency.isNotEmpty) return currency;
    return context.read<ActivityViewModel>().preferredCurrency.trim().toUpperCase();
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
    );
  }

  Widget _buildRecordedExpenseCard(Expense expense, int expenseNumber) {
    final currency = _savedExpenseCurrency(expense);
    final recordedOn = expense.createdAt == null
        ? 'Recorded expense'
        : DateFormat('dd MMM yyyy, hh:mm a').format(expense.createdAt!);

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
              Icon(
                Icons.receipt_long_outlined,
                color: appTheme.teal_A700,
              ),
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
      builder: (dialogContext) => AlertDialog(
        title: Text('Expense #$expenseNumber'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConvertedAmountText(
                  amount: expense.totalAmount,
                  originalCurrency: currency,
                  primaryStyle: TextStyle(
                    color: appTheme.gray_900,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text('Payment: ${expense.paymentMethod ?? 'Not specified'}'),
                Text(
                  expense.createdAt == null
                      ? 'Recorded: Date and time unavailable'
                      : 'Recorded: ${DateFormat('dd MMM yyyy, hh:mm a').format(expense.createdAt!)}',
                ),
                Text(
                  expense.receiptImageUrl == null
                      ? 'Receipt: Not attached'
                      : 'Receipt: Attached',
                ),
                SizedBox(height: 16),
                Text(
                  'ITEMS',
                  style: TextStyle(
                    color: appTheme.gray_400,
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                if (expenseItems.isEmpty)
                  Text('No expense items were found.')
                else
                  for (final item in expenseItems)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _showExpenseItemDetails(item, currency),
                      title: Text(item.itemName),
                      subtitle: Text(
                        '${DateFormat('dd MMM yyyy, hh:mm a').format(item.expenseDateTime)}\n'
                        '${item.quantity} × '
                        '${formatCurrencyAmount(currency, item.unitPrice)}',
                      ),
                      trailing: ConvertedAmountText(
                        amount: item.subtotal,
                        originalCurrency: currency,
                        primaryStyle: _moneyTextStyle,
                        secondaryStyle: TextStyle(
                          color: appTheme.blue_gray_300,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        crossAxisAlignment: CrossAxisAlignment.end,
                        textAlign: TextAlign.end,
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close'),
          ),
        ],
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
          if (_showItemForm) _buildItemForm(),
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
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _showExpenseItemDetails(item, currency),
        leading: CircleAvatar(
          backgroundColor: appTheme.teal_A700,
          child: Icon(Icons.receipt_long_outlined, color: appTheme.white_A700),
        ),
        title: Text(
          item.itemName,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${item.quantity} × ${formatCurrencyAmount(currency, item.unitPrice)}'
          ' = ${formatCurrencyAmount(currency, item.subtotal)}',
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
    );
  }

  Future<void> _showExpenseItemDetails(
    ExpenseItem item,
    String currency,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: EdgeInsets.fromLTRB(24, 20, 8, 0),
        title: Row(
          children: [
            Expanded(child: Text(item.itemName)),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(dialogContext),
              icon: Icon(Icons.close),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildItemDetailRow('Item Name', item.itemName),
              _buildItemDetailRow(
                'Description',
                item.itemDescription?.trim().isNotEmpty == true
                    ? item.itemDescription!
                    : 'Not provided',
              ),
              _buildItemDetailRow(
                'Merchant',
                item.merchantName?.trim().isNotEmpty == true
                    ? item.merchantName!
                    : 'Not provided',
              ),
              _buildItemDetailRow(
                'Date/Time',
                DateFormat('dd MMM yyyy, hh:mm a')
                    .format(item.expenseDateTime),
              ),
              _buildItemDetailRow('Quantity', item.quantity.toString()),
              _buildItemDetailRow(
                'Unit Price',
                formatCurrencyAmount(currency, item.unitPrice),
              ),
              _buildItemDetailRow(
                'Subtotal',
                formatCurrencyAmount(currency, item.subtotal),
              ),
            ],
          ),
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
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildItemForm() {
    final uiState = context.watch<ActivityViewModel>().uiState;
    final currency = _activeExpenseCurrency(uiState);
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final unitPrice = _parsePrice(_unitPriceController.text) ?? 0;
    final subtotal = quantity * unitPrice;
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
                      Text(
                        'ITEM ENTRY',
                        style: _fieldLabelStyle,
                      ),
                      SizedBox(height: 6),
                      if (_isEditingItem)
                        TextField(
                          controller: _itemNameController,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          decoration: _fieldDecoration('Item'),
                        )
                      else
                        Text(
                          _itemNameController.text.trim().isEmpty
                              ? 'Item'
                              : _itemNameController.text.trim(),
                          style: itemNameTextStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                _buildTextField('Item Description', _descriptionController, ''),
                SizedBox(height: 14),
                _buildTextField(
                  'Merchant Name (Optional)',
                  _merchantController,
                  '',
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePicker(),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildTimePicker(),
                    ),
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
                        'Unit Price ($currency)',
                        _unitPriceController,
                        '0.00',
                        TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
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
                            formatCurrencyAmount(currency, subtotal),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _discardItem,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: appTheme.blue_gray_300,
                        side: BorderSide(color: appTheme.gray_200),
                        minimumSize: Size(100, 44),
                      ),
                      child: Text('Discard'),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isEditingItem ? _saveItem : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appTheme.teal_A700,
                        foregroundColor: appTheme.white_A700,
                        minimumSize: Size(98, 44),
                      ),
                      child: Text(
                        _editingItemIndex == null ? 'Save Item' : 'Update Item',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: _fieldLabelStyle),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: !_isEditingItem,
          keyboardType: keyboardType,
          inputFormatters: _inputFormattersFor(controller),
          onChanged: (_) => setState(() {}),
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
            onPressed: _isEditingItem ? _pickDate : null,
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
            onPressed: _isEditingItem ? _pickTime : null,
            style: _dateTimeButtonStyle,
            icon: Icon(Icons.access_time_outlined, size: 18),
            label: Text(_selectedTime.format(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildTaxSection(ActivityUiState uiState) {
    final currency = _activeExpenseCurrency(uiState);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TAX (OPTIONAL)',
                style: TextStyle(
                  color: appTheme.blue_gray_300,
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: _taxController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d{0,5}([.,]\d{0,2})?$'),
              ),
            ],
            onChanged: (value) {
              final parsedTax = _parsePrice(value) ?? 0.0;
              context.read<ActivityViewModel>().setDraftTaxAmount(parsedTax);
            },
            decoration: _fieldDecoration('0.00').copyWith(
              prefixText: '$currency ',
              prefixStyle: TextStyle(
                color: appTheme.gray_900,
                fontWeight: FontWeight.w600,
              ),
              suffixIcon: IconButton(
                onPressed: _confirmTaxAmount,
                icon: Icon(Icons.check, color: appTheme.teal_A700),
                tooltip: 'Confirm tax amount',
              ),
            ),
          ),
        ],
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
            'TOTAL (INCLUDING TAX)',
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
                      onTap: () => _showReceiptPreview(uiState.receiptLocalPath),
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
                          : context.read<ActivityViewModel>().removeReceipt,
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: InteractiveViewer(
                child: Image.file(
                  File(receiptLocalPath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => SizedBox(
                    height: 180,
                    child: Center(child: Text('Unable to display receipt image.')),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: Icon(Icons.close, color: appTheme.errorRed),
                tooltip: 'Close receipt preview',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrReviewSection(ActivityUiState uiState) {
    if (uiState.isScanningReceipt) {
      return _ExpenseSectionCard(
        title: 'RECEIPT OCR',
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Reading receipt text...'),
          ],
        ),
      );
    }

    final hasOcrDateTime = uiState.ocrTransactionDateTime != null;
    final hasOcrTotal = uiState.ocrExtractedTotal != null;
    final currency = _activeExpenseCurrency(uiState);
    final ocrFailed =
        uiState.ocrRawText.isEmpty &&
        uiState.errorMessage.startsWith('Unable to read the receipt.');

    if (ocrFailed) {
      return _ExpenseSectionCard(
        title: 'RECEIPT OCR',
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _scanReceipt,
                child: Text('Retry OCR'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: context
                    .read<ActivityViewModel>()
                    .clearExpenseMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.teal_A700,
                  foregroundColor: appTheme.white_A700,
                ),
                child: Text('Manual Entry'),
              ),
            ),
          ],
        ),
      );
    }

    return _ExpenseSectionCard(
      title: 'RECEIPT OCR REVIEW',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOcrValue(
            'Merchant',
            uiState.ocrMerchantName.isEmpty
                ? 'Not detected'
                : uiState.ocrMerchantName,
          ),
          _buildOcrValue(
            'Date and time',
            hasOcrDateTime
                ? DateFormat(
                    'dd MMM yyyy, hh:mm a',
                  ).format(uiState.ocrTransactionDateTime!)
                : 'Not detected',
          ),
          _buildOcrValue(
            'Extracted tax',
            uiState.ocrExtractedTax != null
                ? formatCurrencyAmount(currency, uiState.ocrExtractedTax!)
                : '${formatCurrencyAmount(currency, 0)} (Not detected)',
          ),
          _buildOcrValue(
            'Extracted total',
            hasOcrTotal
                ? formatCurrencyAmount(currency, uiState.ocrExtractedTotal!)
                : 'Not detected',
          ),
          if (uiState.ocrItemLines.isNotEmpty) ...[
            SizedBox(height: 8),
            Text('Possible receipt items', style: _fieldLabelStyle),
            SizedBox(height: 4),
            ...uiState.ocrItemLines.map(
              (line) => Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text('- $line'),
              ),
            ),
          ],
          SizedBox(height: 8),
          Text(
            'Review and edit these values in the item form before saving.',
            style: TextStyle(color: appTheme.blue_gray_300, fontSize: 12),
          ),
          SizedBox(height: 10),
          if (_hasAppliedOcrValues)
            Text(
              'OCR values created editable expense items below.',
              style: TextStyle(color: appTheme.teal_A700, fontSize: 12),
            ),
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

  Widget _buildOcrValue(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: appTheme.gray_900, fontSize: 14),
          children: [
            TextSpan(text: '$label: ', style: _fieldLabelStyle),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null && mounted) setState(() => _selectedTime = time);
  }

  void _saveItem() {
    final name = _itemNameController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim());
    final price = _parsePrice(_unitPriceController.text);
    if (name.isEmpty) {
      _showValidationMessage('Item name cannot be empty.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      _showValidationMessage('Item quantity must be greater than zero.');
      return;
    }
    if (price == null || price < 0) {
      _showValidationMessage('Enter a valid unit price of zero or more.');
      return;
    }
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final item = ExpenseItem(
      itemName: name,
      itemDescription: _nullIfEmpty(_descriptionController.text),
      merchantName: _nullIfEmpty(_merchantController.text),
      expenseDateTime: dateTime,
      quantity: quantity,
      unitPrice: price,
      subtotal: quantity * price,
    );
    final viewModel = context.read<ActivityViewModel>();
    final currentIndex = _editingItemIndex;
    if (currentIndex == null) {
      final newItemIndex = viewModel.uiState.draftExpenseItems.length;
      viewModel.addExpenseItem(item);
      setState(() {
        _editingItemIndex = newItemIndex;
        _isEditingItem = false;
        _showItemForm = false;
      });
    } else {
      viewModel.updateExpenseItem(currentIndex, item);
      setState(() {
        _isEditingItem = false;
        _showItemForm = false;
      });
    }
  }

  String? _nullIfEmpty(String value) =>
      value.trim().isEmpty ? null : value.trim();

  void _confirmTaxAmount() {
    final tax = _parsePrice(_taxController.text) ?? 0.0;
    if (tax > 99999) {
      _showValidationMessage('Tax amount must be between 0 and 99,999.');
      return;
    }
    _taxController.text = tax > 0 ? tax.toStringAsFixed(2) : '';
    context.read<ActivityViewModel>().setDraftTaxAmount(tax);
    FocusScope.of(context).unfocus();
  }

  double? _parsePrice(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  List<TextInputFormatter>? _inputFormattersFor(
    TextEditingController controller,
  ) {
    if (controller == _quantityController) {
      return [FilteringTextInputFormatter.digitsOnly];
    }
    if (controller == _unitPriceController) {
      return [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))];
    }
    return null;
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
      _editingItemIndex = index;
      _isEditingItem = true;
      _showItemForm = true;
      _itemNameController.text = item.itemName;
      _descriptionController.text = item.itemDescription ?? '';
      _merchantController.text = item.merchantName ?? '';
      _quantityController.text = item.quantity.toString();
      _unitPriceController.text = item.unitPrice.toStringAsFixed(2);
      _selectedDate = item.expenseDateTime;
      _selectedTime = TimeOfDay.fromDateTime(item.expenseDateTime);
    });
  }

  void _discardItem() {
    setState(() {
      _editingItemIndex = null;
      _isEditingItem = false;
      _showItemForm = false;
      _itemNameController.clear();
      _descriptionController.clear();
      _merchantController.clear();
      _quantityController.clear();
      _unitPriceController.clear();
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    });
  }

  void _startNewItem() {
    if (_showItemForm && _hasUnfinishedItem()) {
      _showValidationMessage(
        'Save or discard the current item before adding another item.',
      );
      return;
    }
    _discardItem();
    setState(() {
      _isEditingItem = true;
      _showItemForm = true;
    });
  }

  bool _hasUnfinishedItem() {
    return _itemNameController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _merchantController.text.trim().isNotEmpty ||
        _quantityController.text.trim().isNotEmpty ||
        _unitPriceController.text.trim().isNotEmpty;
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
    }

    if (uiState.ocrRawText.isNotEmpty) {
      final itemCount = viewModel.applyOcrItemsToDraft();
      final detectedTax = viewModel.uiState.draftTaxAmount;
      _taxController.text = detectedTax > 0
          ? detectedTax.toStringAsFixed(2)
          : '';
      if (itemCount > 0) {
        setState(() {
          _editingItemIndex = null;
          _isEditingItem = false;
          _showItemForm = false;
          _hasAppliedOcrValues = true;
          _itemNameController.clear();
          _descriptionController.clear();
          _merchantController.clear();
          _quantityController.clear();
          _unitPriceController.clear();
        });
      } else {
        _showValidationMessage(
          'No item details were detected. Please add the expense item manually.',
        );
      }
    }
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
                  await _offerReceiptCropThenScan();
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
                  await _offerReceiptCropThenScan();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Receipt validation has already succeeded before this dialog is shown.
  /// The tourist may crop the image or keep the original before OCR starts.
  Future<void> _offerReceiptCropThenScan() async {
    final shouldCrop = await _showConfirmationDialog(
      title: 'Crop Receipt Before Scanning?',
      message:
          'You can crop the receipt to remove unnecessary background and improve text recognition.',
      confirmLabel: 'Crop Receipt',
      cancelLabel: 'Skip Cropping',
    );
    if (!mounted) return;

    if (shouldCrop) {
      await context.read<ActivityViewModel>().cropSelectedReceipt();
      if (!mounted) return;

      final errorMessage = context.read<ActivityViewModel>().uiState.errorMessage;
      if (errorMessage.isNotEmpty) {
        _showValidationMessage(errorMessage);
        return;
      }
    }

    await _scanReceipt();
  }

  Future<void> _confirmExpense() async {
    debugPrint('DEBUG: [_confirmExpense] Button action reached');
    final viewModel = context.read<ActivityViewModel>();
    await viewModel.confirmExpense();
    if (!mounted) return;

    debugPrint('DEBUG: confirmExpense done. Error: "${viewModel.uiState.errorMessage}", Success: "${viewModel.uiState.successMessage}"');

    if (viewModel.uiState.errorMessage.isNotEmpty) {
      _showValidationMessage(viewModel.uiState.errorMessage);
      return;
    }

    if (viewModel.uiState.successMessage.isEmpty) return;

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
      _isEditingItem = false;
      _showItemForm = false;
      _itemNameController.clear();
      _descriptionController.clear();
      _merchantController.clear();
      _quantityController.clear();
      _unitPriceController.clear();
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    });
  }

  Future<void> _showConfirmExpenseDialog() async {
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
          '${formatCurrencyAmount(currency, totalAmount)}?',
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
    if (clearEditor) _discardItem();
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'No',
    bool isDestructive = false,
  }) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? appTheme.errorRed
                  : appTheme.teal_A700,
              foregroundColor: appTheme.white_A700,
            ),
            child: Text(confirmLabel),
          ),
        ],
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
    return Container(
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
    );
  }
}

class _ExpenseActivitySummary extends StatelessWidget {
  final Activity activity;
  final String timeText;

  _ExpenseActivitySummary({
    required this.activity,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  formatCurrencyAmount(
                    context.watch<ActivityViewModel>().preferredCurrency,
                    activity.allocatedBudget,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return Container(
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
                Icon(
                  Icons.category_outlined,
                  color: appTheme.blueGray900,
                ),
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
    );
  }
}
