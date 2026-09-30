// 우영: 장소 검색/역지오코딩 라우트 추가함. JWT 필요. 카카오는 kakaoLocalService 경유.
const express = require("express");

const { authMiddleware } = require("../middleware/auth");
const {
  KakaoLocalError,
  reverseGeocode,
  searchKeyword,
} = require("../services/kakaoLocalService");

const router = express.Router();

router.use(authMiddleware);

function handlePlaceError(res, error) {
  if (error instanceof KakaoLocalError) {
    return res.status(error.statusCode).json({
      success: false,
      message: error.message,
    });
  }

  console.error("place route error:", error);
  return res.status(500).json({
    success: false,
    message: "server error",
    error: error.toString(),
  });
}

// 우영: GET /places/reverse?lat=&lng= — 지도 핀 좌표 → 주소
router.get("/places/reverse", async (req, res) => {
  try {
    const result = await reverseGeocode(req.query.lat, req.query.lng);
    return res.status(200).json({
      success: true,
      ...result,
    });
  } catch (e) {
    return handlePlaceError(res, e);
  }
});

// 우영: GET /places/search?q= — 키워드 장소 검색
router.get("/places/search", async (req, res) => {
  try {
    const q = req.query.q ?? req.query.query;
    const items = await searchKeyword(q, { size: req.query.size });
    return res.status(200).json({
      success: true,
      items,
    });
  } catch (e) {
    return handlePlaceError(res, e);
  }
});

module.exports = router;
