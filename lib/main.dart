import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/data/session_store.dart';
import 'package:momo_app/domain/auth_repository.dart';
import 'package:momo_app/presentation/screens/login_screen.dart';
import 'package:momo_app/presentation/screens/main_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:momo_app/test_for_server/ngrok.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  sendLocationData(); // test for server
  runApp(const MomoApp());
}

class MomoApp extends StatelessWidget {
  const MomoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'momo',
      debugShowCheckedModeBanner: false,
      theme: MomoTheme.light,
      home: const _AppEntry(),
    );
  }
}

/// 앱 시작 시 저장된 세션을 확인해 자동 로그인 여부를 결정한다.
///
/// - 유효한 세션이 있으면 [MainScreen] 으로 바로 진입(자동 로그인).
/// - 없으면 [LoginScreen] 으로 진입.
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  final SessionStore _sessionStore = SessionStore();
  late final Future<AuthSession?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _sessionStore.read();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSession?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: MomoColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data;
        final loggedIn =
            session != null &&
            session.accessTokenExpiresAt.isAfter(DateTime.now().toUtc());

        // ===== [DEBUG] 자동 로그인 상태 확인용 — 확인 후 이 블록을 삭제하세요 =====
        if (kDebugMode) {
          if (loggedIn) {
            debugPrint('[AUTO-LOGIN] 저장된 세션 발견 → 자동 로그인');
            debugPrint(
              '[AUTO-LOGIN] userId=${session.userId}, nickname=${session.nickname}',
            );
            debugPrint('[AUTO-LOGIN] token=${session.accessToken}');
            debugPrint(
              '[AUTO-LOGIN] expiresAt=${session.accessTokenExpiresAt}',
            );
          } else {
            debugPrint('[AUTO-LOGIN] 유효한 세션 없음 → 로그인 화면');
          }
        }
        // ===== [DEBUG] 끝 =====

        return loggedIn ? const MainScreen() : const LoginScreen();
      },
    );
  }
}
