// 우영: 카카오 로컬(REST) 호출 서비스 추가함. 키는 .env 의 KAKAO_REST_API_KEY 만 사용.
// 우영: 앱에서 카카오 키를 직접 쓰지 않고 서버가 대신 호출함 (유출 방지).

const KAKAO_BASE = "https://dapi.kakao.com";

class KakaoLocalError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.name = "KakaoLocalError";
    this.statusCode = statusCode;
    this.message = message;
  }
}

function getRestApiKey() {
  const key = process.env.KAKAO_REST_API_KEY;
  if (!key || !String(key).trim()) {
    throw new KakaoLocalError(
      503,
      "KAKAO_REST_API_KEY 가 설정되지 않았습니다."
    );
  }
  return String(key).trim();
}

async function kakaoGet(path, query) {
  const key = getRestApiKey();
  const url = new URL(`${KAKAO_BASE}${path}`);
  for (const [k, v] of Object.entries(query)) {
    if (v != null && v !== "") url.searchParams.set(k, String(v));
  }

  let response;
  try {
    response = await fetch(url, {
      method: "GET",
      headers: {
        Authorization: `KakaoAK ${key}`,
      },
    });
  } catch (e) {
    throw new KakaoLocalError(502, "카카오 API 네트워크 오류");
  }

  let body;
  try {
    body = await response.json();
  } catch {
    body = {};
  }

  if (!response.ok) {
    const msg =
      body.message ||
      body.errorMessage ||
      (response.status === 429
        ? "카카오 API 쿼터 초과"
        : "카카오 API 요청 실패");
    throw new KakaoLocalError(response.status === 429 ? 429 : 502, msg);
  }

  return body;
}

/**
 * 좌표 → 주소 (도로명 우선, 없으면 지번).
 * @returns {{ label: string, roadAddress: string|null, address: string|null }}
 */
async function reverseGeocode(latitude, longitude) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw new KakaoLocalError(400, "validation");
  }

  // 우영: 카카오는 x=경도, y=위도 순서임.
  const data = await kakaoGet("/v2/local/geo/coord2address.json", {
    x: lng,
    y: lat,
  });

  const doc = Array.isArray(data.documents) ? data.documents[0] : null;
  if (!doc) {
    return {
      label: "주소를 찾을 수 없는 위치",
      roadAddress: null,
      address: null,
    };
  }

  const road = doc.road_address?.address_name || null;
  const jibun = doc.address?.address_name || null;
  const label = road || jibun || "주소를 찾을 수 없는 위치";

  return {
    label,
    roadAddress: road,
    address: jibun,
  };
}

/**
 * 키워드 장소 검색.
 * @returns {Array<{ id: string, name: string, address: string, latitude: number, longitude: number }>}
 */
async function searchKeyword(query, { size = 15 } = {}) {
  const q = typeof query === "string" ? query.trim() : "";
  if (!q) {
    throw new KakaoLocalError(400, "validation");
  }

  const limit = Math.min(Math.max(Number(size) || 15, 1), 15);
  const data = await kakaoGet("/v2/local/search/keyword.json", {
    query: q,
    size: limit,
  });

  const docs = Array.isArray(data.documents) ? data.documents : [];
  return docs.map((doc) => ({
    id: String(doc.id || ""),
    name: String(doc.place_name || ""),
    address: String(
      doc.road_address_name || doc.address_name || ""
    ),
    latitude: Number(doc.y),
    longitude: Number(doc.x),
  }));
}

module.exports = {
  KakaoLocalError,
  reverseGeocode,
  searchKeyword,
};
