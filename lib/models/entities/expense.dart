class Expense {
  final String? expenseId;
  final String activitiesId;
  final double totalAmount;
  final String? paymentMethod;
  final String? receiptImageUrl;
  final DateTime? createdAt;

  const Expense({
    this.expenseId,
    required this.activitiesId,
    required this.totalAmount,
    this.paymentMethod,
    this.receiptImageUrl,
    this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      expenseId: json['expense_id'] as String?,
      activitiesId: json['activities_id'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String?,
      receiptImageUrl: json['receipt_image_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (expenseId != null) 'expense_id': expenseId,
      'activities_id': activitiesId,
      'total_amount': totalAmount,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (receiptImageUrl != null) 'receipt_image_url': receiptImageUrl,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Expense copyWith({
    String? expenseId,
    String? activitiesId,
    double? totalAmount,
    String? paymentMethod,
    String? receiptImageUrl,
    DateTime? createdAt,
  }) {
    return Expense(
      expenseId: expenseId ?? this.expenseId,
      activitiesId: activitiesId ?? this.activitiesId,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
