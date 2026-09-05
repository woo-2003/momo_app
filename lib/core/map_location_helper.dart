import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 지도 공통: 위치 권한 + 현재 좌표로 카메라 이동.
class MapLocationHelper {
  const MapLocationHelper._();

  /// 위치 서비스·권한이 허용되면 true.
  static Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// 현재 GPS 좌표. 실패 시 null.
  static Future<LatLng?> currentLatLng() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// 카메라를 현재 위치로 이동. 성공 시 true.
  static Future<bool> moveCameraToCurrent(
    GoogleMapController? controller, {
    double zoom = 16,
  }) async {
    if (controller == null) return false;

    final target = await currentLatLng();
    if (target == null) return false;

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ),
    );
    return true;
  }
}
