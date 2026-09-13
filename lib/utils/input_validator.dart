import 'package:safe_text/safe_text.dart';

class PasswordChecks {
  final bool hasMinimumLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialCharacter;
  final bool hasOnlyAllowedCharacters;

  const PasswordChecks({
    required this.hasMinimumLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialCharacter,
    required this.hasOnlyAllowedCharacters,
  });

  bool get isValid =>
      hasMinimumLength &&
          hasUppercase &&
          hasLowercase &&
          hasDigit &&
          hasSpecialCharacter &&
          hasOnlyAllowedCharacters;
}

/// One validation policy shared by registration, login, recovery and account
/// settings. Email addresses are validated as practical RFC 5322 dot-atoms;
/// quoted local parts are deliberately unsupported in this mobile UI.
class InputValidator {
  InputValidator._();

  static const String defaultDisplayName = 'Trekker';
  static const int maxEmailLength = 254;
  static const int maxEmailLocalPartLength = 64;
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int maxDisplayNameLength = 100;
  static const String allowedPasswordSpecialCharacters =
      r'!@#$%^&*()-_=+[]{};:,.?/';

  /// Characters that are invisible, directional, or unsafe in form input.
  /// This includes U+200E LEFT-TO-RIGHT MARK, zero-width characters, bidi
  /// overrides, soft hyphens, byte-order marks, and C0/C1 controls.
  static final RegExp disallowedInvisibleCharacters = RegExp(
    r'[\u0000-\u001F\u007F-\u009F\u00AD\u034F\u061C\u115F\u1160\u17B4\u17B5\u180B-\u180F\u200B-\u200F\u202A-\u202E\u2060-\u206F\u3164\uFEFF\uFFA0]',
  );

  static final RegExp _emailLocalSegment = RegExp(
    r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+$",
  );
  static final RegExp _gmailUsernamePart = RegExp(
    r'^[A-Za-z0-9]+(?:\.[A-Za-z0-9]+)*$',
  );
  static final RegExp _domainLabel = RegExp(r'^[A-Za-z0-9-]+$');
  static final RegExp _domainTopLevel = RegExp(
    r'^(?:[A-Za-z]{2,63}|xn--[A-Za-z0-9-]{2,59})$',
  );
  static const Set<String> _gmailDomains = {
    'gmail.com',
    'googlemail.com',
  };
  static const Set<String> _reservedGmailUsernames = {
    'abuse',
    'postmaster',
  };
  static bool _publicTextFilterInitialized = false;

  /// Warms the on-device profanity filter once. Validation also calls this
  /// defensively, so tests and secondary entry points remain safe.
  static void initializePublicTextFilter() {
    if (_publicTextFilterInitialized) return;
    SafeTextFilter.init(
      languages: const [
        Language.english,
        Language.malay,
        Language.chinese,
      ],
    );
    _publicTextFilterInitialized = true;
  }

  static String normalizeEmail(String value) {
    final trimmed = value.trim();
    final separator = trimmed.lastIndexOf('@');
    if (separator <= 0 || separator == trimmed.length - 1) {
      return trimmed;
    }
    final local = trimmed.substring(0, separator);
    final domain = trimmed.substring(separator + 1).toLowerCase();
    return '$local@$domain';
  }

  /// Returns a stable duplicate-detection key for a validated email address.
  /// Keep [normalizeEmail] for delivery and authentication; this value is for
  /// a separately stored, uniquely indexed identity key.
  static String canonicalizeEmailForIdentity(String value) {
    final email = normalizeEmail(value);
    final separator = email.lastIndexOf('@');
    if (separator <= 0 || separator == email.length - 1) return email;

    final local = email.substring(0, separator);
    final domain = email.substring(separator + 1).toLowerCase();
    if (!_gmailDomains.contains(domain)) return email.toLowerCase();

    final tagSeparator = local.indexOf('+');
    final gmailUsername = tagSeparator == -1
        ? local
        : local.substring(0, tagSeparator);
    final canonicalUsername = gmailUsername
        .replaceAll('.', '')
        .toLowerCase();
    return '$canonicalUsername@gmail.com';
  }

