import 'package:flutter/material.dart';
import 'package:momo_app/presentation/screens/meeting_list_screen.dart';

// 로그인 후 홈. 모임 목록으로 진입한다.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MeetingListScreen();
  }
}
