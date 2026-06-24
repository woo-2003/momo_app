# momo — 대학생 모임 앱

> **모든 모임, momo.**

---

## 프로젝트

| 항목 | 내용 |
| --- | --- |
| 이름 | momo (모든 모임) |
| 분류 | 대학생 모임 앱 |
| 플랫폼 | Flutter (iOS / Android) |
| 디자인 톤 | Intense Peach 팔레트 — Primary `#EE8F8F`, 배경 `#FFF9F1`, 라운드 16px |
| 앱 진입점 | `LoginScreen` (`lib/main.dart`) |

## 팀원

| 이름 | 역할 |
| --- | --- |
| 이승민 | 기획 |
| 정우영 | 프론트엔드 / 디자인 |
| 김동준 | 백엔드 |
| 김건희 | AI |

---

## 진행 로그

| 일자 | 작업 | 상태 |
| --- | --- | --- |
| 2026-05-12 | **Task 1**: 아키텍처 설계 및 디자인 시스템 구축 | 완료 |
| 2026-05-12 | **Task 2~3**: 로그인 랜딩 UI · Peach 테마 적용 | 완료 |
| 2026-05-22 | **Task 4**: 회원가입 플로우 UI (이메일 → OTP → 비밀번호 → 생년월일 → 닉네임) | 완료 |
| 2026-05-22 | **Task 5**: `MockAuthRepository` · OTP/닉네임 에러 UI | 완료 |
| 2026-05-22 | **Task 6**: 메인 화면 플레이스홀더 · 가입 완료 후 연결 | 완료 |

---

## 폴더 구조

```
lib/
├── main.dart
├── core/
│   ├── theme.dart              # 디자인 시스템 (Color / Spacing / Theme)
│   └── constants.dart          # 인증 정책 · 검증 정규식 · 안내 문구
├── domain/
│   └── auth_repository.dart    # AuthRepository 인터페이스 (순수 Dart)
├── data/
│   └── mock_auth_repository.dart   # 백엔드 연동 전 Mock 구현체
└── presentation/
    └── screens/
        ├── login_screen.dart           # 랜딩 (시작하기 / 계정이 이미 있습니다)
        ├── email_input_screen.dart     # 이메일 입력
        ├── otp_input_screen.dart       # OTP 6자리 (휠 박스 UI)
        ├── password_setup_screen.dart  # 비밀번호 설정
        ├── birthdate_input_screen.dart # 생년월일 (스크롤 + 직접 입력)
        ├── nickname_setup_screen.dart  # 닉네임 + 중복 확인
        └── main_screen.dart            # 메인 (지도 API 미정 · 플레이스홀더)
```

### 규칙

- `domain/` 은 Flutter / HTTP / 스토리지에 의존하지 않는다.
- 프론트는 **`AuthRepository` 타입**만 사용한다. 화면에서 Mock / 실구현체를 생성자로 주입한다.
- 백엔드 실구현체는 `data/auth_repository_impl.dart` (추가 예정)에 둔다.
- UI 색·간격·모양은 `core/theme.dart` 토큰만 사용한다.

---

## 화면 흐름 (현재 구현)

### 회원가입 (`signUp`)

```
LoginScreen
  └─ [시작하기]
       EmailInputScreen          sendOtp(email, OtpPurpose.signUp)
         └─ [계속]
              OtpInputScreen      verifyOtp(email, code)
                └─ [확인]
                     PasswordSetupScreen    (프론트: 비밀번호 일치만 검증)
                       └─ [계속]
                            BirthdateInputScreen   (프론트: 유효 날짜 검증)
                              └─ [계속]
                                   NicknameSetupScreen   checkNicknameAvailability(nickname)
                                     └─ [가입 완료]  ← API TODO
                                          MainScreen   (스택 초기화 후 진입)
```

### 로그인 (미구현)

- `LoginScreen` 의 **「계정이 이미 있습니다」** 버튼 → 후속 Task
- `AuthRepository.login` → Mock 미구현

### 메인

- `MainScreen` — 지도 API 기획 미확정으로 **플레이스홀더**만 표시
- 위치·마커·FAB 등 UI는 후속 Task

---

## 화면별 상세 (백엔드 연동 참고)

| 화면 | 파일 | 호출 API (`AuthRepository`) | 프론트 1차 검증 | 백엔드 연동 상태 |
| --- | --- | --- | --- | --- |
| 이메일 입력 | `email_input_screen.dart` | `sendOtp` | 이메일 형식 (`ValidationPatterns.email`) | Mock ✅ / 실API ❌ |
| OTP 입력 | `otp_input_screen.dart` | `verifyOtp` | 6자리 숫자 | Mock ✅ / 실API ❌ |
| 비밀번호 설정 | `password_setup_screen.dart` | — | **비밀번호·확인 일치만** (정책 검증은 후속) | — |
| 생년월일 | `birthdate_input_screen.dart` | — | 존재하는 날짜 (연도: 올해−100 ~ 올해) | — |
| 닉네임 | `nickname_setup_screen.dart` | `checkNicknameAvailability` | 2~10자 | Mock ✅ / 실API ❌ |
| 가입 완료 | `nickname_setup_screen.dart` `_onComplete` | **`completeSignUp` (미정의)** | 중복 확인 통과 후만 버튼 활성 | **TODO** |
| 메인 | `main_screen.dart` | — | — | 지도 API 미정 |

