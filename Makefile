.PHONY: format lint lint-fix check build package install run

APP_NAME     := OmniWM
BUNDLE_ID    := com.barut.OmniWM
INSTALL_DIR  := /Applications
INSTALL_APP  := $(INSTALL_DIR)/$(APP_NAME).app
DIST_APP     := dist/$(APP_NAME).app
CONFIG       := debug
BUILD_DIR    := .build/$(CONFIG)
EXECUTABLE   := $(BUILD_DIR)/$(APP_NAME)
ENTITLEMENTS := OmniWM.entitlements
SIGN_ID      := Apple Development: Christopher Riley (Z4Y2HWWH6X)

format:
	swiftformat .

lint:
	swiftlint lint

lint-fix:
	swiftlint lint --fix

check: lint

build:
	swift build -c $(CONFIG)

package: build
	@mkdir -p "$(DIST_APP)/Contents/MacOS" "$(DIST_APP)/Contents/Resources"
	@cp "$(EXECUTABLE)" "$(DIST_APP)/Contents/MacOS/$(APP_NAME)"
	@cp Info.plist "$(DIST_APP)/Contents/Info.plist"
	@cp Resources/AppIcon.icns "$(DIST_APP)/Contents/Resources/AppIcon.icns"
	@cp -R "$(BUILD_DIR)/OmniWM_OmniWM.bundle" "$(DIST_APP)/Contents/Resources/"
	@codesign --force --sign "$(SIGN_ID)" --identifier "$(BUNDLE_ID)" \
		--entitlements "$(ENTITLEMENTS)" --timestamp=none \
		"$(DIST_APP)/Contents/MacOS/$(APP_NAME)"
	@codesign --force --sign "$(SIGN_ID)" --identifier "$(BUNDLE_ID)" \
		--entitlements "$(ENTITLEMENTS)" --timestamp=none \
		"$(DIST_APP)"
	@echo "Packaged $(DIST_APP)"

install: package
	@# Quit if running (ignore errors if not running)
	@-osascript -e 'tell application "$(APP_NAME)" to quit' 2>/dev/null; true
	@sleep 0.5
	@# Sync in-place to preserve permissions / TCC grants
	@mkdir -p "$(INSTALL_APP)"
	@rsync -a --delete "$(DIST_APP)/" "$(INSTALL_APP)/"
	@echo "Installed to $(INSTALL_APP)"

run: install
	@open "$(INSTALL_APP)"
