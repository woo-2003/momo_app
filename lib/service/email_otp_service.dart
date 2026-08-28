// momo_server REST 클라이언트.
// Base: Web/iOS localhost:3000, Android 에뮬 10.0.2.2:3000.
// 모임/지도/채팅 API 없음.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// OTP 실패 유형. AuthRepository 가 AuthException.code 로 매핑한다.
enum EmailOtpErrorType {
  network,
  server,
  invalidCode,
  expired,
  notFound,
  alreadyVerified,
  emailAlreadyUsed,
  tooManyRequests,
  unknown,
}

class EmailOtpResult {
  final bool success;
  final EmailOtpErrorType? errorType;
  final String message;

  const EmailOtpResult._({
    required this.success,
    required this.errorType,
    required this.message,
  });

  factory EmailOtpResult.success(String message) {
    return EmailOtpResult._(success: true, errorType: null, message: message);
  }

  factory EmailOtpResult.failure(EmailOtpErrorType errorType, String message) {
    return EmailOtpResult._(
      success: false,
      errorType: errorType,
      message: message,
    );
  }
}

/// HTTP로 OTP·로그인·가입·닉네임 확인을 호출한다.
class EmailOtpService {
  EmailOtpService({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl;

  static String get _defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  final String _baseUrl;
  static const Duration _timeout = Duration(seconds: 10);

  /// POST /send-email-otp
  Future<void> sendEmailOtp(String email) async {
    final result = await _post(
      endpoint: '/send-email-otp',
      body: {'email': email},
    );

    if (!result.success) {
      throw EmailOtpServiceException(result);
    }
  }

  /// POST /verify-email-otp
  Future<EmailOtpResult> verifyEmailOtp(String email, String code) async {
    return _post(
      endpoint: '/verify-email-otp',
      body: {'email': email, 'code': code},
    );
  }

  /// 닉네임 사용 가능 여부 조회.
  /// 사용 가능하면 true, 이미 사용 중이면 false.
  /// 네트워크/서버/정책 오류 시 [ApiException].
  Future<bool> checkNicknameAvailable(String nickname) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/check-nickname?nickname=${Uri.encodeQueryComponent(nickname)}',
      );
      final response = await http.get(uri).timeout(_timeout);

      final decoded = _decodeResponse(response.body);
      final message = decoded['message']?.toString() ?? '';

      if (response.statusCode == 200 && decoded['success'] == true) {
        return decoded['available'] == true;
      }

      throw ApiException(
        response.statusCode,
        message.isNotEmpty ? message : '닉네임 확인에 실패했습니다.',
      );
    } on SocketException catch (_) {
      throw const ApiException(0, '네트워크 오류입니다. 연결을 확인해 주세요.');
    } on TimeoutException catch (_) {
      throw const ApiException(0, '네트워크 오류입니다. 연결을 확인해 주세요.');
    }
  }

  /// 로그인 요청.
  ///
  /// 성공 시 [LoginResponse] 반환, 실패 시 [ApiException] (statusCode + message).
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);

      final decoded = _decodeResponse(response.body);
      final message = decoded['message']?.toString() ?? '';

      if (response.statusCode == 200 && decoded['success'] == true) {
        final user = decoded['user'];
        return LoginResponse(
          token: decoded['token']?.toString() ?? '',
          email: user is Map ? user['email']?.toString() ?? email : email,
          nickname: user is Map ? user['nickname']?.toString() : null,
        );
      }

      throw ApiException(
        response.statusCode,
        message.isNotEmpty ? message : '로그인에 실패했습니다.',
      );
    } on SocketException catch (_) {
      throw const ApiException(0, '네트워크 오류입니다. 연결을 확인해 주세요.');
    } on TimeoutException catch (_) {
      throw const ApiException(0, '네트워크 오류입니다. 연결을 확인해 주세요.');
    }
  }

  /// 회원가입 완료 요청.
  ///
  /// 성공 시 정상 종료, 실패 시 [ApiException] (statusCode + message).
  ///
  /// [변경 2026-08-27]
  /// - 이전: required String birthdate 있고 body 에 'birthdate' 포함
  /// - 지금: birthdate 파라미터/필드 없음 (앱에서 생년월일 미수집)
  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
    // [변경] required String birthdate 삭제됨
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'nickname': nickname,
              // [변경] 'birthdate': birthdate 전송 안 함
            }),
          )
          .timeout(_timeout);

      final decoded = _decodeResponse(response.body);
      final message = decoded['message']?.toString() ?? '';

      if (response.statusCode == 201 && decoded['success'] == true) {
        return;
      }

      throw ApiException(
        response.statusCode,
        message.isNotEmpty ? message : '회원가입에 실패했습니다.',
      );
    } on SocketException catch (_) {
      throw const ApiException(0, '네트워크 오류입니다. 연결을 확인해 주세요.');
    } on TimeoutException catch (_) {
      throw const ApiException(0, '네트워크 오류입니다. 연결을 확인해 주세요.');
    }
  }

  // ---------------------------------------------------------------------------
  // [롤백] 변경 전 signup 전문 (응답 처리 포함)
  // Future<void> signup({
  //   required String email,
  //   required String password,
  //   required String nickname,
  //   required String birthdate,
  // }) async {
  //   try {
  //     final response = await http
  //         .post(
  //           Uri.parse('$_baseUrl/signup'),
  //           headers: {'Content-Type': 'application/json'},
  //           body: jsonEncode({
  //             'email': email,
  //             'password': password,
  //             'nickname': nickname,
  //             'birthdate': birthdate,
  //           }),
  //         )
  //         .timeout(_timeout);
  //
  //     final decoded = _decodeResponse(response.body);
  //     final message = decoded['message']?.toString() ?? '';
  //
  //     if (response.statusCode == 201 && decoded['success'] == true) {
  //       return;
  //     }
  //
  //     throw ApiException(
  //       response.statusCode,
  //       message.isNotEmpty ? message : '회원가입에 실패했습니다.',
  //     );
  //   } on SocketException catch (_) {
  //     throw const ApiException(0, '네트워크 오류입니다. 연결을 확인해 주세요.');
  //   } on TimeoutException catch (_) {
  //     throw const ApiException(0, '네트워크 오류입니다. 연결을 확인해 주세요.');
  //   }
  // }
  // ---------------------------------------------------------------------------

  Future<EmailOtpResult> _post({
    required String endpoint,
    required Map<String, dynamic> body,
  }) async {
    try {
      // 모든 OTP API 요청을 공통 처리해 중복 로직을 줄인다.
      final response = await http
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      final decoded = _decodeResponse(response.body);
      final message = decoded['message']?.toString() ?? 'Unknown response';
      final success = decoded['success'] == true;

      if (response.statusCode == 200 && success) {
        return EmailOtpResult.success(message);
      }

      return EmailOtpResult.failure(
        _mapErrorType(statusCode: response.statusCode, message: message),
        message,
      );
    } on SocketException catch (_) {
      return EmailOtpResult.failure(
        EmailOtpErrorType.network,
        '네트워크 오류입니다. 연결을 확인해 주세요.',
      );
    } on TimeoutException catch (_) {
      return EmailOtpResult.failure(
        EmailOtpErrorType.network,
        '네트워크 오류입니다. 연결을 확인해 주세요.',
      );
    } catch (_) {
      return EmailOtpResult.failure(
        EmailOtpErrorType.unknown,
        '알 수 없는 오류가 발생했습니다.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  EmailOtpErrorType _mapErrorType({
    required int statusCode,
    required String message,
  }) {
    // 서버의 상태코드+메시지를 UI에서 다루기 쉬운 enum으로 통일한다.
    if (statusCode == 429) {
      return EmailOtpErrorType.tooManyRequests;
    }
    if (statusCode == 401 && message == 'Wrong OTP') {
      return EmailOtpErrorType.invalidCode;
    }
    if (statusCode == 404 && message == 'OTP not found') {
      return EmailOtpErrorType.notFound;
    }
    if (statusCode == 400 && message == 'OTP expired') {
      return EmailOtpErrorType.expired;
    }
    if (statusCode == 400 && message == 'Already verified') {
      return EmailOtpErrorType.alreadyVerified;
    }
    if (statusCode == 409) {
      return EmailOtpErrorType.emailAlreadyUsed;
    }
    if (statusCode >= 500) {
      return EmailOtpErrorType.server;
    }
    if (statusCode == 400) {
      return EmailOtpErrorType.unknown;
    }
    return EmailOtpErrorType.unknown;
  }
}

class EmailOtpServiceException implements Exception {
  final EmailOtpResult result;
  const EmailOtpServiceException(this.result);

  @override
  String toString() => result.message;
}

/// 로그인 성공 응답.
class LoginResponse {
  final String token;
  final String email;
  final String? nickname;

  const LoginResponse({
    required this.token,
    required this.email,
    this.nickname,
  });
}

/// OTP 외 일반 API(회원가입/닉네임 확인) 호출 실패 예외.
///
/// [statusCode] 0 은 네트워크 오류를 의미한다.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
