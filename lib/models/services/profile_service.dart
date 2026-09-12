import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../utils/input_validator.dart';
import '../../utils/network_error.dart';
import '../entities/user.dart';
import '../local_data_source/camera_source.dart';
import '../local_data_source/gallery_source.dart';
import '../repository/i_user_repository.dart';
import 'i_auth_service.dart';
import 'i_profile_service.dart';

class InvalidImageFormatException implements Exception {
  const InvalidImageFormatException();
}

class ImageTooLargeException implements Exception {
  const ImageTooLargeException();
}

class ProfileService extends ChangeNotifier implements IProfileService {
  final IUserRepository _userRepository;
  final IAuthService _authService;
  final CameraSource _cameraSource;
  final GallerySource _gallerySource;
  final ImageCropper _imageCropper;
  bool _disposed = false;

  ProfileService(
      this._userRepository,
      this._authService, {
        CameraSource? cameraSource,
        GallerySource? gallerySource,
        ImageCropper? imageCropper,
      })  : _cameraSource = cameraSource ?? CameraSource(),
        _gallerySource = gallerySource ?? GallerySource(),
        _imageCropper = imageCropper ?? ImageCropper() {
    _authService.addListener(_forwardAuthChange);
  }

  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png'};

  @override
  User? get currentUser => _authService.currentUser;

  @override
  String? get currentUserId => _authService.currentUserId;

  @override
  String get preferredCurrency {
    final currency = currentUser?.currency.trim().toUpperCase();
    return currency == null || currency.isEmpty ? 'MYR' : currency;
  }

  @override
  bool get isOffline => _authService.isOffline;

  @override
  Future<void> refreshCurrentUser() => _authService.refreshCurrentUser();

  @override
  Future<List<String>> getSupportedCurrencies() {
    return _userRepository.getSupportedCurrencies();
  }

  @override
  Future<double?> convertToPreferredCurrency({
    required double amount,
    required String fromCurrency,
  }) {
    if (currentUser == null) throw StateError('No signed-in tourist.');
    return _userRepository.convertCurrency(
      amount: amount,
      fromCurrency: fromCurrency,
      toCurrency: preferredCurrency,
    );
  }

  @override
  Future<double?> convertPreferredCurrencyToMyr({
    required double amount,
  }) {
    if (currentUser == null) throw StateError('No signed-in tourist.');
    return _userRepository.convertCurrency(
      amount: amount,
      fromCurrency: preferredCurrency,
      toCurrency: 'MYR',
    );
  }

  @override
  Future<void> updateCurrentProfile({
    required String fullName,
    required String currency,
  }) async {
    _requireOnlineWrite();
    final userId = currentUserId;
    if (userId == null) throw StateError('No signed-in tourist.');
    if (InputValidator.validateDisplayName(fullName) != null) {
      throw const InappropriateDisplayNameException();
    }
    await _userRepository.updateProfile(
      userId: userId,
      fullName: InputValidator.normalizeDisplayName(fullName),
      currency: currency,
    );
    await refreshCurrentUser();
  }

  @override
  Future<String?> updateProfilePicture(ProfileImageSource source) async {
    _requireOnlineWrite();
    final userId = currentUserId;
    if (userId == null) throw StateError('No signed-in tourist.');
    try {
      final selectedPath = source == ProfileImageSource.gallery
          ? await _gallerySource.pickPhoto()
          : await _cameraSource.takePhoto();
      if (selectedPath == null) return null;
      final cropped = await _cropProfilePicture(selectedPath);
      if (cropped == null) return null;
      final url = await _saveProfilePicture(
        userId: userId,
        imageFile: File(cropped.path),
      );
      await refreshCurrentUser();
      return url;
    } on ImageTooLargeException {
      throw const ProfileImageTooLargeException();
    } on InvalidImageFormatException {
      throw const ProfileInvalidImageFormatException();
    }
  }

  @override
  Future<void> removeProfilePicture() async {
    _requireOnlineWrite();
    final userId = currentUserId;
    if (userId == null) throw StateError('No signed-in tourist.');
    await _userRepository.removeProfilePicture(userId: userId);
    await refreshCurrentUser();
  }

  @override
  Future<List<PersonalConstraintOptionData>>
  loadPersonalConstraintOptions() async {
    final userId = currentUserId;
    if (userId == null) throw StateError('No signed-in tourist.');
    final results = await Future.wait([
      _userRepository.getAllPersonalConstraints(),
      _userRepository.getUserConstraints(userId),
    ]);
    final selectedIds =
    results[1].map((constraint) => constraint.constraintId).toSet();
    return results[0]
        .map(
          (constraint) => PersonalConstraintOptionData(
        id: constraint.constraintId,
        category: constraint.category,
        name: constraint.constraintName,
        isSelected: selectedIds.contains(constraint.constraintId),
      ),
    )
        .toList(growable: false);
  }

  @override
  Future<void> savePersonalConstraints(List<String> constraintIds) async {
    _requireOnlineWrite();
    final userId = currentUserId;
    if (userId == null) throw StateError('No signed-in tourist.');
    await _userRepository.replaceUserConstraints(
      userId: userId,
      constraintIds: constraintIds,
    );
    await refreshCurrentUser();
  }

  Future<CroppedFile?> _cropProfilePicture(String sourcePath) {
    return _imageCropper.cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 1024,
      maxHeight: 1024,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop profile picture',
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop profile picture',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          doneButtonTitle: 'Use',
          cancelButtonTitle: 'Cancel',
        ),
      ],
    );
  }

  Future<String> _saveProfilePicture({
    required String userId,
    required File imageFile,
  }) async {
    final extension = imageFile.path.split('.').last.toLowerCase();
    if (await imageFile.length() > _maxImageBytes) {
      throw const ImageTooLargeException();
    }
    final header = await imageFile.openRead(0, 8).expand((bytes) => bytes).toList();
    if (!_allowedExtensions.contains(extension) || !_hasValidHeader(header)) {
      throw const InvalidImageFormatException();
    }
    return _userRepository.uploadAndSetProfilePicture(
      userId: userId,
      imageFile: imageFile,
    );
  }

  void _requireOnlineWrite() {
    if (isOffline) throw const NetworkUnavailableException();
    if (_authService.requiresEmailVerification) {
      throw StateError('Email verification is required.');
    }
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

  void _forwardAuthChange() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authService.removeListener(_forwardAuthChange);
    super.dispose();
  }
}