import 'package:flutter/material.dart';
import 'package:momo_app/core/constants.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/profile_prefs.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/auth_repository.dart';

/// 프로필 수정 — 닉네임·상태메시지 로컬 저장. 사진 업로드는 준비중.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.initialNickname,
    required this.initialStatusMessage,
  });

  final String initialNickname;
  final String initialStatusMessage;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _statusController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.initialNickname);
    _statusController = TextEditingController(text: widget.initialStatusMessage);
    _nicknameController.addListener(() => setState(() {}));
    _statusController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  bool get _canSave {
    final nick = _nicknameController.text.trim();
    return !_saving &&
        nick.length >= AuthPolicy.nicknameMinLength &&
        nick.length <= AuthPolicy.nicknameMaxLength;
  }

  String get _initial {
    final nick = _nicknameController.text.trim();
    if (nick.isEmpty) return '?';
    return nick.substring(0, 1);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final nickname = _nicknameController.text.trim();
    final status = _statusController.text.trim().isEmpty
        ? ProfilePrefs.defaultStatusMessage
        : _statusController.text.trim();

    try {
      final store = SessionStore();
      final session = await store.read();
      if (session != null) {
        await store.save(
          AuthSession(
            userId: session.userId,
            accountId: session.accountId,
            nickname: nickname,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            accessTokenExpiresAt: session.accessTokenExpiresAt,
          ),
        );
      }
      await ProfilePrefs().setStatusMessage(status);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          '프로필 수정',
          style: MomoTextStyles.heading.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(MomoSpacing.sm),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: MomoSpacing.sm),
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: MomoColors.primary,
                              child: Text(
                                _initial,
                                style: MomoTextStyles.title.copyWith(
                                  color: MomoColors.onPrimary,
                                  fontSize: 32,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Material(
                                color: MomoColors.primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '프로필 사진 업로드는 준비 중이에요.',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Icon(
                                      Icons.edit_rounded,
                                      size: 16,
                                      color: MomoColors.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: MomoSpacing.md),
                      Text(
                        '닉네임',
                        style: MomoTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: MomoSpacing.xs),
                      TextField(
                        controller: _nicknameController,
                        maxLength: AuthPolicy.nicknameMaxLength,
                        style: MomoTextStyles.body,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: ValidationMessages.nicknameRule,
                          filled: true,
                          fillColor: MomoColors.background,
                        ),
                      ),
                      const SizedBox(height: MomoSpacing.sm),
                      Text(
                        '상태메시지',
                        style: MomoTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: MomoSpacing.xs),
                      TextField(
                        controller: _statusController,
                        maxLength: 60,
                        maxLines: 2,
                        style: MomoTextStyles.body,
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '한 줄로 나를 소개해 보세요',
                          filled: true,
                          fillColor: MomoColors.background,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: MomoSpacing.md),
                      ElevatedButton(
                        onPressed: _canSave ? _save : null,
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MomoColors.onPrimary,
                                ),
                              )
                            : const Text('저장하기'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
