import 'dart:async';

import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/meeting_repository.dart';

class MeetingChatScreen extends StatefulWidget {
  const MeetingChatScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
    required this.meetingRepository,
  });

  final String meetingId;
  final String meetingTitle;
  final MeetingRepository meetingRepository;

  @override
  State<MeetingChatScreen> createState() => _MeetingChatScreenState();
}

class _MeetingChatScreenState extends State<MeetingChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  StreamSubscription<ChatMessage>? _chatSubscription;

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final history = await widget.meetingRepository.getMessages(
        widget.meetingId,
      );
      await widget.meetingRepository.connectChat();
      await widget.meetingRepository.joinChatRoom(widget.meetingId);

      _chatSubscription = widget.meetingRepository
          .watchChatMessages(widget.meetingId)
          .listen(_onIncomingMessage);

      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
        _isLoading = false;
      });
      _scrollToBottom();
    } on MeetingException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  void _onIncomingMessage(ChatMessage message) {
    if (_messages.any((item) => item.messageId == message.messageId)) {
      return;
    }

    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await widget.meetingRepository.sendChatMessage(
        meetingId: widget.meetingId,
        body: body,
      );
    } on MeetingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    widget.meetingRepository.leaveChatRoom(widget.meetingId);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      appBar: AppBar(
        backgroundColor: MomoColors.background,
        elevation: 0,
        title: Text(widget.meetingTitle, style: MomoTextStyles.heading),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _messages.isEmpty
                ? Center(
                    child: Text(
                      '첫 메시지를 보내 보세요.',
                      style: MomoTextStyles.body.copyWith(
                        color: MomoColors.textSub,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(MomoSpacing.sm),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _ChatBubble(message: message);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                MomoSpacing.sm,
                MomoSpacing.xs,
                MomoSpacing.sm,
                MomoSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isSending && _errorMessage == null,
                      decoration: const InputDecoration(
                        hintText: '메시지 입력',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: MomoSpacing.xs),
                  IconButton(
                    onPressed: _isSending || _errorMessage != null
                        ? null
                        : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    color: MomoColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MomoSpacing.xs),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          padding: const EdgeInsets.all(MomoSpacing.sm),
          decoration: BoxDecoration(
            color: MomoColors.surface,
            borderRadius: MomoRadius.all,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.nickname,
                style: MomoTextStyles.caption.copyWith(
                  color: MomoColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: MomoSpacing.xxs),
              Text(message.body, style: MomoTextStyles.body),
            ],
          ),
        ),
      ),
    );
  }
}
