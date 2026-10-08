/// 모임·채팅 도메인 모델 및 Repository 인터페이스.
library;

enum MeetingCategory { taxi, sports, game }

enum MeetingMode { offline, online }

class MeetingMember {
  final String userId;
  final String nickname;
  final String role;

  const MeetingMember({
    required this.userId,
    required this.nickname,
    required this.role,
  });
}

class MeetingSummary {
  final String meetingId;
  final MeetingCategory category;
  final MeetingMode meetingMode;
  final String status;
  final String title;
  final DateTime startAt;
  final int currentMembers;
  final int maxMembers;
  final String? placeName;
  final double? latitude;
  final double? longitude;

  /// 택시 등 categoryFields.destinationName (목록 API 확장 예정 / 상세에서 채움)
  final String? destinationName;

  /// 택시 categoryFields.departPlaceName
  final String? departPlaceName;

  /// sports.categoryFields.sportType (목록에 없으면 상세 enrichment)
  final String? sportType;

  /// game.categoryFields.gameName
  final String? gameName;

  const MeetingSummary({
    required this.meetingId,
    required this.category,
    required this.meetingMode,
    required this.status,
    required this.title,
    required this.startAt,
    required this.currentMembers,
    required this.maxMembers,
    this.placeName,
    this.latitude,
    this.longitude,
    this.destinationName,
    this.departPlaceName,
    this.sportType,
    this.gameName,
  });

  /// 마커 말풍용: `출발 → 도착` 또는 집결명만.
  String get markerRouteLabel {
    final from = (departPlaceName ?? placeName ?? title).trim();
    final to = destinationName?.trim();
    if (to != null && to.isNotEmpty) {
      return '$from → $to';
    }
    return from;
  }
}

class MeetingDetail extends MeetingSummary {
  final String description;
  final Map<String, dynamic> categoryFields;
  final String creatorId;
  final bool isHost;
  final bool isMember;
  final List<MeetingMember> members;

  const MeetingDetail({
    required super.meetingId,
    required super.category,
    required super.meetingMode,
    required super.status,
    required super.title,
    required super.startAt,
    required super.currentMembers,
    required super.maxMembers,
    super.placeName,
    super.latitude,
    super.longitude,
    super.destinationName,
    super.departPlaceName,
    super.sportType,
    super.gameName,
    required this.description,
    required this.categoryFields,
    required this.creatorId,
    required this.isHost,
    required this.isMember,
    required this.members,
  });
}

class ChatMessage {
  final String messageId;
  final String senderId;
  final String nickname;
  final String body;
  final DateTime createdAt;

  const ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.nickname,
    required this.body,
    required this.createdAt,
  });
}

class CreateMeetingInput {
  final String title;
  final MeetingCategory category;
  final MeetingMode? meetingMode;
  final String? description;
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final DateTime startAt;
  final int maxMembers;
  final Map<String, dynamic> categoryFields;

  const CreateMeetingInput({
    required this.title,
    required this.category,
    this.meetingMode,
    this.description,
    this.placeName,
    this.latitude,
    this.longitude,
    required this.startAt,
    required this.maxMembers,
    required this.categoryFields,
  });
}

class MeetingException implements Exception {
  final String code;
  final String message;

  const MeetingException({required this.code, required this.message});

  @override
  String toString() => 'MeetingException($code): $message';
}

abstract class MeetingRepository {
  Future<String> createMeeting(CreateMeetingInput input);

  Future<List<MeetingSummary>> listMeetings({
    MeetingCategory? category,
    MeetingMode? meetingMode,
  });

  Future<MeetingDetail> getMeeting(String meetingId);

  Future<void> cancelMeeting(String meetingId);

  Future<void> expireMeeting(String meetingId);

  Future<void> finishMeeting(String meetingId);

  Future<void> joinMeeting(String meetingId);

  Future<void> leaveMeeting(String meetingId);

  Future<List<ChatMessage>> getMessages(String meetingId);

  Stream<ChatMessage> watchChatMessages(String meetingId);

  Future<void> connectChat();

  Future<void> joinChatRoom(String meetingId);

  Future<void> leaveChatRoom(String meetingId);

  Future<void> sendChatMessage({
    required String meetingId,
    required String body,
  });

  Future<void> disconnectChat();
}

String meetingCategoryLabel(MeetingCategory category) {
  switch (category) {
    case MeetingCategory.taxi:
      return '택시';
    case MeetingCategory.sports:
      return '운동';
    case MeetingCategory.game:
      return '게임';
  }
}

String? meetingCategoryFieldText(Map<String, dynamic> fields, String key) {
  final value = fields[key];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// 상세 화면에 보여줄 카테고리 전용 줄 (게임 이름, 도착지, 종목).
List<String> meetingCategoryDetailLines(MeetingDetail detail) {
  final fields = detail.categoryFields;
  switch (detail.category) {
    case MeetingCategory.game:
      final gameName = meetingCategoryFieldText(fields, 'gameName');
      final platform = meetingCategoryFieldText(fields, 'platformNote');
      return [
        if (gameName != null) '게임: $gameName',
        if (platform != null) '플랫폼: $platform',
      ];
    case MeetingCategory.taxi:
      final destination = meetingCategoryFieldText(fields, 'destinationName');
      final depart = meetingCategoryFieldText(fields, 'departPlaceName');
      return [
        if (destination != null) '도착지: $destination',
        if (depart != null) '탑승: $depart',
      ];
    case MeetingCategory.sports:
      final sportType = meetingCategoryFieldText(fields, 'sportType');
      return [
        if (sportType != null) '종목: $sportType',
      ];
  }
}
