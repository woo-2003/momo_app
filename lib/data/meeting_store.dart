import 'package:momo_app/domain/taxi_pod_meeting.dart';

/// 생성된 모임 임시 저장 (앱 메모리).
///
/// [롤백용 보관] 메인 지도·택시팟 생성은 MeetingRepository(서버)로 전환됨.
/// 이 클래스는 삭제하지 않는다. 로컬 전용으로 되돌릴 때 CreateTaxiPod / MainScreen
/// 주석 처리된 MeetingStore 호출을 복구하면 된다.
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
