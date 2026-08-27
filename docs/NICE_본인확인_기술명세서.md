# momo NICE 휴대폰본인확인 기술명세서

| 항목 | 내용 |
| --- | --- |
| 문서명 | NICE아이디 휴대폰본인확인 연동 |
| 상태 | **미구현 — 구현 계약** |
| 작성일 | 2026-08-27 |
| 수정 | 2026-08-27 — 이메일 ID 유지 + 전체 서비스 이용 시 NICE(전화/PASS) 필수 |
| 제공사 | [NICE아이디 휴대폰본인확인](https://www.niceid.co.kr/prod_mobile.nc) |
| 전제 | [인증_기능명세서.md](인증_기능명세서.md) (이메일 OTP·JWT·Firestore `users`) |
| 대상 | `momo_server` 우선. Flutter 화면은 후속 |

---

## 0. 제품 인증 정책 (확정)

| 구분 | 정책 |
| --- | --- |
| **계정 ID** | **이메일**. 가입·로그인·세션의 주 식별자는 이메일+비밀번호 |
| **가입** | 기존과 동일 — 이메일 OTP → 비밀번호 → 생년월일 → 닉네임 |
| **로그인** | 이메일+비밀번호 → JWT. NICE로 로그인하지 않음 |
| **전체 서비스 이용** | NICE 휴대폰본인확인 **완료 필수**. 미완료면 제한 모드 |
| **본인확인 수단** | NICE 한 창구. 사용자가 UI에서 **문자(전화) / PASS·간편** 중 선택. momo가 둘을 따로 구현하지 않음 |

```
이메일 가입·로그인  ──►  계정 생성·JWT (기본 이용: 제한)
                              │
                              ▼
                    NICE 본인확인 (전화 문자 또는 PASS)
                              │
                              ▼
                    identityVerified = true  ──►  전체 서비스
```

**제한 모드(미본인확인)** 에서 허용하는 것(권장):

- 로그인·로그아웃·세션
- 본인확인(NICE) 시작/상태 조회
- (선택) 프로필·설정 조회

**전체 서비스** (본인확인 후):

- 모임 생성·참여·채팅·지도 마커 등 서비스 API
- 기획상 성인 전용 카테고리 등은 추가로 `isAdult` 검사

자체 SMS OTP·Firebase Phone Auth는 도입하지 않는다. 전화/PASS는 모두 NICE를 통한다.

---

## 1. 목적

- 통신사 PASS / 간편인증 / 문자인증을 NICE로 처리한다.
- 서버만 NICE와 연동한다. 앱은 HTTP + (이후) WebView.
- 주민등록번호는 저장하지 않는다. 허용 필드만 Firestore에 남긴다.
- **이메일은 ID, NICE는 서비스 이용 자격(본인확인 게이트)** 로 역할을 분리한다.

---

## 2. 범위

### 2.1 In scope

| ID | 내용 |
| --- | --- |
| N-01 | `POST /identity/nice/start` |
| N-02 | NICE 콜백·복호화·검증 |
| N-03 | `GET /identity/nice/status` |
| N-04 | 성공 시 `users`에 본인확인 반영 → `identityVerified=true` |
| N-05 | 서비스 API에 **본인확인 게이트** (`identityVerified`) |
| N-06 | `GET /me/identity` — 게이트·성인 여부 요약 |
| N-07 | Mock (`NICE_MODE=mock`) |

### 2.2 Out of scope (당차)

| 항목 | 비고 |
| --- | --- |
| Flutter NICE WebView 화면 | 후속 |
| 이메일을 전화/PASS로 대체한 가입 | 하지 않음 |
| NICE 단독 로그인 | 하지 않음 |
| 아이핀·실명확인 단독 상품 | 휴대폰본인확인만 |
| 자체 SMS 서버 | NICE 문자 사용 |

### 2.3 단계별 용도

| 단계 | 용도 |
| --- | --- |
| **1차** | 이메일 가입·로그인 후 **필수 본인확인**. 미완료 시 모임 등 차단 |
| **2차** | ID/비밀번호 찾기 전 본인확인 (`purpose`) |
| **하지 않음** | 가입 전에 NICE만으로 계정 생성 |

---

## 3. 아키텍처

```
이메일 OTP 가입 / 이메일 로그인  →  JWT  (인증_기능명세서)
         │
         ▼
제한 모드: identityVerified == false
         │
POST /identity/nice/start (Bearer JWT)
WebView → NICE (문자 또는 PASS)
callback → momo_server
GET /identity/nice/status
         │
         ▼
users.identityVerified = true
         │
         ▼
전체 서비스 API (모임·채팅 등) 허용
```

비밀키·사이트코드는 서버 `.env`만.

---

## 4. NICE 인증 방식

제공사 UI에서 사용자가 선택. momo는 **전화 문자 vs PASS를 구분한 API를 두지 않는다.**

| 방식 | 사용자 체감 | momo 처리 |
| --- | --- | --- |
| PASS/QR | PASS 앱 | 동일 start/callback/status |
| 간편인증 | PASS 푸시 | 동일 |
| 문자인증 | SMS 인증번호 | 동일 |

성공 시 계약·동의 범위에 따라: 성명, 성별, 생년월일, 내/외국인, 이통사, 휴대폰번호, **CI/DI**.  
원문 주민번호 취급·저장 금지.

---

## 5. 데이터

### 5.1 Firestore `users` 추가 필드

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| **identityVerified** | boolean | **서비스 게이트**. NICE 성공 시 `true`. 기본 `false` |
| identityProvider | string | `"none"` \| `"nice"` |
| niceVerifiedAt | string \| null | ISO-8601 UTC |
| isAdult | boolean \| null | NICE 생년월일 기준 만 19세+. 미인증 null |
| ci | string \| null | 중복 본인 방지 키 |
| di | string \| null | 사업자별 DI |
| phoneHash | string \| null | 전화 HMAC (원문 비권장) |
| phoneMasked | string \| null | `010-****-1234` |
| niceName | string \| null | 동의 시에만. 공개 닉네임으로 강제 노출하지 않음 |

계정 로그인 ID는 계속 **`email`**.  
`identityVerified`가 꺼져 있으면 이메일은 유효해도 **전체 서비스 불가**.

기존 `birthDate`(가입 자기신고)는 유지.  
성인 전용 기능 SSoT: **`identityVerified && isAdult === true`**.

### 5.2 `identity_tx/{txId}`

| 필드 | 설명 |
| --- | --- |
| txId | UUID |
| userId | JWT `sub` |
| status | `pending` \| `success` \| `failed` |
| purpose | 1차 `link_identity` (필수 본인확인) |
| createdAt / expiresAt | 약 10분 |
| failReason | 선택 |

---

## 6. 서비스 게이트 규칙

미들웨어 예: `requireIdentityVerified`.

| API 유형 | `identityVerified` |
| --- | --- |
| 로그인·OTP·signup·NICE start/status | 불필요 (또는 로그인만) |
| `GET /me`, `GET /me/identity` | 불필요 |
| 모임 CRUD·참여·채팅·실시간 소켓 join | **필수** → 없으면 **403 `identity-required`** |
| 성인 전용 카테고리 | 추가로 `isAdult === true` → 없으면 **403 `adult-required`** |

소켓(실시간 서버 명세)도 `join` 시 동일 검사.

앱 UX(후속): 로그인 직후 `GET /me/identity`로 게이트 확인 → 미완료면 본인확인 유도 화면. **로그아웃시키지는 않음.**

---

## 7. 연령 계산

- NICE 생년월일 기준 만 19세 이상 → `isAdult = true`
- 서버만 계산·저장. 클라이언트 제출값 무시

---

## 8. HTTP API

공통 JSON. start/status/`/me/identity`는 `Authorization: Bearer <JWT>`. callback은 NICE→서버.

### 8.1 `POST /identity/nice/start`

```json
{ "purpose": "link_identity" }
```

이미 `identityVerified === true`이면 200으로 재인증 허용(정보 갱신)하거나 409 `already-verified` — **1차는 재인증 허용(덮어쓰기, CI 충돌만 검사)** 권장.

**200:** `{ success, txId, authUrl, expiresAt }`

### 8.2 콜백

NICE → `POST /identity/nice/callback` (또는 Return URL).  
성공 시:

- `identityVerified = true`
- `identityProvider = "nice"`
- `niceVerifiedAt`, `isAdult`, `ci`/`di`, phone 해시·마스킹 등

CI가 **다른 userId에 존재** → tx `failed`, `identity-conflict`. 덮어쓰지 않음.

### 8.3 `GET /identity/nice/status?txId=`

```json
{
  "success": true,
  "txId": "uuid",
  "status": "success",
  "identityVerified": true,
  "isAdult": true,
  "phoneMasked": "010-****-1234",
  "verifiedAt": "2026-08-27T15:05:00.000Z"
}
```

CI/DI·성명·전화 원문 미포함.

### 8.4 `GET /me/identity`

```json
{
  "success": true,
  "email": "user@example.com",
  "identityVerified": false,
  "identityProvider": "none",
  "isAdult": null,
  "niceVerifiedAt": null,
  "phoneMasked": null
}
```

앱이 “전체 서비스 가능 여부”를 판단하는 **주 API**.

---

## 9. 에러 코드

| code | HTTP | 상황 |
| --- | --- | --- |
| `unauthorized` | 401 | JWT |
| `identity-required` | 403 | 본인확인 전 서비스 API |
| `adult-required` | 403 | 성인 전용 |
| `validation` | 400 | |
| `tx-not-found` | 404 | |
| `tx-expired` | 410 | |
| `identity-conflict` | 409 | CI 타 계정 |
| `nice-upstream` | 502 | |
| `not-implemented` | 501 | live 미설정 |

---

## 10. 환경변수

| 키 | 설명 |
| --- | --- |
| `NICE_MODE` | `mock` \| `live` (기본 `mock`) |
| `NICE_SITE_CODE` | |
| `NICE_SITE_PASSWORD` | |
| `NICE_RETURN_URL` | |
| `PHONE_HASH_SECRET` | phoneHash HMAC |
| (NICE 추가 키) | 발급 후 `.env.example` 반영 |

---

## 11. Mock (`NICE_MODE=mock`)

1. `start` → `txId` + `authUrl`
2. `POST /identity/nice/mock-complete` `{ "txId", "isAdult": true }` (live 비활성)
3. `identityVerified=true` 등 반영
4. `status` / `GET /me/identity`로 확인
5. 모임 API 스모크: 인증 전 403 → 인증 후 200

---

## 12. 보안·개인정보

- 동의문에 NICE 수집 항목·**서비스 이용을 위한 본인확인 필수** 명시
- 로그에 CI 전체·전화 원문·복호화 전문 금지
- 콜백 HTTPS, tx 1회성
- 앱에 사이트 패스워드 금지

---

## 13. 기존 인증과의 관계

| 기존 | 관계 |
| --- | --- |
| 이메일 = ID | **유지. 메인 가입·로그인** |
| 이메일 OTP | 가입용. NICE와 독립 |
| JWT | 로그인 증명. 본인확인과 별개 |
| NICE | **전체 서비스 이용 자격** |
| `birthDate` | 가입 수집 유지. 성인 기능은 `isAdult` |
| 모임·채팅 API | `identityVerified` 필수 |

---

## 14. 구현 순서

| 단계 | 작업 |
| --- | --- |
| 0 | NICE 신청·테스트 코드 |
| 1 | `users.identityVerified` 등 필드 |
| 2 | mock start / complete / status / `/me/identity` |
| 3 | 모임 등 라우트에 `requireIdentityVerified` |
| 4 | curl: 미인증 403 → mock 인증 → 허용 |
| 5 | live 콜백 |
| 6 | Flutter: 로그인 후 게이트 UI + WebView |

---

## 15. 검수 체크리스트

- [ ] 이메일만으로 가입·로그인 가능
- [ ] 미본인확인 시 모임/채팅 → 403 `identity-required`
- [ ] mock 본인확인 후 `identityVerified=true`, 서비스 API 허용
- [ ] NICE UI상 문자·PASS 모두 동일 서버 플로우로 완료 가능(live)
- [ ] CI 중복 → conflict, 두 번째 계정 미반영
- [ ] `/me/identity`에 ci/전화 원문 없음
- [ ] 이메일 로그인을 NICE가 대체하지 않음

---

## 16. 참고

- https://www.niceid.co.kr/prod_mobile.nc  
- 암복호화·콜백 필드명은 **NICE 공식 연동 가이드**가 최종 SSoT.
