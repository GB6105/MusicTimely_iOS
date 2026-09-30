# MusicTimely_iOS

## 요구 사항

| 도구 | 버전 | 설치 |
|---|---|---|
| Xcode | 26 이상 (Swift 6.2+) | App Store |
| XcodeGen | 2.43 이상 | `brew install xcodegen` |

## 시작하기

```bash
make open    # project.yml로 .xcodeproj를 생성하고 Xcode에서 연다
```

## 명령

| 명령 | 동작 |
|---|---|
| `make generate` | `project.yml` → `MusicTimely.xcodeproj` 생성 |
| `make open` | 생성 후 Xcode로 열기 |
| `make build` | 시뮬레이터용 Debug 빌드 |
| `make test` | 단위 테스트 + UI 테스트 |
| `make unit-test` | 단위 테스트만 |
| `make lint` / `make format` | swift-format 검사 / 자동 정렬 |
| `make clean` | `.build/` 삭제 |

기본 시뮬레이터는 `iPhone 14 Pro`입니다. 다른 기기를 쓰려면 `DESTINATION`을 지정합니다.

```bash
make test DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro'
```

## 폴더 구조

```
music_timely_ios/
├── project.yml               # XcodeGen 프로젝트 정의 (빌드 설정의 원본)
├── Config/                   # 생성 Info.plist에 병합되는 키
├── docs/                     # 요구사항 명세서, PRD, 디자인 사양(docs/design), 구현 목표(GOAL.md)
├── MusicTimely/
│   ├── App/                  # 진입점, 루트 화면, 세션 코디네이터(SessionStore)
│   ├── Core/
│   │   ├── Models/           # 상태 머신, 곡 환산, 체크포인트, 설정 (순수 로직)
│   │   └── Services/         # 시계, 저장소, 알림, 음악 앱 실행, 노이즈, 호스트 어댑터
│   ├── Features/             # 배정, 진행, 결과, 메모, 보정, 음악 선택, 설정, 복구
│   ├── DesignSystem/         # 디자인 토큰과 레코드·톤암·버튼 컴포넌트
│   └── Resources/            # 아이콘 에셋, 폰트, 문자열 카탈로그
├── MusicTimelyTests/         # 단위·통합 테스트 (Swift Testing)
└── MusicTimelyUITests/       # UI 테스트, 화면 캡처 테스트 (XCTest)
```

## 개발 규칙

- **빌드 설정은 `project.yml`에서만 바꿉니다.** `make build`와 `make test`는 실행할 때마다 프로젝트를 재생성하므로, Xcode 화면에서 바꾼 설정은 덮어써집니다.
- **소스 폴더는 동기화 폴더입니다.** `MusicTimely/` 아래에 파일을 추가하거나 삭제하면 재생성하지 않아도 Xcode에 바로 반영됩니다. 코드가 아닌 파일은 앱 번들 리소스로 복사되므로, 번들에 넣지 않을 파일은 `project.yml`의 `excludes`에 추가합니다.
- **동시성은 Swift 6 엄격 모드입니다.** 앱과 단위 테스트 타깃의 선언은 기본적으로 `MainActor`에 격리되므로, 백그라운드에서 실행할 코드는 `nonisolated`나 `@concurrent`로 명시합니다. UI 테스트 타깃은 `XCTestCase`와 충돌하기 때문에 기본 격리를 쓰지 않으며, `XCUIApplication`을 쓰는 테스트 메서드에는 `@MainActor`를 붙입니다.
- **시간과 곡 계산은 `Core/Models`의 순수 함수로만 합니다.** 화면은 `SessionStore`를 거쳐서만 시계·저장소·알림에 접근합니다.
- **UI 문자열의 기준 언어는 한국어입니다.** 문구는 명세서 규칙(추정 표기, 실제 청취 단정 금지)을 따릅니다.

## 기본 설정

| 항목 | 값 | 변경 위치 (`project.yml`) |
|---|---|---|
| Bundle ID | `com.gb6105.MusicTimely` | `options.bundleIdPrefix` |
| 최소 iOS | 18.0 | `options.deploymentTarget` |
| 지원 기기 | iPhone 전용, 세로 모드 | `TARGETED_DEVICE_FAMILY`, `INFOPLIST_KEY_UISupportedInterfaceOrientations` |
| 서명 | Automatic, 팀 미지정 | 실기기 실행 시 `MusicTimely` 타깃에 `DEVELOPMENT_TEAM: <팀 ID>` 추가 |
