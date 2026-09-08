/**
 * 모임 참여자 실시간 GPS.
 * 하버사인·상태 판별은 친구 프로토콜 그대로.
 * userId는 JWT sub, 그 모임 멤버만 올리거나 조회한다.
 */
const { MeetingError, verifyMeetingMember } = require("./meetingService");

const ARRIVAL_THRESHOLD = 15.0;
const meetingRoomStorage = {};

class LocationError extends Error {
  constructor(statusCode, detail) {
    super(detail);
    this.name = "LocationError";
    this.statusCode = statusCode;
    this.detail = detail;
  }
}

function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const dlat = (lat2 - lat1) * (Math.PI / 180);
  const dlon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dlat / 2) ** 2 +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dlon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function round1(value) {
  return Math.round(value * 10) / 10;
}

function asFiniteNumber(value, field) {
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) {
    throw new LocationError(400, `${field} is required`);
  }
  return n;
}

function asNonEmptyString(value, field) {
  if (typeof value !== "string" || !value.trim()) {
    throw new LocationError(400, `${field} is required`);
  }
  return value.trim();
}

function parseLocationBody(body) {
  const payload = body && typeof body === "object" ? body : {};
  return {
    meetingId: asNonEmptyString(payload.meetingId, "meetingId"),
    prev_lat: asFiniteNumber(payload.prev_lat, "prev_lat"),
    prev_lon: asFiniteNumber(payload.prev_lon, "prev_lon"),
    prev_time: asFiniteNumber(payload.prev_time, "prev_time"),
    curr_lat: asFiniteNumber(payload.curr_lat, "curr_lat"),
    curr_lon: asFiniteNumber(payload.curr_lon, "curr_lon"),
    curr_time: asFiniteNumber(payload.curr_time, "curr_time"),
  };
}

function destinationFromMeeting(meetingData) {
  const destLat = meetingData?.latitude;
  const destLon = meetingData?.longitude;
  if (destLat == null || destLon == null) {
    throw new LocationError(400, "모임의 목적지 좌표가 설정되지 않았습니다.");
  }

  const lat = Number(destLat);
  const lon = Number(destLon);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    throw new LocationError(400, "모임의 목적지 좌표가 설정되지 않았습니다.");
  }

  return { destLat: lat, destLon: lon };
}

async function requireParticipant(meetingId, userId) {
  try {
    return await verifyMeetingMember(meetingId, userId);
  } catch (error) {
    if (error instanceof MeetingError) {
      if (error.statusCode === 404) {
        throw new LocationError(404, "존재하지 않는 모임입니다.");
      }
      if (error.statusCode === 403) {
        throw new LocationError(403, "모임 참여자가 아닙니다.");
      }
    }
    throw error;
  }
}

function computeStatus({
  prev_lat,
  prev_lon,
  prev_time,
  curr_lat,
  curr_lon,
  curr_time,
  destLat,
  destLon,
}) {
  const distanceToDest = calculateDistance(curr_lat, curr_lon, destLat, destLon);
  const movedDistance = calculateDistance(prev_lat, prev_lon, curr_lat, curr_lon);
  const timeDiff = curr_time - prev_time;

  let speed = 0.0;
  if (timeDiff > 0) {
    speed = movedDistance / timeDiff;
  }

  let status = "STATIONARY";
  if (distanceToDest <= ARRIVAL_THRESHOLD) {
    status = "ARRIVED";
  } else if (movedDistance > 3 && speed > 0.5) {
    status = "MOVING_TO_DEST";
  }

  return {
    status,
    distance_to_dest: round1(distanceToDest),
    speed: round1(speed),
  };
}

async function ingestLocation(body, userId) {
  const tokenUserId = asNonEmptyString(userId, "userId");
  const input = parseLocationBody(body);
  const meeting = await requireParticipant(input.meetingId, tokenUserId);
  const { destLat, destLon } = destinationFromMeeting(meeting);
  const computed = computeStatus({ ...input, destLat, destLon });

  if (!meetingRoomStorage[input.meetingId]) {
    meetingRoomStorage[input.meetingId] = {};
  }

  meetingRoomStorage[input.meetingId][tokenUserId] = {
    status: computed.status,
    curr_lat: input.curr_lat,
    curr_lon: input.curr_lon,
    distance_to_dest: computed.distance_to_dest,
    speed: computed.speed,
    updated_at: Date.now() / 1000,
  };

  return {
    result: "success",
    user_status: computed.status,
    distance_to_dest: computed.distance_to_dest,
    speed: computed.speed,
  };
}

async function getRoomMembers(meetingId, userId) {
  const id = asNonEmptyString(meetingId, "meetingId");
  await requireParticipant(id, asNonEmptyString(userId, "userId"));

  const room = meetingRoomStorage[id];
  if (!room || Object.keys(room).length === 0) {
    throw new LocationError(404, "해당 모임방에 접속 중인 유저가 없습니다.");
  }

  return {
    meetingId: id,
    members: room,
  };
}

module.exports = {
  LocationError,
  calculateDistance,
  ingestLocation,
  getRoomMembers,
};