### 회원가입 완료 시 프론트가 보유하는 데이터

`가입 완료` 버튼 시점에 화면 스택을 통해 아래 값이 모두 모인다. 백엔드 **회원가입 완료 API** 설계 시 참고.

| 필드 | 타입 | 획득 시점 |
| --- | --- | --- |
| `email` | `String` | 이메일 입력 |
| `verificationToken` | `VerificationToken` | `verifyOtp` 성공 |
| `password` | `String` | 비밀번호 설정 |
| `birthDate` | `DateTime` | 생년월일 입력 (기본값 2000-01-01) |
| `nickname` | `String` | 닉네임 중복 확인 통과 |

> 프론트 `nickname_setup_screen.dart` 의 `_onComplete` 에 `// TODO: 회원가입 완료 API 연동` 주석이 있다.
> 백엔드 API 스펙 확정 후 `AuthRepository` 에 메서드를 추가하고 Mock / 실구현체를 함께 반영한다.

**제안 시그니처 (협의용)**

```dart
Future<AuthSession> completeSignUp({
  required VerificationToken verificationToken,
  required String email,
  required String password,
  required DateTime birthDate,
  required String nickname,
});
```

- `verificationToken` 은 1회성 사용 후 무효화 권장
- 성공 시 `AuthSession` 발급 → 메인 화면 진입

---

## Mock 동작 (`lib/data/mock_auth_repository.dart`)

백엔드 연동 전 프론트 단독 테스트용. **실 API 연결 시 `MockAuthRepository` 대신 구현체만 교체**하면 화면 코드 변경을 최소화할 수 있다.

| 메서드 | Mock 동작 |
| --- | --- |
| `sendOtp` | 400ms 지연 후 `now + 5분` 반환 |
| `verifyOtp` | 코드 `123456` → `VerificationToken` 발급 / 그 외 → `otp-invalid` |
| `checkNicknameAvailability` | `admin`, `momo`, `test` (대소문자 무시) → `nickname-taken` / 2~10자 외 → `nickname-policy` |
| `login`, `findId`, `changePassword` | `network` 예외 (미구현) |

### 프론트 테스트 시나리오

1. **시작하기** → 이메일 입력 → **계속**
2. OTP `123456` 입력 → **확인**
3. 비밀번호 2칸 동일 입력 → **계속**
4. 생년월일 선택 → **계속**
5. 닉네임 입력 → **중복 확인** → **가입 완료** → `MainScreen`

---

## 디자인 시스템 요약

### Color (`MomoColors`) — v2 Intense Peach

| 토큰 | 값 | 용도 |
| --- | --- | --- |
| `primary` | `#EE8F8F` | 메인 액션 / 강조 |
| `background` | `#FFF9F1` | 페이지 배경 |
| `surface` | `#FFF1EF` | 입력창 / 카드 표면 |
| `textMain` | `#4D2121` | 본문 텍스트 |
| `textSub` | `#6D4C4C` | 보조 텍스트 |
| `border` | `#F2E3DE` | 외곽선 |
| `disabled` | `#E8D9D5` | 비활성 배경 |
| `textDisabled` | `#A6908C` | 비활성·힌트 텍스트 |
| `error` | `#E5383B` | 에러 |
| `success` | `#88C057` | 성공 피드백 |
| `onPrimary` | `#FFFFFF` | primary 위 텍스트 |

### Spacing (`MomoSpacing`) — 8px 배수

`xxs=4` · `xs=8` · `sm=16` · `md=24` · `lg=32` · `xl=40` · `xxl=48`

### Shape (`MomoRadius`)

버튼·입력창 BorderRadius = **16px** (`MomoRadius.component`)

---

## 백엔드 가이드 (김동준)

### 1. 인터페이스 위치

`lib/domain/auth_repository.dart` — `AuthRepository` 추상 클래스.

프론트는 이 인터페이스에만 의존한다. 구현체는 `data/` 에 둔다.

### 2. 메서드 명세 (현재 정의됨)

| 메서드 | 입력 | 반환 | 비고 |
| --- | --- | --- | --- |
| `login` | `userId`, `password` | `AuthSession` | 로그인 |
| `sendOtp` | `email`, `purpose` | `DateTime` (만료시각) | OTP 발송 |
| `verifyOtp` | `email`, `code` | `VerificationToken` | OTP 검증 |
| `findId` | `verificationToken` | `String` (userId) | ID 찾기 |
| `changePassword` | `verificationToken`, `newPassword` | `void` | 비밀번호 변경 |
| `checkNicknameAvailability` | `nickname` | `void` | 닉네임 중복 확인 |

