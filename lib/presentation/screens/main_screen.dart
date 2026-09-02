import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/presentation/screens/login_screen.dart';
import 'package:momo_app/presentation/widgets/create_meeting_sheet.dart';

// 로그인 후 홈 — 장면 A(메인 지도).
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 14,
  );

  static const List<String> _filters = [
    '전체',
    '택시팟',
    '스터디',
    '스포츠',
    '밥약',
  ];

  int _selectedFilterIndex = 0;

  // ===== [DEBUG] 임시 로그아웃 — 테스트용, 나중에 이 메서드와 Drawer 항목을 삭제하세요 =====
  Future<void> _onLogout() async {
    await SessionStore().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
  // ===== [DEBUG] 끝 =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      drawer: Drawer(
        backgroundColor: MomoColors.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(MomoSpacing.sm),
                child: Text('메뉴', style: MomoTextStyles.heading),
              ),
              const Divider(),
              // ===== [DEBUG] 임시 로그아웃 — 테스트용, 나중에 삭제하세요 =====
              ListTile(
                leading: const Icon(Icons.logout, color: MomoColors.textSub),
                title: Text(
                  '로그아웃',
                  style: MomoTextStyles.body.copyWith(color: MomoColors.textSub),
                ),
                onTap: _onLogout,
              ),
              // ===== [DEBUG] 끝 =====
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MomoSpacing.sm,
                    MomoSpacing.xs,
                    MomoSpacing.sm,
                    MomoSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) => _MapIconButton(
                          icon: Icons.menu_rounded,
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                      const Spacer(),
                      _MapAddButton(
                        onPressed: () => showCreateMeetingSheet(context),
                      ),
                    ],  
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: MomoSpacing.sm,
                    ),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: MomoSpacing.xs),
                    itemBuilder: (context, index) {
                      final selected = index == _selectedFilterIndex;
                      return _MapFilterChip(
                        label: _filters[index],
                        selected: selected,
                        onTap: () {
                          setState(() => _selectedFilterIndex = index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MomoSpacing.lg,
            child: Center(
              child: _PeachFab(onPressed: () {}),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomoColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: MomoColors.textMain.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: MomoColors.primary, size: 24),
        ),
      ),
    );
  }
}

class _MapAddButton extends StatelessWidget {
  const _MapAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomoColors.primary,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: MomoColors.primary.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.add, color: MomoColors.onPrimary, size: 28),
        ),
      ),
    );
  }
}

class _MapFilterChip extends StatelessWidget {
  const _MapFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MomoColors.textMain : MomoColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MomoSpacing.sm,
            vertical: MomoSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? null
                : Border.all(color: MomoColors.border),
          ),
          child: Text(
            label,
            style: MomoTextStyles.caption.copyWith(
              color: selected ? MomoColors.onPrimary : MomoColors.textMain,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeachFab extends StatelessWidget {
  const _PeachFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomoColors.onPrimary,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: MomoColors.primary.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: MomoColors.primary, width: 2),
          ),
          alignment: Alignment.center,
          child: const Text('🍑', style: TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}
