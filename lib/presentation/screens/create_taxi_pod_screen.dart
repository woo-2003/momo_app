import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/meeting_repository_impl.dart';
// import 'package:momo_app/data/meeting_store.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/domain/selected_place.dart';
// import 'package:momo_app/domain/taxi_pod_meeting.dart';
import 'package:momo_app/presentation/screens/location_picker_screen.dart';
import 'package:momo_app/presentation/widgets/momo_form_field.dart';

/// 택시팟 개설 성공 결과.
/// 메인: 마커 갱신 + 카메라 이동 + 모임 정보(상세)로 이동.
class CreateTaxiPodResult {
  const CreateTaxiPodResult({
    required this.meetingId,
    required this.focus,
  });

  final String meetingId;
  final LatLng focus;
}

/// 예약형 택시팟 만들기.
/// 개설 시 POST /meetings (category=taxi). 성공하면 [CreateTaxiPodResult] pop.
///
/// 집결 매핑: preMeeting ?? departure → placeName / latitude / longitude
class CreateTaxiPodScreen extends StatefulWidget {
  CreateTaxiPodScreen({
    super.key,
    MeetingRepository? meetingRepository,
  }) : meetingRepository = meetingRepository ?? MeetingRepositoryImpl();

  final MeetingRepository meetingRepository;

  @override
  State<CreateTaxiPodScreen> createState() => _CreateTaxiPodScreenState();
}

class _CreateTaxiPodScreenState extends State<CreateTaxiPodScreen> {
  final _titleController = TextEditingController();
  final _departureDisplayController = TextEditingController();
  final _destinationDisplayController = TextEditingController();
  final _preMeetingDisplayController = TextEditingController();

