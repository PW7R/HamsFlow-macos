EXEC     := HamsFlow
CONFIG   := debug

## Build products live OUTSIDE this directory, for the same reason the .app does.
##
## ~/Desktop is iCloud/file-provider synced, and the provider mutates files inside
## .build while the compiler is using them — producing "input file was modified during
## the build" on random object files, and occasionally a wedged swift-frontend stuck at
## 0% CPU. Moving the scratch path to ~/Library/Caches (never synced) removes the race.
SCRATCH  := $(HOME)/Library/Caches/HamsFlowBuild/scratch
BUILD    := $(SCRATCH)/$(CONFIG)/$(EXEC)

## The bundle is assembled and signed OUTSIDE this directory on purpose.
STAGE    := $(HOME)/Library/Caches/HamsFlowBuild
APPNAME  := HamsFlow.app
BUNDLE   := $(STAGE)/$(APPNAME)
CONTENTS := $(BUNDLE)/Contents

## TCC keys the Accessibility grant to the code signature, so an ad-hoc signature — which
## changes on every build — makes the user re-grant after every `make`. Signing with a
## stable Developer ID keeps the identity constant and the grant sticky. Falls back to
## ad-hoc ("-") on a machine without the cert.
SIGN_ID := $(shell security find-identity -v -p codesigning 2>/dev/null \
             | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)".*/\1/')
ifeq ($(strip $(SIGN_ID)),)
SIGN_ID := -
endif

.PHONY: all build app run install clean icon

all: app

SWIFT := /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift

build:
	$(SWIFT) build -c $(CONFIG) --scratch-path "$(SCRATCH)"

## Regenerates AppIcon.icns from Resources/HamsFlowLogo.jpg.
icon:
	@mkdir -p Resources/AppIcon.iconset
	@sips -s format png -z 16 16     Resources/HamsFlowLogo.jpg --out Resources/AppIcon.iconset/icon_16x16.png >/dev/null
	@sips -s format png -z 32 32     Resources/HamsFlowLogo.jpg --out Resources/AppIcon.iconset/icon_16x16@2x.png >/dev/null
	@sips -s format png -z 32 32     Resources/HamsFlowLogo.jpg --out Resources/AppIcon.iconset/icon_32x32.png >/dev/null
	@sips -s format png -z 64 64     Resources/HamsFlowLogo.jpg --out Resources/AppIcon.iconset/icon_32x32@2x.png >/dev/null
	@sips -s format png -z 128 128   Resources/HamsFlowLogo.jpg --out Resources/AppIcon.iconset/icon_128x128.png >/dev/null
	@sips -s format png -z 256 256   Resources/HamsFlowLogo.jpg --out Resources/AppIcon.iconset/icon_128x128@2x.png >/dev/null
	@sips -s format png -z 256 256   Resources/HamsFlowLogo.jpg --out Resources/AppIcon.iconset/icon_256x256.png >/dev/null
	@sips -s format png -z 512 512   Resources/HamsFlowLogo.jpg --out Resources/AppIcon.iconset/icon_256x256@2x.png >/dev/null
	@sips -s format png -z 512 512   Resources/HamsFlowLogo.jpg --out Resources/AppIcon.iconset/icon_512x512.png >/dev/null
	@sips -s format png -z 1024 1024 Resources/HamsFlowLogo.jpg --out Resources/AppIcon.iconset/icon_512x512@2x.png >/dev/null
	@iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
	@echo "generated Resources/AppIcon.icns from HamsFlowLogo.jpg"

## Assemble a real .app bundle.
app: build
	@rm -rf "$(BUNDLE)"
	@mkdir -p "$(CONTENTS)/MacOS" "$(CONTENTS)/Resources"
	@cp $(BUILD) "$(CONTENTS)/MacOS/$(EXEC)"
	@cp Resources/Info.plist "$(CONTENTS)/Info.plist"
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$(CONTENTS)/Resources/"; fi
	@printf 'APPL????' > "$(CONTENTS)/PkgInfo"
	@xattr -cr "$(BUNDLE)"
	@codesign --force --sign "$(SIGN_ID)" \
		--entitlements Resources/$(EXEC).entitlements \
		-r'=designated => identifier "com.mesh.hamsflow"' \
		--options runtime \
		--timestamp=none \
		"$(BUNDLE)"
	@echo "built $(BUNDLE)  [signed: $(SIGN_ID)]"

## Run HamsFlow
run: app
	@pkill -x $(EXEC) 2>/dev/null || true
	@open "$(BUNDLE)"

## Installing to /Applications
install: app
	@pkill -x $(EXEC) 2>/dev/null || true
	@rm -rf "/Applications/$(APPNAME)"
	@cp -R "$(BUNDLE)" "/Applications/$(APPNAME)"
	@open "/Applications/$(APPNAME)"
	@echo "installed to /Applications/$(APPNAME)"

clean:
	@rm -rf .build "$(STAGE)" "$(SCRATCH)"
