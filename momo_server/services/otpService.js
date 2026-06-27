const otpStore = new Map();

const OTP_VALIDITY_MS = 5 * 60 * 1000;
const RESEND_LIMIT_MS = 60 * 1000;

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function createOtpForEmail(email) {
  const now = Date.now();
  const saved = otpStore.get(email);

  // 같은 이메일의 재전송 요청을 60초 동안 제한한다.
  if (saved && now - saved.lastSentAt < RESEND_LIMIT_MS) {
    return {
      ok: false,
      statusCode: 429,
      message: "Too many requests",
      error: "RESEND_LIMIT",
    };
  }

  const otp = generateOtp();
  const entry = {
    otp,
    expiry: now + OTP_VALIDITY_MS,
    verified: false,
    lastSentAt: now,
  };

  otpStore.set(email, entry);

  return {
    ok: true,
    otp,
    expiry: entry.expiry,
  };
}

function verifyOtpForEmail(email, code) {
  const saved = otpStore.get(email);

  if (!saved) {
    return { ok: false, statusCode: 404, message: "OTP not found" };
  }

  if (saved.verified) {
    return { ok: false, statusCode: 400, message: "Already verified" };
  }

  if (Date.now() > saved.expiry) {
    // 만료된 OTP는 즉시 삭제해 다음 요청에서 not found로 처리되도록 한다.
    otpStore.delete(email);
    return { ok: false, statusCode: 400, message: "OTP expired" };
  }

  if (saved.otp !== code) {
    return { ok: false, statusCode: 401, message: "Wrong OTP" };
  }

  otpStore.set(email, {
    ...saved,
    otp: null,
    verified: true,
  });

  return { ok: true };
}

// 해당 이메일이 OTP 인증을 통과한 상태인지 확인 (가입 우회 방지용)
function isEmailVerified(email) {
  const saved = otpStore.get(email);
  return Boolean(saved && saved.verified);
}

// 가입 완료 후 해당 이메일의 OTP 상태를 제거해 재사용을 막는다.
function clearOtpForEmail(email) {
  otpStore.delete(email);
}

module.exports = {
  createOtpForEmail,
  verifyOtpForEmail,
  isEmailVerified,
  clearOtpForEmail,
};
