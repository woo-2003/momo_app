import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/mock_auth_repository.dart';
import 'package:momo_app/domain/auth_repository.dart';
import 'package:momo_app/presentation/screens/nickname_setup_screen.dart';

class BirthdateInputScreen extends StatefulWidget {
  BirthdateInputScreen({
    super.key,
    required this.email,
    required this.verificationToken,
    required this.password,
    AuthRepository? authRepository,
  }) : authRepository = authRepository ?? MockAuthRepository();

  final String email;
  final VerificationToken verificationToken;
  final String password;
  final AuthRepository authRepository;

  @override
  State<BirthdateInputScreen> createState() => _BirthdateInputScreenState();
}

class _BirthdateInputScreenState extends State<BirthdateInputScreen> {
  static const int _defaultYear = 2000;
  static const int _defaultMonth = 1;
  static const int _defaultDay = 1;

  late final int _minYear;
  late final int _maxYear;

  late int _year;
  late int _month;
  late int _day;

  late FixedExtentScrollController _yearWheelController;
  late FixedExtentScrollController _monthWheelController;
  late FixedExtentScrollController _dayWheelController;

  late final TextEditingController _yearTextController;
  late final TextEditingController _monthTextController;
  late final TextEditingController _dayTextController;

  bool _isSyncing = false;

  bool get _isDateValid => _isValidDate(_year, _month, _day);

  @override
  void initState() {
    super.initState();
    _maxYear = DateTime.now().year;
    _minYear = _maxYear - 100;

    _year = _defaultYear;
    _month = _defaultMonth;
    _day = _defaultDay;

    _yearWheelController = FixedExtentScrollController(
      initialItem: _year - _minYear,
    );
    _monthWheelController = FixedExtentScrollController(
      initialItem: _month - 1,
    );
    _dayWheelController = FixedExtentScrollController(
      initialItem: _day - 1,
    );

    _yearTextController = TextEditingController(text: '$_year');
    _monthTextController = TextEditingController(text: '$_month');
    _dayTextController = TextEditingController(text: '$_day');

    _yearTextController.addListener(_onYearTextChanged);
    _monthTextController.addListener(_onMonthTextChanged);
    _dayTextController.addListener(_onDayTextChanged);
  }

  @override
  void dispose() {
    _yearTextController.removeListener(_onYearTextChanged);
    _monthTextController.removeListener(_onMonthTextChanged);
    _dayTextController.removeListener(_onDayTextChanged);
    _yearTextController.dispose();
    _monthTextController.dispose();
    _dayTextController.dispose();
    _yearWheelController.dispose();
    _monthWheelController.dispose();
    _dayWheelController.dispose();
    super.dispose();
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  bool _isValidDate(int year, int month, int day) {
    if (year < _minYear || year > _maxYear) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > _daysInMonth(year, month)) return false;
    return true;
  }

  void _syncTextFromState() {
    _isSyncing = true;
    _yearTextController.text = '$_year';
    _monthTextController.text = '$_month';
    _dayTextController.text = '$_day';
    _isSyncing = false;
  }

<<<<<<< HEAD
  /// 텍스트 필드 입력 등 휠 외부에서 날짜가 바뀔 때만 세 휠 위치를 맞춘다.
=======
>>>>>>> origin/main
  void _syncWheelsFromState() {
    if (_yearWheelController.hasClients) {
      _yearWheelController.jumpToItem(_year - _minYear);
    }
    if (_monthWheelController.hasClients) {
      _monthWheelController.jumpToItem(_month - 1);
    }
    if (_dayWheelController.hasClients) {
      _dayWheelController.jumpToItem(_day - 1);
    }
  }

<<<<<<< HEAD
  /// 년·월 변경 시 일(day)이 해당 월의 마지막 날을 넘으면 보정한다.
  int _clampDay(int year, int month, int day) {
    final maxDay = _daysInMonth(year, month);
    return day > maxDay ? maxDay : day;
  }

  /// 일 휠만 위치를 맞춘다. 년·월 휠은 스크롤 중 jumpToItem 하지 않는다.
  void _syncDayWheelOnly() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_dayWheelController.hasClients) {
        _dayWheelController.jumpToItem(_day - 1);
      }
