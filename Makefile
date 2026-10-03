PROJECT := Calibrate.xcodeproj
SCHEME := Calibrate
DERIVED_DATA := .build/DerivedData
SIMULATOR_ID ?=
TEST_FLAGS ?=

.PHONY: build test clean run

build:
	xcodebuild build -scheme $(SCHEME) -project $(PROJECT) -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO

test:
	@test -n "$(SIMULATOR_ID)" || (echo 'Set SIMULATOR_ID to an available iPhone simulator UUID from xcrun simctl list devices available'; exit 1)
	xcodebuild test -scheme $(SCHEME) -project $(PROJECT) -destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO $(TEST_FLAGS)

run:
	open $(PROJECT)

clean:
	rm -rf $(DERIVED_DATA)
