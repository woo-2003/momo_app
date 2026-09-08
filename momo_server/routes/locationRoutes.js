// 모임 GPS HTTP. JWT + 모임 멤버만 위치 공유·조회.
const express = require("express");

const { authMiddleware } = require("../middleware/auth");
const {
  LocationError,
  ingestLocation,
  getRoomMembers,
} = require("../services/locationService");

const router = express.Router();

function handleLocationError(res, error) {
  if (error instanceof LocationError) {
    return res.status(error.statusCode).json({ detail: error.detail });
  }

  console.error("location route error:", error);
  return res.status(500).json({ detail: error.message });
}

router.use(authMiddleware);

// POST /meeting/location — 위치 수신 후 상태 계산·메모리 저장
router.post("/meeting/location", async (req, res) => {
  try {
    const result = await ingestLocation(req.body, req.user.id);
    return res.json(result);
  } catch (error) {
    return handleLocationError(res, error);
  }
});

// GET /meeting/:meetingId/members — 모임방 멤버 위치·상태
router.get("/meeting/:meetingId/members", async (req, res) => {
  try {
    return res.json(await getRoomMembers(req.params.meetingId, req.user.id));
  } catch (error) {
    return handleLocationError(res, error);
  }
});

module.exports = router;
