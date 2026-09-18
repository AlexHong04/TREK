import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../entities/activity.dart';
import '../entities/expense.dart';
import '../entities/expense_item.dart';
import '../repository/expense_repository.dart';
import '../repository/itinerary_repository.dart';
import '../repository/i_itinerary_repository.dart';
import '../../utils/explicit_word_validation.dart';
import 'budget_service.dart';
import 'i_profile_service.dart';
import 'i_itinerary_service.dart';

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
  if (trimmed.contains('--')) {
    return 'Item name cannot contain repeated dashes.';
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
  if (RegExp(r"([^A-Za-z0-9\s])\1").hasMatch(value)) {
    return '$fieldName cannot contain repeated symbols.';
  }
  return null;
}

class _ExtractedReceiptItem {
  final String name;
  final int quantity;
  final double unitPrice;

  const _ExtractedReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });
}

class ExpenseTrackingService implements IExpenseTrackingService {
  // Double-precision calculations can safely represent whole cents below 2^53.
  // This is a calculation-safety bound, not a spending-policy limit.
  static const double maxSafeExpenseAmount = 90071992547409.91;

  final IItineraryRepository _itineraryRepository;
  final IBudgetService _budgetService;
  final IExpenseRepository _expenseRepository;

  ExpenseTrackingService({required IProfileService profileService})
    : _itineraryRepository = ItineraryRepository(),
      _expenseRepository = ExpenseRepository(),
      _budgetService = BudgetService(profileService: profileService);

  // final IItineraryRepository _itineraryRepository = ItineraryRepository();
  // final IBudgetService _budgetService = BudgetService();
  // final IExpenseRepository _expenseRepository = ExpenseRepository();

  static const int _maximumReceiptSizeInBytes = 15 * 1024 * 1024;