  static String? validateEmail(String value) {
    final email = normalizeEmail(value);
    if (email.isEmpty) return 'Email address is required.';
    if (email.length > maxEmailLength) {
      return 'Email address is too long.';
    }
    if (email.contains(RegExp(r'\s'))) {
      return 'Email address cannot contain spaces.';
    }

    final firstAt = email.indexOf('@');
    if (firstAt <= 0 ||
        firstAt != email.lastIndexOf('@') ||
        firstAt == email.length - 1) {
      return 'Enter a valid email address.';
    }

    final local = email.substring(0, firstAt);
    final domain = email.substring(firstAt + 1);
    if (local.length > maxEmailLocalPartLength ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..')) {
      return 'Enter a valid email address.';
    }
    if (local.split('.').any(
          (segment) => segment.isEmpty || !_emailLocalSegment.hasMatch(segment),
    )) {
      return 'Enter a valid email address.';
    }

    if (_gmailDomains.contains(domain)) {
      final tagSeparator = local.indexOf('+');
      final gmailUsername = tagSeparator == -1
          ? local
          : local.substring(0, tagSeparator);
      final gmailTag = tagSeparator == -1
          ? null
          : local.substring(tagSeparator + 1);

      if (!_gmailUsernamePart.hasMatch(gmailUsername)) {
        return 'Gmail usernames can use only letters, numbers, and single periods.';
      }
      if (gmailTag != null && !_gmailUsernamePart.hasMatch(gmailTag)) {
        return 'Gmail +tags must start and end with a letter or number. Single periods are allowed only between them.';
      }

      final usernameWithoutPeriods =
      gmailUsername.replaceAll('.', '').toLowerCase();
      if (_reservedGmailUsernames.contains(usernameWithoutPeriods)) {
        return 'This Gmail address is reserved and cannot be used.';
      }
    }

    if (domain.startsWith('.') ||
        domain.endsWith('.') ||
        domain.contains('..')) {
      return 'Enter a valid email address.';
    }
    final labels = domain.split('.');
    if (labels.length < 2 || !_domainTopLevel.hasMatch(labels.last)) {
      return 'Enter a valid email address.';
    }
    for (final label in labels) {
      if (label.isEmpty ||
          label.length > 63 ||
          label.startsWith('-') ||
          label.endsWith('-') ||
          !_domainLabel.hasMatch(label)) {
        return 'Enter a valid email address.';
      }
    }
    return null;
  }

  /// Login must accept passwords created under an earlier policy exactly as
  /// entered. It therefore checks only that a value was supplied.
  static String? validateLoginPassword(String value) {
    if (value.isEmpty || value.trim().isEmpty) {
      return 'Password is required.';
    }
    if (disallowedInvisibleCharacters.hasMatch(value)) {
      return 'Password contains unsupported invisible characters.';
    }
    return null;
  }

  static PasswordChecks checkNewPassword(String value) {
    return PasswordChecks(
      hasMinimumLength: value.length >= minPasswordLength &&
          value.length <= maxPasswordLength,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(value),
      hasLowercase: RegExp(r'[a-z]').hasMatch(value),
      hasDigit: RegExp(r'[0-9]').hasMatch(value),
      hasSpecialCharacter: value.codeUnits.any(
            (character) => allowedPasswordSpecialCharacters.contains(
          String.fromCharCode(character),
        ),
      ),
      hasOnlyAllowedCharacters: value.isNotEmpty &&
          value.codeUnits.every(_isAllowedPasswordCharacter),
    );
  }

  static String? validateNewPassword(String value) {
    if (value.isEmpty || value.trim().isEmpty) {
      return 'Password is required.';
    }
    if (value.length > maxPasswordLength) {
      return 'Password must be $maxPasswordLength characters or fewer.';
    }
    final checks = checkNewPassword(value);
    if (!checks.hasOnlyAllowedCharacters) {
      return 'Use only letters, numbers, and the allowed special characters shown below. Spaces are not allowed.';
    }
    if (!checks.isValid) {
      return 'Complete the password requirements shown below.';
    }
    return null;
  }

  static String normalizeDisplayName(String value) {
    return value
        .replaceAll(disallowedInvisibleCharacters, '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String displayNameOrDefault(String? value) {
    final normalized = normalizeDisplayName(value ?? '');
    return normalized.isEmpty ? defaultDisplayName : normalized;
  }

  /// Empty is valid and is stored as empty. Presentation layers display the
  /// friendly "Trekker" fallback without changing the user's saved field.
  static String? validateDisplayName(String value) {
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return null;
    if (name.length > maxDisplayNameLength) {
      return 'Full name must be $maxDisplayNameLength characters or fewer.';
    }
    if (disallowedInvisibleCharacters.hasMatch(name)) {
      return 'Full name contains unsupported characters.';
    }
    if (containsInappropriatePublicText(name)) {
      return 'Please enter an appropriate full name.';
    }
    return null;
  }

  /// Use only for public, user-visible text. Never apply this to passwords,
  /// email addresses, authentication codes, URLs, or private identifiers.
  static bool containsInappropriatePublicText(String value) {
    if (value.trim().isEmpty) return false;
    initializePublicTextFilter();
    return SafeTextFilter.containsBadWord(text: value);
  }

  static bool _isAllowedPasswordCharacter(int character) {
    final isUppercase = character >= 0x41 && character <= 0x5A;
    final isLowercase = character >= 0x61 && character <= 0x7A;
    final isDigit = character >= 0x30 && character <= 0x39;
    return isUppercase ||
        isLowercase ||
        isDigit ||
        allowedPasswordSpecialCharacters.contains(
          String.fromCharCode(character),
        );
  }
}
