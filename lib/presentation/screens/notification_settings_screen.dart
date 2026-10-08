import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/notification_prefs.dart';

/// 알림 설정 (시안 `알림설정`). 푸시 서버 연동 전 로컬 토글만.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _prefs = NotificationPrefs();
  bool _loading = true;
  bool _all = true;
  bool _chat = true;
  bool _meeting = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _prefs.allEnabled();
    final chat = await _prefs.chatEnabled();
    final meeting = await _prefs.meetingEnabled();
    if (!mounted) return;
    setState(() {
      _all = all;
      _chat = chat;
      _meeting = meeting;
      _loading = false;
    });
  }

  Future<void> _setAll(bool value) async {
    setState(() {
      _all = value;
      if (!value) {
        _chat = false;
        _meeting = false;
      }
    });
    await _prefs.setAllEnabled(value);
  }

  Future<void> _setChat(bool value) async {
    setState(() {
      _chat = value;
      if (value) _all = true;
    });
    await _prefs.setChatEnabled(value);
  }

  Future<void> _setMeeting(bool value) async {
    setState(() {
      _meeting = value;
      if (value) _all = true;
    });
    await _prefs.setMeetingEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.surface,
      appBar: AppBar(
        backgroundColor: MomoColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: MomoColors.textMain,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '알림 설정',
          style: MomoTextStyles.heading.copyWith(fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(MomoSpacing.sm),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: MomoColors.background,
                    borderRadius: MomoRadius.all,
                    border: Border.all(color: MomoColors.border),
                  ),
                  child: Column(
                    children: [
                      _NotifTile(
                        title: '전체 알림',
                        subtitle: '모든 푸시 알림을 켜거나 끕니다.',
                        value: _all,
                        onChanged: _setAll,
                      ),
                      const Divider(height: 1, color: MomoColors.border),
                      _NotifTile(
                        title: '채팅 알림',
                        subtitle: '택시팟 및 모임 대화방의 새 메시지 알림',
                        value: _chat && _all,
                        onChanged: _all ? _setChat : null,
                      ),
                      const Divider(height: 1, color: MomoColors.border),
                      _NotifTile(
                        title: '모임 알림',
                        subtitle: '새로운 모임 제안 및 참가 신청 수락 알림',
                        value: _meeting && _all,
                        onChanged: _all ? _setMeeting : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MomoSpacing.sm),
                Text(
                  '실제 푸시 발송은 서버 연동 후 적용됩니다. 지금은 선호만 저장해요.',
                  style: MomoTextStyles.caption.copyWith(
                    color: MomoColors.textDisabled,
                  ),
                ),
              ],
            ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MomoSpacing.sm,
        vertical: MomoSpacing.xs,
      ),
      title: Text(
        title,
        style: MomoTextStyles.body.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle, style: MomoTextStyles.caption),
      value: value,
      activeThumbColor: MomoColors.onPrimary,
      activeTrackColor: MomoColors.primary,
      onChanged: onChanged,
    );
  }
}
