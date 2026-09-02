import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 지도 핀으로 고른 장소. 역지오코딩 전까지 [label]은 사용자가 수정 가능.
class SelectedPlace {
  const SelectedPlace({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);

  SelectedPlace copyWith({
    String? label,
    double? latitude,
    double? longitude,
  }) {
    return SelectedPlace(
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
