/**
 * 우영: 장소 API 스모크 테스트 추가함.
 * 서버 실행 중 + SMOKE_EMAIL/SMOKE_PASSWORD + KAKAO_REST_API_KEY 필요.
 *
 *   npm run smoke:places
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

  const unauth = await request(
    "GET",
    "/places/reverse?lat=37.5665&lng=126.9780"
  );
  assert(unauth.status === 401, `비로그인 reverse는 401, got ${unauth.status}`);
  console.log("unauthorized GET /places/reverse OK");

  if (!EMAIL || !PASSWORD) {
    console.log(
      "SMOKE_EMAIL / SMOKE_PASSWORD 미설정 — 401 검증만 완료. 전체 플로우는 계정 설정 후 재실행."
    );
    console.log("smoke-places PARTIAL PASSED");
    return;
  }

  if (!process.env.KAKAO_REST_API_KEY) {
    throw new Error("KAKAO_REST_API_KEY 미설정");
  }

  const login = await request("POST", "/login", {
    body: { email: EMAIL, password: PASSWORD },
  });
  assert(login.status === 200 && login.data.token, "login failed");
  const token = login.data.token;
  console.log("login OK");

  const reverse = await request(
    "GET",
    "/places/reverse?lat=37.5665&lng=126.9780",
    { token }
  );
  assert(
    reverse.status === 200 && reverse.data.success === true && reverse.data.label,
    `reverse failed: ${JSON.stringify(reverse.data)}`
  );
  console.log("reverse OK:", reverse.data.label);

  const search = await request(
    "GET",
    `/places/search?q=${encodeURIComponent("성결대학교")}`,
    { token }
  );
  assert(
    search.status === 200 &&
      search.data.success === true &&
      Array.isArray(search.data.items) &&
      search.data.items.length > 0,
    `search failed: ${JSON.stringify(search.data)}`
  );
  console.log("search OK:", search.data.items[0].name);

  console.log("smoke-places PASSED");
}

main().catch((e) => {
  console.error("smoke-places FAILED:", e.message);
  process.exit(1);
});
