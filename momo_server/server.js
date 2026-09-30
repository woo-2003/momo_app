// momo_server 진입점. OTP + 인증 HTTP + 모임 API + GPS + Socket.IO 채팅.
// STORAGE=firestore|sqlite. 모임/실시간 채팅/GPS는 firestore 전용.
// 우영: 장소 API(placeRoutes · 카카오 로컬) 추가함. 기존 라우트는 유지.
require("dotenv").config();

const http = require("http");
const express = require("express");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());

const storage = (process.env.STORAGE || "firestore").toLowerCase();

app.get("/", (req, res) => {
  res.send(
    `OTP server is running (storage=${storage}, meetings=${storage === "firestore" ? "enabled" : "disabled"})`
  );
});

const otpRoutes = require("./routes/otpRoutes");
app.use("/", otpRoutes);

const authRoutes = require("./routes/authRoutes");
app.use("/", authRoutes);

// 우영: 카카오 로컬 장소 API(검색/역지오코딩) 라우트 추가함. 기존 OTP·인증·모임과 무관.
const placeRoutes = require("./routes/placeRoutes");
app.use("/", placeRoutes);

if (storage === "firestore") {
  const meetingRoutes = require("./routes/meetingRoutes");
  app.use("/", meetingRoutes);

  const locationRoutes = require("./routes/locationRoutes");
  app.use("/", locationRoutes);
} else {
  console.warn(
    "STORAGE=sqlite — 모임 API는 비활성화됩니다. STORAGE=firestore 로 전환하세요."
  );
}

const PORT = process.env.PORT || 3000;

// 직접 실행할 때만 서버를 띄운다 (테스트에서 app 재사용 가능하도록 export)
if (require.main === module) {
  console.log(`STORAGE=${storage}`);

  if (storage === "firestore") {
    try {
      require("./firebase").getFirestore();
      console.log("Firestore connected");
    } catch (e) {
      console.error(
        "Firestore 초기화 실패. secrets/firebase-service-account.json 과 .env 의 FIREBASE_* 를 확인하세요."
      );
      console.error(e.message);
      process.exit(1);
    }
  }

  const httpServer = http.createServer(app);

  if (storage === "firestore") {
    const { initChatSocket } = require("./realtime/chatSocket");
    initChatSocket(httpServer);
    console.log("Socket.IO chat enabled");
  }

  httpServer.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

module.exports = app;