  SelectedPlace? _departure;
  SelectedPlace? _destination;
  SelectedPlace? _preMeeting;
  int _capacity = 4;
  late DateTime _departureTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _departureTime = _initialDepartureTime();
    _titleController.addListener(_onFormChanged);
  }

  DateTime _initialDepartureTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .add(const Duration(hours: 1));
  }

  bool get _hasTitle => _titleController.text.trim().isNotEmpty;

  bool get _hasDeparture => _departure != null;

  bool get _hasDestination => _destination != null;

  bool get _showDeparture => _hasTitle;

  bool get _showDestination => _hasDeparture;

  bool get _showPreMeeting => _hasDestination;

  bool get _showCapacity => _hasDestination;

  bool get _showTime => _hasDestination;

  bool get _showSubmit => _hasDestination && _isDepartureTimeValid;

  bool get _isDepartureTimeValid {
    final now = DateTime.now();
    return _isSameDay(_departureTime, now) && _departureTime.isAfter(now);
  }

  bool get _canSubmit =>
      _hasTitle &&
      _hasDeparture &&
      _hasDestination &&
      _isDepartureTimeValid &&
      !_isSubmitting;

  /// 지도 마커·서버 place 좌표. 사전 집결이 없으면 출발지.
  SelectedPlace get _meetingPoint => _preMeeting ?? _departure!;

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _onFormChanged() => setState(() {});

  Future<void> _pickPlace({
    required String screenTitle,
    required String confirmPrompt,
    required String confirmButtonLabel,
    required void Function(SelectedPlace place) onSelected,
    SelectedPlace? current,
  }) async {
    final result = await Navigator.of(context).push<SelectedPlace>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          screenTitle: screenTitle,
          confirmPrompt: confirmPrompt,
          confirmButtonLabel: confirmButtonLabel,
          initialPosition: current?.latLng,
          initialLabel: current?.label,
        ),
      ),
    );
    if (result == null || !mounted) return;
    onSelected(result);
    setState(() {});
  }

  Future<void> _pickDeparture() => _pickPlace(
        screenTitle: '출발지 설정',
        confirmPrompt: '출발지로 설정하시겠습니까?',
        confirmButtonLabel: '출발지로 설정',
        current: _departure,
        onSelected: (place) {
          _departure = place;
          _departureDisplayController.text = place.label;
        },
      );

  Future<void> _pickDestination() => _pickPlace(
        screenTitle: '목적지 설정',
        confirmPrompt: '목적지로 설정하시겠습니까?',
        confirmButtonLabel: '목적지로 설정',
        current: _destination,
        onSelected: (place) {
          _destination = place;
          _destinationDisplayController.text = place.label;
        },
      );

  Future<void> _pickPreMeeting() => _pickPlace(
        screenTitle: '사전 집결 장소 설정',
        confirmPrompt: '사전 집결 장소로 설정하시겠습니까?',
        confirmButtonLabel: '집결 장소로 설정',
        current: _preMeeting,
        onSelected: (place) {
          _preMeeting = place;
          _preMeetingDisplayController.text = place.label;
        },
      );

  void _skipPreMeeting() {
    setState(() {
      _preMeeting = null;
      _preMeetingDisplayController.clear();
    });
  }

  // --- [로컬 저장 — 롤백용] MeetingStore에만 넣고 pop(TaxiPodMeeting) ---
  // void _onSubmit() {
  //   if (!_canSubmit) return;
  //
  //   final meeting = TaxiPodMeeting(
  //     id: DateTime.now().millisecondsSinceEpoch.toString(),
  //     title: _titleController.text.trim(),
  //     departure: _departure!,
  //     destination: _destination!,
  //     preMeeting: _preMeeting,
  //     capacity: _capacity,
  //     departureTime: _departureTime,
  //   );
  //
  //   MeetingStore.instance.addTaxiPod(meeting);
  //   Navigator.of(context).pop(meeting);
  // }

  /// 서버에 택시 모임 생성. 성공 시 meetingId + 집결 좌표를 메인에 넘김.
  Future<void> _onSubmit() async {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    final meetingPoint = _meetingPoint;
    final input = CreateMeetingInput(
      title: _titleController.text.trim(),
      category: MeetingCategory.taxi,
      meetingMode: MeetingMode.offline,
      placeName: meetingPoint.label,
      latitude: meetingPoint.latitude,
      longitude: meetingPoint.longitude,
      startAt: _departureTime,
      maxMembers: _capacity,
      categoryFields: {
        'destinationName': _destination!.label,
        'departPlaceName': _departure!.label,
      },
    );

    try {
      final meetingId = await widget.meetingRepository.createMeeting(input);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            meetingId.isEmpty
                ? '개설은 됐지만 모임 ID를 받지 못했어요.'
                : '택시팟을 개설했어요.',
          ),
        ),
      );

      // --- [롤백용] 메인으로 좌표만 반환 ---
      // Navigator.of(context).pop(meetingPoint.latLng);

      // 개설 직후 동선: 메인이 상세(모임 정보)로 이어서 열어 줌
      Navigator.of(context).pop(
        CreateTaxiPodResult(
          meetingId: meetingId,
          focus: meetingPoint.latLng,
        ),
      );
    } on MeetingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('택시팟 개설에 실패했어요.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFormChanged);
    _titleController.dispose();
    _departureDisplayController.dispose();
    _destinationDisplayController.dispose();
    _preMeetingDisplayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MomoSpacing.sm,
                MomoSpacing.xs,
                MomoSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  Material(
                    color: MomoColors.onPrimary,
                    shape: const CircleBorder(),
                    elevation: 2,
                    shadowColor: MomoColors.textMain.withValues(alpha: 0.1),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: MomoColors.textMain,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: MomoSpacing.xs),
                  Text(
                    '택시팟 만들기',
                    style: MomoTextStyles.heading.copyWith(fontSize: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MomoSpacing.md,
                  vertical: MomoSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MomoFormField(
                      label: '팟 제목',
                      hintText: '예: IT BT관 앞 택시 같이 타고 가실 분!',
                      controller: _titleController,
                    ),
                    if (_showDeparture) ...[
                      const SizedBox(height: MomoSpacing.md),
                      MomoFormField(
                        label: '출발지',
                        hintText: '예: IT BT관, 정문, 학생누리관',
                        controller: _departureDisplayController,
                        readOnly: true,
                        onTap: _pickDeparture,
                        onMapTap: _pickDeparture,
                      ),
                    ],
                    if (_showDestination) ...[
                      const SizedBox(height: MomoSpacing.md),
                      MomoFormField(
                        label: '목적지',
                        hintText: '예: 왕십리역, 서울역, 강남역',
                        controller: _destinationDisplayController,
                        readOnly: true,
                        onTap: _pickDestination,
                        onMapTap: _pickDestination,
                      ),
                    ],
                    if (_showPreMeeting) ...[
                      const SizedBox(height: MomoSpacing.md),
                      MomoFormField(
                        label: '사전 집결 장소 (선택)',
                        hintText: '예: IT BT관 1층 로비 (택시 탑승 전 모일 장소)',
                        controller: _preMeetingDisplayController,
                        readOnly: true,
                        onTap: _pickPreMeeting,
                        onMapTap: _pickPreMeeting,
                        helperText:
                            '* 택시 승차 전 멤버들과 사전 집결이 필요할 때 설정하세요.',
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _skipPreMeeting,
                          child: Text(
                            '건너뛰기',
                            style: MomoTextStyles.caption.copyWith(
                              color: MomoColors.textSub,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_showCapacity) ...[
                      const SizedBox(height: MomoSpacing.xs),
                      Text(
                        '탑승 정원',
                        style: MomoTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: MomoSpacing.xs),
                      Row(
                        children: [
                          for (final count in [2, 3, 4])
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: count < 4 ? MomoSpacing.xs : 0,
                                ),
                                child: _CapacityChip(
                                  label: '$count명',
                                  selected: _capacity == count,
                                  onTap: () =>
                                      setState(() => _capacity = count),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (_showTime) ...[
                      const SizedBox(height: MomoSpacing.md),
                      Text(
                        '출발 시간',
                        style: MomoTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: MomoSpacing.xs),
                      // 시간 유효 시 피치 보더로 시각 피드백 (도안 노란 피드백 → theme primary)
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: MomoColors.surface,
                          borderRadius: MomoRadius.all,
                          border: Border.all(
                            color: _isDepartureTimeValid
                                ? MomoColors.primary
                                : MomoColors.border,
                            width: _isDepartureTimeValid ? 1.5 : 1,
                          ),
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          initialDateTime: _departureTime,
                          onDateTimeChanged: (value) {
                            final now = DateTime.now();
                            setState(() {
                              _departureTime = DateTime(
                                now.year,
                                now.month,
                                now.day,
                                value.hour,
                                value.minute,
                              );
                            });
                          },
                        ),
                      ),
                      if (!_isDepartureTimeValid) ...[
                        const SizedBox(height: MomoSpacing.xs),
                        Text(
                          '오늘 이후 시간만 선택할 수 있어요.',
                          style: MomoTextStyles.caption.copyWith(
                            color: MomoColors.error,
                          ),
                        ),
                      ],
                    ],
                    if (_showSubmit) ...[
                      const SizedBox(height: MomoSpacing.lg),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _canSubmit ? _onSubmit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MomoColors.primary,
                            foregroundColor: MomoColors.onPrimary,
                            disabledBackgroundColor: MomoColors.disabled,
                            elevation: _canSubmit ? 3 : 0,
                            shadowColor:
                                MomoColors.primary.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                MomoRadius.component,
                              ),
                            ),
                          ),
                          child: Text(
                            _isSubmitting ? '개설 중…' : '🚕 택시팟 개설하기',
                            style: MomoTextStyles.button,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: MomoSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapacityChip extends StatelessWidget {
  const _CapacityChip({
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
      color: selected ? MomoColors.primary : MomoColors.onPrimary,
      borderRadius: BorderRadius.circular(MomoRadius.component),
      elevation: selected ? 2 : 0,
      shadowColor: MomoColors.primary.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MomoRadius.component),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MomoRadius.component),
            border: selected ? null : Border.all(color: MomoColors.border),
          ),
          child: Text(
            label,
            style: MomoTextStyles.body.copyWith(
              color: selected ? MomoColors.onPrimary : MomoColors.textMain,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
