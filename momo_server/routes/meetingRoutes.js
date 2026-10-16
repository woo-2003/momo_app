// 모임·멤버·메시지 HTTP 라우트 (JWT 보호).
// 명세: docs/모임채팅_프로토타입_기술명세서.md
const express = require("express");

const { authMiddleware } = require("../middleware/auth");
const {
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
} = require("../services/meetingService");

const router = express.Router();

function handleMeetingError(res, error) {
  if (error instanceof MeetingError) {
    return res.status(error.statusCode).json({
      success: false,
      message: error.message,
    });
  }

  console.error("meeting route error:", error);
  return res.status(500).json({
    success: false,
    message: "server error",
    error: error.toString(),
  });
}

router.use(authMiddleware);

// POST /meetings — 생성
router.post("/meetings", async (req, res) => {
  try {
    const result = await createMeeting(req.user.id, req.body);
    return res.status(201).json({
      success: true,
      meetingId: result.meetingId,
      chatRoomId: result.chatRoomId,
      status: result.status,
      createdAt: result.createdAt,
    });
  } catch (e) {
    return handleMeetingError(res, e);
  }
});

// GET /meetings — 목록 (open, full)
router.get("/meetings", async (req, res) => {
  try {
    const items = await listMeetings({
      category: req.query.category,
      meetingMode: req.query.meetingMode,
    });
    return res.status(200).json({ success: true, items });
  } catch (e) {
    return handleMeetingError(res, e);
  }
});

// GET /meetings/mine — 내가 속한 모임 (폭파·종료·취소 포함). :id 보다 앞에 둔다.
router.get("/meetings/mine", async (req, res) => {
  try {
    const items = await listMyMeetings(req.user.id);
    return res.status(200).json({ success: true, items });
  } catch (e) {
    return handleMeetingError(res, e);
  }
});

// GET /meetings/:id — 상세
router.get("/meetings/:id", async (req, res) => {
  try {
    const detail = await getMeetingDetail(req.params.id, req.user.id);
    return res.status(200).json({ success: true, ...detail });
  } catch (e) {
    return handleMeetingError(res, e);
  }
});

// POST /meetings/:id/cancel — 파기
router.post("/meetings/:id/cancel", async (req, res) => {
  try {
    const result = await cancelMeeting(req.params.id, req.user.id);
    return res.status(200).json({
      success: true,
      status: result.status,
      cancelledAt: result.cancelledAt,
    });
  } catch (e) {
    return handleMeetingError(res, e);
  }
});

// POST /meetings/:id/expire — 생명주기 폭파
router.post("/meetings/:id/expire", async (req, res) => {
  try {
    const result = await expireMeeting(req.params.id, req.user.id);
    return res.status(200).json({
      success: true,
      status: result.status,
      expiredAt: result.expiredAt,
    });
  } catch (e) {
    return handleMeetingError(res, e);
  }
});

// POST /meetings/:id/finish — 모임 종료
router.post("/meetings/:id/finish", async (req, res) => {
  try {
    const result = await finishMeeting(req.params.id, req.user.id);
    return res.status(200).json({
      success: true,
      status: result.status,
      finishedAt: result.finishedAt,
    });
  } catch (e) {
    return handleMeetingError(res, e);
  }
});

// POST /meetings/:id/join — 참여
router.post("/meetings/:id/join", async (req, res) => {
  try {
    const result = await joinMeeting(req.params.id, req.user.id);
    if (result.alreadyMember) {
      return res.status(200).json({
        success: true,
        alreadyMember: true,
      });
    }
    return res.status(200).json({ success: true });
  } catch (e) {
    return handleMeetingError(res, e);
  }
});

// POST /meetings/:id/leave — 나가기
router.post("/meetings/:id/leave", async (req, res) => {
  try {
    await leaveMeeting(req.params.id, req.user.id);
    return res.status(200).json({ success: true });
  } catch (e) {
    return handleMeetingError(res, e);
  }
});

// GET /meetings/:id/messages — 채팅 조회
router.get("/meetings/:id/messages", async (req, res) => {
  try {
    const result = await getMessages(req.params.id, req.user.id, {
      limit: req.query.limit,
      before: req.query.before,
    });
    return res.status(200).json({
      success: true,
      items: result.items,
    });
  } catch (e) {
    return handleMeetingError(res, e);
  }
});

// POST /meetings/:id/messages — 채팅 전송
router.post("/meetings/:id/messages", async (req, res) => {
  try {
    const { body } = req.body || {};
    const result = await createMessage(req.params.id, req.user.id, body);
    return res.status(201).json({
      success: true,
      messageId: result.messageId,
      createdAt: result.createdAt,
    });
  } catch (e) {
    return handleMeetingError(res, e);
  }
});

module.exports = router;
