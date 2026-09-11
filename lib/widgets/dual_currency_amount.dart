import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/services/i_auth_service.dart';
import '../theme/app_theme.dart';
import 'converted_amount_text.dart' show formatCurrencyAmount;

/// Shows an amount in the tourist's chosen (preferred) currency as the main
/// figure, with the base currency (default MYR/RM, since TREK is built for
/// Malaysia) as a smaller secondary figure underneath.
///
/// The amount passed in is expressed in [baseCurrency]. When the preferred
/// currency equals the base currency, only one line is shown.
class DualCurrencyAmount extends StatefulWidget {
  final double amount;
  final String baseCurrency;
  final String? baseLabel;
  final TextStyle? primaryStyle;
  final TextStyle? secondaryStyle;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;

  const DualCurrencyAmount({
    super.key,
    required this.amount,
    this.baseCurrency = 'MYR',
    this.baseLabel,
    this.primaryStyle,
    this.secondaryStyle,
    this.crossAxisAlignment = CrossAxisAlignment.end,
    this.textAlign = TextAlign.end,
  });

  @override
  State<DualCurrencyAmount> createState() => _DualCurrencyAmountState();
}

class _DualCurrencyAmountState extends State<DualCurrencyAmount> {
  String? _lastPreferred;
  String? _lastBase;
  double? _lastAmount;
  double? _convertedAmount;
  bool _hasConverted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshIfNeeded(Provider.of<IAuthService>(context));
  }

  @override
  void didUpdateWidget(covariant DualCurrencyAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshIfNeeded(context.read<IAuthService>());
  }

  void _refreshIfNeeded(IAuthService authService) {
    final preferred = authService.preferredCurrency.trim().toUpperCase();
    final base = widget.baseCurrency.trim().toUpperCase();

    if (_lastPreferred == preferred &&
        _lastBase == base &&
        _lastAmount == widget.amount) {
      return;
    }

    _lastPreferred = preferred;
    _lastBase = base;
    _lastAmount = widget.amount;
    _convertedAmount = null;
    _hasConverted = false;

    // Nothing to convert when there is no preferred currency or the preferred
    // currency is already the base currency.
    if (preferred.isEmpty || base.isEmpty || preferred == base) return;

    Future.microtask(() async {
      try {
        final converted = await authService.convertToPreferredCurrency(
          amount: widget.amount,
          fromCurrency: base,
        );
        if (!mounted ||
            _lastPreferred != preferred ||
            _lastBase != base ||
            _lastAmount != widget.amount) {
          return;
        }
        setState(() {
          _convertedAmount = converted;
          _hasConverted = true;
        });
      } catch (_) {
        if (!mounted ||
            _lastPreferred != preferred ||
            _lastBase != base ||
            _lastAmount != widget.amount) {
          return;
        }
        setState(() {
          _convertedAmount = null;
          _hasConverted = false;
        });
      }
    });
  }

  String _format(String label, double value) =>
      formatCurrencyAmount(label, value);

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<IAuthService>();
    final preferred = authService.preferredCurrency.trim().toUpperCase();
    final base = widget.baseCurrency.trim().toUpperCase();
    final baseLabel = (widget.baseLabel ?? base).toUpperCase();

    // When the caller supplies an explicit label we render it verbatim, so a
    // screen that asks for 'MYR' shows 'MYR' instead of the shortened 'RM'.
    // The MYR -> 'RM' shorthand only applies when no label was provided.
    final String baseLine = formatCurrencyAmount(
      baseLabel,
      widget.amount,
      displayMyrAsCode: widget.baseLabel != null,
    );

    final primaryStyle = widget.primaryStyle ??
        TextStyle(
          color: appTheme.gray_900,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        );
    final secondaryStyle = widget.secondaryStyle ??
        TextStyle(
          color: appTheme.blue_gray_700,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        );

    // Single line: no preferred currency, or it equals the base currency.
    if (preferred.isEmpty || base.isEmpty || preferred == base) {
      return Text(
        baseLine,
        textAlign: widget.textAlign,
        style: primaryStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Fall back to the base figure while the rate is loading or unavailable.
    if (!_hasConverted || _convertedAmount == null) {
      return Text(
        baseLine,
        textAlign: widget.textAlign,
        style: primaryStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final primaryLine = _format(preferred, _convertedAmount!);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        Text(primaryLine, textAlign: widget.textAlign, style: primaryStyle,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(baseLine, textAlign: widget.textAlign, style: secondaryStyle,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}