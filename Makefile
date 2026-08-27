.PHONY: project build test lint format app preview clean

# Regenerate MyPorts.xcodeproj from project.yml (git-ignored, needs XcodeGen).
project:
	xcodegen generate

# SwiftPM: build and test the libraries + portsd.
build:
	swift build

test:
	swift test

lint:
	swift format lint --strict --recursive Sources Tests Package.swift

format:
	swift format --in-place --recursive Sources Tests Package.swift

# Build the macOS app (requires full Xcode). Regenerates the project first.
app: project
	xcodebuild build -project MyPorts.xcodeproj -scheme MyPorts-macOS \
		-destination 'platform=macOS' -derivedDataPath .build/dd CODE_SIGNING_ALLOWED=NO

# Run the windowed UI preview with sample data.
preview:
	swift run PortsPreviewApp

clean:
	swift package clean
	rm -rf .build/dd MyPorts.xcodeproj
