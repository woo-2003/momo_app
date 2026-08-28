import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momo_app/core/constants.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/email_otp_auth_repository.dart';
import 'package:momo_app/domain/auth_repository.dart';
import 'package:momo_app/presentation/screens/password_setup_screen.dart';

// 가입 2단계. 6자리 OTP.
// 재전송 쿨다운·유효시간 타이머. 성공 시 PasswordSetupScreen.
class OtpInputScreen extends StatefulWidget {
  OtpInputScreen({
    super.key,
    required this.email,
    required this.otpExpiresAt,
    AuthRepository? authRepository,
  }) : authRepository = authRepository ?? EmailOtpAuthRepository();

  final String email;
  final DateTime otpExpiresAt;
  final AuthRepository authRepository;

  @override
  State<OtpInputScreen> createState() => _OtpInputScreenState();
}

class _OtpInputScreenState extends State<OtpInputScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isLoading = false;
  bool _isResending = false;
  bool _showOtpError = false;
  int _resendRemainingSeconds = AuthPolicy.otpResendCooldown.inSeconds;
  int _otpRemainingSeconds = 0;
  Timer? _resendTimer;
  Timer? _otpValidityTimer;

  bool get _isOtpValid =>
      ValidationPatterns.otpCode.hasMatch(_otpController.text.trim());

  bool get _isOtpExpired => _otpRemainingSeconds <= 0;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onOtpChanged);
    _focusNode.addListener(_onOtpChanged);
    _startResendCountdown();
    _startOtpValidityCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onOtpChanged() {
    if (_showOtpError) {
      setState(() => _showOtpError = false);
    } else {
      setState(() {});
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() {
      _resendRemainingSeconds = AuthPolicy.otpResendCooldown.inSeconds;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendRemainingSeconds <= 1) {
        timer.cancel();
        setState(() => _resendRemainingSeconds = 0);
        return;
      }
      setState(() => _resendRemainingSeconds -= 1);
    });
  }

  void _startOtpValidityCountdown() {
    _startOtpValidityCountdownFrom(widget.otpExpiresAt);
  }

  Future<void> _onResend() async {
    if (_isResending || _resendRemainingSeconds > 0) return;

    setState(() {
      _isResending = true;
      _showOtpError = false;
    });

    try {
      final expiresAt = await widget.authRepository.sendOtp(
        email: widget.email,
        purpose: OtpPurpose.signUp,
      );

      if (!mounted) return;

      _otpController.clear();
      _focusNode.requestFocus();
      _startResendCountdown();
      _startOtpValidityCountdownFrom(expiresAt);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호가 다시 전송되었습니다.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startOtpValidityCountdownFrom(DateTime expiresAt) {
    _otpValidityTimer?.cancel();
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    final initialSeconds =
        remaining.inSeconds.clamp(0, AuthPolicy.otpValidity.inSeconds);

    setState(() => _otpRemainingSeconds = initialSeconds);

    _otpValidityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpRemainingSeconds <= 1) {
        timer.cancel();
        setState(() => _otpRemainingSeconds = 0);
        return;
      }
      setState(() => _otpRemainingSeconds -= 1);
    });
  }

  Future<void> _onConfirm() async {
    if (!_isOtpValid || _isLoading || _isOtpExpired) return;

    setState(() {
      _isLoading = true;
      _showOtpError = false;
    });

    try {
      final token = await widget.authRepository.verifyOtp(
        email: widget.email,
        code: _otpController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PasswordSetupScreen(
            email: widget.email,
            verificationToken: token,
            authRepository: widget.authRepository,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'otp-invalid') {
        _otpController.clear();
        setState(() => _showOtpError = true);
        _focusNode.requestFocus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpValidityTimer?.cancel();
    _otpController.removeListener(_onOtpChanged);
    _focusNode.removeListener(_onOtpChanged);
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Color _boxBorderColor({
    required bool hasDigit,
    required bool isCurrent,
  }) {
    if (_showOtpError) return MomoColors.error;
    if (hasDigit || isCurrent) return MomoColors.primary;
    return MomoColors.border;
  }

  String _formatMmSs(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainSeconds';
  }

  void _requestOtpFocus() {
    if (_isOtpExpired || _isLoading || _isResending) return;
    FocusScope.of(context).requestFocus(_focusNode);
  }

  Widget _buildOtpInput(String code) {
    // 보이는 6칸 + 투명 TextField. 입력은 TextField, 표시는 Row 박스.
    return GestureDetector(
      onTap: _requestOtpFocus,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Row(
              children: List.generate(AuthPolicy.otpLength, (index) {
                final hasDigit = index < code.length;
                final isCurrent =
                    _focusNode.hasFocus && index == code.length;
                final borderColor = _boxBorderColor(
                  hasDigit: hasDigit,
                  isCurrent: isCurrent,
                );
                final isEmphasized =
                    _showOtpError || hasDigit || isCurrent;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : MomoSpacing.xxs / 2,
                      right: index == AuthPolicy.otpLength - 1
                          ? 0
                          : MomoSpacing.xxs / 2,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MomoColors.surface,
                          borderRadius: MomoRadius.all,
                          border: Border.all(
                            color: borderColor,
                            width: isEmphasized ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          hasDigit ? code[index] : '',
                          style: MomoTextStyles.heading.copyWith(
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Positioned.fill(
            child: TextField(
              controller: _otpController,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              maxLength: AuthPolicy.otpLength,
              autocorrect: false,
              enableSuggestions: false,
              enabled: !_isOtpExpired,
              showCursor: false,
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 1,
                height: 1,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = _otpController.text;
    final canResend = !_isResending && _resendRemainingSeconds == 0;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = bottomInset > 0;

    return Scaffold(
      backgroundColor: MomoColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: _requestOtpFocus,
          behavior: HitTestBehavior.translucent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  MomoSpacing.md,
                  0,
                  MomoSpacing.md,
                  bottomInset + MomoSpacing.sm,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: _isLoading || _isResending
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          color: MomoColors.textMain,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      SizedBox(
                        height: isKeyboardOpen
                            ? MomoSpacing.xs
                            : MomoSpacing.lg,
                      ),
                      const Text(
                        '인증번호 6자리를 입력하세요',
                        style: MomoTextStyles.heading,
                      ),
                      const SizedBox(height: MomoSpacing.xs),
                      Text(
                        '${widget.email} 으로 전송된 번호',
                        style: MomoTextStyles.caption,
                      ),
                      if (!_isOtpExpired) ...[
                        const SizedBox(height: MomoSpacing.xs),
                        Text(
                          '유효 시간 ${_formatMmSs(_otpRemainingSeconds)}',
                          style: MomoTextStyles.caption.copyWith(
                            color: MomoColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: MomoSpacing.xs),
                        Text(
                          '인증번호가 만료되었습니다. 다시 전송해 주세요.',
                          style: MomoTextStyles.caption.copyWith(
                            color: MomoColors.error,
                          ),
                        ),
                      ],
                      SizedBox(
                        height: isKeyboardOpen
                            ? MomoSpacing.xs
                            : MomoSpacing.md,
                      ),
                      _buildOtpInput(code),
                      if (_showOtpError) ...[
                        const SizedBox(height: MomoSpacing.xs),
                        Text(
                          ValidationMessages.otpInvalid,
                          style: MomoTextStyles.caption.copyWith(
                            color: MomoColors.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: MomoSpacing.sm),
                      ElevatedButton(
                        onPressed: _isOtpValid && !_isLoading && !_isOtpExpired
                            ? _onConfirm
                            : null,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MomoColors.onPrimary,
                                ),
                              )
                            : const Text('확인'),
                      ),
                      const SizedBox(height: MomoSpacing.xs),
                      TextButton(
                        onPressed: canResend ? _onResend : null,
                        child: _isResending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _resendRemainingSeconds > 0
                                    ? '재전송 ($_resendRemainingSeconds초)'
                                    : '인증번호 재전송',
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
