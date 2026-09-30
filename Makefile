# 자주 쓰는 명령 모음. `make help`로 목록 확인.
SCHEME      := MusicTimely
PROJECT     := $(SCHEME).xcodeproj
DESTINATION ?= platform=iOS Simulator,name=iPhone 14 Pro,OS=26.5
DERIVED     := .build/DerivedData
SOURCES     := MusicTimely MusicTimelyTests MusicTimelyUITests

.PHONY: help generate open build test unit-test lint format clean archive testflight check-release-env device

help: ## 명령 목록
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

generate: ## project.yml → .xcodeproj 생성
	xcodegen generate

open: generate ## Xcode로 열기
	open $(PROJECT)

build: generate ## 시뮬레이터용 Debug 빌드
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) -quiet

test: generate ## 단위 + UI 테스트
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) -collect-test-diagnostics never -quiet

unit-test: generate ## 단위 테스트만
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) -only-testing:$(SCHEME)Tests -collect-test-diagnostics never -quiet

lint: ## swift-format 규칙 검사
	xcrun swift-format lint --strict --recursive --configuration .swift-format $(SOURCES)

format: ## swift-format 자동 정렬
	xcrun swift-format format --in-place --recursive --configuration .swift-format $(SOURCES)

clean: ## 빌드 산출물 삭제 (.build)
	rm -rf .build

# --- TestFlight 배포 ---
# 필요한 환경 변수: DEVELOPMENT_TEAM, ASC_KEY_PATH(.p8), ASC_KEY_ID, ASC_ISSUER_ID
ARCHIVE     := .build/MusicTimely.xcarchive
BUILD_NUMBER ?= $(shell date +%Y%m%d%H%M)
ASC_AUTH     = -allowProvisioningUpdates -authenticationKeyPath "$(ASC_KEY_PATH)" -authenticationKeyID "$(ASC_KEY_ID)" -authenticationKeyIssuerID "$(ASC_ISSUER_ID)"

check-release-env:
	@test -n "$(DEVELOPMENT_TEAM)" || (echo "DEVELOPMENT_TEAM(팀 ID)이 필요해요" && exit 1)
	@test -f "$(ASC_KEY_PATH)" || (echo "ASC_KEY_PATH(.p8 파일 경로)가 필요해요" && exit 1)
	@test -n "$(ASC_KEY_ID)" || (echo "ASC_KEY_ID가 필요해요" && exit 1)
	@test -n "$(ASC_ISSUER_ID)" || (echo "ASC_ISSUER_ID가 필요해요" && exit 1)

archive: check-release-env generate ## 배포용 Release 보관 파일 생성 (빌드 번호 = 현재 시각)
	xcodebuild archive -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'generic/platform=iOS' -archivePath $(ARCHIVE) CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) $(ASC_AUTH)

testflight: archive ## 보관 파일을 App Store Connect에 업로드 (TestFlight)
	xcodebuild -exportArchive -archivePath $(ARCHIVE) -exportOptionsPlist Config/ExportOptions.plist -exportPath .build/export $(ASC_AUTH)

# --- 개인 실기기 설치 (무료 Apple 계정 Personal Team 가능) ---
# 사전 조건: Xcode > Settings > Accounts 로그인, iPhone 개발자 모드 켜기
DEVICE_ID ?= $(shell xcrun devicectl list devices 2>/dev/null | awk '/physical/ && /available/ {for (i=1;i<=NF;i++) if ($$i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$$/) {print $$i; exit}}')
DEVICE_DERIVED := .build/DerivedData-device

device: generate ## 연결된 iPhone에 빌드·설치·실행 (DEVELOPMENT_TEAM 필요)
	@test -n "$(DEVELOPMENT_TEAM)" || (echo "DEVELOPMENT_TEAM(팀 ID)이 필요해요. Xcode > Settings > Accounts에서 확인할 수 있어요" && exit 1)
	@test -n "$(DEVICE_ID)" || (echo "연결된 iPhone을 찾지 못했어요" && exit 1)
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination 'id=$(DEVICE_ID)' -derivedDataPath $(DEVICE_DERIVED) -allowProvisioningUpdates DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) -quiet
	xcrun devicectl device install app --device $(DEVICE_ID) $(DEVICE_DERIVED)/Build/Products/Debug-iphoneos/$(SCHEME).app
	xcrun devicectl device process launch --device $(DEVICE_ID) com.gb6105.MusicTimely
