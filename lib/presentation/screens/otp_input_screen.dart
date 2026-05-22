import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momo_app/core/constants.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/mock_auth_repository.dart';
import 'package:momo_app/domain/auth_repository.dart';

class OtpInputScreen extends StatefulWidget {
  OtpInputScreen({
    super.key,
    required this.email,
    AuthRepository? authRepository,
  }) : authRepository = authRepository ?? MockAuthRepository();

  final String email;
  final AuthRepository authRepository;

  @override
  State<OtpInputScreen> createState() => _OtpInputScreenState();
}

class _OtpInputScreenState extends State<OtpInputScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isLoading = false;
  bool _showOtpError = false;

  bool get _isOtpValid =>
      ValidationPatterns.otpCode.hasMatch(_otpController.text.trim());

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onOtpChanged);
    _focusNode.addListener(_onOtpChanged);
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

  Future<void> _onConfirm() async {
    if (!_isOtpValid || _isLoading) return;

    setState(() {
      _isLoading = true;
      _showOtpError = false;
    });

    try {
      await widget.authRepository.verifyOtp(
        email: widget.email,
        code: _otpController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증되었습니다.')),
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final code = _otpController.text;

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
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: MomoColors.textMain,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: MomoSpacing.lg),
              const Text(
                '인증번호 6자리를 입력하세요',
                style: MomoTextStyles.heading,
              ),
              const SizedBox(height: MomoSpacing.xs),
              Text(
                '${widget.email} 으로 전송된 번호',
                style: MomoTextStyles.caption,
              ),
              const SizedBox(height: MomoSpacing.md),
              GestureDetector(
                onTap: () => _focusNode.requestFocus(),
                behavior: HitTestBehavior.opaque,
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
              if (_showOtpError) ...[
                const SizedBox(height: MomoSpacing.xs),
                Text(
                  ValidationMessages.otpInvalid,
                  style: MomoTextStyles.caption.copyWith(
                    color: MomoColors.error,
                  ),
                ),
              ],
              Offstage(
                child: TextField(
                  controller: _otpController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: AuthPolicy.otpLength,
                  autocorrect: false,
                  enableSuggestions: false,
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
              const SizedBox(height: MomoSpacing.sm),
              ElevatedButton(
                onPressed: _isOtpValid && !_isLoading ? _onConfirm : null,
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
            ],
          ),
        ),
      ),
    );
  }
}
