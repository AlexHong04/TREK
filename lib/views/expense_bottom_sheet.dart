import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entities/activity.dart';
import '../theme/app_colors.dart';
import '../models/entities/expense_item.dart';
import '../view_models/presentation_logic/activity_view_model.dart';
import '../view_models/ui_state/activity_ui_state.dart';

/// Expense-specific shades that are not part of the shared team palette.
class _ExpenseColors {
  static const Color fieldOverlay = Color(0x08F9FAFB);
  static const Color disabledIcon = Color(0xFFB3B3B3);
  static const Color hintText = Color(0xFFBFC4CC);
  static const Color errorBackground = Color(0xFFFFE4E6);
  static const Color errorText = Color(0xFF7F1D1D);
  static const Color cardShadow = Color(0x14000000);
  static const Color subtleShadow = Color(0x0D000000);
  static const Color alertShadow = Color(0x24000000);
}

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
    barrierColor: AppColors.black.withOpacity(0.20),
    backgroundColor: AppColors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: viewModel,
      child: ExpenseBottomSheet(activity: activity),
    ),
  );
}
class ExpenseBottomSheet extends StatefulWidget {
  final Activity activity;

  const ExpenseBottomSheet({required this.activity});

  @override
  State<ExpenseBottomSheet> createState() => _ExpenseBottomSheetState();
}

