import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:momo_app/domain/selected_place.dart';

/// 예약형 택시팟 (로컬·BE 연동 전). 참여·AI 집결지는 후속 기획.
class TaxiPodMeeting {
  TaxiPodMeeting({
    required this.id,
    required this.title,
    required this.departure,
    required this.destination,
    this.preMeeting,
    required this.capacity,
    required this.departureTime,
  });

  final String id;
  final String title;
  final SelectedPlace departure;
  final SelectedPlace destination;

  /// 있으면 집결·마커 위치는 여기 (출발지 대체).
  final SelectedPlace? preMeeting;
  final int capacity;
  final DateTime departureTime;

  /// 지도 마커·모임 핀 좌표.
  SelectedPlace get meetingPoint => preMeeting ?? departure;

  LatLng get markerPosition => meetingPoint.latLng;
}
