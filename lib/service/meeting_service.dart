import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:momo_app/core/server_config.dart';
import 'package:momo_app/domain/meeting_repository.dart';

class MeetingService {
  MeetingService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? ServerConfig.baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 10);

  Future<Map<String, dynamic>> createMeeting({
    required String token,
    required CreateMeetingInput input,
  }) {
    return _authorizedJson(
      token: token,
      method: 'POST',
      path: '/meetings',
      body: _encodeCreateBody(input),
      successStatus: 201,
    );
  }

  Future<List<MeetingSummary>> listMeetings({
    required String token,
    MeetingCategory? category,
    MeetingMode? meetingMode,
  }) async {
    final query = <String, String>{};
    if (category != null) {
      query['category'] = _categoryValue(category);
    }
    if (meetingMode != null) {
      query['meetingMode'] = _modeValue(meetingMode);
    }

    final uri = Uri.parse('$_baseUrl/meetings').replace(queryParameters: query);
    final decoded = await _authorizedJson(
      token: token,
      method: 'GET',
      uri: uri,
    );

    final items = decoded['items'];
    if (items is! List) return const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(_mapMeetingSummary)
        .toList();
  }

  Future<List<MeetingSummary>> listMyMeetings({required String token}) async {
    final decoded = await _authorizedJson(
      token: token,
      method: 'GET',
      path: '/meetings/mine',
    );

    final items = decoded['items'];
    if (items is! List) return const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(_mapMeetingSummary)
        .toList();
  }

  Future<MeetingDetail> getMeeting({
    required String token,
    required String meetingId,
  }) async {
    final decoded = await _authorizedJson(
      token: token,
      method: 'GET',
      path: '/meetings/$meetingId',
    );
    return _mapMeetingDetail(decoded);
  }

  Future<void> cancelMeeting({
    required String token,
    required String meetingId,
  }) async {
    await _authorizedJson(
      token: token,
      method: 'POST',
      path: '/meetings/$meetingId/cancel',
    );
  }

  Future<void> expireMeeting({
    required String token,
    required String meetingId,
  }) async {
    await _authorizedJson(
      token: token,
      method: 'POST',
      path: '/meetings/$meetingId/expire',
    );
  }

  Future<void> finishMeeting({
    required String token,
    required String meetingId,
  }) async {
    await _authorizedJson(
      token: token,
      method: 'POST',
      path: '/meetings/$meetingId/finish',
    );
  }

  Future<void> joinMeeting({
    required String token,
    required String meetingId,
  }) async {
    await _authorizedJson(
      token: token,
      method: 'POST',
      path: '/meetings/$meetingId/join',
    );
  }

  Future<void> leaveMeeting({
    required String token,
    required String meetingId,
  }) async {
    await _authorizedJson(
      token: token,
      method: 'POST',
      path: '/meetings/$meetingId/leave',
    );
  }

  Future<List<ChatMessage>> getMessages({
    required String token,
    required String meetingId,
  }) async {
    final decoded = await _authorizedJson(
      token: token,
      method: 'GET',
      path: '/meetings/$meetingId/messages',
    );

    final items = decoded['items'];
    if (items is! List) return const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(_mapChatMessage)
        .toList();
  }

  Future<Map<String, dynamic>> _authorizedJson({
    required String token,
    required String method,
    String? path,
    Uri? uri,
    Map<String, dynamic>? body,
    int successStatus = 200,
  }) async {
    try {
      final target = uri ?? Uri.parse('$_baseUrl$path');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final http.Response response;
      switch (method) {
        case 'GET':
          response = await _client
              .get(target, headers: headers)
              .timeout(_timeout);
          break;
        case 'POST':
          response = await _client
              .post(
                target,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(_timeout);
          break;
        default:
          throw const MeetingException(
            code: 'server',
            message: '지원하지 않는 HTTP 메서드입니다.',
          );
      }

      final decoded = _decodeResponse(response.body);
      final message = decoded['message']?.toString() ?? '';

      if (response.statusCode == successStatus && decoded['success'] == true) {
        return decoded;
      }

      throw MeetingException(
        code: _mapErrorCode(response.statusCode, message),
        message: _userMessage(response.statusCode, message),
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
    }
  }

  Map<String, dynamic> _encodeCreateBody(CreateMeetingInput input) {
    final body = <String, dynamic>{
      'title': input.title,
      'category': _categoryValue(input.category),
      'startAt': input.startAt.toUtc().toIso8601String(),
      'maxMembers': input.maxMembers,
      'categoryFields': input.categoryFields,
    };

    if (input.description != null && input.description!.trim().isNotEmpty) {
      body['description'] = input.description!.trim();
    }

    final mode = input.meetingMode ?? _defaultMode(input.category);
    body['meetingMode'] = _modeValue(mode);

    if (mode == MeetingMode.offline) {
      body['placeName'] = input.placeName;
      body['latitude'] = input.latitude;
      body['longitude'] = input.longitude;
    }

    return body;
  }

  MeetingMode _defaultMode(MeetingCategory category) {
    if (category == MeetingCategory.game) return MeetingMode.online;
    return MeetingMode.offline;
  }

  MeetingSummary _mapMeetingSummary(Map<String, dynamic> json) {
    final fields = _asStringKeyedMap(json['categoryFields']);
    return MeetingSummary(
      meetingId: json['meetingId']?.toString() ?? '',
      category: _parseCategory(json['category']?.toString()),
      meetingMode: _parseMode(json['meetingMode']?.toString()),
      status: json['status']?.toString() ?? 'open',
      title: json['title']?.toString() ?? '',
      startAt: DateTime.parse(json['startAt']?.toString() ?? ''),
      currentMembers: (json['currentMembers'] as num?)?.toInt() ?? 0,
      maxMembers: (json['maxMembers'] as num?)?.toInt() ?? 0,
      placeName: json['placeName']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      // 목록에 categoryFields가 오면 바로 사용 (동준 확장 후).
      destinationName: _nonEmptyString(fields['destinationName']),
      departPlaceName: _nonEmptyString(fields['departPlaceName']),
      sportType: _nonEmptyString(fields['sportType']),
      gameName: _nonEmptyString(fields['gameName']),
    );
  }

  MeetingDetail _mapMeetingDetail(Map<String, dynamic> json) {
    final membersRaw = json['members'];
    final members = membersRaw is List
        ? membersRaw
              .whereType<Map<String, dynamic>>()
              .map(
                (member) => MeetingMember(
                  userId: member['userId']?.toString() ?? '',
                  nickname: member['nickname']?.toString() ?? '',
                  role: member['role']?.toString() ?? 'member',
                ),
              )
              .toList()
        : <MeetingMember>[];

    final categoryFields = _asStringMap(json['categoryFields']);
    return MeetingDetail(
      meetingId: json['meetingId']?.toString() ?? '',
      category: _parseCategory(json['category']?.toString()),
      meetingMode: _parseMode(json['meetingMode']?.toString()),
      status: json['status']?.toString() ?? 'open',
      title: json['title']?.toString() ?? '',
      startAt: DateTime.parse(json['startAt']?.toString() ?? ''),
      currentMembers: (json['currentMembers'] as num?)?.toInt() ?? 0,
      maxMembers: (json['maxMembers'] as num?)?.toInt() ?? 0,
      placeName: json['placeName']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      destinationName: _nonEmptyString(categoryFields['destinationName']),
      departPlaceName: _nonEmptyString(categoryFields['departPlaceName']),
      sportType: _nonEmptyString(categoryFields['sportType']),
      gameName: _nonEmptyString(categoryFields['gameName']),
      description: json['description']?.toString() ?? '',
      categoryFields: categoryFields,
      creatorId: json['creatorId']?.toString() ?? '',
      isHost: json['isHost'] == true,
      isMember: json['isMember'] == true,
      members: members,
    );
  }

  Map<String, dynamic> _asStringKeyedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  String? _nonEmptyString(dynamic raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  ChatMessage _mapChatMessage(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['messageId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.parse(json['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _decodeResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _categoryValue(MeetingCategory category) {
    switch (category) {
      case MeetingCategory.taxi:
        return 'taxi';
      case MeetingCategory.sports:
        return 'sports';
      case MeetingCategory.game:
        return 'game';
    }
  }

  String _modeValue(MeetingMode mode) {
    switch (mode) {
      case MeetingMode.offline:
        return 'offline';
      case MeetingMode.online:
        return 'online';
    }
  }

  MeetingCategory _parseCategory(String? value) {
    switch (value) {
      case 'taxi':
        return MeetingCategory.taxi;
      case 'sports':
        return MeetingCategory.sports;
      case 'game':
      default:
        return MeetingCategory.game;
    }
  }

  MeetingMode _parseMode(String? value) {
    switch (value) {
      case 'offline':
        return MeetingMode.offline;
      case 'online':
      default:
        return MeetingMode.online;
    }
  }

  String _mapErrorCode(int statusCode, String message) {
    if (statusCode == 401) return 'unauthorized';
    if (statusCode == 403) return message.isNotEmpty ? message : 'forbidden';
    if (statusCode == 404) return 'not-found';
    if (statusCode == 409) return message.isNotEmpty ? message : 'conflict';
    if (statusCode == 400) return 'validation';
    if (statusCode == 0) return 'network';
    return 'server';
  }

  String _userMessage(int statusCode, String message) {
    if (message.isNotEmpty) return message;
    if (statusCode == 401) return '로그인이 필요합니다.';
    if (statusCode == 403) return '권한이 없습니다.';
    if (statusCode == 404) return '모임을 찾을 수 없습니다.';
    return '요청에 실패했습니다.';
  }
}
