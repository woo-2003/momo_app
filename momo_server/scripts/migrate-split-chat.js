/**
 * 기존 meetings 문서를 모임/채팅 분리 스키마로 맞춘다.
 *
 *   node scripts/migrate-split-chat.js
 *
 * - meetings 문서에 type, meetingId, chatRoomId, memberIds, members 채움
 * - members 서브컬렉션에 GPS 자리 필드 채움
 * - meetings/{id}/messages → chat_rooms/{chatRoomId}/messages 복사
 */
require("dotenv").config();

const { getFirestore } = require("../firebase");
const {
  MEETINGS,
  CHAT_ROOMS,
  MEMBERS,
  MESSAGES,
} = require("../services/meetingService");

function nowIso() {
  return new Date().toISOString();
}

function toParticipantIdentity(data) {
  return {
    userId: data.userId,
    nickname: data.nickname,
    role: data.role,
    joinedAt: data.joinedAt,
  };
}

async function migrateMeeting(db, meetingDoc) {
  const meetingRef = meetingDoc.ref;
  const data = meetingDoc.data() || {};
  const meetingId = meetingDoc.id;

  const membersSnap = await meetingRef.collection(MEMBERS).get();
  const memberIds = [];
  const members = [];

  for (const memberDoc of membersSnap.docs) {
    const member = memberDoc.data() || {};
    const userId = member.userId || memberDoc.id;
    memberIds.push(userId);
    members.push(
      toParticipantIdentity({
        userId,
        nickname: member.nickname || "",
        role: member.role || "member",
        joinedAt: member.joinedAt || nowIso(),
      })
    );

    await memberDoc.ref.set(
      {
        lastLatitude: member.lastLatitude ?? null,
        lastLongitude: member.lastLongitude ?? null,
        locationUpdatedAt: member.locationUpdatedAt ?? null,
      },
      { merge: true }
    );
  }

  let chatRoomId = data.chatRoomId;
  if (!chatRoomId) {
    const chatRoomRef = db.collection(CHAT_ROOMS).doc();
    chatRoomId = chatRoomRef.id;
    await chatRoomRef.set({
      type: "chat_room",
      meetingId,
      status: data.status || "open",
      createdAt: data.createdAt || nowIso(),
    });
  }

  const legacyMessages = await meetingRef.collection(MESSAGES).get();
  const chatMessages = db
    .collection(CHAT_ROOMS)
    .doc(chatRoomId)
    .collection(MESSAGES);

  let copied = 0;
  for (const messageDoc of legacyMessages.docs) {
    const existing = await chatMessages.doc(messageDoc.id).get();
    if (existing.exists) continue;
    const message = messageDoc.data() || {};
    await chatMessages.doc(messageDoc.id).set({
      type: "chat_message",
      chatRoomId,
      meetingId,
      senderId: message.senderId,
      nickname: message.nickname,
      body: message.body,
      createdAt: message.createdAt,
    });
    copied += 1;
  }

  await meetingRef.set(
    {
      type: "meeting",
      meetingId,
      chatRoomId,
      memberIds,
      members,
    },
    { merge: true }
  );

  return { meetingId, chatRoomId, memberCount: memberIds.length, copied };
}

async function main() {
  const db = getFirestore();
  const snap = await db.collection(MEETINGS).get();
  console.log(`meetings: ${snap.size}`);

  for (const doc of snap.docs) {
    const result = await migrateMeeting(db, doc);
    console.log(
      `migrated ${result.meetingId} chatRoom=${result.chatRoomId} members=${result.memberCount} messagesCopied=${result.copied}`
    );
  }

  console.log("migrate-split-chat DONE");
}

main().catch((error) => {
  console.error("migrate-split-chat FAILED:", error);
  process.exit(1);
});