class _ExpenseBottomSheetState extends State<ExpenseBottomSheet> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int? _editingItemIndex;
  bool _isEditingItem = false;
  bool _showItemForm = true;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final timeText = activity.startTime?.isNotEmpty == true
        ? activity.startTime!
        : DateFormat.jm().format(activity.date);
    final uiState = context.watch<ActivityViewModel>().uiState;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.10,
      maxChildSize: 0.96,
      snap: true,
      snapSizes: const [0.50, 0.92],
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) => Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Material(
              color: AppColors.white,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 64,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.gray200,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Add Expense',
                        style: TextStyle(
                          color: AppColors.blueGray900,
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ExpenseActivitySummary(
                        activity: activity,
                        timeText: timeText,
                      ),
                      const SizedBox(height: 10),
                      _ExpenseCategoryCard(category: activity.activityCategory),
                      const SizedBox(height: 10),
                      _buildExpenseItemsSection(uiState),
                      const SizedBox(height: 10),
                      _buildTotalAmountSection(uiState),
                      const SizedBox(height: 10),
                      _buildPaymentMethodSection(uiState),
                      const SizedBox(height: 10),
                      _buildReceiptSection(uiState),
                      if (uiState.errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildMessage(uiState.errorMessage, true),
                      ],
                      if (uiState.successMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildMessage(uiState.successMessage, false),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: uiState.isSavingExpense
                              ? null
                              : _showConfirmExpenseDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tealA700,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: uiState.isSavingExpense
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            uiState.isSavingExpense
                                ? 'Saving Expense...'
                                : 'Confirm Expense',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildExpenseItemsSection(ActivityUiState uiState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray100),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: _ExpenseColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXPENSE ITEMS',
            style: TextStyle(
              color: AppColors.blueGray300,
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < uiState.draftExpenseItems.length; index++)
            _buildSavedItemCard(uiState.draftExpenseItems[index], index),
          if (_showItemForm) _buildItemForm(),
          const SizedBox(height: 14),
          InkWell(
            onTap: _startNewItem,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.gray200,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: AppColors.blueGray300, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Add Another Item',
                    style: TextStyle(
                      color: AppColors.blueGray300,
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

  Widget _buildSavedItemCard(ExpenseItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.tealA700,
          child: Icon(Icons.receipt_long_outlined, color: AppColors.white),
        ),
        title: Text(
          item.itemName,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${item.quantity} × RM${item.unitPrice.toStringAsFixed(2)} = RM${item.subtotal.toStringAsFixed(2)}',
        ),
        trailing: Wrap(
          children: [
            IconButton(
              onPressed: () => _editItem(item, index),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: () => _confirmDeleteItem(index),
              icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemForm() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final unitPrice = _parsePrice(_unitPriceController.text) ?? 0;
    final subtotal = quantity * unitPrice;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gray200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _ExpenseColors.fieldOverlay,
              border: Border(bottom: BorderSide(color: AppColors.gray100)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.tealA700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ITEM ENTRY',
                        style: TextStyle(
                          color: AppColors.blueGray300,
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .5,
                        ),
                      ),
                      TextField(
                        controller: _itemNameController,
                        readOnly: !_isEditingItem,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Item Entry',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _isEditingItem = true),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: _ExpenseColors.disabledIcon,
                  ),
                ),
                IconButton(
                  onPressed: _editingItemIndex == null
                      ? null
                      : () => _confirmDeleteItem(
                          _editingItemIndex!,
                          clearEditor: true,
                        ),
                  icon: const Icon(Icons.close, color: _ExpenseColors.disabledIcon),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Item Description', _descriptionController, ''),
                const SizedBox(height: 14),
                _buildTextField(
                  'Merchant Name (Optional)',
                  _merchantController,
                  '',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildDatePicker()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTimePicker()),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Quantity',
                        _quantityController,
                        '',
                        TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'Unit Price',
                        _unitPriceController,
                        '',
                        const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    border: Border.all(color: AppColors.gray200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(
                          color: AppColors.blueGray300,
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'AMOUNT',
                            style: TextStyle(
                              color: AppColors.blueGray300,
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'RM${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _discardItem,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blueGray300,
                        side: const BorderSide(color: AppColors.gray200),
                        minimumSize: const Size(100, 44),
                      ),
                      child: const Text('Discard'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isEditingItem ? _saveItem : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealA700,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size(98, 44),
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
        const SizedBox(height: 6),
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
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 43,
          child: OutlinedButton.icon(
            onPressed: _isEditingItem ? _pickDate : null,
            style: _dateTimeButtonStyle,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
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
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 43,
          child: OutlinedButton.icon(
            onPressed: _isEditingItem ? _pickTime : null,
            style: _dateTimeButtonStyle,
            icon: const Icon(Icons.access_time_outlined, size: 18),
            label: Text(_selectedTime.format(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalAmountSection(ActivityUiState uiState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL AMOUNT',
            style: TextStyle(
              color: AppColors.blueGray300,
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'RM${uiState.draftTotalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.gray900,
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(ActivityUiState uiState) {
    const methods = ['Debit/Credit Card', 'Cash', 'E-wallet', 'Bank Transfer'];
    return _ExpenseSectionCard(
      title: 'PAYMENT METHOD',
      child: DropdownButtonFormField<String>(
        value: uiState.paymentMethod.isEmpty ? null : uiState.paymentMethod,
        decoration: _fieldDecoration(
          'Optional',
        ).copyWith(prefixIcon: const Icon(Icons.credit_card_outlined)),
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
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(uiState.receiptLocalPath),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Receipt selected')),
                IconButton(
                  onPressed: context.read<ActivityViewModel>().removeReceipt,
                  icon: const Icon(Icons.close, color: AppColors.errorRed),
                ),
              ],
            )
          : OutlinedButton.icon(
              onPressed: uiState.isPickingReceipt ? null : _chooseReceipt,
              icon: uiState.isPickingReceipt
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_outlined),
              label: Text(
                uiState.isPickingReceipt
                    ? 'Opening...'
                    : 'Scan or upload receipt',
              ),
            ),
    );
  }

  Widget _buildMessage(String message, bool isError) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? _ExpenseColors.errorBackground : AppColors.teal50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
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
    _topMessageTimer = Timer(const Duration(seconds: 5), _dismissTopMessage);
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

  Future<void> _chooseReceipt() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await context.read<ActivityViewModel>().takeReceiptPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await context
                    .read<ActivityViewModel>()
                    .chooseReceiptFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExpense() async {
    final viewModel = context.read<ActivityViewModel>();
    await viewModel.confirmExpense();
    if (!mounted) return;

    if (viewModel.uiState.errorMessage.isNotEmpty) {
      _showValidationMessage(viewModel.uiState.errorMessage);
      return;
    }

    if (viewModel.uiState.successMessage.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(viewModel.uiState.successMessage)));
    Navigator.pop(context);
  }

  Future<void> _showConfirmExpenseDialog() async {
    final totalAmount = context
        .read<ActivityViewModel>()
        .uiState
        .draftTotalAmount;
    final isConfirmed = await _showConfirmationDialog(
      title: 'Confirm Expense',
      message:
          'Are you sure you want to record this expense of RM${totalAmount.toStringAsFixed(2)}?',
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
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? AppColors.errorRed
                  : AppColors.tealA700,
              foregroundColor: AppColors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return isConfirmed ?? false;
  }

  static const _fieldLabelStyle = TextStyle(
    color: AppColors.blueGray300,
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static final _dateTimeButtonStyle = OutlinedButton.styleFrom(
    alignment: Alignment.centerLeft,
    foregroundColor: AppColors.gray900,
    backgroundColor: AppColors.gray50,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    side: const BorderSide(color: AppColors.gray100),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  InputDecoration _fieldDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _ExpenseColors.hintText),
      filled: true,
      fillColor: AppColors.gray50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray100),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray100),
      ),
    );
  }
}

class _TopMessageAlert extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _TopMessageAlert({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 250),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, -36 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Material(
        color: AppColors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            color: _ExpenseColors.errorBackground,
            border: Border.all(color: AppColors.errorRed),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: _ExpenseColors.alertShadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.errorRed),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: _ExpenseColors.errorText,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: _ExpenseColors.errorText),
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

  const _ExpenseSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray100),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: _ExpenseColors.subtleShadow,
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
            style: const TextStyle(
              color: AppColors.blueGray300,
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ExpenseActivitySummary extends StatelessWidget {
  final Activity activity;
  final String timeText;

  const _ExpenseActivitySummary({
    required this.activity,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gray100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _ExpenseActivityImage(imageUrl: activity.activityImgUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.destination,
                  style: const TextStyle(
                    color: AppColors.gray900,
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _detail(Icons.access_time_outlined, timeText),
                const SizedBox(height: 6),
                _detail(
                  Icons.account_balance_wallet_outlined,
                  'RM${activity.allocatedBudget.toStringAsFixed(2)}',
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
        Icon(icon, size: 18, color: AppColors.blueGray300),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.blueGray300,
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

  const _ExpenseActivityImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: AppColors.gray100,
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

  const _ExpenseCategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray100),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: _ExpenseColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CATEGORY',
            style: TextStyle(
              color: AppColors.blueGray300,
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gray200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.category_outlined, color: AppColors.blueGray900),
                const SizedBox(width: 12),
                Text(
                  category,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
