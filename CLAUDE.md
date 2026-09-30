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
- 시간·곡 계산은 `Core/Models` 순수 함수로만 → UI가 시계·저장소를 직접 호출하지 않음 (`SessionStore` 경유)
- 화면 상태는 `SessionStore` 하나가 소유 → 새 화면은 `Features/<이름>/`에 View만 추가
- 외부 음악 앱은 열기만 (재생·정지·큐 API 금지, FR-025)
- 테스트 기기 기본값: iPhone 14 Pro (`Makefile` `DESTINATION`)
- 화면 캡처: `TEST_RUNNER_CAPTURE_SCREENS=1`로 `ScreenCaptureTests` 실행 → xcresult 첨부
- 테스트: 단위 = Swift Testing + `MusicTimelyTests/Support/Fakes.swift`의 가짜 시계·저장소, UI = XCTest(`-uiTesting` 격리 저장소)
- UI 문자열: `Resources/Localizable.xcstrings` 에 ko 번역 추가
- UI 작업 전 `docs/design/README.md` Read (피그마 추출 토큰·화면·충돌 문구). 피그마 MCP는 호출 한도 있음 → 문서 우선
- 제품 범위: iOS 클라이언트만. 서버 기능은 `Core/Services` 프로토콜 경계만
- 검증: exit code로 판정, 파이프로 출력 자르지 않기

## 구조
| 경로 | 용도 |
|---|---|
| `docs/GOAL.md` | 구현 범위·제외·완료 기준 |
| `MusicTimely/App/` | 진입점, `RootView`(라우팅·테마), `SessionStore`(코디네이터) |
| `MusicTimely/Core/Models/` | 순수 도메인: `TimerMachine`(상태 머신·복원·예고), `SongMath`(D0 환산), 설정·체크포인트 |
| `MusicTimely/Core/Services/` | 시계, 원자 저장소, 알림, 음악 앱 실행, 노이즈 재생, 호스트 어댑터 |
| `MusicTimely/Features/` | Assign, Session, Result, Memo, Correction, MusicSheet, Settings, Recovery |
| `MusicTimely/DesignSystem/` | 토큰(`Theme`, `Palette`, `AppFont`), 레코드·톤암·버튼 컴포넌트 |
| `MusicTimely/Resources/` | 아이콘 에셋, 폰트, 문자열 카탈로그 |
| `Config/MusicTimely-Info.plist` | 생성 plist에 병합되는 키 (폰트, 백그라운드 오디오, 음악 앱 스킴) |
| `MusicTimelyTests/` | 단위 테스트 |
| `MusicTimelyUITests/` | UI 테스트 |
