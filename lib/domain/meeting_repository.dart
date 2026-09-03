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
  });
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