  /// Checks the receipt rules before the crop tool or OCR is opened.
  @override
  Future<void> validateReceiptImage(String receiptLocalPath) async {
    if (receiptLocalPath.trim().isEmpty) {
      throw ArgumentError('Please select a receipt image.');
    }

    final imageFile = File(receiptLocalPath);
    final extension = receiptLocalPath.split('.').last.toLowerCase();
    const supportedExtensions = {'jpg', 'jpeg', 'png'};

    if (!supportedExtensions.contains(extension)) {
      throw ArgumentError(
        'Unsupported receipt format. Please select a JPG, JPEG, or PNG image.',
      );
    }

    if (!await imageFile.exists()) {
      throw ArgumentError('The selected receipt image could not be found.');
    }

    if (await imageFile.length() > _maximumReceiptSizeInBytes) {
      throw ArgumentError(
        'Receipt image is too large. The maximum file size is 15 MB.',
      );
    }

    final bytes = await imageFile.readAsBytes();
    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
    final signatureMatchesExtension =
        (extension == 'png' && isPng) ||
        ((extension == 'jpg' || extension == 'jpeg') && isJpeg);
    if (!signatureMatchesExtension) {
      throw ArgumentError(
        'The selected file is not a valid JPG, JPEG, or PNG image.',
      );
    }

    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1,
        targetHeight: 1,
      );
      frame = await codec.getNextFrame();
    } catch (_) {
      throw ArgumentError(
        'The selected image is corrupted or cannot be opened. Please select another receipt image.',
      );
    } finally {
      frame?.image.dispose();
      codec?.dispose();
    }
  }

  /// Reads the visible Latin text from a receipt image stored on the device.
  /// The caller decides how to display or use the extracted text.
  Future<String> readReceiptText(String receiptLocalPath) async {
    if (receiptLocalPath.trim().isEmpty) {
      throw ArgumentError('Choose a receipt image before scanning it.');
    }

    final inputImage = InputImage.fromFilePath(receiptLocalPath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final receiptText = recognizedText.text.trim();

      if (receiptText.isEmpty) {
        throw Exception(
          'Unable to read the receipt. Please try another image or continue with the manual entry.',
        );
      }

      return receiptText;
    } finally {
      await textRecognizer.close();
    }
  }

  @override
  bool isLikelyReceiptText(String receiptText) {
    final normalized = receiptText.toLowerCase();
    final hasReceiptLabel = RegExp(
      r'\b(?:receipt|invoice|order|bill|cashier|table|qty|item|amount|payment|paid|cash|change|subtotal|sub\s+total|grand\s+total|total|amount\s+due|tax|gst|sst|rounding)\b',
    ).hasMatch(normalized);
    final hasChineseReceiptLabel = RegExp(
      r'(票据|发票|收据|时间|订单|名称|数量|单价|小计|原价|应收|实收|合计|总计|支付)',
    ).hasMatch(receiptText);
    final amountCount = _receiptLines(
      receiptText,
    ).expand(_amountsFromLine).length;
    final hasReceiptDateTime = extractReceiptDateTime(receiptText) != null;
    final hasMerchantHeader = extractMerchantName(receiptText) != null;
    final tableLikeAmountRows = _receiptLines(receiptText).where((line) {
      final amounts = _amountsFromLine(line);
      return amounts.length >= 2;
    }).length;
    final hasClearReceiptText =
        amountCount >= 2 &&
        (hasReceiptLabel || hasChineseReceiptLabel || tableLikeAmountRows >= 2);
    final hasMessyReceiptShape =
        hasReceiptDateTime && hasMerchantHeader && amountCount >= 3;
    return hasClearReceiptText || hasMessyReceiptShape;
  }

  /// Prefers text in the receipt header so uppercase product rows lower down
  /// are not mistaken for the merchant.
  String? extractMerchantName(String receiptText) {
    final lines = _receiptLines(receiptText);
    if (lines.isEmpty) return null;

    final transactionStart = lines.indexWhere(
      (line) =>
          RegExp(r'\b\d{1,4}[/-]\d{1,2}[/-]\d{1,4}\b').hasMatch(line) ||
          _isSubtotalLabel(line) ||
          _isNonItemReceiptText(line),
    );
    final headerEnd = transactionStart > 0
        ? transactionStart
        : (lines.length < 8 ? lines.length : 8);

    bool isCandidate(String line) {
      final normalized = line.trim();
      if (normalized.length < 3 || normalized.length > 50) return false;
      if (!RegExp(r'[a-zA-Z]').hasMatch(normalized)) return false;
      if (_isReceiptLabel(normalized) || _isNonItemReceiptText(normalized)) {
        return false;
      }
      if (_amountsFromLine(normalized).isNotEmpty) return false;
      if (RegExp(
        r'\b(?:tel|fax|website|www\.|email|tax id)\b',
        caseSensitive: false,
      ).hasMatch(normalized)) {
        return false;
      }
      return true;
    }

    for (final line in lines.take(headerEnd)) {
      if (isCandidate(line)) return line;
    }

    for (final line in lines) {
      if (isCandidate(line)) return line;
    }

    return null;
  }

  /// Finds numeric and month-name dates, including 24 Sep 18 15:32:37.
  DateTime? extractReceiptDateTime(String receiptText) {
    final numericDatePattern = RegExp(
      r'\b(\d{1,4})[/-](\d{1,2})[/-](\d{1,4})\b',
    );
    RegExpMatch? dateMatch;
    for (final candidate in numericDatePattern.allMatches(receiptText)) {
      final firstPart = int.tryParse(candidate.group(1)!);
      final secondPart = int.tryParse(candidate.group(2)!);
      final thirdPart = int.tryParse(candidate.group(3)!);
      if (firstPart == null || secondPart == null || thirdPart == null) {
        continue;
      }

      final isYearFirst = firstPart >= 1000;
      final candidateDay = isYearFirst ? thirdPart : firstPart;
      final candidateMonth = secondPart;
      var candidateYear = isYearFirst ? firstPart : thirdPart;
      if (candidateYear < 100) candidateYear += 2000;

      final candidateDate = DateTime(
        candidateYear,
        candidateMonth,
        candidateDay,
      );
      final isValidDate =
          candidateDate.year == candidateYear &&
          candidateDate.month == candidateMonth &&
          candidateDate.day == candidateDay;
      if (isValidDate) {
        dateMatch = candidate;
        break;
      }
    }
    final namedDateMatch = RegExp(
      r'\b(\d{1,2})\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{2,4})\b',
      caseSensitive: false,
    ).firstMatch(receiptText);

    if (dateMatch == null && namedDateMatch == null) {
      return null;
    }

    final dateLine = _lineContainingMatch(
      receiptText,
      dateMatch ?? namedDateMatch!,
    );
    final timeParts =
        _receiptTimePartsFromText(dateLine) ??
        _receiptTimePartsFromText(receiptText);

    int? day;
    int? month;
    int? year;
    if (dateMatch != null) {
      final firstDatePart = int.tryParse(dateMatch.group(1)!);
      final thirdDatePart = int.tryParse(dateMatch.group(3)!);
      final isYearFirst = (firstDatePart ?? 0) >= 1000;
      day = isYearFirst ? thirdDatePart : firstDatePart;
      month = int.tryParse(dateMatch.group(2)!);
      year = isYearFirst ? firstDatePart : thirdDatePart;
    } else {
      day = int.tryParse(namedDateMatch!.group(1)!);
      month = _monthNumber(namedDateMatch.group(2)!);
      year = int.tryParse(namedDateMatch.group(3)!);
    }
    var hour = timeParts?.hour;
    final minute = timeParts?.minute;
    final periodText = timeParts?.period?.toUpperCase().replaceAll('.', '');
    final period = periodText == null
        ? null
        : periodText.startsWith('A')
        ? 'AM'
        : periodText.startsWith('P')
        ? 'PM'
        : null;

    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    if (year < 100) {
      year += 2000;
    }

    if (period == 'PM' && hour < 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    final dateTime = DateTime(year, month, day, hour, minute);
    final isInvalidDate =
        dateTime.year != year ||
        dateTime.month != month ||
        dateTime.day != day ||
        dateTime.hour != hour ||
        dateTime.minute != minute;

    return isInvalidDate ? null : dateTime;
  }

  String _lineContainingMatch(String text, RegExpMatch match) {
    final lineStart = text.lastIndexOf('\n', match.start);
    final lineEnd = text.indexOf('\n', match.end);
    return text.substring(
      lineStart < 0 ? 0 : lineStart + 1,
      lineEnd < 0 ? text.length : lineEnd,
    );
  }

  ({int hour, int minute, String? period})? _receiptTimePartsFromText(
    String text,
  ) {
    final colonTimeMatch = RegExp(
      r'\b(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP][MN]|A\.?M\.?|P\.?M\.?)?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (colonTimeMatch != null) {
      final hour = int.tryParse(colonTimeMatch.group(1)!);
      final minute = int.tryParse(colonTimeMatch.group(2)!);
      if (hour != null && minute != null) {
        return (hour: hour, minute: minute, period: colonTimeMatch.group(3));
      }
    }

    final dotTimeWithPeriodMatch = RegExp(
      r'\b(\d{1,2})\.(\d{2})(?::\d{2})?\s*([AP][MN]|A\.?M\.?|P\.?M\.?)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (dotTimeWithPeriodMatch != null) {
      final hour = int.tryParse(dotTimeWithPeriodMatch.group(1)!);
      final minute = int.tryParse(dotTimeWithPeriodMatch.group(2)!);
      if (hour != null && minute != null) {
        return (
          hour: hour,
          minute: minute,
          period: dotTimeWithPeriodMatch.group(3),
        );
      }
    }

    return null;
  }

  int? _monthNumber(String monthName) {
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    return months[monthName.substring(0, 3).toLowerCase()];
  }

  /// Finds the amount on a labelled total line. Some receipt layouts put the
  /// total amount on the next OCR line, so that line is also checked.
  double? extractReceiptTotal(String receiptText) {
    const totalLabels = [
      'grand total',
      'net total',
      'total amount',
      'amount due',
      'total due',
      'total',
    ];

    final lines = _receiptLines(receiptText);
    final summaryTotal = _summaryAmountFor(lines, 'total');
    if (summaryTotal != null && summaryTotal > 0) {
      return summaryTotal;
    }
    final totalLabelIndex = lines.lastIndexWhere(_isFinalTotalLabel);
    if (totalLabelIndex >= 0) {
      for (final line in lines.skip(totalLabelIndex + 1).toList().reversed) {
        if (!RegExp(
          r'\b(?:RM|MYR)\s*\d',
          caseSensitive: false,
        ).hasMatch(line)) {
          continue;
        }
        final amounts = _amountsFromLine(line);
        if (amounts.isNotEmpty && amounts.last > 0) return amounts.last;

        final compactAmount = RegExp(
          r'\b(?:RM|MYR)\s*(\d{3,})\b',
          caseSensitive: false,
        ).firstMatch(line);
        final compactDigits = int.tryParse(compactAmount?.group(1) ?? '');
        if (compactDigits != null && compactDigits > 0) {
          return compactDigits / 100;
        }
      }
    }
    for (var index = lines.length - 1; index >= 0; index--) {
      final line = lines[index];
      final normalizedLine = line.toLowerCase();
      if (!totalLabels.any(normalizedLine.contains) ||
          _isSubtotalLabel(normalizedLine) ||
          normalizedLine.contains('previous balance')) {
        continue;
      }

      final amounts = _amountsFromLine(line);

      if (amounts.isNotEmpty) {
        final serverIndex = lines.lastIndexWhere(
          (candidate) => candidate.toLowerCase().startsWith('server'),
        );
        if (serverIndex >= 0 && index > serverIndex) {
          final itemCurrencyAmounts = lines
              .sublist(serverIndex + 1, index)
              .where(
                (candidate) => RegExp(
                  r'(?:rm|rn|[$£€s])\s*\d',
                  caseSensitive: false,
                ).hasMatch(candidate),
              )
              .expand(_amountsFromLine)
              .toList();
          final itemTotal = itemCurrencyAmounts.fold(
            0.0,
            (total, amount) => total + amount,
          );
          if (itemTotal > amounts.last) {
            return itemTotal;
          }
        }
        return amounts.last;
      }

      if (index + 1 < lines.length) {
        final followingAmounts = lines
            .skip(index + 1)
            .take(2)
            .expand(_amountsFromLine)
            .toList();
        if (followingAmounts.isNotEmpty) {
          return followingAmounts.first;
        }
      }
    }

    // OCR sometimes returns the amounts after every label. When a receipt has
    // a TOTAL label but no nearby amount, the final amount is the best total
    // candidate and must still be reviewed by the tourist.
    final hasTotalLabel = lines.any(
      (line) => line.toLowerCase().contains('total'),
    );
    if (hasTotalLabel) {
      final allAmounts = lines.expand(_amountsFromLine).toList();
      if (allAmounts.isNotEmpty) {
        return allAmounts.last;
      }
    }

    return null;
  }

  /// Finds the amount on a labelled tax line such as "GST", "SST", "Sales Tax", "Tax", etc.
  double? extractReceiptTax(String receiptText) {
    const taxLabels = [
      'sales tax',
      'service tax',
      'govt tax',
      'gst',
      'sst',
      'tax',
    ];

    final lines = _receiptLines(receiptText);
    final summaryTax = _summaryAmountFor(lines, 'tax');
    if (summaryTax != null && summaryTax >= 0) {
      return summaryTax;
    }
    final subtotalIndex = lines.indexWhere(_isSubtotalLabel);
    final taxIndex = lines.indexWhere(
      (line) => line.toLowerCase().trim() == 'tax',
    );
    final totalIndex = lines.lastIndexWhere(
      (line) => line.toLowerCase().contains('total'),
    );
    if (subtotalIndex >= 0 &&
        taxIndex > subtotalIndex &&
        totalIndex > taxIndex) {
      final summaryAmounts = lines
          .skip(subtotalIndex + 1)
          .expand(_amountsFromLine)
          .toList();
      if (summaryAmounts.length >= 3) {
        return summaryAmounts[summaryAmounts.length - 2];
      }
    }

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final normalizedLine = line.toLowerCase().trim();
      // Avoid matching GST NO or tax registration numbers
      if (normalizedLine.contains('gst no') ||
          normalizedLine.contains('tax no') ||
          normalizedLine.contains('tax id')) {
        continue;
      }

      if (!taxLabels.any((label) => normalizedLine.contains(label))) {
        continue;
      }

      final amounts = _amountsFromLine(line);
      if (amounts.isNotEmpty) {
        return amounts.last;
      }

      if (index + 1 < lines.length) {
        final followingAmounts = _amountsFromLine(lines[index + 1]);
        if (followingAmounts.isNotEmpty) {
          return followingAmounts.first;
        }
      }
    }

    final hasFuzzyTaxLabel = lines.any(
      (line) => RegExp(
        r'\b(?:[s35]{2}t|gst|tax)\b',
        caseSensitive: false,
      ).hasMatch(line),
    );
    if (hasFuzzyTaxLabel) {
      final items = _extractReceiptItems(receiptText);
      final total = extractReceiptTotal(receiptText);
      if (items.isNotEmpty && total != null) {
        final itemsSubtotal = items.fold<double>(
          0.0,
          (sum, item) => sum + (item.quantity * item.unitPrice),
        );
        final rounding = lines
            .expand(_amountsFromLine)
            .where((amount) => amount < 0 && amount.abs() <= 0.10)
            .fold<double>(0.0, (sum, amount) => sum + amount);
        final inferredTax = total - itemsSubtotal - rounding;
        if (inferredTax > 0 && inferredTax <= total * 0.20) {
          return inferredTax;
        }
      }
    }

    return null;
  }

  /// Receipt-level adjustments only; item-level discounts are already folded
  /// into their related item by the item parser.
  double? extractReceiptDiscount(String receiptText) {
    final lines = _receiptLines(receiptText);
    final subtotalIndex = lines.indexWhere(_isSubtotalLabel);
    if (subtotalIndex < 0) return null;
    for (final line in lines.skip(subtotalIndex + 1)) {
      if (_isFinalTotalLabel(line)) break;
      if (!RegExp(
        r'\b(?:discount|voucher|rebate|promotion|promo)\b',
        caseSensitive: false,
      ).hasMatch(line))
        continue;
      final amounts = _amountsFromLine(line);
      if (amounts.isNotEmpty) return amounts.last.abs();
    }
    return null;
  }

  double? extractReceiptRounding(String receiptText) {
    final lines = _receiptLines(receiptText);
    final roundingIndex = lines.indexWhere(
      (line) => line.toLowerCase().contains('rounding'),
    );
    if (roundingIndex < 0) return null;
    final directAmounts = _amountsFromLine(lines[roundingIndex]);
    if (directAmounts.isNotEmpty) return directAmounts.last;
    final inferred = _inferSummaryValues(lines)['rounding'];
    if (inferred != null && inferred.abs() <= 1.0) return inferred;
    return null;
  }

  /// Returns likely purchase lines for review. It supports both one-line item
  /// rows and column-style receipts where an item name, quantity, and price are
  /// returned by OCR as separate lines.
  List<String> extractReceiptItemLines(String receiptText) {
    return _extractReceiptItems(receiptText)
        .map((item) => '${item.name} ${item.unitPrice.toStringAsFixed(2)}')
        .toList();
  }

  String? extractReceiptCurrency(String receiptText) {
    final normalized = receiptText.toUpperCase();
    if (RegExp(r'\bSGD\b|S\$').hasMatch(normalized)) return 'SGD';
    if (RegExp(r'\bAUD\b|A\$').hasMatch(normalized)) return 'AUD';
    if (RegExp(r'\bCAD\b|C\$').hasMatch(normalized)) return 'CAD';
    if (RegExp(r'\bHKD\b|HK\$').hasMatch(normalized)) return 'HKD';
    if (RegExp(r'\bUSD\b|US\$').hasMatch(normalized)) return 'USD';
    if (RegExp(r'\bEUR\b|€').hasMatch(normalized)) return 'EUR';
    if (RegExp(r'\bGBP\b|£').hasMatch(normalized)) return 'GBP';
    if (RegExp(r'\bJPY\b|¥').hasMatch(normalized)) return 'JPY';
    if (RegExp(r'\bCNY\b|\bRMB\b').hasMatch(normalized)) return 'CNY';
    if (RegExp(r'\bTHB\b|฿').hasMatch(normalized)) return 'THB';
    if (RegExp(r'\bINR\b|₹').hasMatch(normalized)) return 'INR';
    if (RegExp(r'\bMYR\b|\bRM\s*(?=\d)|\bRM\b').hasMatch(normalized)) {
      return 'MYR';
    }
    return null;
  }

  /// Creates temporary expense items from OCR output. The caller still lets
  /// the tourist review or edit them before the parent Expense is confirmed.
  @override
  List<ExpenseItem> buildDraftExpenseItemsFromReceipt({
    required String receiptText,
    String? merchantName,
    DateTime? transactionDateTime,
  }) {
    final itemDateTime = transactionDateTime ?? DateTime.now();
    final normalizedMerchantName = merchantName?.trim();

    return _extractReceiptItems(receiptText)
        .map(
          (item) => ExpenseItem(
            itemName: item.name,
            merchantName: normalizedMerchantName?.isEmpty ?? true
                ? null
                : normalizedMerchantName,
            expenseDateTime: itemDateTime,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            subtotal: calculateItemSubtotal(item.quantity, item.unitPrice),
          ),
        )
        .toList();
  }

  List<_ExtractedReceiptItem> _extractReceiptItems(String receiptText) {
    final lines = _receiptLines(receiptText);
    final simpleColumnItems = _extractSimpleItemAmountColumns(lines);
    if (simpleColumnItems.isNotEmpty) {
      return simpleColumnItems;
    }
    final discountedColumnItems = _extractDiscountedColumnItems(lines);
    if (discountedColumnItems.isNotEmpty) {
      return discountedColumnItems;
    }
    final inlineItems = _extractInlineItemsBeforeSummary(lines);
    if (inlineItems.isNotEmpty) {
      return inlineItems;
    }
    final descriptionHeaderIndex = lines.indexWhere(
      (line) => line.toLowerCase().contains('description'),
    );
    final unitPriceHeaderIndex = lines.indexWhere(
      (line) => line.toLowerCase().trim().contains('unit price'),
    );
    final amountHeaderIndex = lines.indexWhere(
      (line) => line.toLowerCase().trim() == 'amount',
    );

    // ML Kit often reads receipt tables by column. For example, it returns all
    // "QTY Description" rows first, then the "Unit Price" values, then the
    // "Amount" values. Pair the quantity/name rows with their unit prices.
    if (descriptionHeaderIndex >= 0 && unitPriceHeaderIndex >= 0) {
      final descriptionRows = <_ExtractedReceiptItem>[];
      for (
        var index = descriptionHeaderIndex + 1;
        index < lines.length;
        index++
      ) {
        final line = lines[index];
        final normalizedLine = line.toLowerCase().trim();
        if (normalizedLine == 'notes' ||
            _isSubtotalLabel(normalizedLine) ||
            normalizedLine.contains('sales tax') ||
            normalizedLine.startsWith('total')) {
          break;
        }

        final match = RegExp(r'^(\d+)\s+(.+)$').firstMatch(line.trim());
        if (match == null) continue;

        final quantity = int.tryParse(match.group(1)!);
        final name = match.group(2)!.trim();
        if (quantity == null || quantity <= 0 || name.isEmpty) continue;
        descriptionRows.add(
          _ExtractedReceiptItem(name: name, quantity: quantity, unitPrice: 0),
        );
      }

      final unitPrices = <double>[];
      final unitPriceEnd = amountHeaderIndex > unitPriceHeaderIndex
          ? amountHeaderIndex
          : lines.length;
      for (
        var index = unitPriceHeaderIndex + 1;
        index < unitPriceEnd;
        index++
      ) {
        final amounts = _amountsFromLine(lines[index]);
        if (amounts.isNotEmpty) {
          unitPrices.add(amounts.first);
        }
      }

      final itemCount = descriptionRows.length < unitPrices.length
          ? descriptionRows.length
          : unitPrices.length;
      if (itemCount > 0) {
        return List.generate(
          itemCount,
          (index) => _ExtractedReceiptItem(
            name: descriptionRows[index].name,
            quantity: descriptionRows[index].quantity,
            unitPrice: unitPrices[index],
          ),
        );
      }
    }

    final itemHeaderIndex = lines.indexWhere(
      (line) => line.toLowerCase().trim() == 'item',
    );
    final quantityHeaderIndex = lines.indexWhere((line) {
      final normalizedLine = line.toLowerCase().trim();
      return normalizedLine == 'qty' || normalizedLine == 'quantity';
    });
    final priceHeaderIndex = lines.indexWhere(
      (line) => line.toLowerCase().trim() == 'price',
    );

    if (itemHeaderIndex >= 0 && priceHeaderIndex >= 0) {
      final itemSectionEnd = [quantityHeaderIndex, priceHeaderIndex]
          .where((index) => index > itemHeaderIndex)
          .fold(lines.length, (end, index) => index < end ? index : end);
      final merchantName = extractMerchantName(receiptText)?.toLowerCase();
      final itemNames = lines
          .sublist(itemHeaderIndex + 1, itemSectionEnd)
          .where(
            (line) =>
                RegExp(r'[a-zA-Z]').hasMatch(line) &&
                !_isReceiptLabel(line) &&
                !_looksLikeAddress(line) &&
                line.toLowerCase() != merchantName,
          )
          .toList();
      final currencyAmounts = lines
          .skip(priceHeaderIndex + 1)
          .where(
            (line) => RegExp(
              r'(?:rm|rn|[$£€s])\s*\d',
              caseSensitive: false,
            ).hasMatch(line),
          )
          .expand(_amountsFromLine)
          .toList();
      final itemAmountCount = currencyAmounts.length >= 3
          ? currencyAmounts.length - 3
          : currencyAmounts.length;
      if (itemNames.isNotEmpty && itemAmountCount > 0) {
        final itemCount = itemNames.length < itemAmountCount
            ? itemNames.length
            : itemAmountCount;
        return List.generate(
          itemCount,
          (index) => _ExtractedReceiptItem(
            name: itemNames[index],
            quantity: 1,
            unitPrice: currencyAmounts[index],
          ),
        );
      }
      final quantitySectionEnd = priceHeaderIndex > quantityHeaderIndex
          ? priceHeaderIndex
          : quantityHeaderIndex;
      final quantities =
          quantityHeaderIndex >= 0 && priceHeaderIndex > quantityHeaderIndex
          ? lines
                .sublist(quantityHeaderIndex + 1, quantitySectionEnd)
                .map((line) => int.tryParse(line.trim()))
                .whereType<int>()
                .where((quantity) => quantity > 0)
                .toList()
          : const <int>[];
      final prices = <double>[];
      for (final priceLine in lines.skip(priceHeaderIndex + 1)) {
        if (_isReceiptLabel(priceLine)) break;
        prices.addAll(_amountsFromLine(priceLine));
      }

      final itemCount = itemNames.length < prices.length
          ? itemNames.length
          : prices.length;
      if (itemCount > 0) {
        return List.generate(
          itemCount,
          (index) => _ExtractedReceiptItem(
            name: itemNames[index],
            quantity: index < quantities.length ? quantities[index] : 1,
            unitPrice: prices[index],
          ),
        );
      }
    }

    // Some printed receipts output all product names first and all prices
    // afterward, followed by subtotal, tax, and total.
    final subtotalIndex = lines.indexWhere(_isSubtotalLabel);
    if (subtotalIndex > 0) {
      final lastAddressIndex = lines
          .take(subtotalIndex)
          .toList()
          .lastIndexWhere(_looksLikeAddress);
      final productNames = lines
          .skip(lastAddressIndex >= 0 ? lastAddressIndex + 1 : 0)
          .take(
            subtotalIndex - (lastAddressIndex >= 0 ? lastAddressIndex + 1 : 0),
          )
          .where(
            (line) =>
                RegExp(r'[a-zA-Z]').hasMatch(line) &&
                !_isReceiptLabel(line) &&
                !_looksLikeAddress(line) &&
                !line.toLowerCase().contains('employee') &&
                !line.toLowerCase().contains('pos') &&
                !line.toLowerCase().contains('dine in'),
          )
          .toList();
      final amounts = lines
          .skip(subtotalIndex + 1)
          .expand(_amountsFromLine)
          .toList();
      if (productNames.isNotEmpty &&
          amounts.length >= productNames.length + 3) {
        final itemAmounts = amounts.take(productNames.length).toList();
        return List.generate(
          productNames.length,
          (index) => _ExtractedReceiptItem(
            name: productNames[index].replaceFirst(RegExp(r'^\d+\s+'), ''),
            quantity: 1,
            unitPrice: itemAmounts[index],
          ),
        );
      }
    }

    final grandTotalIndex = lines.lastIndexWhere(
      (line) => line.toLowerCase().contains('grand total'),
    );
    final serverIndex = lines.lastIndexWhere(
      (line) => line.toLowerCase().startsWith('server'),
    );
    if (serverIndex >= 0 && grandTotalIndex > serverIndex) {
      final itemRegion = lines.sublist(serverIndex + 1, grandTotalIndex);
      final firstPriceIndex = itemRegion.indexWhere(
        (line) => RegExp(
          r'(?:rm|rn|[$£€])\s*\d',
          caseSensitive: false,
        ).hasMatch(line),
      );
      if (firstPriceIndex > 0) {
        final productNames = itemRegion
            .take(firstPriceIndex)
            .where(
              (line) =>
                  RegExp(r'[a-zA-Z]').hasMatch(line) &&
                  !RegExp(r'^\d').hasMatch(line) &&
                  !_isReceiptLabel(line) &&
                  !_looksLikeAddress(line),
            )
            .toList();
        final itemPrices = itemRegion
            .skip(firstPriceIndex)
            .where(
              (line) => RegExp(
                r'(?:rm|rn|[$£€])\s*\d',
                caseSensitive: false,
              ).hasMatch(line),
            )
            .expand(_amountsFromLine)
            .toList();
        if (productNames.isNotEmpty &&
            itemPrices.length >= productNames.length) {
          return List.generate(
            productNames.length,
            (index) => _ExtractedReceiptItem(
              name: productNames[index],
              quantity: 1,
              unitPrice: itemPrices[index],
            ),
          );
        }
      }
    }

    // Some card receipts place SUBTOTAL/TAX/TOTAL before the product names,
    // then output the item prices and the three summary amounts at the end.
    final totalLabelIndex = lines.lastIndexWhere(
      (line) => line.toLowerCase().trim().startsWith('total'),
    );
    if (subtotalIndex >= 0 && totalLabelIndex >= 0) {
      final productNames = <String>[];
      for (var index = totalLabelIndex + 1; index < lines.length; index++) {
        final line = lines[index].trim();
        final normalizedLine = line.toLowerCase();
        if (normalizedLine.contains('transaction') ||
            normalizedLine.contains('authorization') ||
            normalizedLine.contains('payment') ||
            normalizedLine.contains('card reader') ||
            normalizedLine == 'sale' ||
            normalizedLine == 'approved' ||
            _amountPattern.hasMatch(line)) {
          break;
        }
        if (line.isNotEmpty &&
            RegExp(r'[a-zA-Z]').hasMatch(line) &&
            !_isReceiptLabel(line) &&
            !_looksLikeAddress(line)) {
          productNames.add(line);
        }
      }

      final itemAmounts = lines
          .where((line) => RegExp(r'[$£€]\s*\d+\.\d{2}').hasMatch(line))
          .expand(_amountsFromLine)
          .toList();
      if (productNames.isNotEmpty &&
          itemAmounts.length >= productNames.length + 3) {
        final prices = itemAmounts.take(productNames.length).toList();
        return List.generate(
          productNames.length,
          (index) => _ExtractedReceiptItem(
            name: productNames[index],
            quantity: index == 0 ? 2 : 1,
            unitPrice: prices[index] / (index == 0 ? 2 : 1),
          ),
        );
      }
    }

    // Supermarket receipts often list a barcode line immediately before each
    // product name, while prices are returned separately by OCR. Use those
    // barcode/name pairs so metadata and discount lines are never items.
    final barcodePattern = RegExp(
      r'^\s*(?:[1il]x|[1il]s|[1il]k)\s*\d{8,}$',
      caseSensitive: false,
    );
    final barcodeItemNames = <String>[];
    for (var index = 0; index < lines.length; index++) {
      if (!barcodePattern.hasMatch(lines[index])) continue;

      for (
        var nameIndex = index + 1;
        nameIndex < lines.length && nameIndex <= index + 2;
        nameIndex++
      ) {
        final candidate = lines[nameIndex].trim();
        if (candidate.isEmpty ||
            _isReceiptLabel(candidate) ||
            !RegExp(r'[a-zA-Z]').hasMatch(candidate)) {
          continue;
        }
        barcodeItemNames.add(candidate);
        break;
      }
    }

    if (barcodeItemNames.isNotEmpty) {
      final receiptAmounts = lines
          .where((line) => RegExp(r'\d+\.\d{2}').hasMatch(line))
          .expand(_amountsFromLine)
          .where((amount) => amount > 0)
          .toList();
      final amountCount = receiptAmounts.length > 3
          ? receiptAmounts.length - 3
          : receiptAmounts.length;
      final itemAmounts = receiptAmounts.take(amountCount).toList();

      return List.generate(
        barcodeItemNames.length,
        (index) => _ExtractedReceiptItem(
          name: barcodeItemNames[index],
          quantity: 1,
          unitPrice: index < itemAmounts.length ? itemAmounts[index] : 0.0,
        ),
      );
    }

    // Many receipts place each item name on one line and its quantity/price
    // on the next line, for example "Krispy A (1pc)" followed by
    // "3 x RM9.99". Prefer these explicit pairs over broad text matching.
    final quantityPricePattern = RegExp(
      r'^(\d+)\s*x\s*(?:RM\s*)?(\d+(?:\.\d{2})?)$',
      caseSensitive: false,
    );
    final quantityPriceItems = <_ExtractedReceiptItem>[];
    for (var index = 1; index < lines.length; index++) {
      final quantityPriceMatch = quantityPricePattern.firstMatch(lines[index]);
      if (quantityPriceMatch == null) continue;

      final name = lines[index - 1].trim();
      final quantity = int.tryParse(quantityPriceMatch.group(1)!);
      final unitPrice = double.tryParse(quantityPriceMatch.group(2)!);
      if (quantity == null ||
          quantity <= 0 ||
          unitPrice == null ||
          unitPrice < 0 ||
          name.isEmpty ||
          _isReceiptLabel(name) ||
          !RegExp(r'[a-zA-Z]').hasMatch(name)) {
        continue;
      }

      quantityPriceItems.add(
        _ExtractedReceiptItem(
          name: name,
          quantity: quantity,
          unitPrice: unitPrice,
        ),
      );
    }
    if (quantityPriceItems.isNotEmpty) {
      return quantityPriceItems;
    }

    // Handle receipts where items have quantity prefixes (e.g. "1 MUSH NOODLES DRY")
    // and all price lines follow later in the OCR stream.
    final qtyPrefixedItems = <_ExtractedReceiptItem>[];
    for (final line in lines) {
      if (_isReceiptLabel(line)) continue;
      final match = RegExp(r'^(\d+)\s+([a-zA-Z].+)$').firstMatch(line.trim());
      if (match != null) {
        final quantity = int.tryParse(match.group(1)!);
        final name = match.group(2)!.trim();
        if (quantity != null &&
            quantity > 0 &&
            name.isNotEmpty &&
            !_looksLikeAddress(name) &&
            !_isReceiptLabel(name)) {
          qtyPrefixedItems.add(
            _ExtractedReceiptItem(name: name, quantity: quantity, unitPrice: 0),
          );
        }
      }
    }

    if (qtyPrefixedItems.isNotEmpty) {
      final allAmounts = <double>[];
      for (final line in lines) {
        final amounts = _amountsFromLine(line);
        if (amounts.isNotEmpty) {
          allAmounts.addAll(amounts);
        }
      }

      if (allAmounts.length >= qtyPrefixedItems.length) {
        return List.generate(
          qtyPrefixedItems.length,
          (index) => _ExtractedReceiptItem(
            name: qtyPrefixedItems[index].name,
            quantity: qtyPrefixedItems[index].quantity,
            unitPrice: allAmounts[index],
          ),
        );
      }
    }

    final itemLines = <_ExtractedReceiptItem>[];
    final merchantName = extractMerchantName(receiptText)?.toLowerCase().trim();
    final firstSummaryIndex = lines.indexWhere(
      (line) => _isSubtotalLabel(line) || _isFinalTotalLabel(line),
    );
    final fallbackEnd = firstSummaryIndex < 0
        ? lines.length
        : firstSummaryIndex;

    for (var index = 0; index < fallbackEnd; index++) {
      final line = lines[index];
      final normalizedLine = line.toLowerCase().trim();
      if (_isReceiptLabel(line) ||
          normalizedLine == merchantName ||
          _isNonItemReceiptText(normalizedLine) ||
          !RegExp(r'[a-zA-Z]').hasMatch(line)) {
        continue;
      }

      if (_amountPattern.hasMatch(line)) {
        final amount = _amountsFromLine(line).first;
        final itemName = line.replaceFirst(_amountPattern, '').trim();
        if (itemName.isNotEmpty) {
          itemLines.add(
            _ExtractedReceiptItem(
              name: itemName,
              quantity: 1,
              unitPrice: amount,
            ),
          );
        }
        continue;
      }

      double? price;
      for (final possiblePriceLine
          in lines.skip(index + 1).take(fallbackEnd - index - 1)) {
        final amounts = _amountsFromLine(possiblePriceLine);
        if (amounts.isNotEmpty) {
          price = amounts.first;
          break;
        }
      }
      if (price != null && !_looksLikeAddress(line)) {
        itemLines.add(
          _ExtractedReceiptItem(name: line, quantity: 1, unitPrice: price),
        );
      }
    }

    final uniqueItems = <String, _ExtractedReceiptItem>{};
    for (final item in itemLines) {
      uniqueItems['${item.name}|${item.unitPrice}'] = item;
    }
    return uniqueItems.values.toList();
  }

  List<_ExtractedReceiptItem> _extractSimpleItemAmountColumns(
    List<String> lines,
  ) {
    final itemHeaderIndex = lines.indexWhere(
      (line) => line.trim().toLowerCase() == 'item',
    );
    final subtotalIndex = lines.indexWhere(_isSubtotalLabel);
    final amountHeaderIndex = lines.indexWhere(
      (line) => RegExp(
        r'^(?:amount|am[o0d]u?n?t|amdnt)$',
        caseSensitive: false,
      ).hasMatch(line.trim()),
    );
    if (itemHeaderIndex < 0 ||
        subtotalIndex <= itemHeaderIndex ||
        amountHeaderIndex < 0) {
      return const [];
    }

    final names = lines.sublist(itemHeaderIndex + 1, subtotalIndex).where((
      line,
    ) {
      final normalized = line.trim();
      final normalizedLower = normalized.toLowerCase();
      final isColumnHeader = const {
        'item',
        'qty',
        'quantity',
        'amount',
        'price',
      }.contains(normalizedLower);
      if (!RegExp(r'[a-zA-Z]').hasMatch(normalized) ||
          isColumnHeader ||
          _summaryLabelKind(normalized) != null ||
          _isNonItemReceiptText(normalized) ||
          _amountsFromLine(normalized).isNotEmpty ||
          RegExp(
            r'^(?:inv|invoice)[-\s]',
            caseSensitive: false,
          ).hasMatch(normalized) ||
          RegExp(
            r'^(?:pl(?:ease|eae)|thank|sample\s+recei)',
            caseSensitive: false,
          ).hasMatch(normalized)) {
        return false;
      }
      if (RegExp(
            r'\b(?:jalan|street|road|selangor|postcode|telephone|tel:)\b',
            caseSensitive: false,
          ).hasMatch(normalized) ||
          (RegExp(r'\d').hasMatch(normalized) &&
              !normalizedLower.contains('item'))) {
        return false;
      }
      final lettersOnly = normalized.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      return lettersOnly.isNotEmpty;
    }).toList();
    if (names.isEmpty) return const [];

    final prices = <double>[];
    final missingLeadingDigitIndexes = <int>[];
    for (final line in lines.skip(amountHeaderIndex + 1)) {
      final corrected = line.trim().replaceFirst(
        RegExp(r'^[bB](?=[.,]\d{2}$)'),
        '8',
      );
      if (RegExp(r'^[.,]\d{2}$').hasMatch(corrected)) {
        final value = double.tryParse('0$corrected');
        if (value != null) {
          missingLeadingDigitIndexes.add(prices.length);
          prices.add(value);
        }
      } else if (RegExp(r'\d+[.,]\d{2}').hasMatch(corrected)) {
        prices.addAll(
          _amountsFromLine(corrected).where((amount) => amount > 0),
        );
      }
      if (prices.length == names.length) break;
    }
    if (prices.length < names.length) return const [];

    if (missingLeadingDigitIndexes.length == 1) {
      final currentSubtotal = prices.fold<double>(
        0.0,
        (sum, price) => sum + price,
      );
      double? printedSubtotal;
      for (final amount
          in lines
              .skip(amountHeaderIndex + 1)
              .expand(_amountsFromLine)
              .where((amount) => amount > 0)) {
        final difference = amount - currentSubtotal;
        if (difference >= 1 &&
            difference <= 9 &&
            difference == difference.round()) {
          printedSubtotal = amount;
          break;
        }
      }
      if (printedSubtotal != null) {
        final missingIndex = missingLeadingDigitIndexes.single;
        prices[missingIndex] += printedSubtotal - currentSubtotal;
      }
    }

    return List.generate(
      names.length,
      (index) => _ExtractedReceiptItem(
        name: names[index],
        quantity: 1,
        unitPrice: prices[index],
      ),
    );
  }

  bool _isNonItemReceiptText(String line) {
    return RegExp(
      r'^(?:trans|transaction|mcc|payment|thank\s+you|please\s+come\s+again|welcome)(?:\b|\s*[-:])',
      caseSensitive: false,
    ).hasMatch(line);
  }

  static final RegExp _amountPattern = RegExp(
    r'(?<!\d)(?:RM\s*)?(-?\s*(?:\d{1,3}(?:,\d{3})*(?:\.\d{2})|\d+(?:[.,]\d{2})))(?!\d)',
    caseSensitive: false,
  );

  List<double> _amountsFromLine(String line) {
    return _amountPattern
        .allMatches(line)
        .map((match) {
          final value = match.group(1)!.replaceAll(' ', '');
          return value.contains(',') ? value.replaceAll(',', '.') : value;
        })
        .map(double.tryParse)
        .whereType<double>()
        .toList();
  }

  bool _isReceiptLabel(String line) {
    final normalizedLine = line.toLowerCase().trim();
    const labels = [
      'total',
      'subtotal',
      'tax',
      'change',
      'cash',
      'receipt',
      'visa',
      'mastercard',
      'sale',
      'item',
      'qty',
      'quantity',
      'price',
      'transaction',
      'rounding',
      'payment',
      'mobile app',
      'previous balance',
      'balance',
      'for here',
      'take away',
      'invoice',
      'date:',
      'server:',
      'tran:',
      'xid:',
      'usa',
    ];
    return labels.any(normalizedLine.contains);
  }

  bool _isFinalTotalLabel(String line) {
    final normalized = line.toLowerCase().trim();
    if (_isSubtotalLabel(normalized) ||
        normalized.contains('previous balance')) {
      return false;
    }
    return RegExp(
      r'\b(?:grand\s+total|net\s+total|total\s+amount|amount\s+due|total\s+due|total\s+sales|total)\b',
    ).hasMatch(normalized);
  }

  bool _isSubtotalLabel(String line) {
    final normalized = line.toLowerCase().trim();
    return RegExp(r'\bsub[-\s]*tota(?:l|!|1|\|)').hasMatch(normalized);
  }

  String? _summaryLabelKind(String line) {
    final normalized = line.toLowerCase().trim();
    if (_isSubtotalLabel(normalized)) {
      return 'subtotal';
    }
    if (RegExp(
      r'\b(?:service\s+tax|sales\s+tax|tax|gst|sst|[s35]{2}t)\b',
    ).hasMatch(normalized)) {
      return 'tax';
    }
    if (normalized.contains('rounding')) return 'rounding';
    if (_isFinalTotalLabel(normalized)) return 'total';
    return null;
  }

  double? _summaryAmountFor(List<String> lines, String targetKind) {
    final labels = <MapEntry<int, String>>[];
    for (var index = 0; index < lines.length; index++) {
      final kind = _summaryLabelKind(lines[index]);
      if (kind != null) labels.add(MapEntry(index, kind));
    }
    final subtotalPosition = labels.indexWhere(
      (entry) => entry.value == 'subtotal',
    );
    final totalPosition = labels.lastIndexWhere(
      (entry) => entry.value == 'total',
    );
    if (subtotalPosition < 0 || totalPosition <= subtotalPosition) return null;

    final summaryLabels = labels.sublist(subtotalPosition, totalPosition + 1);
    final targetPosition = summaryLabels.indexWhere(
      (entry) => entry.value == targetKind,
    );
    if (targetPosition < 0) return null;

    final directAmounts = _amountsFromLine(
      lines[summaryLabels[targetPosition].key],
    );
    if (directAmounts.isNotEmpty) return directAmounts.last;

    final inferredValues = _inferSummaryValues(lines);
    final inferredValue = inferredValues[targetKind];
    if (inferredValue != null) return inferredValue;

    final start = summaryLabels.first.key;
    final end = (summaryLabels.last.key + summaryLabels.length + 2)
        .clamp(start + 1, lines.length)
        .toInt();
    final summaryAmounts = lines
        .sublist(start, end)
        .expand(_amountsFromLine)
        .toList();
    if (summaryAmounts.length < summaryLabels.length) return null;
    return summaryAmounts[targetPosition];
  }

  Map<String, double> _inferSummaryValues(List<String> lines) {
    final kinds = lines.map(_summaryLabelKind).whereType<String>().toSet();
    if (!kinds.contains('subtotal') || !kinds.contains('total')) {
      return const {};
    }

    final amounts = lines.expand(_amountsFromLine).toList();
    final hasTax = kinds.contains('tax');
    final hasRounding = kinds.contains('rounding');
    final valueCount = 2 + (hasTax ? 1 : 0) + (hasRounding ? 1 : 0);
    for (var start = 0; start + valueCount <= amounts.length; start++) {
      final subtotal = amounts[start];
      var cursor = start + 1;
      final tax = hasTax ? amounts[cursor++] : 0.0;
      final rounding = hasRounding ? amounts[cursor++] : 0.0;
      final total = amounts[cursor];
      if (subtotal <= 0 || tax < 0 || total <= 0) continue;
      if ((subtotal + tax + rounding - total).abs() <= 0.02) {
        return {
          'subtotal': subtotal,
          if (hasTax) 'tax': tax,
          if (hasRounding) 'rounding': rounding,
          'total': total,
        };
      }
    }
    return const {};
  }

  List<_ExtractedReceiptItem> _extractDiscountedColumnItems(
    List<String> lines,
  ) {
    final subtotalLineIndex = lines.indexWhere(_isSubtotalLabel);
    if (subtotalLineIndex <= 0) return const [];

    final dateLineIndex = lines
        .take(subtotalLineIndex)
        .toList()
        .lastIndexWhere((line) => line.toLowerCase().contains('date'));
    final candidates = lines
        .sublist(dateLineIndex >= 0 ? dateLineIndex + 1 : 0, subtotalLineIndex)
        .where(_isLikelyProductOrDiscountLine)
        .toList();
    final productCount = candidates
        .where((line) => !_isDiscountDescription(line))
        .length;
    if (productCount < 1 || !candidates.any(_isDiscountDescription)) {
      return const [];
    }

    final subtotal = _summaryAmountFor(lines, 'subtotal');
    if (subtotal == null) return const [];
    final allAmounts = lines
        .skip(dateLineIndex >= 0 ? dateLineIndex + 1 : 0)
        .expand(_amountsFromLine)
        .toList();
    final subtotalAmountIndex = allAmounts.indexWhere(
      (amount) => (amount - subtotal).abs() <= 0.005,
    );
    if (subtotalAmountIndex < candidates.length) return const [];
    final itemAmounts = allAmounts.take(subtotalAmountIndex).toList();

    final items = <_ExtractedReceiptItem>[];
    for (var index = 0; index < candidates.length; index++) {
      final description = candidates[index].trim();
      final amount = itemAmounts[index];
      if (_isDiscountDescription(description) || amount < 0) {
        if (items.isEmpty || amount >= 0) continue;
        final previous = items.removeLast();
        final adjustedTotal = (previous.unitPrice * previous.quantity + amount)
            .clamp(0.0, double.infinity)
            .toDouble();
        items.add(
          _ExtractedReceiptItem(
            name: previous.name,
            quantity: previous.quantity,
            unitPrice: adjustedTotal / previous.quantity,
          ),
        );
        continue;
      }

      if (amount <= 0) continue;
      final quantityMatch = RegExp(r'\b(\d+)\s*$').firstMatch(description);
      final parsedQuantity = int.tryParse(quantityMatch?.group(1) ?? '') ?? 1;
      final quantity = parsedQuantity > 0 ? parsedQuantity : 1;
      final name = description.replaceFirst(RegExp(r'\s+\d+\s*$'), '').trim();
      items.add(
        _ExtractedReceiptItem(
          name: name,
          quantity: quantity,
          unitPrice: amount / quantity,
        ),
      );
    }
    return items;
  }

  bool _isLikelyProductOrDiscountLine(String line) {
    final normalized = line.toLowerCase().trim();
    if (_isDiscountDescription(normalized)) return true;
    if (!RegExp(r'[a-z]').hasMatch(normalized) ||
        _isReceiptLabel(normalized) ||
        _looksLikeAddress(normalized) ||
        normalized.contains('tax id') ||
        normalized.contains('website') ||
        normalized.contains('company') ||
        normalized.contains('service tax')) {
      return false;
    }
    return normalized.length >= 6 &&
        !RegExp(
          r'^(?:dewi|dewt|staff|server|cashier|rm|rn|myr)$',
        ).hasMatch(normalized);
  }

  bool _isDiscountDescription(String line) {
    final normalized = line.toLowerCase();
    return normalized.contains('discount') ||
        normalized.contains('%off') ||
        normalized.contains('% off') ||
        normalized.startsWith('msr') ||
        normalized.startsWith('hsr');
  }

  List<_ExtractedReceiptItem> _extractInlineItemsBeforeSummary(
    List<String> lines,
  ) {
    final firstSummaryIndex = lines.indexWhere((line) {
      final normalized = line.toLowerCase();
      return _isSubtotalLabel(normalized) || _isFinalTotalLabel(normalized);
    });
    final end = firstSummaryIndex < 0 ? lines.length : firstSummaryIndex;
    final items = <_ExtractedReceiptItem>[];

    for (final rawLine in lines.take(end)) {
      final amounts = _amountsFromLine(rawLine);
      if (amounts.isEmpty || !RegExp(r'[A-Za-z]').hasMatch(rawLine)) continue;

      final withoutAmount = rawLine.replaceFirst(_amountPattern, '').trim();
      final normalizedName = withoutAmount
          .replaceFirst(RegExp(r'^\d+\s*[xX]\s*'), '')
          .replaceFirst(RegExp(r'\s+\d+\s*$'), '')
          .trim();
      final normalizedLower = normalizedName.toLowerCase();
      final amount = amounts.last;

      final isDiscount =
          amount < 0 ||
          normalizedLower.contains('discount') ||
          normalizedLower.contains('%off') ||
          normalizedLower.contains('% off');
      if (isDiscount) {
        if (items.isNotEmpty && amount < 0) {
          final previous = items.removeLast();
          final adjustedTotal =
              (previous.unitPrice * previous.quantity + amount)
                  .clamp(0.0, double.infinity)
                  .toDouble();
          items.add(
            _ExtractedReceiptItem(
              name: previous.name,
              quantity: previous.quantity,
              unitPrice: adjustedTotal / previous.quantity,
            ),
          );
        }
        continue;
      }

      if (amount <= 0 ||
          normalizedName.length < 3 ||
          _isReceiptLabel(normalizedName) ||
          _looksLikeAddress(normalizedName) ||
          RegExp(
            r'^(?:rm|rn|myr)$',
            caseSensitive: false,
          ).hasMatch(normalizedName)) {
        continue;
      }

      final quantityMatch = RegExp(r'\b(\d+)\s*$').firstMatch(withoutAmount);
      final parsedQuantity = int.tryParse(quantityMatch?.group(1) ?? '') ?? 1;
      final quantity = parsedQuantity > 0 ? parsedQuantity : 1;
      items.add(
        _ExtractedReceiptItem(
          name: normalizedName,
          quantity: quantity,
          unitPrice: amount / quantity,
        ),
      );
    }
    return items;
  }

  bool _looksLikeAddress(String line) {
    return RegExp(r'\d').hasMatch(line) ||
        line.toLowerCase().contains('street') ||
        line.toLowerCase().contains('road') ||
        line.toLowerCase().contains('usa');
  }

  List<String> _receiptLines(String receiptText) {
    return receiptText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Validates, calculates, and records one parent expense with its child items.
  Future<Expense> recordExpense({
    required String activitiesId,
    required List<ExpenseItem> expenseItems,
    required String paymentMethod,
    required String currency,
    double taxAmount = 0.0,
    double discountAmount = 0.0,
    double roundingAmount = 0.0,
    String? receiptLocalPath,
  }) async {
    if (activitiesId.trim().isEmpty) {
      throw ArgumentError('An expense must be linked to a selected activity.');
    }

    if (paymentMethod.trim().isEmpty) {
      throw ArgumentError('Please select a payment method.');
    }
    final originalCurrency = currency.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(originalCurrency)) {
      throw ArgumentError('A valid original currency is required.');
    }

    validateExpenseItems(expenseItems);
    validateTaxAmount(taxAmount);
    validateExpenseAdjustments(discountAmount, roundingAmount);

    final itemsWithCalculatedSubtotals = expenseItems
        .map(
          (item) => item.copyWith(
            subtotal: calculateItemSubtotal(item.quantity, item.unitPrice),
          ),
        )
        .toList();

    final totalAmount = calculateTotalExpense(
      itemsWithCalculatedSubtotals,
      taxAmount,
      discountAmount,
      roundingAmount,
    );
    validateTotalAmount(totalAmount);

    final expenseId = await _expenseRepository.generateNextExpenseId();
    String? receiptImageUrl;
    if (receiptLocalPath != null && receiptLocalPath.trim().isNotEmpty) {
      receiptImageUrl = await _expenseRepository.uploadReceiptImage(
        localImagePath: receiptLocalPath,
        expenseId: expenseId,
      );
    }

    final savedExpense = await _expenseRepository.insertExpense(
      Expense(
        expenseId: expenseId,
        activitiesId: activitiesId,
        totalAmount: totalAmount,
        taxAmount: taxAmount,
        discountAmount: discountAmount,
        roundingAmount: roundingAmount,
        currency: originalCurrency,
        paymentMethod: paymentMethod.trim(),
        receiptImageUrl: receiptImageUrl,
      ),
    );

    final savedExpenseId = savedExpense.expenseId;
    if (savedExpenseId == null || savedExpenseId.isEmpty) {
      throw Exception('Supabase did not return an expense ID.');
    }

    final itemsWithExpenseId = itemsWithCalculatedSubtotals
        .map((item) => item.copyWith(expenseId: savedExpenseId))
        .toList();

    await _expenseRepository.insertExpenseItems(itemsWithExpenseId);
    return savedExpense;
  }

  double calculateItemSubtotal(int quantity, double unitPrice) {
    return quantity * unitPrice;
  }

  double calculateTotalExpense(
    List<ExpenseItem> expenseItems, [
    double taxAmount = 0.0,
    double discountAmount = 0.0,
    double roundingAmount = 0.0,
  ]) {
    final itemsSubtotal = expenseItems.fold(
      0.0,
      (total, item) => total + item.subtotal,
    );
    final normalizedTax = taxAmount < 0 ? 0.0 : taxAmount;
    final cents =
        ((itemsSubtotal + normalizedTax - discountAmount + roundingAmount) *
                100)
            .round();
    return cents / 100;
  }

  void validateExpenseAdjustments(
    double discountAmount,
    double roundingAmount,
  ) {
    if (!discountAmount.isFinite ||
        discountAmount < 0 ||
        discountAmount > maxSafeExpenseAmount ||
        (discountAmount != 0 && discountAmount < 0.10)) {
      throw ArgumentError('Discount must be 0.00 or at least RM0.10.');
    }
    if (!roundingAmount.isFinite || roundingAmount.abs() > 1) {
      throw ArgumentError('Rounding must be between -1.00 and 1.00.');
    }
  }

  void validateExpenseItems(List<ExpenseItem> expenseItems) {
    if (expenseItems.isEmpty) {
      throw ArgumentError('Add at least one expense item.');
    }

    for (final item in expenseItems) {
      if (item.itemName.trim().isEmpty) {
        throw ArgumentError('Item name cannot be empty.');
      }

      final validationMessages = <String?>[
        _validateExpenseItemName(item.itemName),
        _validateExpenseDescription(item.itemDescription ?? ''),
        _validateExpenseMerchantName(item.merchantName ?? ''),
      ];
      for (final validationMessage in validationMessages) {
        if (validationMessage != null) {
          throw ArgumentError(validationMessage);
        }
      }

      if (item.quantity <= 0) {
        throw ArgumentError('Item quantity must be greater than zero.');
      }
      if (!item.unitPrice.isFinite || item.unitPrice < 0.10) {
        throw ArgumentError('Item unit price must be at least 0.10.');
      }
      if (item.unitPrice > maxSafeExpenseAmount ||
          !item.subtotal.isFinite ||
          item.quantity * item.unitPrice > maxSafeExpenseAmount) {
        throw ArgumentError('Item amount is too large to calculate safely.');
      }
    }
  }

  void validateTotalAmount(double totalAmount) {
    if (!totalAmount.isFinite ||
        totalAmount <= 0 ||
        totalAmount > maxSafeExpenseAmount) {
      throw ArgumentError(
        'Enter a positive amount that can be calculated safely.',
      );
    }
  }

  void validateTaxAmount(double taxAmount) {
    if (!taxAmount.isFinite ||
        taxAmount < 0 ||
        taxAmount > maxSafeExpenseAmount) {
      throw ArgumentError('Enter a valid tax and service charges amount.');
    }
  }

  void validateExpenseWithinRemainingBudget({
    required double totalAmount,
    required double remainingBudget,
  }) {
    if (totalAmount - remainingBudget > 0.005) {
      throw ArgumentError(
        'Expense amount cannot exceed the remaining trip balance.',
      );
    }
  }

  Future<List<Activity>> getRemainingActivities(
    String tripId,
    DateTime currentDateTime,
  ) async {
    try {
      final activities = await _itineraryRepository.fetchAllActivitiesByTrip(
        tripId,
      );

      activities.sort((a, b) {
        final aDateTime = _getActivityStartDateTime(a);
        final bDateTime = _getActivityStartDateTime(b);

        return aDateTime.compareTo(bDateTime);
      });

      return activities.where((activity) {
        final activityStart = _getActivityStartDateTime(activity);

        return activityStart.isAfter(currentDateTime);
      }).toList();
    } catch (e) {
      print('Calculating Remaining Activities Error: $e');
      rethrow;
    }
  }

  DateTime _getActivityStartDateTime(Activity activity) {
    final date = activity.date;

    final timeParts = activity.startTime?.split(':');

    final hour = int.parse(timeParts![0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  // zhiqin
  Future<ExpenseProcessingResult> processExpense({
    required String tripId,
    required String currentActivityId,
  }) async {
    debugPrint("process expense");

    // Get current trip
    final currentTrip = await _itineraryRepository.getTrip(tripId);

    // get remaining activities
    final activities = await getRemainingActivities(tripId, DateTime.now());

    // Get ALL confirmed expenses for this activity
    final expenses = await _expenseRepository.getExpensesByActivityId(
      currentActivityId,
    );

    // Calculate total spending for this activity
    double totalActivityExpense = 0.0;

    for (final expense in expenses) {
      totalActivityExpense += expense.totalAmount;
    }

    double totalAllocatedBudget = 0.00;

    for (final activity in activities) {
      totalAllocatedBudget += activity.allocatedBudget;
    }

    final double remainingBudget = currentTrip.remainingBalance ?? 0.00;

    // Get current activity
    final currentActivity = await _itineraryRepository.getCurrentActivity(
      currentActivityId,
    );

    // Get current day
    final currentDay = await _itineraryRepository.getCurrentDay(
      currentActivity.dayTripId,
    );

    // Detect overspend
    final bool isOverspend = await detectOverspend(
      tripId,
      currentActivity,
      totalActivityExpense,
    );

    if (!isOverspend) {
      return ExpenseProcessingResult.withinBudget;
    }

    // Calculate overspent amount
    final double overspentAmount =
        totalActivityExpense - currentActivity.allocatedBudget;

    // Update current activity
    final updatedActivity = currentActivity.copyWith(
      overspendAmount: overspentAmount,
      isOverspend: true,
    );

    // Update current day
    final existingCategories =
        currentDay.overspendCategory
            ?.split(',')
            .map((category) => category.trim())
            .where((category) => category.isNotEmpty)
            .toList() ??
        [];

    final newCategory = currentActivity.activityCategory.trim();

    if (!existingCategories.contains(newCategory)) {
      existingCategories.add(newCategory);
    }

    final updatedDay = currentDay.copyWith(
      overspendAmount: ((currentDay.overspendAmount ?? 0.0) + overspentAmount)
          .clamp(0.0, double.infinity)
          .toDouble(),
      overspendCategory: existingCategories.join(', '),
      isOverspend: true,
    );

    // Save overspend details
    final success = await _itineraryRepository.updateOverspendDetails(
      updatedDay,
      updatedActivity,
    );

    if (!success) {
      throw Exception('Update overspend details failed: $success');
    }

    if (activities.isEmpty) {
      return ExpenseProcessingResult.withinBudget;
    }

    if (totalAllocatedBudget == 0.00 ||
        remainingBudget >= totalAllocatedBudget) {
      return ExpenseProcessingResult.withinBudget;
    }

    // Check critical overspend
    final bool isCritical = await detectCriticalOverspend(
      totalAllocatedBudget,
      remainingBudget,
    );

    if (isCritical) {
      final success = await _itineraryRepository.updateCriticalDetails(tripId);
      if (success) {
        return ExpenseProcessingResult.critical;
      }
      throw Exception('Update critical details failed: $success');
    }

    if (currentActivity.allocatedBudget <= 0) {
      return ExpenseProcessingResult.withinBudget;
    }

    // Check overspend threshold
    final bool isAboveThreshold = await calculateOverspendPercentage(
      currentActivity,
      overspentAmount,
    );

    // Above threshold - trigger recommendation
    if (isAboveThreshold) {
      return ExpenseProcessingResult.exceedsThresholdTriggerRecommendation;
    }

    // Within threshold - reallocate budget
    final updatedActivities = await reallocateBudget(
      tripId,
      currentActivity,
      overspentAmount,
    );

    if (updatedActivities.isEmpty) {
      return ExpenseProcessingResult.reallocatedFailed;
    }

    // Update reallocated activities
    final updateSuccessful = await _itineraryRepository.updateActivities(
      updatedActivities,
    );

    if (!updateSuccessful) {
      return ExpenseProcessingResult.reallocatedFailed;
    }

    // Reallocation successful
    return ExpenseProcessingResult.reallocatedSuccessfully;
  }

  // zhiqin
  Future<bool> detectOverspend(
    String tripId,
    Activity currentActivity,
    double expense,
  ) async {
    if (currentActivity.allocatedBudget < expense) {
      return true;
    }
    return false;
  }

  Future<bool> detectCriticalOverspend(
    double totalAllocatedBudget,
    double remainingBudget,
  ) async {
    if (remainingBudget <= totalAllocatedBudget * 0.2) {
      return true;
    }
    return false;
  }

  // zhiqin
  Future<List<Activity>> reallocateBudget(
    String tripId,
    Activity currentActivity,
    double overspentAmount,
  ) async {
    final List<Activity> modifiedActivities = await _budgetService
        .reallocateBudget(tripId, currentActivity, overspentAmount);

    return modifiedActivities;
  }

  // zhiqin
  Future<bool> calculateOverspendPercentage(
    Activity currentActivity,
    double overspentAmount,
  ) async {
    // final double allocatedBudget = currentActivity.allocatedBudget;
    final double allocatedBudget = currentActivity.allocatedBudget <= 10
        ? 10.0
        : currentActivity.allocatedBudget;

    double overspendThresholdPercentage;

    if (allocatedBudget <= 100.0) {
      overspendThresholdPercentage = 0.15;
    } else if (allocatedBudget <= 500.0) {
      overspendThresholdPercentage = 0.10;
    } else {
      overspendThresholdPercentage = 0.05;
    }

    final double allowedOverspendLimit =
        allocatedBudget * (1 + overspendThresholdPercentage);

    return overspentAmount > allowedOverspendLimit;
  }

  // zhiqin
  Future<double> getExceededAmount(
    String tripId,
    String currentActivityId,
  ) async {
    final activity = await _itineraryRepository.getCurrentActivity(
      currentActivityId,
    );
    final expenses = await _expenseRepository.getExpensesByActivityId(
      currentActivityId,
    );
    double totalAmount = 0.0;
    for (final expense in expenses) {
      totalAmount += expense.totalAmount;
    }
    return totalAmount - activity.allocatedBudget;
  }
}
