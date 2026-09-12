import 'package:flutter/foundation.dart';

import '../entities/user.dart';

enum ProfileImageSource { gallery, camera }

class PersonalConstraintOptionData {
  final String id;
  final String category;
  final String name;
  final bool isSelected;

  const PersonalConstraintOptionData({
    required this.id,
    required this.category,
    required this.name,
    required this.isSelected,
  });
}

abstract interface class IProfileService implements Listenable {
  User? get currentUser;

  String? get currentUserId;

  String get preferredCurrency;

  bool get isOffline;

  Future<void> refreshCurrentUser();

  Future<List<String>> getSupportedCurrencies();

  Future<double?> convertToPreferredCurrency({
    required double amount,
    required String fromCurrency,
  });

  /// Converts an amount stored in the signed-in tourist's preferred currency
  /// back to TREK's MYR base currency.
  Future<double?> convertPreferredCurrencyToMyr({
    required double amount,
  });

  Future<void> updateCurrentProfile({
    required String fullName,
    required String currency,
  });

  Future<String?> updateProfilePicture(ProfileImageSource source);

  Future<void> removeProfilePicture();

  Future<List<PersonalConstraintOptionData>> loadPersonalConstraintOptions();

  Future<void> savePersonalConstraints(List<String> constraintIds);
}

class ProfileImageTooLargeException implements Exception {
  const ProfileImageTooLargeException();
}

class ProfileInvalidImageFormatException implements Exception {
  const ProfileInvalidImageFormatException();
}

class InappropriateDisplayNameException implements Exception {
  const InappropriateDisplayNameException();
}
