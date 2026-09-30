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

기본 시뮬레이터는 `iPhone 18 Pro`이며, Xcode 27부터 포함됩니다. Xcode 26을 쓰거나 다른 기기를 쓰려면 `DESTINATION`을 지정합니다.

```bash
make test DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro'
```

## 폴더 구조

```
music_timely_ios/
├── project.yml            # XcodeGen 프로젝트 정의 (빌드 설정의 원본)
├── Makefile               # 빌드·테스트·린트 명령
├── .swift-format          # 코드 스타일 규칙
├── MusicTimely/
│   ├── App/               # 앱 진입점 (@main)
│   ├── Features/          # 화면 단위 모듈 (View + ViewModel)
│   │   └── Home/
│   ├── Core/
│   │   ├── Models/        # 도메인 모델
│   │   └── Services/      # 네트워크·저장소 등 데이터 접근
│   ├── DesignSystem/      # 디자인 토큰(Theme)과 공용 컴포넌트
│   │   └── Components/
│   ├── Utilities/         # 로거, 공용 확장
│   │   └── Extensions/
│   └── Resources/         # Assets.xcassets, Localizable.xcstrings
├── MusicTimelyTests/      # 단위 테스트 (Swift Testing), 앱 소스와 같은 폴더 구조
└── MusicTimelyUITests/    # UI 테스트 (XCTest)
```

## 개발 규칙

- **빌드 설정은 `project.yml`에서만 바꿉니다.** `make build`와 `make test`는 실행할 때마다 프로젝트를 재생성하므로, Xcode 화면에서 바꾼 설정은 덮어써집니다.
- **소스 폴더는 동기화 폴더입니다.** `MusicTimely/` 아래에 파일을 추가하거나 삭제하면 재생성하지 않아도 Xcode에 바로 반영됩니다. 코드가 아닌 파일은 앱 번들 리소스로 복사되므로, 번들에 넣지 않을 파일은 `project.yml`의 `excludes`에 추가합니다.
- **동시성은 Swift 6 엄격 모드입니다.** 앱과 단위 테스트 타깃의 선언은 기본적으로 `MainActor`에 격리되므로, 백그라운드에서 실행할 코드는 `nonisolated`나 `@concurrent`로 명시합니다. UI 테스트 타깃은 `XCTestCase`와 충돌하기 때문에 기본 격리를 쓰지 않으며, `XCUIApplication`을 쓰는 테스트 메서드에는 `@MainActor`를 붙입니다.
- **새 화면은 `Features/<이름>/`에 추가합니다.** View와 `@Observable` ViewModel을 한 쌍으로 두고, 데이터 접근은 `Core/Services`에 위임합니다.
- **UI 문자열은 `Resources/Localizable.xcstrings`에서 번역합니다.** 기준 언어는 영어이고 한국어 번역이 포함되어 있습니다.

## 기본 설정

| 항목 | 값 | 변경 위치 (`project.yml`) |
|---|---|---|
| Bundle ID | `com.gb6105.MusicTimely` | `options.bundleIdPrefix` |
| 최소 iOS | 18.0 | `options.deploymentTarget` |
| 지원 기기 | iPhone 전용, 세로 모드 | `TARGETED_DEVICE_FAMILY`, `INFOPLIST_KEY_UISupportedInterfaceOrientations` |
| 서명 | Automatic, 팀 미지정 | 실기기 실행 시 `MusicTimely` 타깃에 `DEVELOPMENT_TEAM: <팀 ID>` 추가 |
