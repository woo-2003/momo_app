/**
 * 모임·멤버·채팅 Firestore 서비스.
 *
 * 컬렉션을 모임과 채팅으로 분리한다. GPS 실시간 좌표 프로토콜은 아직 없다.
 * 멤버 문서에 lastLatitude/lastLongitude 자리만 둔다.
 *
 * meetings/{meetingId}
 *   status: open | full | expired | finished | cancelled
 *   memberIds[], members[]          — 식별·참여 인원 (모임 문서에 표시)
 *   latitude/longitude              — 만남 장소. 유저 GPS 아님
 * meetings/{meetingId}/members/{userId}
 *   userId, nickname, role, joinedAt
 *   lastLatitude, lastLongitude, locationUpdatedAt  — GPS용 자리 (지금은 null)
 * chat_rooms/{chatRoomId}
 *   type: chat_room, meetingId, status, createdAt
 * chat_rooms/{chatRoomId}/messages/{messageId}
 *   type: chat_message, chatRoomId, meetingId, senderId, nickname, body, createdAt
 */
const { getFirestore } = require("../firebase");
const { findById } = require("./userService");

const MEETINGS = "meetings";
const CHAT_ROOMS = "chat_rooms";
const MEMBERS = "members";
const MESSAGES = "messages";

const CATEGORIES = new Set(["taxi", "sports", "game"]);
const MEETING_MODES = new Set(["offline", "online"]);
const STATUSES = new Set(["open", "full", "expired", "finished", "cancelled"]);
const LISTED_STATUSES = ["open", "full"];
const ALIVE_STATUSES = new Set(["open", "full"]);
const TERMINAL_STATUSES = new Set(["expired", "finished", "cancelled"]);

const TITLE_MIN = 1;
const TITLE_MAX = 40;
const DESC_MAX = 500;
const BODY_MIN = 1;
const BODY_MAX = 500;
const MIN_MEMBERS = 2;
const MAX_MEMBERS = 50;
const LIST_LIMIT = 100;
const MSG_DEFAULT_LIMIT = 50;
const MSG_MAX_LIMIT = 100;

class MeetingError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.name = "MeetingError";
    this.statusCode = statusCode;
    this.message = message;
  }
}

function nowIso() {
  return new Date().toISOString();
}

function occupancyStatus(currentMembers, maxMembers) {
  return currentMembers >= maxMembers ? "full" : "open";
}

function assertJoinable(status) {
  if (status === "full") {
    throw new MeetingError(409, "meeting-full");
  }
  if (TERMINAL_STATUSES.has(status) || status !== "open") {
    throw new MeetingError(409, "meeting-ended");
  }
}

function chatRejectCode(status) {
  if (status === "cancelled") return "meeting-cancelled";
  if (status === "expired") return "meeting-expired";
  if (status === "finished") return "meeting-finished";
  return "meeting-ended";
}

