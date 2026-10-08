import 'package:momo_app/domain/meeting_repository.dart';

/// 서버 enum(taxi/sports/game) + 임시 sportType prefix → 화면용 종류.
enum MeetingDisplayKind {
  taxi,
  meal,
  sports,
  study,
  hobby,
  drink,
  dating,
  other,
}

/// 로비 칩 / 카드 칩용 표시 헬퍼.
class MeetingDisplay {
  const MeetingDisplay._();

  static MeetingDisplayKind kindOf(MeetingSummary meeting) {
    switch (meeting.category) {
      case MeetingCategory.taxi:
        return MeetingDisplayKind.taxi;
      case MeetingCategory.game:
        return MeetingDisplayKind.hobby;
      case MeetingCategory.sports:
        return _fromSportType(meeting.sportType);
    }
  }

  static MeetingDisplayKind kindFromFields({
    required MeetingCategory category,
    String? sportType,
    String? gameName,
  }) {
    switch (category) {
      case MeetingCategory.taxi:
        return MeetingDisplayKind.taxi;
      case MeetingCategory.game:
        return MeetingDisplayKind.hobby;
      case MeetingCategory.sports:
        return _fromSportType(sportType);
    }
  }

  static MeetingDisplayKind _fromSportType(String? sportType) {
    final raw = (sportType ?? '').trim();
    if (raw.startsWith('밥약')) return MeetingDisplayKind.meal;
    if (raw.startsWith('스터디')) return MeetingDisplayKind.study;
    if (raw.startsWith('술약속')) return MeetingDisplayKind.drink;
    if (raw.startsWith('미팅')) return MeetingDisplayKind.dating;
    return MeetingDisplayKind.sports;
  }

  static String label(MeetingDisplayKind kind) {
    switch (kind) {
      case MeetingDisplayKind.taxi:
        return '택시팟';
      case MeetingDisplayKind.meal:
        return '식사';
      case MeetingDisplayKind.sports:
        return '스포츠';
      case MeetingDisplayKind.study:
        return '공부';
      case MeetingDisplayKind.hobby:
        return '취미';
      case MeetingDisplayKind.drink:
        return '술약속';
      case MeetingDisplayKind.dating:
        return '미팅';
      case MeetingDisplayKind.other:
        return '모임';
    }
  }

  static String labelOf(MeetingSummary meeting) => label(kindOf(meeting));

  /// 세부 문구 (sportType / gameName에서 prefix 제거).
  static String? detailOf(MeetingSummary meeting) {
    switch (meeting.category) {
      case MeetingCategory.taxi:
        return meeting.destinationName;
      case MeetingCategory.game:
        return meeting.gameName;
      case MeetingCategory.sports:
        final raw = meeting.sportType?.trim();
        if (raw == null || raw.isEmpty) return null;
        final colon = raw.indexOf(':');
        if (colon > 0 && colon < raw.length - 1) {
          return raw.substring(colon + 1).trim();
        }
        return raw;
    }
  }
}
