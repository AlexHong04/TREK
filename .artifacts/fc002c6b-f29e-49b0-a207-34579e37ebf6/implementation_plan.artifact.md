# Fix Build Errors and Update Permissions

The current build failure is caused by an incompatibility between the Flutter SDK (v3.44.9) and older versions of the `permission_handler` plugin. Specifically, the plugin is referencing the `PluginRegistry.Registrar` class, which has been removed in newer Flutter versions in favor of the V2 embedding.

## User Review Required

> [!IMPORTANT]
> I will be upgrading several dependencies to their latest stable versions to ensure compatibility with your current Flutter SDK. This may include `permission_handler`, `image_picker`, and potentially others if conflicts arise.

## Proposed Changes

### [Core] Dependency Updates

#### [MODIFY] [pubspec.yaml](file:///C:/Users/cwson/StudioProjects/TREK/pubspec.yaml)
- Upgrade `permission_handler` to `^13.0.1`.
- Upgrade `image_picker` to `^1.2.3`.
- (Optional but recommended) Upgrade `path_provider` to `^2.1.4`.

### [Android] Gradle Configuration

#### [MODIFY] [gradle.properties](file:///C:/Users/cwson/StudioProjects/TREK/android/gradle.properties)
- Set `android.builtInKotlin=true` (if applicable for the new Flutter Gradle Plugin).
- Ensure `android.useAndroidX=true`.

## Verification Plan

### Automated Tests
- Run `flutter pub get` to verify dependency resolution.
- Run `flutter build apk --debug` (or `flutter run`) to verify that the compilation error is resolved.

### Manual Verification
- Test the camera functionality in the app to ensure `image_picker` and `permission_handler` are working correctly with the new versions.
