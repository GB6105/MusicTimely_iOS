# 자주 쓰는 명령 모음. `make help`로 목록 확인.
SCHEME      := MusicTimely
PROJECT     := $(SCHEME).xcodeproj
DESTINATION ?= platform=iOS Simulator,name=iPhone 18 Pro
DERIVED     := .build/DerivedData
SOURCES     := MusicTimely MusicTimelyTests MusicTimelyUITests

.PHONY: help generate open build test unit-test lint format clean

help: ## 명령 목록
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

generate: ## project.yml → .xcodeproj 생성
	xcodegen generate

open: generate ## Xcode로 열기
	open $(PROJECT)

build: generate ## 시뮬레이터용 Debug 빌드
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) -quiet

test: generate ## 단위 + UI 테스트
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) -quiet

unit-test: generate ## 단위 테스트만
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) -only-testing:$(SCHEME)Tests -quiet

lint: ## swift-format 규칙 검사
	xcrun swift-format lint --strict --recursive --configuration .swift-format $(SOURCES)

format: ## swift-format 자동 정렬
	xcrun swift-format format --in-place --recursive --configuration .swift-format $(SOURCES)

clean: ## 빌드 산출물 삭제 (.build)
	rm -rf .build
