/**
 * Socket.IO 채팅 스모크 테스트.
 * 서버 실행 중 + SMOKE_EMAIL/SMOKE_PASSWORD 필요.
 *
 *   npm run smoke:socket
 */
require("dotenv").config();

const { io } = require("socket.io-client");

const BASE_URL = process.env.SMOKE_BASE_URL || "http://localhost:3000";
const EMAIL = process.env.SMOKE_EMAIL;
const PASSWORD = process.env.SMOKE_PASSWORD;

async function request(method, path, { token, body } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { raw: text };
  }

  return { status: response.status, data };
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function waitForEvent(socket, eventName, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`timeout waiting for ${eventName}`));
    }, timeoutMs);

    socket.once(eventName, (payload) => {
      clearTimeout(timer);
      resolve(payload);
    });
  });
}

async function main() {
  console.log(`BASE_URL=${BASE_URL}`);

  if (!EMAIL || !PASSWORD) {
    console.log(
      "SMOKE_EMAIL / SMOKE_PASSWORD 미설정 — socket 스모크는 계정 설정 후 실행하세요."
    );
    console.log("smoke-socket SKIPPED");
    return;
  }

  const login = await request("POST", "/login", {
    body: { email: EMAIL, password: PASSWORD },
  });
  assert(login.status === 200 && login.data.token, "login failed");
  const token = login.data.token;
  console.log("login OK");

  const created = await request("POST", "/meetings", {
    token,
    body: {
      title: `socket-smoke-${Date.now()}`,
      category: "game",
      meetingMode: "online",
      startAt: new Date(Date.now() + 3600000).toISOString(),
      maxMembers: 4,
      categoryFields: { gameName: "lol" },
    },
  });
  assert(created.status === 201 && created.data.meetingId, "create meeting failed");
  const meetingId = created.data.meetingId;
  console.log("create meeting OK:", meetingId);

  const socket = io(BASE_URL, {
    auth: { token },
    transports: ["websocket"],
  });

  await new Promise((resolve, reject) => {
    socket.on("connect", resolve);
    socket.on("connect_error", reject);
  });
  console.log("socket connected");

  const joinAck = await new Promise((resolve) => {
    socket.emit("join", { meetingId }, resolve);
  });
  assert(joinAck?.success === true, `join failed: ${JSON.stringify(joinAck)}`);
  console.log("join OK");

  const chatPromise = waitForEvent(socket, "chat");
  socket.emit("chat", {
    meetingId,
    body: `socket smoke ${Date.now()}`,
  });

  const chatPayload = await chatPromise;
  assert(chatPayload.meetingId === meetingId, "chat meetingId mismatch");
  assert(chatPayload.body?.includes("socket smoke"), "chat body mismatch");
  console.log("chat broadcast OK:", chatPayload.messageId);

  socket.emit("leave", { meetingId });
  socket.disconnect();
  console.log("smoke-socket PASSED");
}

main().catch((e) => {
  console.error("smoke-socket FAILED:", e.message);
  process.exit(1);
});
