import 'dart:convert';

import 'package:momo_app/domain/meeting_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 서버 listMeetings 는 open 만 반환 → 종료 탭용 로컬 스냅샷.
class EndedMeetingSnapshot {
  const EndedMeetingSnapshot({
    required this.meetingId,
    required this.title,
    required this.category,
    required this.memberCount,
    required this.endedAt,
    required this.isHost,
    this.placeName,
  });

  final String meetingId;
  final String title;
  final MeetingCategory category;
  final String? placeName;
  final int memberCount;
  final DateTime endedAt;
  final bool isHost;

  Map<String, dynamic> toJson() => {
        'meetingId': meetingId,
        'title': title,
        'category': category.name,
        'placeName': placeName,
        'memberCount': memberCount,
        'endedAt': endedAt.toIso8601String(),
        'isHost': isHost,
      };

  factory EndedMeetingSnapshot.fromJson(Map<String, dynamic> json) {
    return EndedMeetingSnapshot(
      meetingId: json['meetingId'] as String,
      title: json['title'] as String? ?? '',
      category: MeetingCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => MeetingCategory.taxi,
      ),
      placeName: json['placeName'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ??
          DateTime.now(),
      isHost: json['isHost'] == true,
    );
  }

  factory EndedMeetingSnapshot.fromDetail(MeetingDetail detail) {
    return EndedMeetingSnapshot(
      meetingId: detail.meetingId,
      title: detail.title,
      category: detail.category,
      placeName: detail.placeName,
      memberCount: detail.currentMembers,
      endedAt: DateTime.now(),
      isHost: detail.isHost,
    );
  }
}

class EndedMeetingsStore {
  static const _key = 'ended_meetings_v1';

  Future<List<EndedMeetingSnapshot>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => EndedMeetingSnapshot.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList()
        ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsert(EndedMeetingSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await list();
    final next = [
      snapshot,
      ...current.where((e) => e.meetingId != snapshot.meetingId),
    ];
    await prefs.setString(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }
}
