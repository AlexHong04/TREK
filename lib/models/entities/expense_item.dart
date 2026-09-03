/// Monetary values inherit the original currency from the parent [Expense].
class ExpenseItem {
  final String? expenseItemId;
  final String? expenseId;
  final String itemName;
  final String? itemDescription;
  final String? merchantName;
  final DateTime expenseDateTime;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const ExpenseItem({
    this.expenseItemId,
    this.expenseId,
    required this.itemName,
    this.itemDescription,
    this.merchantName,
    required this.expenseDateTime,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      expenseItemId: json['expense_item_id'] as String?,
      expenseId: json['expense_id'] as String?,
      itemName: json['item_name'] as String,
      itemDescription: json['item_description'] as String?,
      merchantName: json['merchant_name'] as String?,
      expenseDateTime: DateTime.parse(json['expense_datetime'] as String),
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (expenseItemId != null) 'expense_item_id': expenseItemId,
      if (expenseId != null) 'expense_id': expenseId,
      'item_name': itemName,
      if (itemDescription != null) 'item_description': itemDescription,
      if (merchantName != null) 'merchant_name': merchantName,
      'expense_datetime': expenseDateTime.toIso8601String(),
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
    };
  }

  ExpenseItem copyWith({
    String? expenseItemId,
    String? expenseId,
    String? itemName,
    String? itemDescription,
    String? merchantName,
    DateTime? expenseDateTime,
    int? quantity,
    double? unitPrice,
    double? subtotal,
  }) {
    return ExpenseItem(
      expenseItemId: expenseItemId ?? this.expenseItemId,
      expenseId: expenseId ?? this.expenseId,
      itemName: itemName ?? this.itemName,
      itemDescription: itemDescription ?? this.itemDescription,
      merchantName: merchantName ?? this.merchantName,
      expenseDateTime: expenseDateTime ?? this.expenseDateTime,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}