function parseIso(value, fieldName) {
  if (typeof value !== "string" || !value.trim()) {
    throw new MeetingError(400, "validation");
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new MeetingError(400, "validation");
  }
  return date.toISOString();
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isValidCoordinate(value) {
  return typeof value === "number" && Number.isFinite(value);
}

function validateCategoryFields(category, categoryFields) {
  const fields =
    categoryFields && typeof categoryFields === "object" ? categoryFields : {};

  if (category === "taxi") {
    if (!isNonEmptyString(fields.destinationName)) {
      throw new MeetingError(400, "validation");
    }
    return {
      destinationName: fields.destinationName.trim(),
      ...(isNonEmptyString(fields.departPlaceName)
        ? { departPlaceName: fields.departPlaceName.trim() }
        : {}),
      ...(isNonEmptyString(fields.costShareNote)
        ? { costShareNote: fields.costShareNote.trim() }
        : {}),
    };
  }

  if (category === "sports") {
    if (!isNonEmptyString(fields.sportType)) {
      throw new MeetingError(400, "validation");
    }
    return { sportType: fields.sportType.trim() };
  }

  if (category === "game") {
    if (!isNonEmptyString(fields.gameName)) {
      throw new MeetingError(400, "validation");
    }
    return {
      gameName: fields.gameName.trim(),
      ...(isNonEmptyString(fields.platformNote)
        ? { platformNote: fields.platformNote.trim() }
        : {}),
    };
  }

  throw new MeetingError(400, "validation");
}

function validateCreateInput(body) {
  const {
    title,
    description,
    category,
    meetingMode,
    placeName,
    latitude,
    longitude,
    startAt,
    maxMembers,
    categoryFields,
  } = body || {};

  if (!isNonEmptyString(title)) {
    throw new MeetingError(400, "validation");
  }
  const trimmedTitle = title.trim();
  if (
    trimmedTitle.length < TITLE_MIN ||
    trimmedTitle.length > TITLE_MAX
  ) {
    throw new MeetingError(400, "validation");
  }

  if (description != null && description !== "") {
    if (typeof description !== "string" || description.length > DESC_MAX) {
      throw new MeetingError(400, "validation");
    }
  }

  if (!CATEGORIES.has(category)) {
    throw new MeetingError(400, "validation");
  }

  let resolvedMode = meetingMode;
  if (category === "taxi" || category === "sports") {
    resolvedMode = "offline";
  } else if (!resolvedMode) {
    resolvedMode = "online";
  }

  if (!MEETING_MODES.has(resolvedMode)) {
    throw new MeetingError(400, "validation");
  }

  const parsedStartAt = parseIso(startAt, "startAt");

  if (
    typeof maxMembers !== "number" ||
    !Number.isInteger(maxMembers) ||
    maxMembers < MIN_MEMBERS ||
    maxMembers > MAX_MEMBERS
  ) {
    throw new MeetingError(400, "validation");
  }

  const validatedCategoryFields = validateCategoryFields(
    category,
    categoryFields
  );

  let resolvedPlaceName = null;
  let resolvedLatitude = null;
  let resolvedLongitude = null;

  if (resolvedMode === "offline") {
    if (!isNonEmptyString(placeName)) {
      throw new MeetingError(400, "validation");
    }
    if (!isValidCoordinate(latitude) || !isValidCoordinate(longitude)) {
      throw new MeetingError(400, "validation");
    }
    resolvedPlaceName = placeName.trim();
    resolvedLatitude = latitude;
    resolvedLongitude = longitude;
  } else if (
    isNonEmptyString(placeName) ||
    latitude != null ||
    longitude != null
  ) {
    if (
      !isNonEmptyString(placeName) ||
      !isValidCoordinate(latitude) ||
      !isValidCoordinate(longitude)
    ) {
      throw new MeetingError(400, "validation");
    }
    resolvedPlaceName = placeName.trim();
    resolvedLatitude = latitude;
    resolvedLongitude = longitude;
  }

  return {
    title: trimmedTitle,
    description:
      typeof description === "string" && description.trim().length > 0
        ? description.trim()
        : "",
    category,
    meetingMode: resolvedMode,
    placeName: resolvedPlaceName,
    latitude: resolvedLatitude,
    longitude: resolvedLongitude,
    startAt: parsedStartAt,
    maxMembers,
    categoryFields: validatedCategoryFields,
  };
}

function mapMeetingListItem(meetingId, data) {
  return {
    meetingId,
    category: data.category,
    meetingMode: data.meetingMode,
    status: data.status,
    title: data.title,
    startAt: data.startAt,
    currentMembers: data.currentMembers,
    maxMembers: data.maxMembers,
    placeName: data.placeName ?? null,
    latitude: data.latitude ?? null,
    longitude: data.longitude ?? null,
  };
}

function getMeetingRef(meetingId) {
  return getFirestore().collection(MEETINGS).doc(meetingId);
}

function getChatRoomRef(chatRoomId) {
  return getFirestore().collection(CHAT_ROOMS).doc(chatRoomId);
}

function buildMemberRecord({ userId, nickname, role, joinedAt }) {
  return {
    userId,
    nickname,
    role,
    joinedAt,
    lastLatitude: null,
    lastLongitude: null,
    locationUpdatedAt: null,
  };
}

function toParticipantIdentity(member) {
  return {
    userId: member.userId,
    nickname: member.nickname,
    role: member.role,
    joinedAt: member.joinedAt,
  };
}

async function ensureChatRoomId(meetingRef) {
  return getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(meetingRef);
    if (!snap.exists) {
      throw new MeetingError(404, "not-found");
    }

    const data = snap.data();
    if (isNonEmptyString(data.chatRoomId)) {
      return data.chatRoomId;
    }

    const chatRoomRef = getFirestore().collection(CHAT_ROOMS).doc();
    tx.set(chatRoomRef, {
      type: "chat_room",
      meetingId: meetingRef.id,
      status: data.status || "open",
      createdAt: nowIso(),
    });
    tx.update(meetingRef, {
      type: "meeting",
      meetingId: meetingRef.id,
      chatRoomId: chatRoomRef.id,
    });
    return chatRoomRef.id;
  });
}

