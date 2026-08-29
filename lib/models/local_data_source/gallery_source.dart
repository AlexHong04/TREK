import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class GallerySource {
  final ImagePicker _picker;

  GallerySource({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const String _subDirectory = 'images/gallery';

  Future<String?> pickPhoto({int imageQuality = 80}) async {
    // Android's modern system photo picker is permissionless. iOS still uses
    // Photos permission and may return limited access, which is sufficient.
    if (Platform.isIOS || Platform.isMacOS) {
      final permission = await Permission.photos.request();
      if (!permission.isGranted && !permission.isLimited) return null;
    }

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
      maxWidth: 1440,
    );
    if (image == null) return null;
    return _saveToPermanentStorage(image.path);
  }

  Future<String> _saveToPermanentStorage(String temporaryPath) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${path.basename(temporaryPath)}';
    final targetPath = path.join(
      documentsDirectory.path,
      _subDirectory,
      fileName,
    );
    final targetFolder = Directory(path.dirname(targetPath));
    if (!await targetFolder.exists()) {
      await targetFolder.create(recursive: true);
    }
    return (await File(temporaryPath).copy(targetPath)).path;
  }
}
