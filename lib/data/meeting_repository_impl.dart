import 'dart:async';

import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/service/chat_socket_service.dart';
import 'package:momo_app/service/meeting_location_share_service.dart';
import 'package:momo_app/service/meeting_service.dart';

class MeetingRepositoryImpl implements MeetingRepository {
  MeetingRepositoryImpl({
    MeetingService? meetingService,
    ChatSocketService? chatSocketService,
    SessionStore? sessionStore,
  }) : _meetingService = meetingService ?? MeetingService(),
       _chatSocketService = chatSocketService ?? ChatSocketService(),
       _sessionStore = sessionStore ?? SessionStore();

  final MeetingService _meetingService;
  final ChatSocketService _chatSocketService;
  final SessionStore _sessionStore;

  Future<String> _token() async {
    final session = await _sessionStore.read();
    if (session == null ||
        session.accessTokenExpiresAt.isBefore(DateTime.now().toUtc())) {
      throw const MeetingException(
        code: 'unauthorized',
        message: '로그인이 필요합니다.',
      );
    }
    return session.accessToken;
  }

  @override
  Future<String> createMeeting(CreateMeetingInput input) async {
    final result = await _meetingService.createMeeting(
      token: await _token(),
      input: input,
    );
    final meetingId = result['meetingId']?.toString() ?? '';
    if (meetingId.isNotEmpty &&
        input.latitude != null &&
        input.longitude != null) {
      unawaited(MeetingLocationShareService.instance.startSharing(meetingId));
    }
    return meetingId;
  }

  @override
  Future<List<MeetingSummary>> listMeetings({
    MeetingCategory? category,
    MeetingMode? meetingMode,
  }) async {
    return _meetingService.listMeetings(
      token: await _token(),
      category: category,
      meetingMode: meetingMode,
    );
  }

  @override
  Future<List<MeetingSummary>> listMyMeetings() async {
    return _meetingService.listMyMeetings(token: await _token());
  }

  @override
  Future<MeetingDetail> getMeeting(String meetingId) async {
    return _meetingService.getMeeting(
      token: await _token(),
      meetingId: meetingId,
    );
  }

  @override
  Future<void> cancelMeeting(String meetingId) async {
    await _meetingService.cancelMeeting(
      token: await _token(),
      meetingId: meetingId,
    );
    MeetingLocationShareService.instance.stopSharing(meetingId);
  }

  @override
  Future<void> expireMeeting(String meetingId) async {
    await _meetingService.expireMeeting(
      token: await _token(),
      meetingId: meetingId,
    );
    MeetingLocationShareService.instance.stopSharing(meetingId);
  }

  @override
  Future<void> finishMeeting(String meetingId) async {
    await _meetingService.finishMeeting(
      token: await _token(),
      meetingId: meetingId,
    );
    MeetingLocationShareService.instance.stopSharing(meetingId);
  }

  @override
  Future<void> joinMeeting(String meetingId) async {
    await _meetingService.joinMeeting(
      token: await _token(),
      meetingId: meetingId,
    );
    unawaited(MeetingLocationShareService.instance.startSharing(meetingId));
  }

  @override
  Future<void> leaveMeeting(String meetingId) async {
    await _meetingService.leaveMeeting(
      token: await _token(),
      meetingId: meetingId,
    );
    MeetingLocationShareService.instance.stopSharing(meetingId);
  }

  @override
  Future<List<ChatMessage>> getMessages(String meetingId) async {
    return _meetingService.getMessages(
      token: await _token(),
      meetingId: meetingId,
    );
  }

  @override
  Stream<ChatMessage> watchChatMessages(String meetingId) {
    return _chatSocketService.messages;
  }

  @override
  Future<void> connectChat() async {
    await _chatSocketService.connect(await _token());
  }

  @override
  Future<void> joinChatRoom(String meetingId) {
    return _chatSocketService.joinRoom(meetingId);
  }

  @override
  Future<void> leaveChatRoom(String meetingId) {
    _chatSocketService.leaveRoom(meetingId);
    return Future<void>.value();
  }

  @override
  Future<void> sendChatMessage({
    required String meetingId,
    required String body,
  }) async {
    _chatSocketService.sendChat(meetingId: meetingId, body: body);
  }

  @override
  Future<void> disconnectChat() {
    return _chatSocketService.disconnect();
  }
}
