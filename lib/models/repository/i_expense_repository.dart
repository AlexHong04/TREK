import '../entities/expense.dart';
import '../entities/expense_item.dart';

abstract interface class IExpenseRepository {
  Future<List<Expense>> getExpensesByActivityId(String activityId);

  Future<List<ExpenseItem>> getExpenseItemsByExpenseId(String expenseId);

  Future<Expense> insertExpense(Expense expense);

  Future<void> insertExpenseItems(List<ExpenseItem> expenseItems);

  Future<void> updateReceiptImageUrl({
    required String expenseId,
    required String receiptImageUrl,
  });

  Future<String> uploadReceiptImage({
    required String localImagePath,
    required String expenseId,
  });
}
