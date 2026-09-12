/// Validation utilities for place names (wishlist, attractions, destinations).
///
/// Ensures only valid place name text is allowed and blocks profanity / vulgarities
/// in English, Malay, and Chinese dialects.

/// Returns true when text contains profanity, vulgarity, or sexually explicit terms.
bool containsProhibitedPlaceLanguage(String value) {
  var normalized = value.toLowerCase();

  // Common leetspeak substitutions
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

  // Comprehensive list of profanities across English, Malay, and Chinese
  const prohibitedWords = [
    // English
    'fuck',
    'fucker',
    'fucking',
    'shit',
    'bullshit',
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
    'bastard',
    'dumbass',
    'wanker',
    'prick',
    'retard',

    // Malay / Manglish
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
    'anjing',
    'buto',
    'butoh',
    'pantek',
    'palatao',
    'pepek',
    'kontol',
    'memek',
    'jibake',
    'celaka',
    'sohai',
    'kanasai',
    'cheebye',
    'chee bye',

    // Chinese / Dialects
    '操',
    '肏',
    '草泥马',
    '傻逼',
    '煞笔',
    '弱智',
    '脑残',
    '他妈的',
    '妈的',
    '你妈',
    '卧槽',
    '我操',
    '屌',
    '屌你',
    '仆街',
    '扑街',
    '含家产',
    '阖家铲',
    '白痴',
    '笨蛋',
    '干你娘',
    '靠北',
    '鸡巴',
    '臭逼',
    '烂货',
    '臭嗨',
  ];

  // Direct check for Chinese / multibyte characters
  for (final word in prohibitedWords) {
    if (word.runes.any((r) => r > 127)) {
      if (value.contains(word)) return true;
    }
  }

  // Direct check for plain word or substring match for Latin words
  for (final word in prohibitedWords) {
    if (word.runes.any((r) => r > 127)) continue;
    if (normalized == word || normalized.contains(word)) return true;
  }

  // Regex check for Latin characters with potential obfuscation (e.g. f.u.c.k)
  for (final word in prohibitedWords) {
    if (word.runes.any((r) => r > 127)) continue;

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

/// Validates place name input (e.g. wishlist field).
/// Returns an error message if the text is invalid, or null if valid.
String? validatePlaceInput(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.length > 60) {
    return 'Place name cannot exceed 60 characters.';
  }

  // Check for profanity / vulgar language
  if (containsProhibitedPlaceLanguage(trimmed)) {
    return 'Inappropriate language is not allowed.';
  }

  // Must contain at least one valid alphabet letter or Chinese character
  if (!RegExp(r'[a-zA-Z\u4e00-\u9fa5]').hasMatch(trimmed)) {
    return 'Please enter a valid place name.';
  }

  // Check against repeated consecutive symbols (like '....', '----', '////')
  if (RegExp(r"([.,'()\-&/])\1{2,}").hasMatch(trimmed)) {
    return 'Please enter a valid place name.';
  }

  // Only allow valid characters for place names
  // (English/Malay letters, Chinese characters, numbers, spaces, and punctuation: .,'()-&/)
  if (!RegExp(r"^[\w\s.,'()\-&/\u4e00-\u9fa5]+$").hasMatch(trimmed)) {
    return 'Place name contains unsupported characters.';
  }

  return null;
}
