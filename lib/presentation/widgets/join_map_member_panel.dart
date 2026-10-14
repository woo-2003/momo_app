import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';

/// 합류 지도 하단 패널 (도안 Chatting 합류맵 톤).
/// 색은 [MomoColors]만 사용.
class JoinMapMemberPanel extends StatelessWidget {
  const JoinMapMemberPanel({
    super.key,
    required this.title,
    required this.placeLabel,
    required this.overallStatus,
    required this.rows,
    required this.onChat,
    required this.onLeave,
  });

  final String title;
  final String placeLabel;

  /// 예: 이동 중 / 도착 / 전원 도착 🎉
  final String overallStatus;
  final List<JoinMapMemberRowData> rows;
  final VoidCallback onChat;
  final VoidCallback onLeave;

  bool get _allGathered => overallStatus.contains('전원 도착');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MomoColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: MomoColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MomoSpacing.sm,
            MomoSpacing.sm,
            MomoSpacing.sm,
            MomoSpacing.sm,
          ),
          child: Column(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: MomoTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '약속 장소: $placeLabel',
                          style: MomoTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MomoSpacing.xs),
                  _StatusPill(
                    label: overallStatus,
                    emphasis: overallStatus == '도착' || _allGathered,
                  ),
                ],
              ),
              if (_allGathered) ...[
                const SizedBox(height: MomoSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MomoSpacing.sm,
                    vertical: MomoSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: MomoColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MomoColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '🎉 전원 집결 완료! 채팅으로 이어가 보세요.',
                    style: MomoTextStyles.caption.copyWith(
                      color: MomoColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: MomoSpacing.sm),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          '표시할 위치가 없어요.',
                          style: MomoTextStyles.caption,
                        ),
                      )
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: MomoSpacing.xs),
                        itemBuilder: (context, index) {
                          return _MemberTile(data: rows[index]);
                        },
                      ),
              ),
              const SizedBox(height: MomoSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                      label: const Text('채팅방'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MomoColors.primary,
                        backgroundColor: MomoColors.surface,
                        side: const BorderSide(color: MomoColors.border),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: MomoSpacing.sm,
                          vertical: MomoSpacing.xs,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            MomoRadius.component,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: MomoSpacing.xs),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onLeave,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MomoColors.textMain,
                        backgroundColor: MomoColors.surface,
                        side: const BorderSide(color: MomoColors.border),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: MomoSpacing.sm,
                          vertical: MomoSpacing.xs,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            MomoRadius.component,
                          ),
                        ),
                      ),
                      child: const Text('나가기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JoinMapMemberRowData {
  const JoinMapMemberRowData({
    required this.nickname,
    required this.statusText,
    required this.chipLabel,
    required this.isArrived,
    required this.isMe,
    required this.isDummy,
    this.isHost = false,
  });

  final String nickname;
  final String statusText;
  final String chipLabel;
  final bool isArrived;
  final bool isMe;
  final bool isDummy;
  final bool isHost;
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.data});

  final JoinMapMemberRowData data;

  @override
  Widget build(BuildContext context) {
    final initial =
        data.nickname.isEmpty ? '?' : data.nickname.substring(0, 1);
    final name = data.isDummy ? '${data.nickname} (더미)' : data.nickname;

    return Container(
      padding: const EdgeInsets.all(MomoSpacing.xs),
      decoration: BoxDecoration(
        color: MomoColors.onPrimary,
        borderRadius: BorderRadius.circular(MomoRadius.component),
        border: Border.all(color: MomoColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: data.isMe
                ? MomoColors.primary
                : MomoColors.success.withValues(alpha: 0.85),
            child: Text(
              initial,
              style: MomoTextStyles.caption.copyWith(
                color: MomoColors.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: MomoSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: MomoTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (data.isHost) ...[
                      const SizedBox(width: 4),
                      const Text('👑', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                Text(
                  data.statusText,
                  style: MomoTextStyles.caption.copyWith(
                    color: data.isArrived
                        ? MomoColors.primary
                        : MomoColors.textSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MomoSpacing.xs,
              vertical: MomoSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: data.isArrived
                  ? MomoColors.success.withValues(alpha: 0.2)
                  : MomoColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: data.isArrived
                  ? null
                  : Border.all(color: MomoColors.border),
            ),
            child: Text(
              data.chipLabel,
              style: MomoTextStyles.caption.copyWith(
                color: data.isArrived
                    ? MomoColors.success
                    : MomoColors.textSub,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.emphasis,
  });

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MomoSpacing.xs,
        vertical: MomoSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: emphasis
            ? MomoColors.success.withValues(alpha: 0.2)
            : MomoColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: MomoTextStyles.caption.copyWith(
          color: emphasis ? MomoColors.success : MomoColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