async function getMeetingOrThrow(meetingId) {
  const ref = getMeetingRef(meetingId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new MeetingError(404, "not-found");
  }
  return { ref, snap, data: snap.data() };
}

function getMemberRef(meetingId, userId) {
  return getFirestore()
    .collection(MEETINGS)
    .doc(meetingId)
    .collection(MEMBERS)
    .doc(userId);
}

async function isMember(meetingId, userId) {
  const memberSnap = await getMemberRef(meetingId, userId).get();
  return memberSnap.exists;
}

async function listMembers(meetingId) {
  const snap = await getFirestore()
    .collection(MEETINGS)
    .doc(meetingId)
    .collection(MEMBERS)
    .orderBy("joinedAt", "asc")
    .get();

  return snap.docs.map((doc) => {
    const data = doc.data();
    return {
      userId: data.userId,
      nickname: data.nickname,
      role: data.role,
    };
  });
}

async function createMeeting(userId, body) {
  const user = await findById(userId);
  if (!user) {
    throw new MeetingError(401, "unauthorized");
  }

  const input = validateCreateInput(body);
  const createdAt = nowIso();
  const meetingRef = getFirestore().collection(MEETINGS).doc();
  const chatRoomRef = getFirestore().collection(CHAT_ROOMS).doc();
  const hostMember = buildMemberRecord({
    userId,
    nickname: user.nickname,
    role: "host",
    joinedAt: createdAt,
  });

  const meetingData = {
    type: "meeting",
    meetingId: meetingRef.id,
    chatRoomId: chatRoomRef.id,
    title: input.title,
    description: input.description,
    category: input.category,
    meetingMode: input.meetingMode,
    status: "open",
    visibility: "public",
    placeName: input.placeName,
    latitude: input.latitude,
    longitude: input.longitude,
    startAt: input.startAt,
    maxMembers: input.maxMembers,
    currentMembers: 1,
    creatorId: userId,
    memberIds: [userId],
    members: [toParticipantIdentity(hostMember)],
    categoryFields: input.categoryFields,
    cancelledAt: null,
    createdAt,
  };

  const memberRef = meetingRef.collection(MEMBERS).doc(userId);
  const chatRoomData = {
    type: "chat_room",
    meetingId: meetingRef.id,
    status: "open",
    createdAt,
  };

  await getFirestore().runTransaction(async (tx) => {
    tx.set(meetingRef, meetingData);
    tx.set(memberRef, hostMember);
    tx.set(chatRoomRef, chatRoomData);
  });

  return {
    meetingId: meetingRef.id,
    chatRoomId: chatRoomRef.id,
    status: "open",
    createdAt,
  };
}

async function listMeetings(filters = {}) {
  const { category, meetingMode } = filters;

  let query = getFirestore()
    .collection(MEETINGS)
    .where("status", "in", LISTED_STATUSES);

  if (category) {
    if (!CATEGORIES.has(category)) {
      throw new MeetingError(400, "validation");
    }
    query = query.where("category", "==", category);
  }

  if (meetingMode) {
    if (!MEETING_MODES.has(meetingMode)) {
      throw new MeetingError(400, "validation");
    }
    query = query.where("meetingMode", "==", meetingMode);
  }

  const snap = await query.orderBy("startAt", "asc").limit(LIST_LIMIT).get();

  return snap.docs.map((doc) => mapMeetingListItem(doc.id, doc.data()));
}

/**
 * 내가 만든·참여한 모임. open/full 과 expired/finished/cancelled 를 함께 반환한다.
 * 공개 목록(listMeetings)은 지도용으로 살아 있는 모임만 유지한다.
 * memberIds 가 없는 예전 문서도 주최자면 creatorId 로 잡는다.
 */
async function listMyMeetings(userId) {
  if (!isNonEmptyString(userId)) {
    throw new MeetingError(401, "unauthorized");
  }

  const db = getFirestore();
  const [memberSnap, creatorSnap] = await Promise.all([
    db
      .collection(MEETINGS)
      .where("memberIds", "array-contains", userId)
      .limit(LIST_LIMIT)
      .get(),
    db
      .collection(MEETINGS)
      .where("creatorId", "==", userId)
      .limit(LIST_LIMIT)
      .get(),
  ]);

  const byId = new Map();
  for (const doc of memberSnap.docs) byId.set(doc.id, doc);
  for (const doc of creatorSnap.docs) byId.set(doc.id, doc);

  return [...byId.values()]
    .map((doc) => mapMeetingListItem(doc.id, doc.data()))
    .sort((a, b) =>
      String(b.startAt || "").localeCompare(String(a.startAt || ""))
    );
}

