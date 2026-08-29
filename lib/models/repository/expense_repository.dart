import 'dart:io';

import 'package:path/path.dart' as path;

import '../../utils/id_generator.dart';
import '../configurations/supabase_config.dart';
import '../entities/expense.dart';
import '../entities/expense_item.dart';

import 'i_expense_repository.dart';

class ExpenseRepository implements IExpenseRepository {
  static const String _expensesTable = 'expenses';
  static const String _expenseItemsTable = 'expense_item';
  static const String _receiptImagesBucket = 'receipt_images';
  static const int _maximumReceiptSizeInBytes = 15 * 1024 * 1024;
  static const String _expenseIdPrefix = 'EX';
  static const String _expenseItemIdPrefix = 'EI';

  /// Retrieves every confirmed Expense recorded for one Activity.
  Future<List<Expense>> getExpensesByActivityId(String activityId) async {
    if (activityId.trim().isEmpty) {
      throw ArgumentError('An activity ID is required to retrieve expenses.');
    }

    try {
      final response = await SupabaseConfig.client
          .from(_expensesTable)
          .select()
          .eq('activities_id', activityId)
          .order('created_at', ascending: true);

      return (response as List<dynamic>)
          .map((row) => Expense.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error) {
      throw Exception('Unable to retrieve recorded expenses: $error');
    }
  }

  /// Retrieves the child ExpenseItems belonging to one confirmed Expense.
  Future<List<ExpenseItem>> getExpenseItemsByExpenseId(String expenseId) async {
    if (expenseId.trim().isEmpty) {
      throw ArgumentError(
        'An expense ID is required to retrieve expense items.',
      );
    }

    try {
      final response = await SupabaseConfig.client
          .from(_expenseItemsTable)
          .select()
          .eq('expense_id', expenseId)
          .order('expense_datetime', ascending: true);

      return (response as List<dynamic>)
          .map((row) => ExpenseItem.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error) {
      throw Exception('Unable to retrieve recorded expense items: $error');
    }
  }

  /// Records the parent expense with the next formatted EX ID.
  Future<Expense> insertExpense(Expense expense) async {
    try {
      final expenseId = await _nextFormattedId(
        table: _expensesTable,
        idColumn: 'expense_id',
        prefix: _expenseIdPrefix,
      );
      final expenseWithId = expense.copyWith(expenseId: expenseId);

      final response = await SupabaseConfig.client
          .from(_expensesTable)
          .insert(expenseWithId.toJson())
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
      String? lastExpenseItemId = await _latestFormattedId(
        table: _expenseItemsTable,
        idColumn: 'expense_item_id',
        prefix: _expenseItemIdPrefix,
      );
      final itemsWithIds = expenseItems.map((item) {
        lastExpenseItemId = IdGenerator.generateNextFormattedId(
          _expenseItemIdPrefix,
          lastExpenseItemId,
        );
        return item.copyWith(expenseItemId: lastExpenseItemId);
      }).toList();
      final itemsJson = itemsWithIds.map((item) => item.toJson()).toList();

      await SupabaseConfig.client.from(_expenseItemsTable).insert(itemsJson);
    } catch (error) {
      throw Exception('Unable to record expense items: $error');
    }
  }

  /// Follows the team's formatted-ID approach used by the itinerary repository.
  Future<String> _nextFormattedId({
    required String table,
    required String idColumn,
    required String prefix,
  }) async {
    final lastId = await _latestFormattedId(
      table: table,
      idColumn: idColumn,
      prefix: prefix,
    );
    return IdGenerator.generateNextFormattedId(prefix, lastId);
  }

  /// Ignores old UUID records so only IDs with the requested prefix determine
  /// the next formatted ID, for example EX0001 then EX0002.
  Future<String?> _latestFormattedId({
    required String table,
    required String idColumn,
    required String prefix,
  }) async {
    final response = await SupabaseConfig.client
        .from(table)
        .select(idColumn)
        .like(idColumn, '$prefix%')
        .order(idColumn, ascending: false)
        .limit(1)
        .maybeSingle();

    return response?[idColumn] as String?;
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
