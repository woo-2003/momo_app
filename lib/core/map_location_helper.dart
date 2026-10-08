import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/theme.dart';

/// 지도·택시팟 참여 공통: 위치 권한 + 현재 좌표로 카메라 이동.
class MapLocationHelper {
  const MapLocationHelper._();

  /// 이미 whileInUse / always 권한이 있는지 (다이얼로그·요청 없음).
  static Future<bool> hasPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// 위치 서비스·권한이 허용되면 true.
  /// denied 이면 시스템 권한 팝업을 띄운다. (앱 진입·내 위치 버튼용)
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

  /// 택시팟 「참여하기」 직전 위치 동의 게이트.
  ///
  /// - 이미 허용됨 → true (바로 join 가능)
  /// - 없음 → 앱 다이얼로그 → 허용 시 시스템 요청 / 취소 시 false (join 안 함)
  /// - 영구 거부·서비스 OFF → false + SnackBar (설정 유도)
  static Future<bool> ensurePermissionForJoin(BuildContext context) async {
    // 1) 이미 동의된 경우 — 추가 UI 없음
    if (await hasPermission()) {
      return true;
    }

    if (!context.mounted) return false;

    // 2) 위치 서비스(GPS) 자체가 꺼진 경우
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기기 위치 서비스를 켠 뒤 다시 시도해 주세요.')),
      );
      return false;
    }

    final permission = await Geolocator.checkPermission();

    // 3) 설정에서 영구 거부 — 시스템 팝업이 안 뜨므로 참여 불가
    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정에서 위치 권한을 허용해 주세요.')),
      );
      return false;
    }

    if (!context.mounted) return false;

    // 4) 사용자에게 참여용 위치 동의 확인
    final goRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: MomoColors.background,
          title: Text(
            '위치 권한',
            style: MomoTextStyles.heading.copyWith(fontSize: 18),
          ),
          content: Text(
            '택시팟에 참여하려면 위치 권한이 필요해요. 허용할까요?',
            style: MomoTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                '취소',
                style: MomoTextStyles.button.copyWith(
                  color: MomoColors.textSub,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                '허용',
                style: MomoTextStyles.button.copyWith(
                  color: MomoColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );

    // 취소 → 참여(가입) 진행하지 않음
    if (goRequest != true) {
      return false;
    }

    // 5) 시스템 권한 요청
    final after = await Geolocator.requestPermission();
    final granted =
        after == LocationPermission.always ||
        after == LocationPermission.whileInUse;

    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 권한이 없어 참여할 수 없어요.')),
      );
    }
    return granted;
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
  /// 지도가 이미 dispose 된 뒤(로그아웃 등)에는 false — 예외를 밖으로 안 던짐.
  static Future<bool> moveCameraToCurrent(
    GoogleMapController? controller, {
    double zoom = 16,
  }) async {
    if (controller == null) return false;

    final target = await currentLatLng();
    if (target == null) return false;

    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom),
        ),
      );
      return true;
    } on StateError {
      // GoogleMapController used after GoogleMap disposed
      return false;
    } catch (_) {
      return false;
    }
  }
}
