# MusicTimely iOS

## 명령
| 목적 | 명령 |
|---|---|
| 프로젝트 재생성 | `make generate` |
| 빌드 | `make build` |
| 전체 / 단위 테스트 | `make test` / `make unit-test` |
| 린트 / 포맷 | `make lint` / `make format` |
| 시뮬레이터 변경 | `make test DESTINATION='platform=iOS Simulator,name=<기기>'` |

## 규칙
- 빌드 설정 원본 = `project.yml` → 수정 후 `make generate`
- `.xcodeproj` 직접 편집 금지 (build·test가 매번 재생성)
- 소스 = 동기화 폴더 → 파일 추가·삭제 시 재생성 불필요
- 비코드 파일은 번들 리소스로 복사됨 → 제외할 파일은 `project.yml` `excludes`에 추가 (`.gitkeep` 등)
- 동시성: Swift 6, 앱·단위 테스트 기본 격리 `MainActor` → 백그라운드 코드는 `nonisolated` / `@concurrent` 명시
- UI 테스트 타깃은 기본 격리 없음 (XCTestCase와 충돌) → `XCUIApplication` 쓰는 메서드에 `@MainActor`
- 새 화면: `Features/<이름>/` 에 `<이름>View` + `@Observable` `<이름>ViewModel`
- 데이터 접근: `Core/Services`, 모델: `Core/Models`
- 테스트: 단위 = Swift Testing (앱 소스 경로 미러링), UI = XCTest
- UI 문자열: `Resources/Localizable.xcstrings` 에 ko 번역 추가
- UI 작업 전 `docs/design/README.md` Read (피그마 추출 토큰·화면·충돌 문구). 피그마 MCP는 호출 한도 있음 → 문서 우선
- 제품 범위: iOS 클라이언트만. 서버 기능은 `Core/Services` 프로토콜 경계만
- 검증: exit code로 판정, 파이프로 출력 자르지 않기

## 구조
| 경로 | 용도 |
|---|---|
| `MusicTimely/App/` | 앱 진입점 |
| `MusicTimely/Features/` | 화면 단위 View + ViewModel |
| `MusicTimely/Core/` | Models, Services |
| `MusicTimely/DesignSystem/` | `Theme` 토큰, 공용 컴포넌트 |
| `MusicTimely/Utilities/` | `Logger` 카테고리, 확장 |
| `MusicTimely/Resources/` | 에셋, 문자열 카탈로그 |
| `MusicTimelyTests/` | 단위 테스트 |
| `MusicTimelyUITests/` | UI 테스트 |
