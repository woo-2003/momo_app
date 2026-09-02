import 'package:momo_app/domain/taxi_pod_meeting.dart';

/// 생성된 모임 임시 저장 (앱 메모리). BE 연동 시 교체.
class MeetingStore {
  MeetingStore._();

  static final MeetingStore instance = MeetingStore._();

  final List<TaxiPodMeeting> _taxiPods = [];

  List<TaxiPodMeeting> get taxiPods => List.unmodifiable(_taxiPods);

  void addTaxiPod(TaxiPodMeeting meeting) {
    _taxiPods.add(meeting);
  }

  void clear() {
    _taxiPods.clear();
  }
}
