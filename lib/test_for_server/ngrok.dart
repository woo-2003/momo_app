import 'package:http/http.dart' as http;
import 'dart:convert'; // JSON 변환을 위해 필요

Future<void> sendLocationData() async {
  // 작성자님의 ngrok 주소
  final url = Uri.parse(
    'https://1a15-218-237-138-42.ngrok-free.app/check-movement',
  );

  final now = DateTime.now().millisecondsSinceEpoch / 1000;
  final bodyData = {
    'prev_lat': 42.5665,
    'prev_lon': 256.9780,
    'prev_time': now - 10,
    'curr_lat': 44.6666,
    'curr_lon': 35.9780,
    'curr_time': now,
    'dest_lat': 43.5666,
    'dest_lon': 34.9780,
  };

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode(bodyData), // 데이터를 JSON 문자열로 변환
    );

    if (response.statusCode == 200) {
      print('서버 응답 성공: ${response.body}');
    } else {
      print('서버 에러: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    print('통신 실패: $e');
  }
}
