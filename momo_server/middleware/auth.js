const jwt = require("jsonwebtoken");

const { JWT_SECRET } = process.env;

if (!JWT_SECRET) {
  throw new Error(
    "JWT_SECRET 환경변수가 설정되지 않았습니다. .env 파일을 확인하세요."
  );
}

/**
 * JWT 문자열을 검증하고 사용자 정보를 반환한다.
 * 실패 시 null.
 */
function verifyAccessToken(token) {
  if (!token || typeof token !== "string") {
    return null;
  }

  try {
    const payload = jwt.verify(token.trim(), JWT_SECRET);
    if (!payload.sub) {
      return null;
    }

    return {
      id: payload.sub,
      email: payload.email,
    };
  } catch {
    return null;
  }
}

/**
 * Bearer JWT 검증 미들웨어.
 * 성공 시 req.user = { id: sub, email } 를 설정한다.
 */
function authMiddleware(req, res, next) {
  const header = req.headers.authorization;

  if (!header || !header.startsWith("Bearer ")) {
    return res.status(401).json({
      success: false,
      message: "unauthorized",
    });
  }

  const user = verifyAccessToken(header.slice("Bearer ".length));
  if (!user) {
    return res.status(401).json({
      success: false,
      message: "unauthorized",
    });
  }

  req.user = user;
  return next();
}

module.exports = { authMiddleware, verifyAccessToken };
