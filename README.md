# momo — 대학생 모임 앱

> **모든 모임, momo.**

---

## 프로젝트

| 항목 | 내용 |
| --- | --- |
| 이름 | momo (모든 모임) |
| 분류 | 대학생 모임 앱 |
| 플랫폼 | Flutter (iOS / Android) |
| 디자인 톤 | Peach & Spring 팔레트 — Primary `#FF8E7A`, 웜 화이트 배경 `#FFF9F8`, 라운드 16px |

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
| 2026-05-12 | **Task 2**: MAIN1 디자인 구현 (로그인 화면 UI 레이아웃) | 완료 |
| 2026-05-12 | **Task 3**: 브랜드 모티브(복숭아/봄) 반영 컬러 테마 업데이트 | 완료 |

### Task 1 결과물

- `lib/core/theme.dart` — momo 디자인 시스템 (Color / Spacing / Shape / Theme)
- `lib/core/constants.dart` — 인증 정책 상수 및 입력 검증 정규식
- `lib/domain/auth_repository.dart` — `AuthRepository` 추상 인터페이스 + 보조 타입
- `lib/presentation/screens/`, `lib/presentation/widgets/` — 화면/위젯 자리 (현재 비어있음)

### Task 2 결과물

- `lib/presentation/screens/login_screen.dart` — [MAIN1] 로그인 화면 (StatelessWidget, 디자인 전용)
  - 100×100 원형 로고 자리 / 아이디·비밀번호 필드 / 로그인 버튼 / 비번찾기·ID찾기·회원가입 보조 링크 (사이 세로 구분선)
  - 유효성 검사·네비게이션·이벤트 로직 일체 미포함 (후속 Task에서 부착)
- `lib/main.dart` — `MaterialApp` 에 `MomoTheme.light` 적용, 첫 화면을 `LoginScreen` 으로 연결

### Task 3 결과물

- `lib/core/theme.dart` — `MomoColors` 값만 **Peach & Spring** 팔레트로 전면 교체
- Spacing / Radius / 컴포넌트 테마 정의는 일체 변경하지 않음 (구조 무손실)
- `ColorScheme` 및 `inputDecorationTheme.focusedBorder` 가 토큰을 그대로 참조 → 새 Primary `#FF8E7A` 가 자동 반영
- `login_screen.dart` 는 처음부터 토큰 기반이라 별도 수정 없이 즉시 새 컬러로 렌더링

| 변경 토큰 | 이전 (토스 블루) | 이후 (Peach & Spring) |
| --- | --- | --- |
| `primary` | `#3182F6` | **`#FF8E7A`** (피치 코랄) |
| `background` | `#FFFFFF` | **`#FFF9F8`** (웜 화이트) |
| `surface` | `#F2F4F6` | **`#FFF1EF`** (연한 피치) |
| `success` | `#00C896` | **`#88C057`** (봄 새싹 연두) |
| `border` | `#E5E8EB` | `#F2E3DE` (웜 톤 정렬) |
| `disabled` | `#D1D6DB` | `#E8D9D5` (웜 톤 정렬) |
| `error` | `#F04452` | `#E5383B` (피치와 명확히 구분되는 정통 레드) |
| `textMain` | `#191F28` | 유지 |
| `textSub` | `#4E5968` | 유지 |

---

## 폴더 구조

```
lib/
├── main.dart                  # 앱 진입점
├── core/                      # 앱 전역 토큰 / 상수
│   ├── theme.dart
│   └── constants.dart
├── domain/                    # 비즈니스 인터페이스 (구현 X)
│   └── auth_repository.dart
└── presentation/              # 화면 / 위젯
    ├── screens/
    └── widgets/
```

규칙

- `domain/` 은 Flutter / 네트워크 / 스토리지에 의존하지 않는다. (순수 Dart)
- 백엔드 구현체는 추후 `data/` (예: `data/auth_repository_impl.dart`) 에 위치시킨다.
- UI 토큰(색·간격·모양)은 반드시 `core/theme.dart` 의 상수만 사용한다.

---

## 디자인 시스템 요약

### Color (`MomoColors`) — Peach & Spring 팔레트

| 토큰 | 값 | 용도 |
| --- | --- | --- |
| `primary` | `#FF8E7A` | 피치 코랄 — 메인 액션 / 강조 |
| `background` | `#FFF9F8` | 웜 화이트 — 페이지 배경 |
| `surface` | `#FFF1EF` | 연한 피치 — 입력창 / 카드 표면 |
| `textMain` | `#191F28` | 본문 텍스트 (가독성 유지) |
| `textSub` | `#4E5968` | 보조 텍스트 (가독성 유지) |
| `border` | `#F2E3DE` | 웜 톤 외곽선 |
| `disabled` | `#E8D9D5` | 비활성 배경 |
| `error` | `#E5383B` | 에러 상태 (피치와 구분되는 정통 레드) |
| `success` | `#88C057` | 봄 새싹 연두 — 긍정 피드백 |
| `onPrimary` | `#FFFFFF` | primary 위 텍스트 |

