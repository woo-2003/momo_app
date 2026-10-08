import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/meeting_repository_impl.dart';
import 'package:momo_app/domain/meeting_repository.dart';
import 'package:momo_app/domain/selected_place.dart';
import 'package:momo_app/presentation/screens/location_picker_screen.dart';
import 'package:momo_app/presentation/widgets/momo_form_field.dart';

/// 일반 모임 개설 결과 (메인: 마커 갱신 + 선택적 카메라 + 상세).
class CreateGatheringResult {
  const CreateGatheringResult({
    required this.meetingId,
    this.focus,
  });

  final String meetingId;
  final LatLng? focus;
}

/// 엑셀 UI용 모임 종류 (서버 enum과 1:1 아님 → [_toServer] 매핑).
enum GatheringKind {
  meal,
  sports,
  study,
  hobby,
  drink,
  dating,
}

extension on GatheringKind {
  String get label {
    switch (this) {
      case GatheringKind.meal:
        return '밥약';
      case GatheringKind.sports:
        return '스포츠';
      case GatheringKind.study:
        return '스터디';
      case GatheringKind.hobby:
        return '취미(소셜)';
      case GatheringKind.drink:
        return '술약속';
      case GatheringKind.dating:
        return '미팅·소개팅';
    }
  }

  String get emoji {
    switch (this) {
      case GatheringKind.meal:
        return '🍚';
      case GatheringKind.sports:
        return '⚽';
      case GatheringKind.study:
        return '📚';
      case GatheringKind.hobby:
        return '🎨';
      case GatheringKind.drink:
        return '🍻';
      case GatheringKind.dating:
        return '❤️';
    }
  }

  String get detailHint {
    switch (this) {
      case GatheringKind.meal:
        return '예: 학식, 한식, 양식, 분식, 디저트 등';
      case GatheringKind.sports:
        return '예: 축구, 풋살, 농구, 배드민턴, 볼링 등';
      case GatheringKind.study:
        return '예: 토익, 코딩, 자격증, 전공 스터디 등';
      case GatheringKind.hobby:
        return '예: 보드게임, 방탈출, 독서, 영화 등';
      case GatheringKind.drink:
        return '예: 맥주, 소주, 칵테일, 가벼운 한잔 등';
      case GatheringKind.dating:
        return '예: 소개팅, 과팅, 미팅 등';
    }
  }

  /// 서버 CATEGORIES = taxi|sports|game 만 허용 → 임시 매핑.
  ({MeetingCategory category, Map<String, dynamic> fields, MeetingMode mode})
      toServer({
    required String detail,
    required MeetingMode preferredMode,
  }) {
    final trimmed = detail.trim().isEmpty ? label : detail.trim();
    switch (this) {
      case GatheringKind.sports:
        return (
          category: MeetingCategory.sports,
          fields: {'sportType': trimmed},
          mode: MeetingMode.offline,
        );
      case GatheringKind.hobby:
        return (
          category: MeetingCategory.game,
          fields: {'gameName': trimmed},
          mode: preferredMode,
        );
      case GatheringKind.meal:
      case GatheringKind.study:
      case GatheringKind.drink:
      case GatheringKind.dating:
        // 서버 meal/study 없음 → sports + prefix (동준 카테고리 추가 전)
        return (
          category: MeetingCategory.sports,
          fields: {'sportType': '$label:$trimmed'},
          mode: MeetingMode.offline,
        );
    }
  }
}

/// 엑셀 `Metting` 톤 — 일반 모임 만들기.
class CreateGatheringScreen extends StatefulWidget {
  CreateGatheringScreen({
    super.key,
    MeetingRepository? meetingRepository,
  }) : meetingRepository = meetingRepository ?? MeetingRepositoryImpl();

  final MeetingRepository meetingRepository;

  @override
  State<CreateGatheringScreen> createState() => _CreateGatheringScreenState();
}

