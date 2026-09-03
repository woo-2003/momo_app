# momo NICE 휴대폰본인확인 기술명세서

| 항목 | 내용 |
| --- | --- |
| 문서명 | NICE아이디 휴대폰본인확인 연동 |
| 상태 | **미구현 — 구현 계약** |
| 작성일 | 2026-08-27 |
| 개정 | 2026-08-27 — **14세 미만 가입 방지**. 이메일 OTP 직후 NICE 필수 |
| 제공사 | [NICE아이디 휴대폰본인확인](https://www.niceid.co.kr/prod_mobile.nc) |
| 전제 | [인증_기능명세서.md](인증_기능명세서.md) (이메일 OTP·JWT·Firestore `users`) |
| 대상 | `momo_server` 우선. Flutter 화면은 후속 |

---

## 0. 제품 인증 정책 (확정)

| 구분 | 정책 |
| --- | --- |
| **계정 ID** | **이메일** + 비밀번호 |
| **가입 중 이메일** | 기존과 같이 이메일 OTP로 소유 확인 |
| **가입 중 본인확인** | 이메일 OTP **성공 직후 NICE 필수**. 생략·나중 인증 불가 |
| **가입 연령** | NICE 생년월일 기준 **만 14세 미만이면 가입 거부** |
| **NICE 수단** | 제공사 UI에서 문자(전화) / PASS·간편 선택. momo는 단일 연동 |
| **로그인** | 이메일+비밀번호. NICE로 로그인하지 않음 |

### 가입 순서 (필수)

```
이메일 입력
  → sendOtp / verifyOtp (이메일)
  → NICE 본인확인 (필수)     ★ 신규 OTP 통과 후에만
  → 연령 검사 (만 14세 미만이면 중단)
  → 비밀번호 · 닉네임 등 나머지 가입 단계
  → POST /signup
```

생년월일 화면의 **자기신고만으로 14세 미만을 막지 않는다.**  
가입 허용 여부의 연령 SSoT는 **NICE가 준 생년월일**이다.

자체 SMS·Firebase Phone Auth는 쓰지 않는다.

---

## 1. 목적

- 14세 미만 가입을 막기 위해, 가입 플로우에 NICE 휴대폰본인확인을 넣는다.
- 이메일은 ID·로그인용, NICE는 **가입 자격(연령·본인) 확인**용이다.
- 서버만 NICE와 연동. 주민번호 원문 저장 금지.

---

## 2. 범위

### 2.1 In scope

| ID | 내용 |
| --- | --- |
| N-01 | 이메일 OTP 검증과 연결된 NICE start (가입용 세션) |
| N-02 | 콜백·복호화·연령 판정 |
| N-03 | status 조회 |
| N-04 | **만 14세 미만 → 가입 불가** (`underage`) |
| N-05 | `/signup`이 **유효한 NICE 가입 토큰** 없이 완료되지 않게 함 |
| N-06 | Mock 모드 |

### 2.2 Out of scope (당차)

| 항목 | 비고 |
| --- | --- |
| Flutter WebView UI | 후속 |
| 로그인 후 나중에 본인확인 | **하지 않음** (가입 시 필수) |
| NICE 로그인 대체 | 하지 않음 |
| 부모 동의로 14세 미만 가입 | 당차 미지원 (거절만) |
| 만 19세 소셜 게이트 | 본 문서 주 목적 아님. `isAdult19`는 선택 저장 |

### 2.3 기존 명세와의 차이

| 이전 초안 | 본 개정 |
| --- | --- |
| 가입 후 제한 모드 → 나중에 NICE | **OTP 직후 NICE 필수**, 통과 전 `/signup` 불가 |
| 게이트 = 서비스 이용 | 게이트 = **가입 자체** (14세 미만 차단) |
| `identityVerified`로 모임 차단 | 가입 완료 사용자는 이미 NICE 통과 |

---

## 3. 가입 상태 머신

서버(또는 짧은 TTL 세션)가 이메일 단위로 상태를 가진다.

| 상태 | 의미 | 다음 |
| --- | --- | --- |
| `email_pending` | OTP 미검증 | verifyOtp |
| `email_verified` | 이메일 OTP 통과 | **NICE start만 허용** |
| `nice_pending` | NICE 진행 중 | callback / status |
| `nice_verified` | NICE 성공 + 만 14세 이상 | 비밀번호·닉네임·signup |
| `blocked_underage` | NICE 성공 but 만 14세 미만 | 가입 종료. signup 거부 |
| `registered` | signup 완료 | 로그인 |

`email_verified`에서 NICE를 건너뛰고 signup 호출 → **403 `nice-required`**.

---

## 4. 아키텍처

```
앱
  POST /send-email-otp
  POST /verify-email-otp          → email_verified
  POST /identity/nice/start       → purpose=sign_up, email(+이메일 verified 증명)
  WebView → NICE
  callback → 서버
  GET /identity/nice/status
       ├─ underage → blocked_underage (가입 중단 UI)
       └─ ok → nice_verified + signupToken
  POST /signup { ..., signupToken }  → users 생성
```

로그인 JWT는 **가입 완료 후**에만 발급된다.  
가입 중 NICE start는 JWT 대신 **이메일 OTP 검증 증표**를 쓴다.

---

## 5. 연령 규칙 (14세 미만 가입 방지)

| 항목 | 규칙 |
| --- | --- |
| 기준 | NICE 제공 생년월일 |
| 임계 | **만 14세 미만** → 가입 불가 |
| 계산 | 서버만 수행 (KST 기준 권장, 팀에서 고정) |
| 미만 | `status=failed` 또는 전용 `blocked_underage`, 코드 `underage` |
| 이상 | 가입 계속. `birthDate`는 NICE 값으로 signup에 고정 가능 |

선택 필드 `isAdult19`: 만 19세 이상 여부(소셜 등 후속).  
**가입 허용과 무관.** 가입 허용은 “만 14세 이상”만 보면 된다.

---

## 6. 데이터

### 6.1 가입 중 세션 (`signup_sessions/{id}` 또는 메모리)

이메일 OTP·NICE를 잇는 서버 측 상태. TTL 예: 30분.

| 필드 | 설명 |
| --- | --- |
| sessionId | 서버 발급 |
| email | |
| emailVerifiedAt | |
| niceTxId | |
| niceStatus | pending / verified / underage / failed |
| birthDateFromNice | 성공 시 |
| ci / di | 성공 시 (signup 시 users로 이전) |
| phoneHash / phoneMasked | 성공 시 |
| signupToken | `nice_verified`일 때만 발급. 1회성 |
| expiresAt | |

앱은 `sessionId` 또는 `signupToken`을 이후 단계에 전달한다.

### 6.2 Firestore `users` (가입 완료 후)

기존 필드 + 본인확인 결과:

| 필드 | 설명 |
| --- | --- |
| email | ID |
| birthDate | **NICE 생년월일** 권장 (자기신고와 불일치 시 NICE 우선) |
| identityProvider | `"nice"` |
| niceVerifiedAt | |
| ci / di | 중복 가입 방지 |
| phoneHash / phoneMasked | |
| isAdult19 | 선택 (만 19+) |

`identityVerified`는 가입 완료 사용자는 사실상 항상 true이므로,  
명시 필드 대신 `niceVerifiedAt != null`로 봐도 된다.

---

## 7. HTTP API

### 7.1 이메일 OTP (기존, 연동 포인트)

- `POST /verify-email-otp` 성공 시 → 서버가 `signup_session`을 만들거나 갱신하고, 응답에 `sessionId`를 포함하도록 **확장**한다.

```json
{
  "success": true,
  "message": "Email verified successfully",
  "sessionId": "uuid"
}
```

(기존 앱 호환이 필요하면 당분간 `sessionId` optional + 구버전은 막기.)

### 7.2 `POST /identity/nice/start`

**인증:** JWT 아님. `sessionId` (이메일 verified 상태) 필수.

```json
{
  "sessionId": "uuid",
  "purpose": "sign_up"
}
```

**처리**

1. session이 `email_verified` 또는 `nice_pending`인지 확인
2. 아니면 403 `email-not-verified`
3. NICE tx 생성, session → `nice_pending`
4. `authUrl` 반환

**200:** `{ success, txId, authUrl, expiresAt }`

### 7.3 콜백

NICE → 서버.  
성공 시 연령 계산:

- 만 14세 미만 → session `blocked_underage`, users **생성 안 함**, `signupToken` 없음  
- 만 14세 이상 → session `nice_verified`, `signupToken` 발급  
- CI가 **이미 가입된 users에 존재** → `identity-conflict` (재가입 차단)

### 7.4 `GET /identity/nice/status`

쿼리: `txId` 또는 `sessionId`.

**만 14세 이상 성공**

```json
{
  "success": true,
  "status": "verified",
  "signupToken": "one-time-token",
  "birthDate": "2008-05-01",
  "phoneMasked": "010-****-1234"
}
```

**미만**

```json
{
  "success": false,
  "status": "underage",
  "code": "underage",
  "message": "만 14세 미만은 가입할 수 없습니다."
}
```

CI/DI·성명·전화 원문 미포함.

### 7.5 `POST /signup` (기존 확장)

기존 body + **`signupToken` 필수**.

```json
{
  "email": "user@example.com",
  "password": "...",
  "nickname": "...",
  "signupToken": "one-time-token"
}
```

- `birthdate` 클라이언트 값은 **무시하거나**, NICE 값과 불일치 시 400.  
  권장: body에서 빼고 서버가 session의 NICE `birthDate`만 저장.
- OTP `verified`만으로는 부족. **`signupToken` 유효**해야 함.
- 성공 후 session·token 무효화, OTP 클리어.
- 없으면 403 `nice-required` / 401 `token-invalid`.

---

## 8. 에러 코드

| code | HTTP | 상황 |
| --- | --- | --- |
| `email-not-verified` | 403 | NICE start 전 OTP 미통과 |
| `nice-required` | 403 | signup 시 NICE/signupToken 없음 |
| `underage` | 403 | 만 14세 미만 |
| `identity-conflict` | 409 | CI 기가입 |
| `token-invalid` | 401 | signupToken 위조·만료·재사용 |
| `tx-expired` | 410 | |
| `nice-upstream` | 502 | |
| `unauthorized` / `validation` | 401 / 400 | |

---

## 9. 환경변수

| 키 | 설명 |
| --- | --- |
| `NICE_MODE` | `mock` \| `live` |
| `NICE_SITE_CODE` / `NICE_SITE_PASSWORD` | |
| `NICE_RETURN_URL` | |
| `PHONE_HASH_SECRET` | |
| `SIGNUP_TOKEN_SECRET` | signupToken 서명(선택) |

---

## 10. Mock

1. 이메일 verify → `sessionId`
2. nice/start → txId  
3. `POST /identity/nice/mock-complete`  
   `{ "sessionId", "birthDate": "2015-01-01" }` → underage  
   `{ "sessionId", "birthDate": "2005-01-01" }` → signupToken  
4. underage로 signup → 실패  
5. 정상 token으로 signup → users 생성  

live에서 mock-complete 비활성.

---

## 11. 보안·개인정보

- 만 14세 미만 가입 불가·본인확인 필수 고지
- NICE 수집 항목 동의문 명시
- 로그에 CI·전화 원문·복호화 전문 금지
- signupToken 1회성·짧은 TTL
- underage 세션도 CI를 users에 넣지 않음 (선택: 남용 방지용 underage 시도 로그만)

---

## 12. 기존 인증과의 관계

| 기존 | 관계 |
| --- | --- |
| 이메일 = ID | 유지 |
| 이메일 OTP | 가입 1단계. **직후 NICE** |
| 생년월일 입력 화면 | NICE 생년월일로 대체하거나 확인용만. **가입 연령 판정에 단독 사용 금지** |
| `/signup` OTP verified만 | **부족**. signupToken(NICE) 추가 |
| 로그인 | 이메일+PW. 가입 시 이미 NICE 완료 |

---

## 13. 구현 순서

| 단계 | 작업 |
| --- | --- |
| 1 | signup_session + verifyOtp 응답에 sessionId |
| 2 | nice start/status/callback + 14세 판정 |
| 3 | signup에 signupToken 게이트 |
| 4 | mock underage / 정상 스모크 |
| 5 | live NICE |
| 6 | 앱: OTP 다음 화면 = NICE WebView → 통과 후 비밀번호 |

---

## 14. 검수 체크리스트

- [ ] 이메일 OTP만으로 signup → 403 `nice-required`
- [ ] NICE 없이 비밀번호 단계로 가는 API 우회 불가
- [ ] mock 생년월일 만 14세 미만 → `underage`, users 없음
- [ ] 만 14세 이상 → signupToken → signup 201
- [ ] 동일 CI 재가입 → conflict
- [ ] 로그인 ID는 이메일 유지

---

## 15. 참고

- https://www.niceid.co.kr/prod_mobile.nc  
- 암복호화·콜백 형식은 NICE 공식 가이드가 최종 SSoT.
