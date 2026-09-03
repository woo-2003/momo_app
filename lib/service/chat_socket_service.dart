import 'dart:async';

import 'package:momo_app/core/server_config.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatSocketService {
  ChatSocketService({String? baseUrl}) : _baseUrl = baseUrl ?? ServerConfig.baseUrl;

  final String _baseUrl;
  io.Socket? _socket;
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _errorController = StreamController<MeetingException>.broadcast();

  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<MeetingException> get errors => _errorController.stream;

  bool get isConnected => _socket?.connected == true;

  Future<void> connect(String token) async {
    if (_socket?.connected == true) return;

    final completer = Completer<void>();
    final socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    socket
      ..onConnect((_) {
        if (!completer.isCompleted) completer.complete();
      })
      ..onConnectError((error) {
        if (!completer.isCompleted) {
          completer.completeError(
            MeetingException(
              code: 'network',
              message: error?.toString() ?? '소켓 연결에 실패했습니다.',
            ),
          );
        }
      })
      ..on('chat', (data) {
        final message = _mapChatPayload(data);
        if (message != null) {
          _messageController.add(message);
        }
      })
      ..on('error', (data) {
        final mapped = _mapSocketError(data);
        _errorController.add(mapped);
      });

    _socket = socket;
    socket.connect();

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw const MeetingException(
          code: 'network',
          message: '소켓 연결 시간이 초과되었습니다.',
        );
      },
    );
  }

  Future<void> joinRoom(String meetingId) async {
    final socket = _requireSocket();
    final completer = Completer<void>();

    socket.emitWithAck('join', {'meetingId': meetingId}, ack: (data) {
      final success = data is Map && data['success'] == true;
      if (success) {
        completer.complete();
        return;
      }

      final message = data is Map ? data['message']?.toString() : null;
      completer.completeError(
        MeetingException(
          code: message ?? 'forbidden',
          message: message ?? '채팅방 입장에 실패했습니다.',
        ),
      );
    });

    return completer.future;
  }

  void leaveRoom(String meetingId) {
    _socket?.emit('leave', {'meetingId': meetingId});
  }

  void sendChat({required String meetingId, required String body}) {
    _requireSocket().emit('chat', {
      'meetingId': meetingId,
      'body': body,
    });
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
  }

  io.Socket _requireSocket() {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      throw const MeetingException(
        code: 'network',
        message: '채팅 서버에 연결되어 있지 않습니다.',
      );
    }
    return socket;
  }

  ChatMessage? _mapChatPayload(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final createdAtRaw = map['createdAt']?.toString();
    if (createdAtRaw == null || createdAtRaw.isEmpty) return null;

    return ChatMessage(
      messageId: map['messageId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      nickname: map['nickname']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      createdAt: DateTime.parse(createdAtRaw),
    );
  }

  MeetingException _mapSocketError(dynamic data) {
    if (data is Map) {
      final code = data['code']?.toString() ?? 'server';
      final message = data['message']?.toString() ?? '채팅 오류가 발생했습니다.';
      return MeetingException(code: code, message: message);
    }
    return const MeetingException(
      code: 'server',
      message: '채팅 오류가 발생했습니다.',
    );
  }
}
