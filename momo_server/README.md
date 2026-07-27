# momo_server

Express OTP/인증 API. Flutter 앱은 이 HTTP API만 호출한다.

## 저장소

| `STORAGE` | 설명 |
|-----------|------|
| `firestore` (기본) | Firebase Admin → Firestore `users` |
| `sqlite` | 로컬 `data/momo.db` (롤백용) |

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

Firestore 보안 규칙: 클라이언트 직접 접근 deny, Admin SDK만 사용.

## 스크립트

```bash
npm install
npm start
npm run db:view       # 사용자 목록 (해시 제외)
npm run db:export     # data/export-users.json (AI 학습용)
npm run db:migrate    # SQLite → Firestore 1회 이관
```

## API (변경 없음)

- `POST /send-email-otp`
- `POST /verify-email-otp`
- `GET /check-nickname`
- `POST /signup`
- `POST /login`
