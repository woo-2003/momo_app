const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

const {
  findByEmail,
  isNicknameTaken,
  createUser,
  ConflictError,
} = require("../services/userService");
const { isEmailVerified, clearOtpForEmail } = require("../services/otpService");

const router = express.Router();

const { JWT_SECRET } = process.env;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "7d";

if (!JWT_SECRET) {
  throw new Error(
    "JWT_SECRET 환경변수가 설정되지 않았습니다. .env 파일을 확인하세요."
  );
}

const PASSWORD_MIN_LENGTH = 8;
const NICKNAME_MIN_LENGTH = 2;
const NICKNAME_MAX_LENGTH = 10;
const BCRYPT_ROUNDS = 10;

const EMAIL_REGEX = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
const BIRTHDATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

function isValidNickname(nickname) {
  const length = nickname.trim().length;
  return length >= NICKNAME_MIN_LENGTH && length <= NICKNAME_MAX_LENGTH;
}

function isConflictError(e) {
  return (
    e &&
    (e.code === "USER_CONFLICT" ||
      e.code === "SQLITE_CONSTRAINT_UNIQUE" ||
      e instanceof ConflictError)
  );
}

// 닉네임 중복 확인
router.get("/check-nickname", async (req, res) => {
  try {
    const nickname = (req.query.nickname || "").toString().trim();

    if (!nickname) {
      return res.status(400).json({
        success: false,
        message: "nickname is required",
      });
    }

    if (!isValidNickname(nickname)) {
      return res.status(400).json({
        success: false,
        available: false,
        message: "닉네임은 2~10자여야 합니다.",
      });
    }

    const taken = await isNicknameTaken(nickname);
    return res.status(200).json({
      success: true,
      available: !taken,
      message: taken ? "이미 사용 중인 닉네임입니다." : "사용 가능한 닉네임입니다!",
    });
  } catch (e) {
    console.error("check-nickname error:", e);
    return res.status(500).json({
      success: false,
      message: "server error",
      error: e.toString(),
    });
  }
});

// 회원가입 완료
router.post("/signup", async (req, res) => {
  console.log("POST /signup body:", { ...req.body, password: "***" });
  try {
    const { email, password, nickname, birthdate } = req.body;

    if (!email || !password || !nickname || !birthdate) {
      return res.status(400).json({
        success: false,
        message: "email, password, nickname, birthdate are required",
      });
    }

    if (!EMAIL_REGEX.test(email)) {
      return res.status(400).json({
        success: false,
        message: "올바른 이메일 형식이 아닙니다.",
      });
    }

    if (password.length < PASSWORD_MIN_LENGTH) {
      return res.status(400).json({
        success: false,
        message: `비밀번호는 ${PASSWORD_MIN_LENGTH}자 이상이어야 합니다.`,
      });
    }

    if (!isValidNickname(nickname)) {
      return res.status(400).json({
        success: false,
        message: "닉네임은 2~10자여야 합니다.",
      });
    }

    if (!BIRTHDATE_REGEX.test(birthdate)) {
      return res.status(400).json({
        success: false,
        message: "생년월일 형식이 올바르지 않습니다. (YYYY-MM-DD)",
      });
    }

    // 가입 우회 방지: 반드시 OTP 인증을 통과한 이메일만 허용
    if (!isEmailVerified(email)) {
      return res.status(403).json({
        success: false,
        message: "이메일 인증이 필요합니다.",
      });
    }

    if (await findByEmail(email)) {
      return res.status(409).json({
        success: false,
        message: "이미 가입된 이메일입니다.",
      });
    }

    if (await isNicknameTaken(nickname)) {
      return res.status(409).json({
        success: false,
        message: "이미 사용 중인 닉네임입니다.",
      });
    }

    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

    let userId;
    try {
      userId = await createUser({
        email: email.trim(),
        passwordHash,
        nickname: nickname.trim(),
        birthdate,
      });
    } catch (e) {
      if (isConflictError(e)) {
        return res.status(409).json({
          success: false,
          message: "이미 사용 중인 이메일 또는 닉네임입니다.",
        });
      }
      throw e;
    }

    // 가입 완료 후 OTP 상태 제거 (재사용 방지)
    clearOtpForEmail(email);

    console.log("User created:", userId, email);

    return res.status(201).json({
      success: true,
      message: "회원가입이 완료되었습니다.",
      userId,
    });
  } catch (e) {
    console.error("signup error:", e);
    return res.status(500).json({
      success: false,
      message: "server error",
      error: e.toString(),
    });
  }
});

// 로그인
router.post("/login", async (req, res) => {
  console.log("POST /login body:", { ...req.body, password: "***" });
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "email and password are required",
      });
    }

    const user = await findByEmail(email);

    // 계정 존재 여부와 무관하게 동일한 메시지로 응답 (계정 열거 방지)
    const invalidResponse = () =>
      res.status(401).json({
        success: false,
        message: "이메일 또는 비밀번호가 올바르지 않습니다.",
      });

    if (!user) {
      return invalidResponse();
    }

    const matched = await bcrypt.compare(password, user.password_hash);
    if (!matched) {
      return invalidResponse();
    }

    const token = jwt.sign(
      { sub: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    console.log("Login success for", user.email);

    return res.status(200).json({
      success: true,
      message: "로그인 되었습니다.",
      token,
      user: {
        id: user.id,
        email: user.email,
        nickname: user.nickname,
      },
    });
  } catch (e) {
    console.error("login error:", e);
    return res.status(500).json({
      success: false,
      message: "server error",
      error: e.toString(),
    });
  }
});

module.exports = router;
