# momo_server

Express OTP/인증 + 모임 API. Flutter 앱은 이 HTTP API만 호출한다.

## 저장소

| `STORAGE` | 설명 |
|-----------|------|
| `firestore` (기본) | Firebase Admin → Firestore `users`, `meetings` |
| `sqlite` | 로컬 `data/momo.db` (롤백용, **모임 API 비활성**) |

앱은 Firebase에 직접 접근하지 않는다. 저장소는 서버 뒤에서만 바뀐다.

## Firebase 설정

1. Firebase Console에서 프로젝트·Firestore 생성
2. 서비스 계정 JSON 발급 → `secrets/firebase-service-account.json`
3. `.env.example`을 복사해 `.env` 작성:

```
STORAGE=firestore
FIREBASE_PROJECT_ID=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=./secrets/firebase-service-account.json
JWT_SECRET=...
GMAIL_USER=...
GMAIL_APP_PASSWORD=...
```

Firestore 보안 규칙: 클라이언트 직접 접근 deny (`firestore.rules`), Admin SDK만 사용.

### Firestore 복합 인덱스 (`GET /meetings`)

모임 목록 쿼리(`status=open` + `startAt` 정렬, 선택 필터 `category`/`meetingMode`)에 필요한 인덱스는 저장소 루트 `firestore.indexes.json`에 정의되어 있다.

**1회 배포 (Firebase CLI):**

```bash
cd momo_server
npm install
npx firebase login          # 최초 1회
npm run deploy:indexes      # firestore.indexes.json → Firebase 프로젝트
```

인덱스 빌드는 수 분 걸릴 수 있다. [Firebase Console → Firestore → Indexes](https://console.firebase.google.com/project/momoserver-4d336/firestore/indexes)에서 `Enabled` 상태를 확인한다.

| 인덱스 필드 | 사용 쿼리 |
| --- | --- |
| `status` + `startAt` | `GET /meetings` |
| `status` + `category` + `startAt` | `?category=taxi` 등 |
| `status` + `meetingMode` + `startAt` | `?meetingMode=offline` 등 |
| `status` + `category` + `meetingMode` + `startAt` | 두 필터 동시 |

## 스크립트

```bash
npm install
npm start
npm run deploy:indexes # Firestore 복합 인덱스 배포
npm run db:view          # 사용자 목록 (해시 제외)
npm run db:export        # data/export-users.json (AI 학습용)
npm run db:migrate       # SQLite → Firestore 1회 이관
npm run smoke:meetings   # 모임 API 스모크 (서버 실행 중)
npm run smoke:places     # 우영: 장소 API 스모크 (KAKAO_REST_API_KEY + 로그인 계정)
```

## 인증 API

- `POST /send-email-otp`
- `POST /verify-email-otp`
- `GET /check-nickname`
- `POST /signup`
- `POST /login`

## 모임 API (`Authorization: Bearer <JWT>`)

- `POST /meetings` — 생성
- `GET /meetings` — open 목록 (쿼리: `category`, `meetingMode`)
- `GET /meetings/:id` — 상세
- `POST /meetings/:id/cancel` — 주최자 파기
- `POST /meetings/:id/join` — 참여
- `POST /meetings/:id/leave` — 나가기
- `GET /meetings/:id/messages` — 채팅 조회 (멤버만)
- `POST /meetings/:id/messages` — 채팅 전송 (open 모임만)

## 실시간 채팅 (Socket.IO)

명세: `docs/실시간서버_기술명세서.md`

- 연결: `ws://localhost:3000` (안드 에뮬 `10.0.2.2:3000`)
- handshake: `auth.token` 또는 `query.token` = JWT
- C→S: `join` `{ meetingId }`, `leave` `{ meetingId }`, `chat` `{ meetingId, body }`
- S→C: `chat` `{ messageId, meetingId, senderId, nickname, body, createdAt }`, `error` `{ code, message }`
- 히스토리: `GET /meetings/:id/messages` (HTTP). 이후 메시지는 소켓.

```bash
npm run smoke:socket   # SMOKE_EMAIL/SMOKE_PASSWORD 필요
```

상세 명세: `docs/모임채팅_프로토타입_기술명세서.md`

## 장소 API (우영 추가 · 카카오 로컬 서버 경유)

`.env`에 `KAKAO_REST_API_KEY` 필요. `Authorization: Bearer <JWT>` 필수.

- `GET /places/reverse?lat=&lng=` — 좌표 → 주소 (`label`, `roadAddress`, `address`)
- `GET /places/search?q=` — 키워드 장소 검색 (`items[]`: name, address, latitude, longitude)

카카오 키는 서버에만 둔다. 무료 쿼터 앱 키 사용 시 유료 API는 켜지 말 것.
