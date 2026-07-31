const express = require("express");
const nodemailer = require("nodemailer");

const { createOtpForEmail, verifyOtpForEmail } = require("../services/otpService");

const router = express.Router();

const { GMAIL_USER, GMAIL_APP_PASSWORD } = process.env;

if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
  throw new Error(
    "GMAIL_USER / GMAIL_APP_PASSWORD 환경변수가 설정되지 않았습니다. .env 파일을 확인하세요."
  );
}

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: GMAIL_USER,
    pass: GMAIL_APP_PASSWORD,
  },
});

router.post("/send-email-otp", async (req, res) => {
  console.log("POST /send-email-otp body:", req.body);
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        success: false,
        message: "email is required",
      });
    }

    const created = createOtpForEmail(email);
    if (!created.ok) {
      return res.status(created.statusCode).json({
        success: false,
        message: created.message,
        error: created.error,
      });
    }

    console.log("Generated OTP:", created.otp, "for email:", email);

    await transporter.sendMail({
      from: GMAIL_USER,
      to: email,
      subject: "회원가입 인증번호",
      text: `인증번호는 ${created.otp} 입니다. 5분 안에 입력해주세요.`,
    });

    console.log("Email sent to", email);

    return res.status(200).json({
      success: true,
      message: "OTP sent successfully",
    });
  } catch (e) {
    console.error("send-email-otp error:", e);
    return res.status(500).json({
      success: false,
      message: "server error",
      error: e.toString(),
    });
  }
});

router.post("/verify-email-otp", (req, res) => {
  console.log("POST /verify-email-otp body:", req.body);
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      return res.status(400).json({
        success: false,
        message: "email and code are required",
      });
    }

    const verified = verifyOtpForEmail(email, code);
    if (!verified.ok) {
      return res.status(verified.statusCode).json({
        success: false,
        message: verified.message,
      });
    }

    console.log("OTP verified for", email);

    return res.status(200).json({
      success: true,
      message: "Email verified successfully",
    });
  } catch (e) {
    console.error("verify-email-otp error:", e);
    return res.status(500).json({
      success: false,
      message: "server error",
      error: e.toString(),
    });
  }
});

module.exports = router;
