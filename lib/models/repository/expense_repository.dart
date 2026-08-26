import 'dart:io';

import 'package:path/path.dart' as path;

import '../configurations/supabase_config.dart';
import '../entities/expense.dart';
import '../entities/expense_item.dart';

class ExpenseRepository {
  static const String _expensesTable = 'expenses';
  static const String _expenseItemsTable = 'expense_item';
  static const String _receiptImagesBucket = 'receipt_images';
  static const int _maximumReceiptSizeInBytes = 15 * 1024 * 1024;

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

  /// Uploads one validated local receipt image and returns its public URL.
  Future<String> uploadReceiptImage({
    required String localImagePath,
    required String expenseId,
  }) async {
    if (localImagePath.trim().isEmpty || expenseId.trim().isEmpty) {
      throw ArgumentError('Receipt path and expense ID are required.');
    }

    final receiptFile = File(localImagePath);
    if (!await receiptFile.exists()) {
      throw ArgumentError('The selected receipt image could not be found.');
    }

    final extension = path.extension(localImagePath).toLowerCase();
    const supportedExtensions = {'.jpg', '.jpeg', '.png'};
    if (!supportedExtensions.contains(extension)) {
      throw ArgumentError(
        'Invalid receipt image. Please upload a JPG, JPEG, or PNG image not exceeding 15 MB.',
      );
    }

    final fileSizeInBytes = await receiptFile.length();
    if (fileSizeInBytes > _maximumReceiptSizeInBytes) {
      throw ArgumentError(
        'Invalid receipt image. Please upload a JPG, JPEG, or PNG image not exceeding 15 MB.',
      );
    }

    final storagePath =
        'expenses/$expenseId/${DateTime.now().millisecondsSinceEpoch}$extension';

    try {
      await SupabaseConfig.client.storage
          .from(_receiptImagesBucket)
          .upload(storagePath, receiptFile);

      return SupabaseConfig.client.storage
          .from(_receiptImagesBucket)
          .getPublicUrl(storagePath);
    } catch (error) {
      throw Exception('Unable to upload receipt image: $error');
    }
  }
}
