import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CurrencyPickerField extends StatelessWidget {
  final String sectionTitle;
  final String value;
  final List<String> currencies;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final EdgeInsetsGeometry margin;

  const CurrencyPickerField({
    super.key,
    this.sectionTitle = 'PREFERRED CURRENCY',
    required this.value,
    required this.currencies,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: appTheme.gray_100, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            offset: const Offset(0, 1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionTitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: appTheme.blue_gray_300,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6.0),
          Semantics(
            button: true,
            enabled: enabled,
            label: value.isEmpty
                ? 'Select preferred currency'
                : 'Preferred currency: $value',
            child: InkWell(
              borderRadius: BorderRadius.circular(12.0),
              onTap: enabled ? () => _openPicker(context) : null,
              child: InputDecorator(
                isEmpty: value.isEmpty,
                decoration: InputDecoration(
                  enabled: enabled,
                  errorText: errorText,
                  errorMaxLines: 3,
                  prefixIcon: const Icon(Icons.currency_exchange_outlined),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 44.0,
                    minHeight: 34.0,
                  ),
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 6.0,
                    horizontal: 12.0,
                  ),
                  filled: true,
                  fillColor: enabled
                      ? appTheme.white_A700
                      : appTheme.gray_200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: appTheme.gray_200,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: appTheme.gray_200,
                      width: 1.0,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: appTheme.gray_200,
                      width: 1.0,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: appTheme.colorFFEF44,
                      width: 1.0,
                    ),
                  ),
                ),
                child: value.isEmpty
                    ? Text(
                  'Select a currency',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                    color: appTheme.blue_gray_300,
                  ),
                )
                    : Row(
                  children: [
                    Text(
                      currencyFlag(value),
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: appTheme.gray_800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
        .where((code) => _matchesCurrencySearch(code, query))
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
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search USD, MYR, EUR…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: appTheme.white_A700,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: appTheme.gray_200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: appTheme.gray_200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: appTheme.teal_A700,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (value) => setState(() => query = value),
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
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
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
  final normalizedCode = code.trim().toUpperCase();

  // ISO 4217 national currency codes normally begin with the issuing
  // country's ISO 3166-1 alpha-2 code. X-prefixed codes are international
  // currencies, funds or precious metals and do not represent one country.
  if (normalizedCode.length != 3 ||
      normalizedCode.startsWith('X') ||
      normalizedCode == 'ANG') {
    return '💱';
  }

  final countryCode = normalizedCode.substring(0, 2);
  final firstLetter = countryCode.codeUnitAt(0);
  final secondLetter = countryCode.codeUnitAt(1);
  const letterA = 0x41;
  const letterZ = 0x5A;
  if (firstLetter < letterA ||
      firstLetter > letterZ ||
      secondLetter < letterA ||
      secondLetter > letterZ) {
    return '💱';
  }

  const regionalIndicatorA = 0x1F1E6;
  return String.fromCharCodes([
    regionalIndicatorA + firstLetter - letterA,
    regionalIndicatorA + secondLetter - letterA,
  ]);
}

bool _matchesCurrencySearch(String code, String query) {
  final normalizedCode = code.trim().toUpperCase();
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return true;

  if (normalizedCode.toLowerCase().contains(normalizedQuery)) return true;

  final aliases = (_currencySearchAliases[normalizedCode] ?? '')
      .toLowerCase();
  if (normalizedQuery.contains(' ')) {
    return aliases.contains(normalizedQuery);
  }
  return aliases
      .split(' ')
      .any((alias) => alias.startsWith(normalizedQuery));
}

const Map<String, String> _currencySearchAliases = {
  'AED': 'united arab emirates uae dirham dh',
  'AFN': 'afghanistan afghan afghani',
  'ALL': 'albania albanian lek',
  'AMD': 'armenia armenian dram',
  'ARS': 'argentina argentine peso',
  'AUD': 'australia australian aussie dollar dollars a\$',
  'BDT': 'bangladesh bangladeshi taka',
  'BGN': 'bulgaria bulgarian lev',
  'BHD': 'bahrain bahraini dinar',
  'BND': 'brunei dollar b\$',
  'BRL': 'brazil brazilian real r\$',
  'CAD': 'canada canadian dollar dollars loonie c\$',
  'CHF': 'switzerland swiss franc',
  'CLP': 'chile chilean peso',
  'CNH': 'china chinese offshore renminbi ren min bi yuan rmb kuai ¥',
  'CNY': 'china chinese onshore renminbi ren min bi yuan rmb kuai ¥',
  'COP': 'colombia colombian peso',
  'CZK': 'czech czechia koruna kč',
  'DKK': 'denmark danish krone kr',
  'EGP': 'egypt egyptian pound',
  'EUR': 'euro euros europe european union eu €',
  'GBP': 'britain british england english united kingdom uk pound pounds sterling quid £',
  'HKD': 'hong kong dollar hk\$',
  'HUF': 'hungary hungarian forint ft',
  'IDR': 'indonesia indonesian rupiah rp',
  'ILS': 'israel israeli shekel ₪',
  'INR': 'india indian rupee rs ₹',
  'ISK': 'iceland icelandic krona kr',
  'JPY': 'japan japanese yen jpy ¥',
  'KRW': 'korea south korean won ₩',
  'KWD': 'kuwait kuwaiti dinar',
  'MXN': 'mexico mexican peso',
  'MYR': 'malaysia malaysian ringgit ringgits rm',
  'NOK': 'norway norwegian krone kr',
  'NZD': 'new zealand nz kiwi dollar dollars nz\$',
  'PHP': 'philippines philippine peso ₱',
  'PKR': 'pakistan pakistani rupee rs',
  'PLN': 'poland polish zloty zł',
  'QAR': 'qatar qatari riyal',
  'RON': 'romania romanian leu lei',
  'RUB': 'russia russian ruble ₽',
  'SAR': 'saudi arabia saudi riyal',
  'SEK': 'sweden swedish krona kr',
  'SGD': 'singapore singaporean dollar dollars s\$',
  'THB': 'thailand thai baht ฿',
  'TRY': 'turkey turkish lira ₺',
  'TWD': 'taiwan new taiwan dollar nt\$',
  'UAH': 'ukraine ukrainian hryvnia ₴',
  'USD': 'united states america us usa american dollar dollars buck bucks greenback \$',
  'VND': 'vietnam vietnamese dong đồng ₫',
  'ZAR': 'south africa south african rand r',
};
