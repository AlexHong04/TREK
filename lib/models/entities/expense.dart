class Expense {
  final String? expenseId;
  final String activitiesId;
  final double totalAmount;
  final double taxAmount;
  final double discountAmount;
  final double roundingAmount;
  final String currency;
  final String? paymentMethod;
  final String? receiptImageUrl;
  final DateTime? createdAt;

  const Expense({
    this.expenseId,
    required this.activitiesId,
    required this.totalAmount,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    this.roundingAmount = 0.0,
    this.currency = '',
    this.paymentMethod,
    this.receiptImageUrl,
    this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      expenseId: json['expense_id'] as String?,
      activitiesId: json['activities_id'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      roundingAmount: (json['rounding_amount'] as num?)?.toDouble() ?? 0.0,
      currency: _optionalCurrency(json['currency']),
      paymentMethod: json['payment_method'] as String?,
      receiptImageUrl: json['receipt_image_url'] as String?,
      createdAt: json['created_at'] != null
          ? _parseCreatedAt(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (expenseId != null) 'expense_id': expenseId,
      'activities_id': activitiesId,
      'total_amount': totalAmount,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'rounding_amount': roundingAmount,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (receiptImageUrl != null) 'receipt_image_url': receiptImageUrl,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Expense copyWith({
    String? expenseId,
    String? activitiesId,
    double? totalAmount,
    double? taxAmount,
    double? discountAmount,
    double? roundingAmount,
    String? currency,
    String? paymentMethod,
    String? receiptImageUrl,
    DateTime? createdAt,
  }) {
    return Expense(
      expenseId: expenseId ?? this.expenseId,
      activitiesId: activitiesId ?? this.activitiesId,
      totalAmount: totalAmount ?? this.totalAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      roundingAmount: roundingAmount ?? this.roundingAmount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String _optionalCurrency(Object? value) =>
      value?.toString().trim().toUpperCase() ?? '';

  static DateTime _parseCreatedAt(String value) {
    final normalized = value.trim().replaceFirst(' ', 'T');
    final parsed = DateTime.parse(normalized);
    final hasTimeZone = RegExp(
      r'(?:Z|[+-]\d{2}(?::?\d{2})?)$',
    ).hasMatch(normalized);
    if (hasTimeZone) return parsed.toLocal();

    // Supabase timestamps without an explicit offset are stored as UTC in this
    // project. Mark the parsed components as UTC before displaying locally.
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }
}
