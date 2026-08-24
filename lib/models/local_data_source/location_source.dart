import 'dart:developer' as developer;
import 'package:geolocator/geolocator.dart';

// TO USE THE LOCATION FETCHING
// SIMPLY IMPLEMENT THIS EXAMPLE INTO YOUR APPLICATION

// "
// final locationSource = LocationSource();
// final Position? position = await locationSource.getCurrentLocation();
//
// if (position != null) {
// // Use position.latitude and position.longitude
// } else {
// // User canceled, denied permission, or GPS remains disabled
// }
// "


class LocationSource {
  /// Fetches position and directs the user to turn on GPS if disabled
  Future<Position?> getCurrentLocation() async {
    // 1. Check if device-level GPS service is turned on
    bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationEnabled) {
      developer.log('[LOCATION_TEST] GPS is disabled on device.', name: 'LocationSource');
      // Direct the user to the native Android Location Settings screen
      await Geolocator.openLocationSettings();
      return null;
    }

    // 2. Handle app permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        developer.log('[LOCATION_TEST] Permission denied.', name: 'LocationSource');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      developer.log('[LOCATION_TEST] Permission denied forever.', name: 'LocationSource');
      await Geolocator.openAppSettings();
      return null;
    }

    // 3. Fetch position with Android accuracy settings
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      return position;
    } catch (e) {
      developer.log('[LOCATION_TEST] Error fetching position: $e', name: 'LocationSource');
      return null;
    }
  }

  double getDistanceBetweenLocations(Position location1, Position location2) {
    return Geolocator.distanceBetween(
      location1.latitude,
      location1.longitude,
      location2.latitude,
      location2.longitude,
    );
  }
}