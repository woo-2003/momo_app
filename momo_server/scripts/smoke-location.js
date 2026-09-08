/**
 * GPS 위치 API 스모크 (HTTP). JWT + 멤버만 허용.
 * 서버가 떠 있어야 한다: npm start
 *
 *   node scripts/smoke-location.js
 *
 * 환경변수 (선택):
 *   SMOKE_EMAIL / SMOKE_PASSWORD  있으면 개설 후 위치 올리기까지 검증
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

function locationBody(meetingId) {
  const now = Date.now() / 1000;
  return {
    meetingId,
    prev_lat: 37.5665,
    prev_lon: 126.978,
    prev_time: now - 5,
    curr_lat: 37.5666,
    curr_lon: 126.9781,
    curr_time: now,
  };
}

async function main() {
  console.log(`BASE_URL=${BASE_URL}`);

  const unauthPost = await request("POST", "/meeting/location", { body: {} });
  assert(
    unauthPost.status === 401,
    `비로그인 POST 는 401, got ${unauthPost.status} ${JSON.stringify(unauthPost.data)}`
  );
  console.log("unauthorized POST /meeting/location OK");

  const unauthGet = await request("GET", "/meeting/x/members");
  assert(
    unauthGet.status === 401,
    `비로그인 GET 은 401, got ${unauthGet.status}`
  );
  console.log("unauthorized GET /meeting/:id/members OK");

  if (!EMAIL || !PASSWORD) {
    console.log(
      "SMOKE_EMAIL / SMOKE_PASSWORD 미설정 — 401 검증만 완료. 전체 플로우는 계정 설정 후 재실행."
    );
    console.log("smoke-location PARTIAL PASSED");
    return;
  }

  const login = await request("POST", "/login", {
    body: { email: EMAIL, password: PASSWORD },
  });
  assert(login.status === 200 && login.data.token, "login failed");
  const token = login.data.token;
  console.log("login OK");

  const unknownMeeting = await request("POST", "/meeting/location", {
    token,
    body: locationBody("missing-meeting-for-smoke"),
  });
  assert(
    unknownMeeting.status === 404 &&
      unknownMeeting.data.detail === "존재하지 않는 모임입니다.",
    `없는 모임은 404, got ${unknownMeeting.status} ${JSON.stringify(unknownMeeting.data)}`
  );
  console.log("POST /meeting/location unknown meeting OK");

  const created = await request("POST", "/meetings", {
    token,
    body: {
      title: `gps-smoke-${Date.now()}`,
      category: "taxi",
      meetingMode: "offline",
      placeName: "서울시청",
      latitude: 37.5665,
      longitude: 126.978,
      startAt: new Date(Date.now() + 3600000).toISOString(),
      maxMembers: 4,
      categoryFields: { destinationName: "강남역" },
    },
  });
  assert(created.status === 201 && created.data.meetingId, "create meeting failed");
  const meetingId = created.data.meetingId;
  console.log("create offline meeting OK:", meetingId);

  const posted = await request("POST", "/meeting/location", {
    token,
    body: locationBody(meetingId),
  });
  assert(
    posted.status === 200 &&
      posted.data.result === "success" &&
      typeof posted.data.user_status === "string",
    `위치 전송 실패, got ${posted.status} ${JSON.stringify(posted.data)}`
  );
  console.log("POST /meeting/location as member OK:", posted.data.user_status);

  const members = await request("GET", `/meeting/${meetingId}/members`, {
    token,
  });
  assert(
    members.status === 200 &&
      members.data.meetingId === meetingId &&
      members.data.members &&
      Object.keys(members.data.members).length >= 1,
    `멤버 조회 실패, got ${members.status} ${JSON.stringify(members.data)}`
  );
  console.log("GET /meeting/:id/members as member OK");

  console.log("smoke-location PASSED");
}

main().catch((error) => {
  console.error("smoke-location FAILED:", error.message);
  process.exit(1);
});
