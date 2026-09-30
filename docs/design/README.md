# MusicTimely 디자인 사양 (피그마 추출본)

- 원본: https://www.figma.com/design/0tVXNjTmVjGrpIjPcm977K/Music-Timely?node-id=1-3 (페이지 `Gui`)
- 추출일: 2026-09-30. 피그마 MCP Starter 요금제의 호출 한도로 일부 화면만 추출했다. 누락 목록은 맨 아래에 있다.
- 기준 캔버스: 390 × 844pt (iPhone). 수치는 이 캔버스 기준 pt다.

## 우선순위 규칙

| 영역 | 따를 문서 |
|---|---|
| 색, 폰트, 그림자, 모서리, 레이아웃, 모션 | **이 문서와 피그마** (명세서 §11.1의 Chalk·SUIT·#4E6477 초안을 대체) |
| 문구, 표시 내용의 진실성, 기능 동작 | **명세서** (`docs/개발-요구사항-명세서.md` §1, §3.1, DEC-06) |
| 접근성 | 명세서 §11.2 (대비 4.5:1, 44pt 터치 영역, Dynamic Type 200%, Reduce Motion) |

- 목업의 곡명 `Slow Tide`, 아티스트 `LUMEN FIELD`, 시각 `9:24`는 예시 데이터다 (명세서 §0-5).
- 아래 "명세서와 충돌하는 문구"는 명세서 문구로 바꿔 구현한다.

## 토큰

### 색

| 토큰 | Light | Dark | 용도 |
|---|---|---|---|
| background | `#ECECEC` | `#26272C` | 화면 배경 |
| surface | `#EEEEEE` | 배경과 같은 계열 | 뉴모피즘 버튼·카드 |
| field | `#FFFFFF` | `#303138` | 입력 필드, 저장된 생각 카드 |
| ink | `#26262C` | `#F3F3F5` | 본문·제목 |
| muted | `#64656E` | `#B4B5BE` | 보조 텍스트, MIN 라벨 |
| contrast.charcoal | `#232429` | | 결과 비교 카드 배경 |
| contrast.navy | `#1B1B33` | | 보조 버튼 배경 (Navy 테마 강조) |
| vinyl | `#0B0B0D` | | 레코드 본체 |
| accent.sunset | 가로 그라데이션 `#FF9C3F` → `#FF7544`(48%) → `#FF3B4D` | 같음 | 선택 칩, 주 버튼, 진행 막대, 레코드 라벨 |
| accent.outline | `#F5474F` 1.6pt 테두리 | 같음 | 현재 곡 분량 칸 |
| accent.coral | `#FF7544` | | 아이콘 선 색 (plus, pause, stop, note, chevron) |

- 테마는 Light, Navy, Dark 세 가지다. Navy는 Light 토큰에 contrast.navy 강조를 쓴다 (`screens/navy-01-home.png`).
- 명세서 §11.2에 따라 muted 텍스트 대비를 실제 배경에서 검증한다. 계산값: muted/background Light 4.9:1, Dark 7.31:1.
- **미해결:** 주 버튼·선택 칩의 흰 글자와 sunset 그라데이션의 대비는 2.08:1(`#FF9C3F`)~3.51:1(`#FF3B4D`)로, 명세서 §11.2의 4.5:1에 못 미친다. 디자이너 확인 전까지 피그마 색을 쓰되, 이 항목은 decisions.json에 미해결로 기록하고 verifier는 이를 신규 결함으로 세지 않는다.

### 그림자 (뉴모피즘)

| 토큰 | 값 (x, y, blur, color) |
|---|---|
| raised.light | (-9, -9, 20, `#FFFFFF` 95%) + (10, 12, 26, `#92949B` 38%) |
| inset.light | inner (-5, -5, 11, `#FFFFFF` 95%) + inner (5, 5, 11, `#92949B` 35%) |
| raised.dark | (-7, -7, 16, `#FFFFFF` 5%) + (9, 11, 22, `#000000` 50%) |
| inset.dark | inner (-4, -4, 10, `#FFFFFF` 5%) + inner (5, 5, 11, `#000000` 50%) |
| accent.glow | (0, 12, 12, `#FF5046` 27%) 주 버튼, (0, 10, 10, `#FF5046` 30%) 선택 칩 |
| vinyl | (-7, -7, 18, `#FFFFFF` 24%) + (0, 24, 38, `#000000` 30%) |
| field | (0, 8, 10, `#96989E` 18%) |

- 텍스트에는 그림자를 넣지 않는다 (명세서 §11.1).

### 폰트

- 한글: **IBM Plex Sans KR** (Regular 400, Medium 500, Bold 700). 숫자·영문: **Montserrat** (Light 300 ~ SemiBold 600).
- 파일: `MusicTimely/Resources/Fonts/` (OFL 라이선스 동봉). Info.plist 자동 생성을 쓰므로 앱 시작 시 `CTFontManagerRegisterFontsForURL`로 등록한다.
- 한 문장 안에서 한글은 Plex, 숫자·영문·공백은 Montserrat로 섞는다. 폰트 폴백(cascade) 또는 AttributedString으로 구현한다.
- 타이머 숫자는 tabular numerals를 쓴다 (명세서 §11.2).

| 역할 | 크기/행간 | 굵기 |
|---|---|---|
| 화면 제목 ("집중 세션") | 24/34 | Plex Bold |
| 결과 작업 제목 | 26/37 | Plex Bold |
| 섹션 제목 ("얼마나 하실까요?") | 21/30 | Plex Bold |
| 진행 패널 제목 ("세 번째 곡") | 22/31 | Plex Bold |
| 곡 수 강조 ("약 7곡") | 32/45 | Plex Medium + Montserrat Medium |
| 다이얼 숫자 | 38/54 | Montserrat Light |
| 칩 숫자 (`MT/Number`) | 24/34 | Montserrat Light |
| 결과 지표 (`MT/Metric`) | 34/48 | Montserrat Medium |
| 입력·버튼 | 17/24 | Plex Medium |
| 본문 | 14/20, 15/21 | Plex Medium |
| 보조 | 12/17, 13/19 | Plex Regular |
| 캡션 | 11/16 | Plex Regular |
| 단위 라벨 (MIN, SET) | 9/13, 10/14 | Montserrat SemiBold |

### 모양·간격

| 요소 | 크기 | 모서리 |
|---|---|---|
| 좌우 여백 | 20pt (카드), 24pt (텍스트·버튼) | |
| 원형 컨트롤 (gear, back, more, close) | 44 | 원 |
| 시간 칩 | 70 | 원, 간격 21 |
| 세션 컨트롤 | plus·stop 60, pause·play 84 | 원 |
| 입력 필드 | 350 × 58 | 29 |
| 카드 (분→곡) | 350 × 188 | 30 |
| 진행 패널 | 350 × 134 | 26 |
| 결과 비교 카드 | 350 × 182 | 26 |
| 음악 앱 행 | 350 × 68 | 34 |
| 주 버튼 | 342 × 58 | 29 |
| 보조 버튼 | 342 × 46 | 23 |
| 진행 막대 칸 | 38 × 10, 간격 5, 트랙 306 × 20 inset | 5 |

## 화면

| 파일 | 피그마 노드 | 명세서 화면 | 구성 |
|---|---|---|---|
| `screens/light-01-home.png` | 4:428 | SCR-01 배정 | 제목+설정, 작업 필드, 시간 칩 10/25/40/+SET, 분→곡 다이얼 카드, 음악 앱 행, 주 버튼 "N곡 동안 시작" |
| `screens/light-02-running.png` | 4:480 | SCR-02 진행 | back/more, 작업 제목, 레코드+톤암, 진행 패널(N번째 곡, 칸 막대, 경과), plus(생각 메모)/pause/stop(마치기) |
| `screens/light-02-paused.png` | 4:1045 | SCR-03 일시정지 | 톤암 거치, 레코드 위 알약 라벨, pause → play |
| `screens/light-02-last-song.png` | 4:1123 | 진행 중 끝 예고 | "마지막 곡이에요" + "마무리하셔도 돼요", 마지막 칸만 outline |
| `screens/light-02-estimated.png` | 4:1224 | D0 추정 표시 | 곡명 자리에 "약 세 번째 곡" + "곡 정보 없이 평균 길이로 추정 중" |
| `screens/light-03-result.png` | 4:555 | SCR-05 결과 | 세션 시각, 작업 제목, 계획/측정 비교 카드, 곡 레코드 아이콘 열, 보정 버튼, 저장된 생각, 주/보조 버튼 |
| `screens/light-06-capture.png` | 4:1198 | SCR-08 생각 메모 | 제목, 설명, 여러 줄 필드, 취소(3차 버튼), 저장하고 돌아가기 |
| `screens/light-07-correct-song-count.png` | 4:1211 | SCR-07 곡 보정 | 제목, 설명, 숫자 필드, 취소, 저장 |
| `screens/dark-0{1,2,3}-*.png` | 4:840, 4:891, 4:966 | Dark 테마 | Light와 같은 배치 |
| `screens/navy-01-home.png` | 4:634 | Navy 테마 | Light와 같은 배치 |

- D0(외부 음악) 진행 화면의 기본형은 **`light-02-estimated`** 이다. 곡명·아티스트가 있는 `light-02-running`은 P3 로컬 파일(O0)처럼 실제 메타데이터가 있을 때만 쓴다.
- 3차 버튼(취소, 곡 수 고치기)은 surface + raised, 주 버튼은 sunset 그라데이션 + 흰 글자, 보조 버튼은 navy 배경 + 흰 글자다.

## 레코드와 톤암

- 레코드: 286pt 원, `#0B0B0D`, 홈(groove) 동심원 28개(3pt 간격), 광택 PNG, 가운데 sunset 라벨 100pt + 스핀들 8pt. 라벨 문구 "SIDE A"/"FOCUS 03"은 장식이다.
- 톤암: 회전축 (298, 18) 기준. **진행 중 30°(레코드 위), 준비·일시정지·종료 0°(오른쪽 거치대)**.
- 모션: 시작·재개 650ms, 멈춤·종료 550ms (피그마 Smart Animate). Reduce Motion이면 즉시 최종 각도.
- 레코드 회전은 명세서 §11.1을 따른다. D0에서는 정지 상태가 기본이고, 톤암 위치는 세션 상태만 뜻한다. 레코드는 탭 가능한 재생 버튼이 아니다.
- 에셋: `assets/vinyl-*`, `assets/tonearm-*`. 홈 동심원은 SwiftUI `Circle().stroke`로 그려도 된다.

### 레코드 회전 (명세서와 다르게 결정)

- 명세서 §11.1은 외부 음악(D0)일 때 레코드를 기본 정지로 두지만, 제품 결정(2026-10-01)으로 **세션이 진행 중이면 모든 소스에서 돈다**.
- 한 바퀴 12초. 각도는 세션 경과에서 계산해 일시정지하면 그 자리에 멈추고 재개하면 이어진다.
- "곡 정보 없이 평균 길이로 추정 중" 문구는 유지해, 회전이 실제 재생 표시로 오인되지 않게 한다.
- 설정의 "레코드·톤암 움직임" OFF 또는 시스템 동작 줄이기면 멈춘 이미지.

## 잠금화면 (`lock-screen-and-components.png`)

| 피그마 | 구현 |
|---|---|
| Live Activity 7 states | `MusicTimelyWidgets/SessionLiveActivity.swift` — Running(Light/Dark는 시스템 모드), Last amount, Paused, Private, Ended, Unlimited + 배정 도달 |
| Dynamic Island compact·minimal·expanded | 같은 파일 `dynamicIsland` |
| WidgetKit vibrant 3 sizes | `MusicTimelyWidgets/LauncherWidget.swift` (곡 수·초 단위 값 없음) |
| Android system template | 해당 없음 (iOS 전용) |

- 칩은 `ProgressView(timerInterval:)`로 각 구간이 스스로 차오른다. "약 N번째 곡" 문구는 앱이 갱신할 때만 바뀌고, 다음 곡 경계가 지나면 "집중 세션 진행 중"으로 바뀐다 (staleDate).
- 피그마 Paused의 "음악은 그대로"는 명세서 §3.1에 따라 "음악은 음악 앱에서"로 바꿨다.

## 에셋 (`assets/`)

| 파일 | 용도 |
|---|---|
| `icon-{gear,back,more,close,plus,pause,stop,note,chevron}.svg` | 24pt 아이콘 (note 22, chevron 16). Asset Catalog에 벡터로 넣는다 |
| `dial-segment-1…7.svg` | 홈 다이얼의 7개 곡 조각 (116pt 기준). 곡 수에 따라 개수가 달라지므로 코드로 그리는 편이 낫다 |
| `vinyl-sunset-label.svg`, `vinyl-spindle.svg`, `vinyl-sheen-282.png`, `vinyl-groove-outer.svg` | 레코드 |
| `tonearm-*.svg` | 톤암 받침·베어링·나사 (팔·카트리지는 그라데이션 사각형이라 코드로 그린다) |
| `result-extra-song.png`, `result-divider.svg` | 결과 화면 점선 원, 카드 구분선 |

## 명세서와 충돌하는 문구 (명세서 쪽으로 구현)

| 피그마 | 문제 | 구현 문구 |
|---|---|---|
| 결과 "들은 양 · LISTENED · 9곡", "7곡을 잡고 · 9곡 들었어요" | 추정치를 실제 청취로 단정 (§1.1 금지, DEC-06) | "세션 시간 32분 · 약 9곡 분량"처럼 시간과 분량으로 표기. 곡 수 출처(평균 길이 추정/보정값)를 함께 표시 (SCR-05) |
| "들은 곡 수 고치기" | 같은 이유 | "곡 분량 고치기" 계열. 시간·목표는 바꾸지 않음 (SCR-07) |
| 일시정지 "음악 재생은 그대로예요" | 재생 확인 없이 재생 상태 단정 (§3.1) | "타이머만 멈췄어요. 음악은 음악 앱에서 조절해요." |
| 일시정지 알약 "세션을 잠시 멈췄어요" | SCR-03 문구 | "타이머만 쉬고 있어요" |
| 진행 "Slow Tide / LUMEN FIELD" | D0에서 곡명 표시 금지 (§3.1) | `light-02-estimated` 형태 사용 |
| 홈 "얼마나 하실까요?" | 명세서는 "얼마나 할까?" | 피그마 존댓말 문구를 쓰되 명세서 문구와의 차이는 decisions.json에 기록 |

## 추출하지 못한 항목 (피그마에서 직접 확인 필요)

- Navy 진행·결과 화면 (4:686, 4:761): Light와 배치가 같다고 가정한다.
- 잠금화면·위젯·Dynamic Island 섹션 (8:972): 노드 이름만 확인했다. 요약: 작업 제목 기본 숨김, 오렌지는 진행 포인트에만, 음악 재생 버튼 없음, 위젯은 rectangular/circular/inline, Always-On에서 애니메이션 없음, 축소 Dynamic Island는 시간만.
- 톤암 모션 상태 섹션 (8:1726): 위 "레코드와 톤암"의 각도·시간이 노드 설명에서 확인한 값이다.
- SCR-04 배정 도달, SCR-06 음악 선택 시트, SCR-09 설정 화면: 피그마에 없다. 이 문서의 토큰과 컴포넌트로 구성한다.
