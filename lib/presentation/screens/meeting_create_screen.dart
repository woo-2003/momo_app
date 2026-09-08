import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/domain/meeting_repository.dart';

class MeetingCreateScreen extends StatefulWidget {
  const MeetingCreateScreen({super.key, required this.meetingRepository});

  final MeetingRepository meetingRepository;

  @override
  State<MeetingCreateScreen> createState() => _MeetingCreateScreenState();
}

class _MeetingCreateScreenState extends State<MeetingCreateScreen> {
  final _titleController = TextEditingController();
  final _gameNameController = TextEditingController();
  final _destinationController = TextEditingController();
  final _placeNameController = TextEditingController();
  final _sportTypeController = TextEditingController();

  MeetingCategory _category = MeetingCategory.game;
  int _maxMembers = 4;
  bool _isSubmitting = false;

  bool get _hasCategoryFields {
    switch (_category) {
      case MeetingCategory.game:
        return _gameNameController.text.trim().isNotEmpty;
      case MeetingCategory.taxi:
        return _placeNameController.text.trim().isNotEmpty &&
            _destinationController.text.trim().isNotEmpty;
      case MeetingCategory.sports:
        return _placeNameController.text.trim().isNotEmpty &&
            _sportTypeController.text.trim().isNotEmpty;
    }
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _hasCategoryFields &&
      !_isSubmitting;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onFormChanged);
    _gameNameController.addListener(_onFormChanged);
    _destinationController.addListener(_onFormChanged);
    _placeNameController.addListener(_onFormChanged);
    _sportTypeController.addListener(_onFormChanged);
  }

  void _onFormChanged() => setState(() {});

  Future<void> _onSubmit() async {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    try {
      final input = _buildInput();
      await widget.meetingRepository.createMeeting(input);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on MeetingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  CreateMeetingInput _buildInput() {
    final startAt = DateTime.now().toUtc().add(const Duration(hours: 1));

    switch (_category) {
      case MeetingCategory.game:
        return CreateMeetingInput(
          title: _titleController.text.trim(),
          category: _category,
          meetingMode: MeetingMode.online,
          startAt: startAt,
          maxMembers: _maxMembers,
          categoryFields: {
            'gameName': _gameNameController.text.trim(),
          },
        );
      case MeetingCategory.taxi:
        return CreateMeetingInput(
          title: _titleController.text.trim(),
          category: _category,
          meetingMode: MeetingMode.offline,
          placeName: _placeNameController.text.trim(),
          latitude: 37.3801,
          longitude: 126.9281,
          startAt: startAt,
          maxMembers: _maxMembers,
          categoryFields: {
            'destinationName': _destinationController.text.trim(),
          },
        );
      case MeetingCategory.sports:
        return CreateMeetingInput(
          title: _titleController.text.trim(),
          category: _category,
          meetingMode: MeetingMode.offline,
          placeName: _placeNameController.text.trim(),
          latitude: 37.3801,
          longitude: 126.9281,
          startAt: startAt,
          maxMembers: _maxMembers,
          categoryFields: {
            'sportType': _sportTypeController.text.trim(),
          },
        );
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFormChanged);
    _gameNameController.removeListener(_onFormChanged);
    _destinationController.removeListener(_onFormChanged);
    _placeNameController.removeListener(_onFormChanged);
    _sportTypeController.removeListener(_onFormChanged);
    _titleController.dispose();
    _gameNameController.dispose();
    _destinationController.dispose();
    _placeNameController.dispose();
    _sportTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomoColors.background,
      appBar: AppBar(
        backgroundColor: MomoColors.background,
        elevation: 0,
        title: const Text('모임 만들기', style: MomoTextStyles.heading),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(hintText: '모임 제목'),
              ),
              const SizedBox(height: MomoSpacing.sm),
              DropdownButtonFormField<MeetingCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: '카테고리'),
                items: MeetingCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(meetingCategoryLabel(category)),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value != null) setState(() => _category = value);
                      },
              ),
              const SizedBox(height: MomoSpacing.sm),
              if (_category == MeetingCategory.game)
                TextField(
                  controller: _gameNameController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(hintText: '게임 이름'),
                ),
              if (_category == MeetingCategory.taxi) ...[
                TextField(
                  controller: _placeNameController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(hintText: '집결 장소'),
                ),
                const SizedBox(height: MomoSpacing.sm),
                TextField(
                  controller: _destinationController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(hintText: '도착지'),
                ),
              ],
              if (_category == MeetingCategory.sports) ...[
                TextField(
                  controller: _sportTypeController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(hintText: '종목 (예: 러닝, 축구)'),
                ),
                const SizedBox(height: MomoSpacing.sm),
                TextField(
                  controller: _placeNameController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(hintText: '운동 장소'),
                ),
              ],
              const SizedBox(height: MomoSpacing.sm),
              Row(
                children: [
                  const Text('정원', style: MomoTextStyles.body),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _maxMembers,
                    items: List.generate(
                      9,
                      (index) => DropdownMenuItem(
                        value: index + 2,
                        child: Text('${index + 2}명'),
                      ),
                    ),
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _maxMembers = value);
                            }
                          },
                  ),
                ],
              ),
              const SizedBox(height: MomoSpacing.sm),
              ElevatedButton(
                onPressed: _canSubmit ? _onSubmit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MomoColors.onPrimary,
                        ),
                      )
                    : const Text('만들기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
