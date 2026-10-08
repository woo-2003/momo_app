import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:momo_app/core/map_location_helper.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/location_share_prefs.dart';

/// 위치 공유·OS 권한 설정. 실시간 소켓 반영은 서버 계약 후.
class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  final _prefs = LocationSharePrefs();
  bool _loading = true;
  bool _shareEnabled = true;
  bool _osGranted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _prefs.isEnabled();
    final granted = await MapLocationHelper.hasPermission();
    if (!mounted) return;
    setState(() {
      _shareEnabled = enabled;
      _osGranted = granted;
      _loading = false;
    });
  }

  Future<void> _setShare(bool value) async {
    setState(() => _shareEnabled = value);
    await _prefs.setEnabled(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? '위치 공유를 켰어요. (실시간 반영은 서버 연동 후)'
              : '위치 공유를 껐어요. (실시간 반영은 서버 연동 후)',
        ),
      ),
    );
  }

  Future<void> _requestOsPermission() async {
    final granted = await MapLocationHelper.ensurePermission();
    if (!granted) {
      await Geolocator.openAppSettings();
    }
    if (!mounted) return;
    final now = await MapLocationHelper.hasPermission();
    setState(() => _osGranted = now);
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
          '위치 설정',
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
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: MomoSpacing.sm,
                      vertical: MomoSpacing.xs,
                    ),
                    title: Text(
                      '위치 공유',
                      style: MomoTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '합류 지도·친구에게 내 위치를 보여줄지 정해요.',
                      style: MomoTextStyles.caption,
                    ),
                    value: _shareEnabled,
                    activeThumbColor: MomoColors.onPrimary,
                    activeTrackColor: MomoColors.primary,
                    onChanged: _setShare,
                  ),
                ),
                const SizedBox(height: MomoSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(MomoSpacing.sm),
                  decoration: BoxDecoration(
                    color: MomoColors.background,
                    borderRadius: MomoRadius.all,
                    border: Border.all(color: MomoColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '기기 위치 권한',
                        style: MomoTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _osGranted
                            ? '권한이 허용되어 있어요.'
                            : '권한이 꺼져 있어요. 지도·합류에 필요합니다.',
                        style: MomoTextStyles.caption,
                      ),
                      const SizedBox(height: MomoSpacing.sm),
                      OutlinedButton(
                        onPressed: _requestOsPermission,
                        child: Text(_osGranted ? '권한 상태 새로고침' : '권한 허용하기'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
