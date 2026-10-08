import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/presentation/screens/location_settings_screen.dart';
import 'package:momo_app/presentation/screens/login_screen.dart';
import 'package:momo_app/presentation/screens/notification_settings_screen.dart';
import 'package:momo_app/presentation/screens/profile_screen.dart';
import 'package:momo_app/presentation/widgets/my_joined_meetings_sheet.dart';

/// 메인 햄버거 → 설정/프로필 진입 드로어.
class AppMenuDrawer extends StatelessWidget {
  const AppMenuDrawer({
    super.key,
    required this.meetingRepository,
    this.onLogoutMapCleanup,
    this.onJoinedCount,
    this.onJoinedMapFocus,
  });

  final MeetingRepository meetingRepository;

  /// 로그아웃 직전 지도 컨트롤러 정리용.
  final VoidCallback? onLogoutMapCleanup;

  final ValueChanged<int>? onJoinedCount;

  /// 내 모임 시트에서 지도 포커스 좌표가 올 때.
  final ValueChanged<LatLng>? onJoinedMapFocus;

  Future<void> _logout(BuildContext context) async {
    onLogoutMapCleanup?.call();
    await SessionStore().clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(meetingRepository: meetingRepository),
      ),
    );
  }

  Future<void> _openMyMeetings(BuildContext context) async {
    Navigator.of(context).pop();
    final focus = await showMyJoinedMeetingsSheet(
      context: context,
      meetingRepository: meetingRepository,
      onJoinedCount: onJoinedCount,
    );
    if (focus != null) onJoinedMapFocus?.call(focus);
  }

  Future<void> _openNotifications(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationSettingsScreen(),
      ),
    );
  }

  Future<void> _openLocation(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const LocationSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: MomoColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(
                MomoSpacing.sm,
                MomoSpacing.md,
                MomoSpacing.sm,
                MomoSpacing.sm,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MomoColors.primary,
                    MomoColors.primary.withValues(alpha: 0.55),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '메뉴',
                    style: MomoTextStyles.heading.copyWith(
                      color: MomoColors.onPrimary,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '프로필 · 알림 · 위치 설정',
                    style: MomoTextStyles.caption.copyWith(
                      color: MomoColors.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MomoSpacing.xs),
            _MenuTile(
              icon: Icons.person_outline_rounded,
              title: '내 프로필',
              subtitle: '닉네임 · 내가 만든/참여한 모임',
              onTap: () => _openProfile(context),
            ),
            _MenuTile(
              icon: Icons.groups_outlined,
              emoji: '🍑',
              title: '내 모임',
              subtitle: '참여 중 번개 · 채팅 · 합류 지도',
              onTap: () => _openMyMeetings(context),
            ),
            _MenuTile(
              icon: Icons.notifications_none_rounded,
              title: '알림 설정',
              subtitle: '전체 · 채팅 · 모임 알림',
              onTap: () => _openNotifications(context),
            ),
            _MenuTile(
              icon: Icons.location_on_outlined,
              title: '위치 설정',
              subtitle: '위치 공유 · OS 권한',
              onTap: () => _openLocation(context),
            ),
            const Spacer(),
            const Divider(height: 1, color: MomoColors.border),
            _MenuTile(
              icon: Icons.logout_rounded,
              title: '로그아웃',
              subtitle: '이 기기에서 세션 종료',
              danger: true,
              onTap: () => _logout(context),
            ),
            Padding(
              padding: const EdgeInsets.all(MomoSpacing.sm),
              child: Text(
                'momo · 지금 이 핀으로, 모이는 동안만',
                style: MomoTextStyles.caption.copyWith(
                  color: MomoColors.textDisabled,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emoji,
    this.danger = false,
  });

  final IconData icon;
  final String? emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? MomoColors.error : MomoColors.textMain;
    return ListTile(
      leading: emoji != null
          ? Text(emoji!, style: const TextStyle(fontSize: 22))
          : Icon(icon, color: danger ? MomoColors.error : MomoColors.primary),
      title: Text(
        title,
        style: MomoTextStyles.body.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: MomoTextStyles.caption.copyWith(fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}