class _CreateGatheringScreenState extends State<CreateGatheringScreen> {
  GatheringKind? _kind;
  final _detailController = TextEditingController();
  MeetingMode _mode = MeetingMode.offline;
  final _titleController = TextEditingController();
  final _placeDisplayController = TextEditingController();
  final _descriptionController = TextEditingController();
  SelectedPlace? _place;
  late DateTime _startAt;
  int _maxMembers = 4;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startAt = _initialStartAt();
    _detailController.addListener(_onFormChanged);
    _titleController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
  }

  DateTime _initialStartAt() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .add(const Duration(hours: 1));
  }

  void _onFormChanged() => setState(() {});

  bool get _hasKind => _kind != null;
  bool get _hasDetail => _detailController.text.trim().isNotEmpty;
  bool get _hasTitle => _titleController.text.trim().isNotEmpty;
  bool get _needsPlace {
    if (_kind == null) return false;
    final mapped = _kind!.toServer(
      detail: _detailController.text,
      preferredMode: _mode,
    );
    return mapped.mode == MeetingMode.offline;
  }

  bool get _hasPlace => _place != null;
  bool get _showDetail => _hasKind;
  bool get _showMode => _hasDetail;
  bool get _showTitle => _hasDetail;
  bool get _showPlace => _hasTitle && _needsPlace;
  bool get _showTime => _hasTitle && (!_needsPlace || _hasPlace);
  bool get _showCapacity => _showTime;
  bool get _showDescription => _showCapacity;
  bool get _showSubmit =>
      _hasKind &&
      _hasDetail &&
      _hasTitle &&
      (!_needsPlace || _hasPlace) &&
      !_isSubmitting;

  Future<void> _pickPlace() async {
    final result = await Navigator.of(context).push<SelectedPlace>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          screenTitle: '만날 장소 설정',
          confirmPrompt: '이 장소를 만날 장소로 설정할까요?',
          confirmButtonLabel: '장소로 설정',
          initialPosition: _place?.latLng,
          initialLabel: _place?.label,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _place = result;
      _placeDisplayController.text = result.label;
    });
  }

  void _onKindSelected(GatheringKind kind) {
    setState(() {
      _kind = kind;
      final mapped = kind.toServer(
        detail: _detailController.text,
        preferredMode: _mode,
      );
      if (mapped.mode == MeetingMode.offline) {
        _mode = MeetingMode.offline;
      }
    });
  }

  /// 시간만 고르므로 과거면 다음날로 올림.
  DateTime _resolvedStartAt() {
    final now = DateTime.now();
    var start = _startAt;
    if (!start.isAfter(now)) {
      start = start.add(const Duration(days: 1));
    }
    return start;
  }

  Future<void> _onSubmit() async {
    if (!_showSubmit || _kind == null) return;
    setState(() => _isSubmitting = true);

    final mapped = _kind!.toServer(
      detail: _detailController.text,
      preferredMode: _mode,
    );

    final startAt = _resolvedStartAt();
    if (mounted && startAt != _startAt) {
      setState(() => _startAt = startAt);
    }

    final input = CreateMeetingInput(
      title: _titleController.text.trim(),
      category: mapped.category,
      meetingMode: mapped.mode,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      placeName: mapped.mode == MeetingMode.offline ? _place!.label : null,
      latitude: mapped.mode == MeetingMode.offline ? _place!.latitude : null,
      longitude: mapped.mode == MeetingMode.offline ? _place!.longitude : null,
      startAt: startAt,
      maxMembers: _maxMembers.clamp(2, 50),
      categoryFields: mapped.fields,
    );

    try {
      final meetingId = await widget.meetingRepository.createMeeting(input);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임을 개설했어요.')),
      );
      Navigator.of(context).pop(
        CreateGatheringResult(
          meetingId: meetingId,
          focus: mapped.mode == MeetingMode.offline ? _place!.latLng : null,
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
        const SnackBar(content: Text('모임 개설에 실패했어요.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _detailController.dispose();
    _titleController.dispose();
    _placeDisplayController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modeLockedOffline = _kind != null &&
        _kind!.toServer(
              detail: _detailController.text,
              preferredMode: _mode,
            ).mode ==
            MeetingMode.offline &&
        _kind != GatheringKind.hobby;

    return Scaffold(
      backgroundColor: MomoColors.background,
      body: SafeArea(
        child: Column(
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: MomoColors.textMain,
                  ),
                  Expanded(
                    child: Text(
                      '🤝 모임 만들기',
                      style: MomoTextStyles.heading.copyWith(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  MomoSpacing.md,
                  MomoSpacing.sm,
                  MomoSpacing.md,
                  MomoSpacing.md,
                ),
                children: [
                  Text(
                    '모임 종류',
                    style: MomoTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: MomoSpacing.xs),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: GatheringKind.values.map((kind) {
                      final selected = _kind == kind;
                      return ChoiceChip(
                        label: Text('${kind.emoji} ${kind.label}'),
                        selected: selected,
                        onSelected: (_) => _onKindSelected(kind),
                        selectedColor: MomoColors.primary.withValues(alpha: 0.2),
                        backgroundColor: MomoColors.surface,
                        side: BorderSide(
                          color: selected
                              ? MomoColors.primary
                              : MomoColors.border,
                        ),
                        labelStyle: MomoTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: MomoColors.textMain,
                        ),
                      );
                    }).toList(),
                  ),
                  if (_showDetail) ...[
                    const SizedBox(height: MomoSpacing.md),
                    MomoFormField(
                      label: '${_kind!.label} 세부 항목/분야',
                      hintText: _kind!.detailHint,
                      controller: _detailController,
                    ),
                  ],
                  if (_showMode) ...[
                    const SizedBox(height: MomoSpacing.md),
                    Text(
                      '모임 형태',
                      style: MomoTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MomoSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeChip(
                            label: '📍 오프라인',
                            selected: _mode == MeetingMode.offline,
                            onTap: () => setState(
                              () => _mode = MeetingMode.offline,
                            ),
                          ),
                        ),
                        const SizedBox(width: MomoSpacing.xs),
                        Expanded(
                          child: _ModeChip(
                            label: '💻 온라인',
                            selected: _mode == MeetingMode.online,
                            onTap: modeLockedOffline
                                ? null
                                : () => setState(
                                      () => _mode = MeetingMode.online,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    if (modeLockedOffline)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '이 종류는 서버에서 오프라인으로 개설돼요.',
                          style: MomoTextStyles.caption.copyWith(
                            color: MomoColors.textDisabled,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                  if (_showTitle) ...[
                    const SizedBox(height: MomoSpacing.md),
                    MomoFormField(
                      label: '모임 제목',
                      hintText: '예: 주말 자바스크립트 스터디 모임',
                      controller: _titleController,
                    ),
                  ],
                  if (_showPlace) ...[
                    const SizedBox(height: MomoSpacing.md),
                    MomoFormField(
                      label: '만날 장소',
                      hintText: '예: IT BT관 1층 세미나실, 명학역 1번',
                      controller: _placeDisplayController,
                      readOnly: true,
                      onTap: _pickPlace,
                      onMapTap: _pickPlace,
                    ),
                  ],
                  if (_showTime) ...[
                    const SizedBox(height: MomoSpacing.md),
                    Text(
                      '시작 시간',
                      style: MomoTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MomoSpacing.xs),
                    SizedBox(
                      height: 120,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        initialDateTime: _startAt,
                        use24hFormat: false,
                        onDateTimeChanged: (value) {
                          setState(() {
                            final now = DateTime.now();
                            var next = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              value.hour,
                              value.minute,
                            );
                            if (!next.isAfter(now)) {
                              next = next.add(const Duration(days: 1));
                            }
                            _startAt = next;
                          });
                        },
                      ),
                    ),
                  ],
                  if (_showCapacity) ...[
                    const SizedBox(height: MomoSpacing.md),
                    Text(
                      '최대 인원 (최소 2명 ~ 최대 50명)',
                      style: MomoTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MomoSpacing.xs),
                    Row(
                      children: [
                        _StepButton(
                          icon: Icons.remove,
                          onPressed: _maxMembers <= 2
                              ? null
                              : () => setState(() => _maxMembers--),
                        ),
                        Expanded(
                          child: Text(
                            '$_maxMembers 명',
                            textAlign: TextAlign.center,
                            style: MomoTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _StepButton(
                          icon: Icons.add,
                          onPressed: _maxMembers >= 50
                              ? null
                              : () => setState(() => _maxMembers++),
                        ),
                      ],
                    ),
                  ],
                  if (_showDescription) ...[
                    const SizedBox(height: MomoSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '모임 설명',
                            style: MomoTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('AI 초안은 아직 준비 중이에요.'),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: MomoColors.primary,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('✨ AI 초안 생성'),
                        ),
                      ],
                    ),
                    const SizedBox(height: MomoSpacing.xs),
                    TextField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      style: MomoTextStyles.body,
                      decoration: const InputDecoration(
                        hintText: '모임의 목적, 활동 내용, 준수사항 등을 간단히 적어주세요.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MomoSpacing.md,
                0,
                MomoSpacing.md,
                MomoSpacing.md,
              ),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showSubmit ? _onSubmit : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MomoColors.onPrimary,
                          ),
                        )
                      : const Text('🤝 모임 개설하기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: selected
          ? MomoColors.primary
          : enabled
              ? MomoColors.surface
              : MomoColors.disabled,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? MomoColors.primary : MomoColors.border,
            ),
          ),
          child: Text(
            label,
            style: MomoTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? MomoColors.onPrimary
                  : enabled
                      ? MomoColors.textMain
                      : MomoColors.textDisabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomoColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: onPressed == null
                ? MomoColors.textDisabled
                : MomoColors.primary,
          ),
        ),
      ),
    );
  }
}
