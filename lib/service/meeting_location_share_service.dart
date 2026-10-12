import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/service/meeting_location_service.dart';

/// 개설/가입한 모임의 GPS를 주기적으로 올리고, 멤버 위치를 지도용으로 모아 둔다.
class MeetingLocationShareService {
  MeetingLocationShareService._({
    MeetingLocationService? locationService,
    SessionStore? sessionStore,
  }) : _locationService = locationService ?? MeetingLocationService(),
       _sessionStore = sessionStore ?? SessionStore();

  static final MeetingLocationShareService instance =
      MeetingLocationShareService._();

  final MeetingLocationService _locationService;
  final SessionStore _sessionStore;
  final Set<String> _meetingIds = {};
  final Set<String> _disabledMeetingIds = {};
  final _membersController =
      StreamController<List<MeetingMemberGps>>.broadcast();

  StreamSubscription<Position>? _positionSub;
  Position? _previous;
  double? _previousTime;
  List<MeetingMemberGps> _latest = const [];

  Stream<List<MeetingMemberGps>> get members => _membersController.stream;

  List<MeetingMemberGps> get currentMembers => _latest;

  Future<void> startSharing(String meetingId) async {
    final id = meetingId.trim();
    if (id.isEmpty || _disabledMeetingIds.contains(id)) return;

    _meetingIds.add(id);
    final granted = await _ensurePermission();
    if (!granted) {
      _meetingIds.remove(id);
      return;
    }
    _ensureStream();
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _onPosition(current);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[GPS] initial position failed: $error');
      }
    }
  }

  void stopSharing(String meetingId) {
    _meetingIds.remove(meetingId.trim());
    if (_meetingIds.isEmpty) {
      _stopStream();
      _latest = const [];
      _membersController.add(_latest);
    }
  }

  void stopAll() {
    _meetingIds.clear();
    _stopStream();
    _previous = null;
    _previousTime = null;
    _latest = const [];
    _membersController.add(_latest);
  }

  void _ensureStream() {
    if (_positionSub != null) return;
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _backgroundSettings(),
    ).listen(
      _onPosition,
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('[GPS] stream failed: $error');
        }
      },
    );
  }

  void _stopStream() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// 포그라운드 알림(Android)과 백그라운드 위치(iOS)로
  /// 앱이 화면 뒤에 있어도 모임 위치를 계속 보낸다.
  LocationSettings _backgroundSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 8),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'momo 위치 공유',
          notificationText: '참여 중인 모임에 위치를 보내고 있어요.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 8,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    );
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<String?> _token() async {
    final session = await _sessionStore.read();
    if (session == null ||
        session.accessTokenExpiresAt.isBefore(DateTime.now().toUtc())) {
      return null;
    }
    return session.accessToken;
  }

  Future<void> _onPosition(Position current) async {
    if (_meetingIds.isEmpty) return;

    final token = await _token();
    if (token == null) {
      stopAll();
      return;
    }

    if (!await _ensurePermission()) return;

    final previous = _previous ?? current;
    final now = DateTime.now();
    final currTime = _epochSeconds(now);
    final prevTime = _previousTime ?? currTime;

    final ids = List<String>.from(_meetingIds);
    for (final meetingId in ids) {
      try {
        await _locationService.postLocation(
          token: token,
          meetingId: meetingId,
          prevLat: previous.latitude,
          prevLon: previous.longitude,
          prevTime: prevTime,
          currLat: current.latitude,
          currLon: current.longitude,
          currTime: currTime,
        );
      } on MeetingException catch (error) {
        if (kDebugMode) {
          debugPrint('[GPS] post $meetingId failed: ${error.message}');
        }
        if (error.code == 'validation' || error.code == 'not-participant') {
          _meetingIds.remove(meetingId);
          _disabledMeetingIds.add(meetingId);
        }
        if (error.code == 'unauthorized') {
          stopAll();
          return;
        }
      }
    }

    _previous = current;
    _previousTime = currTime;
    await _refreshMembers(token);
  }

  Future<void> _refreshMembers(String token) async {
    final collected = <MeetingMemberGps>[];
    for (final meetingId in List<String>.from(_meetingIds)) {
      try {
        final items = await _locationService.getMembers(
          token: token,
          meetingId: meetingId,
        );
        collected.addAll(items);
      } on MeetingException catch (error) {
        if (error.code == 'unauthorized') {
          stopAll();
          return;
        }
        if (error.code == 'not-participant') {
          _meetingIds.remove(meetingId);
        }
      }
    }

    _latest = collected;
    if (!_membersController.isClosed) {
      _membersController.add(_latest);
    }
  }

  double _epochSeconds(DateTime value) {
    return value.millisecondsSinceEpoch / 1000.0;
  }
}