async function getMeetingDetail(meetingId, userId) {
  const { data } = await getMeetingOrThrow(meetingId);
  const members = await listMembers(meetingId);
  const member = members.find((m) => m.userId === userId);

  return {
    ...mapMeetingListItem(meetingId, data),
    description: data.description ?? "",
    categoryFields: data.categoryFields ?? {},
    creatorId: data.creatorId,
    chatRoomId: data.chatRoomId ?? null,
    memberIds: Array.isArray(data.memberIds) ? data.memberIds : members.map((m) => m.userId),
    isHost: data.creatorId === userId,
    isMember: Boolean(member),
    members,
  };
}

async function endMeeting(meetingId, userId, nextStatus, atField) {
  const { ref, data } = await getMeetingOrThrow(meetingId);

  if (data.creatorId !== userId) {
    throw new MeetingError(403, "forbidden");
  }

  if (TERMINAL_STATUSES.has(data.status)) {
    throw new MeetingError(409, "meeting-ended");
  }

  if (!ALIVE_STATUSES.has(data.status)) {
    throw new MeetingError(409, "meeting-ended");
  }

  const endedAt = nowIso();
  await ref.update({
    status: nextStatus,
    [atField]: endedAt,
  });

  if (isNonEmptyString(data.chatRoomId)) {
    await getChatRoomRef(data.chatRoomId).update({
      status: nextStatus,
    });
  }

  return { status: nextStatus, [atField]: endedAt };
}

async function cancelMeeting(meetingId, userId) {
  return endMeeting(meetingId, userId, "cancelled", "cancelledAt");
}

async function expireMeeting(meetingId, userId) {
  return endMeeting(meetingId, userId, "expired", "expiredAt");
}

async function finishMeeting(meetingId, userId) {
  return endMeeting(meetingId, userId, "finished", "finishedAt");
}

async function joinMeeting(meetingId, userId) {
  const user = await findById(userId);
  if (!user) {
    throw new MeetingError(401, "unauthorized");
  }

  const { ref, data } = await getMeetingOrThrow(meetingId);

  assertJoinable(data.status);

  const memberRef = ref.collection(MEMBERS).doc(userId);
  const memberSnap = await memberRef.get();
  if (memberSnap.exists) {
    return { alreadyMember: true };
  }

  if (data.currentMembers >= data.maxMembers) {
    throw new MeetingError(409, "meeting-full");
  }

  const joinedAt = nowIso();
  let alreadyMemberInTx = false;

  await getFirestore().runTransaction(async (tx) => {
    const meetingSnap = await tx.get(ref);
    if (!meetingSnap.exists) {
      throw new MeetingError(404, "not-found");
    }

    const meeting = meetingSnap.data();
    assertJoinable(meeting.status);

    const existingMember = await tx.get(memberRef);
    if (existingMember.exists) {
      alreadyMemberInTx = true;
      return;
    }

    if (meeting.currentMembers >= meeting.maxMembers) {
      throw new MeetingError(409, "meeting-full");
    }

    tx.set(memberRef, buildMemberRecord({
      userId,
      nickname: user.nickname,
      role: "member",
      joinedAt,
    }));
    const nextCount = meeting.currentMembers + 1;
    tx.update(ref, {
      currentMembers: nextCount,
      status: occupancyStatus(nextCount, meeting.maxMembers),
      memberIds: [...(meeting.memberIds || []), userId],
      members: [
        ...(meeting.members || []),
        toParticipantIdentity({
          userId,
          nickname: user.nickname,
          role: "member",
          joinedAt,
        }),
      ],
    });
  });

  return { alreadyMember: alreadyMemberInTx };
}

async function leaveMeeting(meetingId, userId) {
  const { ref, data } = await getMeetingOrThrow(meetingId);
  const memberRef = ref.collection(MEMBERS).doc(userId);
  const memberSnap = await memberRef.get();

  if (!memberSnap.exists) {
    throw new MeetingError(403, "forbidden");
  }

  if (data.creatorId === userId) {
    throw new MeetingError(403, "host-cannot-leave");
  }

  await getFirestore().runTransaction(async (tx) => {
    const meetingSnap = await tx.get(ref);
    const currentMemberSnap = await tx.get(memberRef);

    if (!meetingSnap.exists || !currentMemberSnap.exists) {
      throw new MeetingError(403, "forbidden");
    }

    const meeting = meetingSnap.data();
    const nextCount = Math.max(0, meeting.currentMembers - 1);
    const patch = {
      currentMembers: nextCount,
      memberIds: (meeting.memberIds || []).filter((id) => id !== userId),
      members: (meeting.members || []).filter(
        (member) => member.userId !== userId
      ),
    };
    if (meeting.status === "full" && nextCount < meeting.maxMembers) {
      patch.status = "open";
    }
    tx.delete(memberRef);
    tx.update(ref, patch);
  });

  return { left: true };
}