=======
  void _applyDate({required int year, required int month, required int day}) {
    var nextDay = day;
    final maxDay = _daysInMonth(year, month);
    if (nextDay > maxDay) nextDay = maxDay;

    setState(() {
      _year = year;
      _month = month;
      _day = nextDay;
    });

    _syncTextFromState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncWheelsFromState();
>>>>>>> origin/main
    });
  }

  void _onYearWheelChanged(int index) {
    if (_isSyncing) return;
<<<<<<< HEAD
    final year = _minYear + index;
    final oldDay = _day;
    final prevDayCount = _daysInMonth(_year, _month);
    final nextDay = _clampDay(year, _month, _day);

    setState(() {
      _year = year;
      _day = nextDay;
    });
    _syncTextFromState();
    if (nextDay != oldDay || _daysInMonth(year, _month) != prevDayCount) {
      _syncDayWheelOnly();
    }
=======
    _applyDate(year: _minYear + index, month: _month, day: _day);
>>>>>>> origin/main
  }

  void _onMonthWheelChanged(int index) {
    if (_isSyncing) return;
<<<<<<< HEAD
    final month = index + 1;
    final oldDay = _day;
    final prevDayCount = _daysInMonth(_year, _month);
    final nextDay = _clampDay(_year, month, _day);

    setState(() {
      _month = month;
      _day = nextDay;
    });
    _syncTextFromState();
    if (nextDay != oldDay || _daysInMonth(_year, month) != prevDayCount) {
      _syncDayWheelOnly();
    }
=======
    _applyDate(year: _year, month: index + 1, day: _day);
>>>>>>> origin/main
  }

  void _onDayWheelChanged(int index) {
    if (_isSyncing) return;
    setState(() => _day = index + 1);
    _syncTextFromState();
  }

  void _tryApplyFromTextFields() {
    if (_isSyncing) return;

    final year = int.tryParse(_yearTextController.text);
    final month = int.tryParse(_monthTextController.text);
    final day = int.tryParse(_dayTextController.text);

    if (year == null || month == null || day == null) return;
    if (!_isValidDate(year, month, day)) return;

    _isSyncing = true;
    setState(() {
      _year = year;
      _month = month;
      _day = day;
    });
    _syncWheelsFromState();
    _isSyncing = false;
  }

  void _onYearTextChanged() {
    if (_isSyncing) return;
    if (_yearTextController.text.length == 4) {
      _tryApplyFromTextFields();
    } else {
      setState(() {});
    }
  }

  void _onMonthTextChanged() {
    if (_isSyncing) return;
    _tryApplyFromTextFields();
    setState(() {});
  }

  void _onDayTextChanged() {
    if (_isSyncing) return;
    _tryApplyFromTextFields();
    setState(() {});
  }

  void _onContinue() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NicknameSetupScreen(
          email: widget.email,
          verificationToken: widget.verificationToken,
          password: widget.password,
          birthDate: DateTime(_year, _month, _day),
          authRepository: widget.authRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayCount = _daysInMonth(_year, _month);

    return Scaffold(
      backgroundColor: MomoColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MomoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: MomoColors.textMain,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: MomoSpacing.lg),
              const Text(
                '생년월일을 입력해주세요',
                style: MomoTextStyles.heading,
              ),
              const SizedBox(height: MomoSpacing.md),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: MomoColors.surface,
                  borderRadius: MomoRadius.all,
                ),
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: MomoTextStyles.body.copyWith(
                        color: MomoColors.textMain,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: _yearWheelController,
                          itemExtent: 40,
                          onSelectedItemChanged: _onYearWheelChanged,
                          children: List.generate(_maxYear - _minYear + 1, (
                            index,
                          ) {
                            final year = _minYear + index;
                            return Center(child: Text('$year년'));
                          }),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: _monthWheelController,
                          itemExtent: 40,
                          onSelectedItemChanged: _onMonthWheelChanged,
                          children: List.generate(12, (index) {
                            return Center(child: Text('${index + 1}월'));
                          }),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          key: ValueKey('$dayCount-$_year-$_month'),
                          scrollController: _dayWheelController,
                          itemExtent: 40,
                          onSelectedItemChanged: _onDayWheelChanged,
                          children: List.generate(dayCount, (index) {
                            return Center(child: Text('${index + 1}일'));
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: MomoSpacing.sm),
              Text(
                '위아래로 스크롤하거나 아래에 직접 입력하세요',
                textAlign: TextAlign.center,
                style: MomoTextStyles.caption.copyWith(
                  color: MomoColors.textSub,
                ),
              ),
              const SizedBox(height: MomoSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _yearTextController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 4,
                      style: MomoTextStyles.body,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        hintText: '년',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: MomoSpacing.xs),
                  Expanded(
                    child: TextField(
                      controller: _monthTextController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 2,
                      style: MomoTextStyles.body,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        hintText: '월',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: MomoSpacing.xs),
                  Expanded(
                    child: TextField(
                      controller: _dayTextController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 2,
                      style: MomoTextStyles.body,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        hintText: '일',
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MomoSpacing.sm),
              ElevatedButton(
                onPressed: _isDateValid ? _onContinue : null,
                child: const Text('계속'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
