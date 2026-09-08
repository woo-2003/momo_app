import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:momo_app/core/server_config.dart';
import 'package:momo_app/domain/meeting_repository.dart';

/// 친구 GPS 프로토콜 HTTP. JWT 필요. userId는 서버가 토큰에서 읽는다.
class MeetingLocationService {
  MeetingLocationService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? ServerConfig.baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 10);

  Future<void> postLocation({
    required String token,
    required String meetingId,
    required double prevLat,
    required double prevLon,
    required double prevTime,
    required double currLat,
    required double currLon,
    required double currTime,
  }) async {
    final decoded = await _send(
      token: token,
      method: 'POST',
      path: '/meeting/location',
      body: {
        'meetingId': meetingId,
        'prev_lat': prevLat,
        'prev_lon': prevLon,
        'prev_time': prevTime,
        'curr_lat': currLat,
        'curr_lon': currLon,
        'curr_time': currTime,
      },
      successStatus: 200,
    );

    if (decoded['result'] != 'success') {
      throw MeetingException(
        code: 'server',
        message: decoded['detail']?.toString() ?? '위치 전송에 실패했습니다.',
      );
    }
  }

  Future<List<MeetingMemberGps>> getMembers({
    required String token,
    required String meetingId,
  }) async {
    try {
      final decoded = await _send(
        token: token,
        method: 'GET',
        path: '/meeting/$meetingId/members',
        successStatus: 200,
      );

      final raw = decoded['members'];
      if (raw is! Map) return const [];

      return raw.entries.map((entry) {
        final value = entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : <String, dynamic>{};
        return MeetingMemberGps(
          meetingId: meetingId,
          userId: entry.key.toString(),
          status: value['status']?.toString() ?? 'STATIONARY',
          latitude: (value['curr_lat'] as num?)?.toDouble() ?? 0,
          longitude: (value['curr_lon'] as num?)?.toDouble() ?? 0,
          distanceToDest: (value['distance_to_dest'] as num?)?.toDouble() ?? 0,
          speed: (value['speed'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
    } on MeetingException catch (e) {
      if (e.code == 'not-found') return const [];
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _send({
    required String token,
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required int successStatus,
  }) async {
    try {
      final target = Uri.parse('$_baseUrl$path');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final http.Response response;
      if (method == 'GET') {
        response = await _client.get(target, headers: headers).timeout(_timeout);
      } else {
        response = await _client
            .post(
              target,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(_timeout);
      }

      final decoded = _decode(response.body);
      if (response.statusCode == successStatus) return decoded;

      final detail =
          decoded['detail']?.toString() ??
          decoded['message']?.toString() ??
          '';
      throw MeetingException(
        code: _code(response.statusCode, detail),
        message: detail.isNotEmpty ? detail : '위치 요청에 실패했습니다.',
      );
    } on MeetingException {
      rethrow;
    } on SocketException catch (_) {
      throw const MeetingException(
        code: 'network',
        message: '네트워크 오류입니다. 연결을 확인해 주세요.',
      );
    } on TimeoutException catch (_) {
      throw const MeetingException(
        code: 'network',
        message: '네트워크 오류입니다. 연결을 확인해 주세요.',
      );
    } on http.ClientException catch (_) {
      throw const MeetingException(
        code: 'network',
        message: '네트워크 오류입니다. 연결을 확인해 주세요.',
      );
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _code(int statusCode, String detail) {
    if (statusCode == 401) return 'unauthorized';
    if (statusCode == 403) return 'not-participant';
    if (statusCode == 404) return 'not-found';
    if (statusCode == 400) return 'validation';
    return 'server';
  }
}

class MeetingMemberGps {
  final String meetingId;
  final String userId;
  final String status;
  final double latitude;
  final double longitude;
  final double distanceToDest;
  final double speed;

  const MeetingMemberGps({
    required this.meetingId,
    required this.userId,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.distanceToDest,
    required this.speed,
  });
}