function mapChatMessage(doc) {
  const message = doc.data();
  return {
    messageId: doc.id,
    senderId: message.senderId,
    nickname: message.nickname,
    body: message.body,
    createdAt: message.createdAt,
  };
}

async function queryMessages(collectionRef, options, limit) {
  let query = collectionRef.orderBy("createdAt", "desc");
  if (options.before) {
    const beforeIso = parseIso(options.before, "before");
    query = query.where("createdAt", "<", beforeIso);
  }
  const snap = await query.limit(limit).get();
  return snap.docs.map(mapChatMessage).reverse();
}

async function getMessages(meetingId, userId, options = {}) {
  const { ref, data } = await getMeetingOrThrow(meetingId);

  if (!(await isMember(meetingId, userId))) {
    throw new MeetingError(403, "not-participant");
  }

  let limit = MSG_DEFAULT_LIMIT;
  if (options.limit != null) {
    const parsed = Number(options.limit);
    if (!Number.isInteger(parsed) || parsed < 1) {
      throw new MeetingError(400, "validation");
    }
    limit = Math.min(parsed, MSG_MAX_LIMIT);
  }

  const chatRoomId = await ensureChatRoomId(ref);
  let items = await queryMessages(
    getChatRoomRef(chatRoomId).collection(MESSAGES),
    options,
    limit
  );

  if (items.length === 0 && !options.before) {
    items = await queryMessages(ref.collection(MESSAGES), options, limit);
  }

  return { items, meetingStatus: data.status, chatRoomId };
}

async function verifyMeetingMember(meetingId, userId) {
  const { data } = await getMeetingOrThrow(meetingId);

  if (!(await isMember(meetingId, userId))) {
    throw new MeetingError(403, "not-participant");
  }

  return data;
}

function meetingRoom(meetingId) {
  return `meeting:${meetingId}`;
}

function toChatPayload(meetingId, result) {
  return {
    messageId: result.messageId,
    meetingId,
    chatRoomId: result.chatRoomId,
    senderId: result.message.senderId,
    nickname: result.message.nickname,
    body: result.message.body,
    createdAt: result.createdAt,
  };
}

async function createMessage(meetingId, userId, body) {
  const user = await findById(userId);
  if (!user) {
    throw new MeetingError(401, "unauthorized");
  }

  const { ref, data } = await getMeetingOrThrow(meetingId);

  if (!(await isMember(meetingId, userId))) {
    throw new MeetingError(403, "not-participant");
  }

  if (!ALIVE_STATUSES.has(data.status)) {
    throw new MeetingError(403, chatRejectCode(data.status));
  }

  if (typeof body !== "string") {
    throw new MeetingError(400, "validation");
  }

  const trimmedBody = body.trim();
  if (trimmedBody.length < BODY_MIN || trimmedBody.length > BODY_MAX) {
    throw new MeetingError(400, "validation");
  }

  const chatRoomId = await ensureChatRoomId(ref);
  const createdAt = nowIso();
  const messageRef = getChatRoomRef(chatRoomId).collection(MESSAGES).doc();
  const messageData = {
    type: "chat_message",
    chatRoomId,
    meetingId,
    senderId: userId,
    nickname: user.nickname,
    body: trimmedBody,
    createdAt,
  };

  await messageRef.set(messageData);

  return {
    messageId: messageRef.id,
    chatRoomId,
    createdAt,
    message: messageData,
  };
}

module.exports = {
  MeetingError,
  createMeeting,
  listMeetings,
  listMyMeetings,
  getMeetingDetail,
  cancelMeeting,
  expireMeeting,
  finishMeeting,
  joinMeeting,
  leaveMeeting,
  getMessages,
  createMessage,
  verifyMeetingMember,
  meetingRoom,
  toChatPayload,
  CATEGORIES,
  MEETING_MODES,
  STATUSES,
  MEETINGS,
  CHAT_ROOMS,
  MEMBERS,
  MESSAGES,
};