### 3. 메서드 명세 (협의 필요 · 프론트 TODO)

| 메서드 | 입력 | 반환 | 비고 |
| --- | --- | --- | --- |
| `completeSignUp` (가칭) | `verificationToken`, `email`, `password`, `birthDate`, `nickname` | `AuthSession` | 회원가입 최종 제출 |

### 4. 인증 정책 (`AuthPolicy` · `lib/core/constants.dart`)

| 항목 | 정책 |
| --- | --- |
| ID | 영문/숫자, 4~20자 |
| PW | 영문 + 숫자 포함, 8~32자 |
| OTP | 6자리 숫자, 5분 유효, 재전송 쿨다운 30초 |
| 닉네임 | 2~10자 |

> 프론트에서 1차 검증을 수행하지만, **서버에서 동일 정책으로 재검증**한다.
> 현재 비밀번호 화면은 **일치 여부만** 검사한다. 정책 검증은 가입 완료 API 단계에서 서버가 담당하는 것을 권장한다.

### 5. OTP 사용 목적 (`OtpPurpose`)

| enum | 흐름 | `sendOtp` 사전 조건 |
| --- | --- | --- |
| `signUp` | 회원가입 이메일 인증 | 미가입 이메일 → 아니면 `email-already-used` |
| `changePassword` | 비밀번호 변경 | 가입 이메일 → 아니면 `email-not-found` |
| `findId` | 아이디 찾기 | 가입 이메일 → 아니면 `email-not-found` |

회원가입 플로우에서는 `OtpPurpose.signUp` 만 사용 중이다.

### 6. 단기 인증 토큰 (`VerificationToken`)

- `verifyOtp` 성공 시 발급 (`value`, `expiresAt`)
- `findId`, `changePassword`, **회원가입 완료** 호출 시 제출
- 불투명 문자열 권장, **1회성 사용 권장**

### 7. 에러 코드 규약 (`AuthException.code`)

| code | 발생 위치 | 의미 |
| --- | --- | --- |
| `invalid-credentials` | `login` | ID/PW 불일치 |
| `account-locked` | `login` | 계정 잠금 |
| `email-not-found` | `sendOtp` | 미가입 이메일 |
| `email-already-used` | `sendOtp` | 이미 가입된 이메일 (회원가입) |
| `rate-limited` | `sendOtp` | 재전송 쿨다운 미경과 |
| `otp-invalid` | `verifyOtp` | 코드 불일치 |
| `otp-expired` | `verifyOtp` | 유효시간 초과 |
| `otp-attempts` | `verifyOtp` | 시도 횟수 초과 |
| `token-invalid` | `findId`, `changePassword`, `completeSignUp` | 토큰 위조/만료 |
| `user-not-found` | `findId` | 계정 없음 |
| `password-policy` | `changePassword`, `completeSignUp` | 비밀번호 정책 위반 |
| `password-reused` | `changePassword` | 직전 비밀번호와 동일 |
| `nickname-taken` | `checkNicknameAvailability` | 닉네임 중복 |
| `nickname-policy` | `checkNicknameAvailability` | 닉네임 길이/형식 위반 |
| `network` | 공통 | 네트워크 오류 |

새 코드 추가 시 **본 표 + `auth_repository.dart` doc-comment** 에 동시 반영한다.

### 8. 구현체 연결 방법

1. `lib/data/auth_repository_impl.dart` 작성 (`AuthRepository` 구현)
2. 회원가입 진입 화면(`EmailInputScreen`) 생성 시 Mock 대신 구현체 주입
   - 동일 인스턴스를 OTP ~ 닉네임 화면까지 전달해야 토큰·세션 컨텍스트가 유지된다
3. `completeSignUp` API 확정 후 도메인 인터페이스 추가 → `nickname_setup_screen.dart` TODO 연결

```dart
// 예시: main.dart 또는 DI 설정에서
final auth = AuthRepositoryImpl(baseUrl: '...');
// EmailInputScreen(authRepository: auth)
```

---

## 다음 작업

### 프론트

- [ ] `LoginScreen` — 「계정이 이미 있습니다」로 로그인 플로우
- [ ] 비밀번호 화면 — `ValidationPatterns.password` 정책 검증 추가
- [ ] `MainScreen` — 지도 API 확정 후 전체 화면 지도 + 현재 위치
- [ ] `completeSignUp` 도메인 메서드 추가 및 Mock/실구현 연결

### 백엔드

- [ ] `AuthRepository` 실구현체 (`sendOtp`, `verifyOtp`, `checkNicknameAvailability`)
- [ ] 회원가입 완료 API 스펙 확정 및 구현
- [ ] `login` API
