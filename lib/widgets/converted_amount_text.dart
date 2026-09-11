import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/services/i_auth_service.dart';
import '../theme/app_theme.dart';

String formatCurrencyAmount(
  String currency,
  double amount, {
  int decimalDigits = 2,
}) {
  final normalizedCurrency = currency.trim().toUpperCase();
  final displayCurrency = normalizedCurrency == 'MYR' ? 'RM' : normalizedCurrency;
  final sign = amount < 0 ? '-' : '';
  final decimalPattern = decimalDigits > 0
      ? '.${List.filled(decimalDigits, '0').join()}'
      : '';
  final formattedAmount = NumberFormat(
    '#,##0$decimalPattern',
    'en_US',
  ).format(amount.abs());
  return '$displayCurrency $sign$formattedAmount';
}

class ConvertedAmountText extends StatefulWidget {
  final double amount;
  final String originalCurrency;
  final String originalLabel;
  final String convertedLabel;
  final TextStyle? primaryStyle;
  final TextStyle? secondaryStyle;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;
  final bool showLabelsWhenSameCurrency;

  const ConvertedAmountText({
    super.key,
    required this.amount,
    required this.originalCurrency,
    this.originalLabel = 'Original Expense',
    this.convertedLabel = 'Display',
    this.primaryStyle,
    this.secondaryStyle,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.textAlign = TextAlign.start,
    this.showLabelsWhenSameCurrency = false,
  });

  @override
  State<ConvertedAmountText> createState() => _ConvertedAmountTextState();
}

class _ConvertedAmountTextState extends State<ConvertedAmountText> {
  String? _lastPreferredCurrency;
  String? _lastOriginalCurrency;
  double? _lastAmount;
  double? _convertedAmount;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshConversionIfNeeded(Provider.of<IAuthService>(context));
  }

  @override
  void didUpdateWidget(covariant ConvertedAmountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshConversionIfNeeded(context.read<IAuthService>());
  }

  void _refreshConversionIfNeeded(IAuthService authService) {
    final preferredCurrency = authService.preferredCurrency.trim().toUpperCase();
    final originalCurrency = widget.originalCurrency.trim().toUpperCase();

    final unchanged = _lastPreferredCurrency == preferredCurrency &&
        _lastOriginalCurrency == originalCurrency &&
        _lastAmount == widget.amount;
    if (unchanged) return;

    _lastPreferredCurrency = preferredCurrency;
    _lastOriginalCurrency = originalCurrency;
    _lastAmount = widget.amount;
    _convertedAmount = null;
    _errorMessage = null;

    if (originalCurrency.isEmpty || originalCurrency == preferredCurrency) {
      _isLoading = false;
      return;
    }

    _isLoading = true;
    Future.microtask(() async {
      try {
        final convertedAmount = await authService.convertToPreferredCurrency(
          amount: widget.amount,
          fromCurrency: originalCurrency,
        );
        if (!mounted ||
            _lastPreferredCurrency != preferredCurrency ||
            _lastOriginalCurrency != originalCurrency ||
            _lastAmount != widget.amount) {
          return;
        }
        setState(() {
          _convertedAmount = convertedAmount;
          _errorMessage = convertedAmount == null
              ? 'Unable to convert to $preferredCurrency'
              : null;
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted ||
            _lastPreferredCurrency != preferredCurrency ||
            _lastOriginalCurrency != originalCurrency ||
            _lastAmount != widget.amount) {
          return;
        }
        setState(() {
          _convertedAmount = null;
          _errorMessage = 'Unable to convert to $preferredCurrency';
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<IAuthService>();
    final preferredCurrency = authService.preferredCurrency.trim().toUpperCase();
    final originalCurrency = widget.originalCurrency.trim().toUpperCase();
    final displayCurrency = originalCurrency.isEmpty
        ? preferredCurrency
        : originalCurrency;
    final primaryStyle = widget.primaryStyle ??
        TextStyle(
          color: appTheme.gray_900,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        );
    final secondaryStyle = widget.secondaryStyle ??
        TextStyle(
          color: appTheme.blue_gray_700,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );

    if (displayCurrency == preferredCurrency) {
      final text = formatCurrencyAmount(displayCurrency, widget.amount);
      return Text(
        widget.showLabelsWhenSameCurrency
            ? '${widget.convertedLabel}: $text'
            : text,
        textAlign: widget.textAlign,
        style: primaryStyle,
      );
    }

    Widget convertedLine;
    if (_isLoading) {
      convertedLine = Text(
        'Converting to $preferredCurrency...',
        textAlign: widget.textAlign,
        style: secondaryStyle,
      );
    } else if (_errorMessage != null || _convertedAmount == null) {
      convertedLine = Text(
        _errorMessage ?? 'Unable to convert',
        textAlign: widget.textAlign,
        style: secondaryStyle.copyWith(color: appTheme.errorRed),
      );
    } else {
      convertedLine = Text(
        formatCurrencyAmount(preferredCurrency, _convertedAmount!),
        textAlign: widget.textAlign,
        style: secondaryStyle,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        Text(
          formatCurrencyAmount(displayCurrency, widget.amount),
          textAlign: widget.textAlign,
          style: primaryStyle,
        ),
        const SizedBox(height: 2),
        convertedLine,
      ],
    );
  }
}
