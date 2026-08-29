import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CurrencyPickerField extends StatelessWidget {
  final String value;
  final List<String> currencies;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const CurrencyPickerField({
    super.key,
    required this.value,
    required this.currencies,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? () => _openPicker(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: 'Search and select a currency',
          errorText: errorText,
          filled: true,
          fillColor: appTheme.white_A700,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: appTheme.blue_gray_300),
          ),
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: value.isEmpty
            ? Text(
          'Search and select a currency',
          style: TextStyle(color: appTheme.blue_gray_300),
        )
            : Row(
          children: [
            Text(currencyFlag(value),
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: appTheme.white_A700,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _CurrencyPickerSheet(
        currencies: currencies,
        selectedCurrency: value,
      ),
    );
    if (selected != null) onChanged(selected);
  }
}

class _CurrencyPickerSheet extends StatefulWidget {
  final List<String> currencies;
  final String selectedCurrency;

  const _CurrencyPickerSheet({
    required this.currencies,
    required this.selectedCurrency,
  });

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.currencies
        .where((code) => code.toLowerCase().contains(query.toLowerCase()))
        .toList(growable: false);
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: appTheme.gray_200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Choose currency',
              style: TextStyle(
                color: appTheme.teal_A700,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              autofocus: false,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: 'Search USD, MYR, EUR…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: appTheme.gray_50_02,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: results.isEmpty
                  ? Center(
                child: Text(
                  'No matching currency.',
                  style: TextStyle(color: appTheme.blue_gray_700),
                ),
              )
                  : ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final code = results[index];
                  return ListTile(
                    leading: Text(
                      currencyFlag(code),
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(code),
                    trailing: code == widget.selectedCurrency
                        ? Icon(Icons.check, color: appTheme.teal_A700)
                        : null,
                    onTap: () => Navigator.pop(context, code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String currencyFlag(String code) {
  return const {
    'MYR': '🇲🇾',
    'USD': '🇺🇸',
    'SGD': '🇸🇬',
    'EUR': '🇪🇺',
    'GBP': '🇬🇧',
    'JPY': '🇯🇵',
    'AUD': '🇦🇺',
    'CAD': '🇨🇦',
    'CHF': '🇨🇭',
    'CNY': '🇨🇳',
    'HKD': '🇭🇰',
    'IDR': '🇮🇩',
    'INR': '🇮🇳',
    'KRW': '🇰🇷',
    'NZD': '🇳🇿',
    'PHP': '🇵🇭',
    'THB': '🇹🇭',
    'TWD': '🇹🇼',
    'VND': '🇻🇳',
  }[code.toUpperCase()] ??
      '💱';
}
