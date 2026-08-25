import 'dart:io';

import '../entities/personal_constraint.dart';
import '../repository/i_user_repository.dart';

class InvalidImageFormatException implements Exception {
  const InvalidImageFormatException();
}

class ImageTooLargeException implements Exception {
  const ImageTooLargeException();
}

/// Profile business rules. Camera/gallery selection remains in the supplied
/// local-data-source classes; the selected [File] is passed into this service.
class ProfileService {
  final IUserRepository _userRepository;

  ProfileService(this._userRepository);

  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png'};

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String currency,
  }) {
    if (fullName.trim().isEmpty) {
      throw ArgumentError.value(fullName, 'fullName', 'Must not be empty.');
    }
    return _userRepository.updateProfile(
      userId: userId,
      fullName: fullName.trim(),
      currency: currency,
    );
  }

  Future<String> saveProfilePicture({
    required String userId,
    required File imageFile,
  }) async {
    final extension = imageFile.path.split('.').last.toLowerCase();
    if (await imageFile.length() > _maxImageBytes) {
      throw const ImageTooLargeException();
    }
    final header = await imageFile
        .openRead(0, 8)
        .expand((bytes) => bytes)
        .toList();
    if (!_allowedExtensions.contains(extension) || !_hasValidHeader(header)) {
      throw const InvalidImageFormatException();
    }
    return _userRepository.uploadAndSetProfilePicture(
      userId: userId,
      imageFile: imageFile,
    );
  }

  Future<List<PersonalConstraint>> getAllConstraints() {
    return _userRepository.getAllPersonalConstraints();
  }

  Future<List<PersonalConstraint>> getUserConstraints(String userId) {
    return _userRepository.getUserConstraints(userId);
  }

  Future<void> saveUserConstraints({
    required String userId,
    required List<String> constraintIds,
  }) {
    return _userRepository.replaceUserConstraints(
      userId: userId,
      constraintIds: constraintIds,
    );
  }

  bool _hasValidHeader(List<int> bytes) {
    final isJpeg = bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    final isPng = bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
    return isJpeg || isPng;
  }
}
