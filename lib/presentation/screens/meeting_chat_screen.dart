import 'dart:async';

import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/join_map_screen.dart';

/// 모임 채팅 (도안 Chatting 톤 + 메신저 정렬).
/// 색은 [MomoColors]만.
///
/// 읽음 수(1)·안읽음 뱃지는 서버 API 없음 → 이번 범위 미구현.
class MeetingChatScreen extends StatefulWidget {
  const MeetingChatScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
    required this.meetingRepository,
    this.forceReadOnly = false,
  });

  final String meetingId;
  final String meetingTitle;
  final MeetingRepository meetingRepository;

  /// 종료 화면에서 진입 시 true. 또는 서버 status=cancelled 이면 읽기 전용.
  final bool forceReadOnly;

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
  bool _isReadOnly = false;
  String? _errorMessage;
  String? _myUserId;
  String? _myAccountId;
  String? _myNickname;
  int? _memberCount;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final session = await SessionStore().read();
      final history = await widget.meetingRepository.getMessages(
        widget.meetingId,
      );
      // 참여자 수·종료 여부 (실패해도 채팅 히스토리는 진행)
      int? members;
      var readOnly = widget.forceReadOnly;
      try {
        final detail =
            await widget.meetingRepository.getMeeting(widget.meetingId);
        members = detail.currentMembers;
        if (detail.status == 'cancelled' || detail.status == 'closed') {
          readOnly = true;
        }
      } catch (_) {}

      if (!readOnly) {
        await widget.meetingRepository.connectChat();
        await widget.meetingRepository.joinChatRoom(widget.meetingId);
        _chatSubscription = widget.meetingRepository
            .watchChatMessages(widget.meetingId)
            .listen(_onIncomingMessage);
      }

      if (!mounted) return;
      setState(() {
        _myUserId = session?.userId;
        _myAccountId = session?.accountId;
        _myNickname = session?.nickname;
        _memberCount = members;
        _isReadOnly = readOnly;
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

  bool _isMine(ChatMessage message) {
    final sender = message.senderId.trim();
    if (sender.isEmpty) return false;
    if (_myUserId != null && sender == _myUserId) return true;
    if (_myAccountId != null && sender == _myAccountId) return true;
    // 예전 세션이 email 을 userId 로 저장한 경우 대비 (닉네임은 보조)
    if (_myNickname != null &&
        _myNickname!.isNotEmpty &&
        message.nickname == _myNickname &&
        (_myUserId == null || sender == _myUserId)) {
      return true;
    }
    return false;
  }

  void _onIncomingMessage(ChatMessage message) {
    if (_messages.any((item) => item.messageId == message.messageId)) {
      return;
    }

    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  Future<void> _sendMessage([String? preset]) async {
    final body = (preset ?? _messageController.text).trim();
    if (body.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    if (preset == null) {
      _messageController.clear();
    }

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

  Future<void> _openJoinMap() async {
    try {
      final detail = await widget.meetingRepository.getMeeting(
        widget.meetingId,
      );
      if (!mounted) return;
      if (detail.latitude == null || detail.longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('집결 위치가 없어 합류 지도를 열 수 없어요.')),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => JoinMapScreen(
            meeting: detail,
            meetingRepository: widget.meetingRepository,
          ),
        ),
      );
    } on MeetingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _showReportSheet() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MomoColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MomoSpacing.sm,
              MomoSpacing.sm,
              MomoSpacing.sm,
              MomoSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: MomoSpacing.sm),
                    decoration: BoxDecoration(
                      color: MomoColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  '신고하기',
                  style: MomoTextStyles.heading.copyWith(fontSize: 18),
                ),
                const SizedBox(height: MomoSpacing.xxs),
                Text(
                  '사유 선택 UI만 있어요. 서버 신고 API는 아직 없습니다.',
                  style: MomoTextStyles.caption,
                ),
                const SizedBox(height: MomoSpacing.sm),
                for (final item in const [
                  '불쾌한 언행',
                  '스팸 / 광고',
                  '약속 불이행',
                  '기타',
                ])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item, style: MomoTextStyles.body),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: MomoColors.textSub,
                    ),
                    onTap: () => Navigator.of(ctx).pop(item),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: MomoColors.neutralFill,
                    foregroundColor: MomoColors.textMain,
                  ),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || reason == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$reason」선택 확인. 실제 접수는 서버 연동 후예요.')),
    );
  }

  Future<void> _showPlusSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MomoColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MomoSpacing.sm,
              MomoSpacing.sm,
              MomoSpacing.sm,
              MomoSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: MomoSpacing.sm),
                    decoration: BoxDecoration(
                      color: MomoColors.primary.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  '빠른 기능',
                  style: MomoTextStyles.heading.copyWith(fontSize: 18),
                ),
                const SizedBox(height: MomoSpacing.sm),
                _PlusActionTile(
                  icon: Icons.schedule_send_rounded,
                  title: '지연 알림',
                  subtitle: '「5~10분 늦을 것 같아요」 전송',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _sendMessage('5~10분 늦을 것 같아요!');
                  },
                ),
                _PlusActionTile(
                  icon: Icons.photo_outlined,
                  title: '사진 첨부',
                  subtitle: '서버·업로드 연동 전',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('사진 첨부는 아직 서버에 없어요.')),
                    );
                  },
                ),
                _PlusActionTile(
                  icon: Icons.my_location_rounded,
                  title: '위치 공유',
                  subtitle: '합류 location 소켓 연동 후',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('위치 공유 메시지는 location 소켓 후예요.')),
                    );
                  },
                ),
                _PlusActionTile(
                  icon: Icons.payments_outlined,
                  title: '더치페이',
                  subtitle: '정산 박스 메시지 (예정)',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('더치페이는 아직 서버에 없어요.')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime at) {
    final local = at.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    if (!_isReadOnly) {
      widget.meetingRepository.leaveChatRoom(widget.meetingId);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputEnabled =
        !_isReadOnly && !_isSending && _errorMessage == null;
    final titlePrefix = _isReadOnly ? '[종료] ' : '';

    return Scaffold(
      backgroundColor: MomoColors.background,
      appBar: AppBar(
        backgroundColor: MomoColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 72,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: MomoColors.textMain,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_back_rounded, size: 20),
              const SizedBox(width: 2),
              Text(
                _isReadOnly ? '안내' : '지도',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$titlePrefix${widget.meetingTitle}',
              style: MomoTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (_memberCount != null)
              Text(
                _isReadOnly
                    ? '참여자 $_memberCount명 · 읽기 전용'
                    : '참여자 $_memberCount명',
                style: MomoTextStyles.caption.copyWith(fontSize: 11),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (!_isReadOnly)
            TextButton(
              onPressed: _openJoinMap,
              style: TextButton.styleFrom(
                foregroundColor: MomoColors.primary,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gps_fixed_rounded, size: 18),
                  SizedBox(width: 2),
                  Text('합류맵', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          IconButton(
            onPressed: _showReportSheet,
            icon: const Icon(Icons.report_outlined),
            color: MomoColors.error,
            tooltip: '신고',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(MomoSpacing.md),
                          child: Text(
                            _errorMessage!,
                            style: MomoTextStyles.body.copyWith(
                              color: MomoColors.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
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
                            itemCount:
                                _messages.length + (_isReadOnly ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isReadOnly &&
                                  index == _messages.length) {
                                return _EndedReadOnlyBanner();
                              }
                              final message = _messages[index];
                              return _ChatBubble(
                                message: message,
                                isMine: _isMine(message),
                                timeLabel: _formatTime(message.createdAt),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                MomoSpacing.sm,
                MomoSpacing.xs,
                MomoSpacing.sm,
                MomoSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: MomoColors.background,
                border: Border(top: BorderSide(color: MomoColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Material(
                    color: MomoColors.surface,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: inputEnabled ? _showPlusSheet : null,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.add_rounded,
                          color: inputEnabled
                              ? MomoColors.primary
                              : MomoColors.textDisabled,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: MomoSpacing.xs),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: inputEnabled,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: _isReadOnly
                            ? '모임이 종료되어 메시지를 입력할 수 없어요'
                            : '메시지 입력',
                        filled: true,
                        fillColor: MomoColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: MomoSpacing.sm,
                          vertical: MomoSpacing.xs,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: MomoColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: MomoColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: MomoColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: MomoSpacing.xs),
                  // theme ElevatedButton.minimumSize 가 Size.fromHeight(56)
                  // (= 가로 infinity) 라 Row 안에서 레이아웃 예외 → 여기서 덮어씀.
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: inputEnabled ? () => _sendMessage() : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MomoColors.primary,
                        foregroundColor: MomoColors.onPrimary,
                        disabledBackgroundColor: MomoColors.disabled,
                        elevation: 0,
                        minimumSize: const Size(64, 44),
                        maximumSize: const Size(96, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: MomoColors.onPrimary,
                              ),
                            )
                          : Text(
                              '전송',
                              style: MomoTextStyles.button.copyWith(
                                fontSize: 14,
                              ),
                            ),
                    ),
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

class _PlusActionTile extends StatelessWidget {
  const _PlusActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: MomoColors.surface,
        child: Icon(icon, color: MomoColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: MomoTextStyles.body.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: MomoTextStyles.caption),
      onTap: onTap,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.timeLabel,
  });

  final ChatMessage message;
  final bool isMine;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MomoSpacing.sm,
        vertical: MomoSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isMine ? MomoColors.primary : MomoColors.onPrimary,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(MomoRadius.component),
          topRight: const Radius.circular(MomoRadius.component),
          bottomLeft: Radius.circular(isMine ? MomoRadius.component : 4),
          bottomRight: Radius.circular(isMine ? 4 : MomoRadius.component),
        ),
        border: isMine ? null : Border.all(color: MomoColors.border),
      ),
      child: Text(
        message.body,
        style: MomoTextStyles.body.copyWith(
          color: isMine ? MomoColors.onPrimary : MomoColors.textMain,
          fontSize: 15,
        ),
      ),
    );

    final meta = Text(
      timeLabel,
      style: MomoTextStyles.caption.copyWith(
        fontSize: 11,
        color: MomoColors.textDisabled,
      ),
    );

    if (isMine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: MomoSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            meta,
            const SizedBox(height: 2),
            bubble,
            // 읽음 수(1) — 서버에 read receipt 없음. 자리만 비워 둠.
          ],
        ),
      );
    }

    final initial =
        message.nickname.isEmpty ? '?' : message.nickname.substring(0, 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: MomoSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: MomoColors.surface,
            child: Text(
              initial,
              style: MomoTextStyles.caption.copyWith(
                color: MomoColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: MomoSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.nickname,
                      style: MomoTextStyles.caption.copyWith(
                        color: MomoColors.textMain,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    meta,
                  ],
                ),
                const SizedBox(height: 2),
                bubble,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EndedReadOnlyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: MomoSpacing.sm, bottom: MomoSpacing.md),
      padding: const EdgeInsets.all(MomoSpacing.sm),
      decoration: BoxDecoration(
        color: MomoColors.surface,
        borderRadius: MomoRadius.all,
        border: Border.all(color: MomoColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔒 모임이 종료되어 읽기 전용으로 전환되었습니다',
            style: MomoTextStyles.body.copyWith(
              color: MomoColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '실시간 위치 공유는 OFF입니다. 채팅은 30일 보관 후 삭제될 수 있어요.',
            style: MomoTextStyles.caption.copyWith(
              color: MomoColors.textSub,
            ),
          ),
        ],
      ),
    );
  }
}
