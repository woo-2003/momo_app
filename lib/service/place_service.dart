// 카카오 로컬은 서버(/places/*) 경유. 앱에 REST 키를 두지 않는다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:momo_app/core/server_config.dart';
import 'package:momo_app/data/session_store.dart';

class PlaceLookupResult {
  const PlaceLookupResult({
    required this.label,
    this.roadAddress,
    this.address,
  });

  final String label;
  final String? roadAddress;
  final String? address;
}

class PlaceSearchItem {
  const PlaceSearchItem({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
}

class PlaceServiceException implements Exception {
  const PlaceServiceException(this.message, {this.code = 'server'});

  final String message;
  final String code;

  @override
  String toString() => 'PlaceServiceException($code): $message';
}

class PlaceService {
  PlaceService({
    String? baseUrl,
    http.Client? client,
    SessionStore? sessionStore,
  }) : _baseUrl = baseUrl ?? ServerConfig.baseUrl,
       _client = client ?? http.Client(),
       _sessionStore = sessionStore ?? SessionStore();

  final String _baseUrl;
  final http.Client _client;
  final SessionStore _sessionStore;
  static const Duration _timeout = Duration(seconds: 10);

  Future<PlaceLookupResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final token = await _requireToken();
    // 우영: 기존 — baseUrl 한 번만 호출 (네트워크 실패 시 즉시 종료)
    // final uri = Uri.parse('$_baseUrl/places/reverse').replace(
    //   queryParameters: {
    //     'lat': latitude.toString(),
    //     'lng': longitude.toString(),
    //   },
    // );
    // final decoded = await _getJson(uri, token);

    // 우영: 로그인처럼 연결 실패 시 fallback URL로 1회 재시도
    final decoded = await _getJsonWithFallback(
      path: '/places/reverse',
      queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
      },
      token: token,
    );
    final label = decoded['label']?.toString().trim() ?? '';
    if (label.isEmpty) {
      throw const PlaceServiceException('주소를 찾지 못했습니다.');
    }

    return PlaceLookupResult(
      label: label,
      roadAddress: decoded['roadAddress']?.toString(),
      address: decoded['address']?.toString(),
    );
  }

  Future<List<PlaceSearchItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final token = await _requireToken();
    // 우영: 기존 — baseUrl 한 번만 호출
    // final uri = Uri.parse('$_baseUrl/places/search').replace(
    //   queryParameters: {'q': q},
    // );
    // final decoded = await _getJson(uri, token);

    // 우영: 로그인처럼 연결 실패 시 fallback URL로 1회 재시도
    final decoded = await _getJsonWithFallback(
      path: '/places/search',
      queryParameters: {'q': q},
      token: token,
    );
    final items = decoded['items'];
    if (items is! List) return const [];

    return items.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      return PlaceSearchItem(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        address: map['address']?.toString() ?? '',
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      );
    }).where((item) {
      return item.name.isNotEmpty &&
          item.latitude != 0 &&
          item.longitude != 0;
    }).toList();
  }

  Future<String> _requireToken() async {
    final session = await _sessionStore.read();
    final token = session?.accessToken.trim() ?? '';
    if (token.isEmpty) {
      throw const PlaceServiceException(
        '로그인이 필요합니다.',
        code: 'unauthorized',
      );
    }
    return token;
  }

  // 우영: EmailOtpService.login 과 동일 — 첫 URL 네트워크 실패 시 반대 주소(10.0.2.2↔LAN)로 재시도
  Future<Map<String, dynamic>> _getJsonWithFallback({
    required String path,
    required Map<String, String> queryParameters,
    required String token,
  }) async {
    final primaryUri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParameters,
    );

    try {
      return await _getJson(primaryUri, token);
    } on PlaceServiceException catch (e) {
      if (e.code != 'network') rethrow;
      final fallback = ServerConfig.androidFallbackBaseUrl(_baseUrl);
      if (fallback == null) rethrow;
      if (kDebugMode) {
        debugPrint('[PLACE] $_baseUrl 연결 실패 → $fallback 재시도');
      }
      final fallbackUri = Uri.parse('$fallback$path').replace(
        queryParameters: queryParameters,
      );
      return _getJson(fallbackUri, token);
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, String token) async {
    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_timeout);

      final decoded = _decode(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true) {
        return decoded;
      }

      final message = decoded['message']?.toString() ?? '';
      throw PlaceServiceException(
        message.isNotEmpty ? message : '장소 조회에 실패했습니다.',
        code: response.statusCode == 401 ? 'unauthorized' : 'server',
      );
    } on PlaceServiceException {
      rethrow;
    } on SocketException {
      throw const PlaceServiceException(
        '네트워크 오류입니다. 연결을 확인해 주세요.',
        code: 'network',
      );
    } on TimeoutException {
      throw const PlaceServiceException(
        '네트워크 오류입니다. 연결을 확인해 주세요.',
        code: 'network',
      );
    } catch (e) {
      throw PlaceServiceException(e.toString());
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
