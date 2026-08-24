import '../configurations/supabase_config.dart';
import '../entities/expense.dart';
import '../entities/expense_item.dart';

class ExpenseRepository {
  static const String _expensesTable = 'expenses';
  static const String _expenseItemsTable = 'expense_items';

  /// Records the parent expense and returns it with the Supabase-generated ID.
  Future<Expense> insertExpense(Expense expense) async {
    try {
      final response = await SupabaseConfig.client
          .from(_expensesTable)
          .insert(expense.toJson())
          .select()
          .single();

      return Expense.fromJson(Map<String, dynamic>.from(response));
    } catch (error) {
      throw Exception('Unable to record expense: $error');
    }
  }

  /// Records all child items after each item has been given its parent expense ID.
  Future<void> insertExpenseItems(List<ExpenseItem> expenseItems) async {
    if (expenseItems.isEmpty) {
      throw ArgumentError('An expense must contain at least one item.');
    }

    final hasMissingExpenseId = expenseItems.any(
      (item) => item.expenseId == null || item.expenseId!.isEmpty,
    );

    if (hasMissingExpenseId) {
      throw ArgumentError(
        'Every expense item must have a parent expense ID before it is saved.',
      );
    }

    try {
      final itemsJson = expenseItems.map((item) => item.toJson()).toList();

      await SupabaseConfig.client.from(_expenseItemsTable).insert(itemsJson);
    } catch (error) {
      throw Exception('Unable to record expense items: $error');
    }
  }

  /// Stores the optional receipt reference after its image has been uploaded.
  Future<void> updateReceiptImageUrl({
    required String expenseId,
    required String receiptImageUrl,
  }) async {
    try {
      await SupabaseConfig.client
          .from(_expensesTable)
          .update({'receipt_image_url': receiptImageUrl})
          .eq('expense_id', expenseId);
    } catch (error) {
      throw Exception('Unable to save receipt reference: $error');
    }
  }
}
