/// Returns true when expense text contains profanity or explicit sexual terms.
/// Separators are ignored, so obfuscations such as `f.u.c.k` are also rejected.
bool containsProhibitedExpenseLanguage(String value) {
  var normalized = value.toLowerCase();
  const substitutions = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '@': 'a',
    r'$': 's',
  };
  substitutions.forEach((source, replacement) {
    normalized = normalized.replaceAll(source, replacement);
  });

  const prohibitedWords = [
    'fuck',
    'shit',
    'pussy',
    'porn',
    'porno',
    'pornography',
    'hentai',
    'sex',
    'sexy',
    'nude',
    'naked',
    'boob',
    'boobs',
    'tit',
    'tits',
    'penis',
    'vagina',
    'blowjob',
    'handjob',
    'gangbang',
    'orgasm',
    'masturbate',
    'rape',
    'bitch',
    'cunt',
    'dick',
    'cock',
    'whore',
    'slut',
    'asshole',
    'motherfucker',
    'babi',
    'puki',
    'pukimak',
    'lancau',
    'lanjiao',
    'kimak',
    'bodoh',
    'sial',
    'pantat',
    'tetek',
    'pelacur',
    'jalang',
  ];

  for (final word in prohibitedWords) {
    final separatedLetters = word
        .split('')
        .map((character) => '${RegExp.escape(character)}+')
        .join(r'[^a-z0-9]*');
    final pattern = RegExp(
      '(^|[^a-z0-9])${separatedLetters}[a-z]*([^a-z0-9]|\$)',
      caseSensitive: false,
    );
    if (pattern.hasMatch(normalized)) return true;
  }

  return false;
}

String? validateExpenseText(String fieldName, String value) {
  if (!containsProhibitedExpenseLanguage(value)) return null;
  return '$fieldName contains inappropriate language. Please remove it.';
}

String? validateExpenseItemName(String value) {
  final trimmed = value.trim();
  if (trimmed.length > 30) {
    return 'Item name cannot exceed 30 characters.';
  }
  if (!RegExp(r'^[A-Za-z0-9 -]+$').hasMatch(trimmed)) {
    return 'Item name may only contain letters, numbers, spaces, and dashes.';
  }
  return validateExpenseText('Item name', trimmed);
}

String? validateExpenseDescription(String value) {
  final trimmed = value.trim();
  if (trimmed.length > 60) {
    return 'Item description cannot exceed 60 characters.';
  }
  final symbolError = _validateOptionalExpenseTextSymbols(
    'Item description',
    trimmed,
  );
  if (symbolError != null) return symbolError;
  return validateExpenseText('Item description', trimmed);
}

String? validateExpenseMerchantName(String value) {
  final trimmed = value.trim();
  if (trimmed.length > 50) {
    return 'Merchant name cannot exceed 50 characters.';
  }
  final symbolError = _validateOptionalExpenseTextSymbols(
    'Merchant name',
    trimmed,
  );
  if (symbolError != null) return symbolError;
  return validateExpenseText('Merchant name', trimmed);
}

String? _validateOptionalExpenseTextSymbols(String fieldName, String value) {
  if (value.isEmpty) return null;
  if (!RegExp(r'[A-Za-z0-9]').hasMatch(value)) {
    return '$fieldName must contain at least one letter or number.';
  }
  if (!RegExp(r"^[A-Za-z0-9 .,!?&'()/-]+$").hasMatch(value)) {
    return "$fieldName contains an unsupported symbol. Use only . , ! ? & ' ( ) / or -.";
  }
  if (RegExp(r"([^A-Za-z0-9\s])\1{3,}").hasMatch(value)) {
    return '$fieldName cannot contain the same symbol more than 3 times in a row.';
  }
  return null;
}