### Spacing (`MomoSpacing`) — 8px 배수

`xxs=4` · `xs=8` · `sm=16` · `md=24` · `lg=32` · `xl=40` · `xxl=48`

### Shape (`MomoRadius`)

모든 버튼·입력창의 BorderRadius = **16px** (`MomoRadius.component`).
빠른 적용을 위해 `MomoRadius.all`, `MomoRadius.shape` 토큰 제공.

### Theme 적용

```dart
import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';

void main() => runApp(const MomoApp());

class MomoApp extends StatelessWidget {
  const MomoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'momo',
      theme: MomoTheme.light,
      home: const SizedBox(),
    );
  }
}
```

---

## 백엔드 가이드 (김동준)

### 1. 인터페이스 위치

`lib/domain/auth_repository.dart` — `AuthRepository` 추상 클래스.
백엔드는 본 인터페이스의 **구현체**를 제공한다. 프론트는 구현체에 직접 의존하지 않으며 항상 `AuthRepository` 타입으로만 사용한다.

### 2. 메서드 명세

| 메서드 | 입력 | 반환 | 비고 |
| --- | --- | --- | --- |
| `login` | `userId`, `password` | `AuthSession` | ID/PW 인증 |
| `sendOtp` | `email`, `purpose` | `DateTime` (만료시각) | 6자리 OTP, 5분 유효, 재전송 쿨다운 30초 |
| `verifyOtp` | `email`, `code` | `VerificationToken` | 1회성 단기 토큰 |
| `findId` | `verificationToken` | `String` (사용자 ID) | OTP 검증 후에만 호출 |
| `changePassword` | `verificationToken`, `newPassword` | `void` | OTP 검증 후에만 호출 |

### 3. 인증 정책 (`AuthPolicy`)

- **ID** : 영문/숫자, 4~20자
- **PW** : 영문 + 숫자 포함, 8~32자
- **OTP** : 6자리 숫자, 5분 유효, 재전송 쿨다운 30초

> 프론트 단에서 1차 검증을 수행하지만, **서버에서 반드시 동일 정책으로 재검증**한다.

### 4. OTP 사용 목적 (`OtpPurpose`)

| enum | 흐름 |
| --- | --- |
| `signUp` | 회원가입 1단계 (이메일 인증) |
| `changePassword` | 비밀번호 변경 |
| `findId` | 아이디 찾기 |

같은 `sendOtp` API 라도 `purpose` 별로 사전 조건이 다르다.

- `signUp` : 미가입 이메일이어야 함 → 가입된 경우 `email-already-used`
- `changePassword`, `findId` : 가입된 이메일이어야 함 → 아니면 `email-not-found`

### 5. 단기 인증 토큰 (`VerificationToken`)

- `verifyOtp` 성공 시 발급, 만료 시각(`expiresAt`) 포함.
- `findId`, `changePassword`, (추후) 회원가입 완료 API 호출 시 함께 제출.
- 불투명(opaque) 문자열 권장 (JWT / UUID / signed nonce 등 백엔드 자유).
- **1회성 사용 권장** — 사용 후 즉시 무효화.

### 6. 에러 코드 규약 (`AuthException.code`)

각 메서드의 doc-comment 에 정의된 코드 문자열을 그대로 사용한다.

| code | 발생 위치 | 의미 |
| --- | --- | --- |
| `invalid-credentials` | `login` | ID/PW 불일치 |
| `account-locked` | `login` | 계정 잠금 |
| `email-not-found` | `sendOtp` | 미가입 이메일 (비번변경/ID찾기) |
| `email-already-used` | `sendOtp` | 이미 가입된 이메일 (회원가입) |
| `rate-limited` | `sendOtp` | 재전송 쿨다운 미경과 |
| `otp-invalid` | `verifyOtp` | 코드 불일치 |
| `otp-expired` | `verifyOtp` | 유효시간 초과 |
| `otp-attempts` | `verifyOtp` | 시도 횟수 초과 |
| `token-invalid` | `findId`, `changePassword` | 토큰 위조/만료 |
| `user-not-found` | `findId` | 해당 이메일로 가입된 계정 없음 |
| `password-policy` | `changePassword` | 비밀번호 정책 위반 |
| `password-reused` | `changePassword` | 직전 비밀번호와 동일 |
| `network` | 공통 | 네트워크 오류 |

새로운 코드 추가는 본 표와 도메인 파일에 **동시 반영**한다.

---

## 다음 작업

- 회원가입 / 비밀번호 변경 화면 디자인 (프론트)
- `LoginScreen` 입력 검증·버튼 활성화·네비게이션 부착
- `AuthRepository` Mock 구현 (프론트 자체 진행, 백엔드 연동 전 임시)
- `AuthRepository` 실 구현체 (백엔드 연동)
