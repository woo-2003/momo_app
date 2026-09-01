/**
 * 모임 API 스모크 테스트 (HTTP).
 * 서버가 떠 있어야 한다: npm start
 *
 *   node scripts/smoke-meetings.js
 *
 * 환경변수 (선택):
 *   SMOKE_BASE_URL   기본 http://localhost:3000
 *   SMOKE_EMAIL      테스트 계정 이메일
 *   SMOKE_PASSWORD   테스트 계정 비밀번호
 */
require("dotenv").config();

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

async function main() {
  console.log(`BASE_URL=${BASE_URL}`);

  const unauth = await request("GET", "/meetings");
  assert(unauth.status === 401, `비로그인 목록 조회는 401, got ${unauth.status}`);
  console.log("unauthorized GET /meetings OK");

  if (!EMAIL || !PASSWORD) {
    console.log(
      "SMOKE_EMAIL / SMOKE_PASSWORD 미설정 — 401 검증만 완료. 전체 플로우는 계정 설정 후 재실행."
    );
    console.log("smoke-meetings PARTIAL PASSED");
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
      title: `smoke-${Date.now()}`,
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

  const list = await request("GET", "/meetings", { token });
  assert(list.status === 200 && Array.isArray(list.data.items), "list failed");
  assert(
    list.data.items.some((item) => item.meetingId === meetingId),
    "created meeting not in list"
  );
  console.log("list meetings OK");

  const detail = await request("GET", `/meetings/${meetingId}`, { token });
  assert(detail.status === 200 && detail.data.isHost === true, "detail failed");
  console.log("get detail OK");

  const message = await request("POST", `/meetings/${meetingId}/messages`, {
    token,
    body: { body: "smoke test message" },
  });
  assert(message.status === 201 && message.data.messageId, "post message failed");
  console.log("post message OK");

  const messages = await request("GET", `/meetings/${meetingId}/messages`, {
    token,
  });
  assert(
    messages.status === 200 &&
      messages.data.items.some((m) => m.body === "smoke test message"),
    "get messages failed"
  );
  console.log("get messages OK");

  const cancelled = await request("POST", `/meetings/${meetingId}/cancel`, {
    token,
  });
  assert(cancelled.status === 200, "cancel failed");
  console.log("cancel meeting OK");

  const listAfterCancel = await request("GET", "/meetings", { token });
  assert(
    !listAfterCancel.data.items.some((item) => item.meetingId === meetingId),
    "cancelled meeting still in list"
  );
  console.log("cancelled excluded from list OK");

  const postAfterCancel = await request("POST", `/meetings/${meetingId}/messages`, {
    token,
    body: { body: "should fail" },
  });
  assert(
    postAfterCancel.status === 403 && postAfterCancel.data.message === "meeting-cancelled",
    "post after cancel should be 403 meeting-cancelled"
  );
  console.log("post after cancel blocked OK");

  console.log("smoke-meetings PASSED");
}

main().catch((e) => {
  console.error("smoke-meetings FAILED:", e.message);
  process.exit(1);
});
