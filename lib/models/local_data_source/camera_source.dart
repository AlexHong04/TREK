import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';


class CameraSource {
  final ImagePicker _picker = ImagePicker();
  static const String _subDirectory = 'images';

  // open camera and take photo
  Future<String?> takePhoto({int imageQuality = 80}) async{
    final permission  = await Permission.camera.request();
    if(!permission.isGranted) return null;

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality:imageQuality,
    );

    if(photo == null) return null;

    return await _saveToPermanentStorage(photo.path);
  }

  // save the photo to permanent storage
  Future<String> _saveToPermanentStorage(String tempFilePath) async{
    final docsDir = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(tempFilePath)}';
    final permanentPath = path.join(docsDir.path, _subDirectory, fileName);

    final targetFolder = Directory(path.dirname(permanentPath));
    if(!await targetFolder.exists()) {
      await targetFolder.create(recursive: true);
    }

    final savedFile = await File(tempFilePath).copy(permanentPath);
    return savedFile.path;
  }

  // open gallery and pick photo
  Future<String?> pickPhotoFromGallery({int imageQuality = 80}) async {
    final status = await Permission.photos.request();
    if(!status.isGranted && !status.isLimited) {
      final storageStatus = await Permission.storage.request();
      if(!storageStatus.isGranted) return null;
    }
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
    );
    if(image == null) return null;
    return await _saveToPermanentStorage(image.path);

  }
}