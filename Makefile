# DevDock Makefile
# Common commands for building and managing the project

.PHONY: all build debug release archive dmg clean open test version help

# Default target
all: build

# Build debug configuration
build: debug

debug:
	@./scripts/build.sh debug

# Build release configuration
release:
	@./scripts/build.sh release

# Create archive for distribution
archive:
	@./scripts/build.sh archive

# Export and create DMG
dmg: archive
	@./scripts/build.sh export
	@./scripts/build.sh dmg

# Full release build
dist:
	@./scripts/build.sh full

# Clean build artifacts
clean:
	@./scripts/build.sh clean

# Open project in Xcode
open:
	@open DevDock/DevDock.xcodeproj

# Run tests
test:
	@xcodebuild test \
		-project DevDock/DevDock.xcodeproj \
		-scheme DevDock \
		-destination 'platform=macOS' \
		| xcpretty || xcodebuild test \
		-project DevDock/DevDock.xcodeproj \
		-scheme DevDock \
		-destination 'platform=macOS'

# Show current version
version:
	@./scripts/version.sh get

# Bump patch version
bump-patch:
	@./scripts/version.sh bump patch

# Bump minor version
bump-minor:
	@./scripts/version.sh bump minor

# Bump major version
bump-major:
	@./scripts/version.sh bump major

# Format Swift code (requires swift-format)
format:
	@if command -v swift-format &> /dev/null; then \
		find DevDock -name "*.swift" -exec swift-format -i {} \;; \
		echo "Formatted all Swift files"; \
	else \
		echo "swift-format not installed. Run: brew install swift-format"; \
	fi

# Lint Swift code (requires swiftlint)
lint:
	@if command -v swiftlint &> /dev/null; then \
		cd DevDock && swiftlint; \
	else \
		echo "swiftlint not installed. Run: brew install swiftlint"; \
	fi

# Generate documentation
docs:
	@echo "Generating documentation..."
	@if command -v jazzy &> /dev/null; then \
		jazzy --clean --author "DevDock" --module "DevDock" --output docs/api; \
	else \
		echo "jazzy not installed. Run: gem install jazzy"; \
	fi

# Install development dependencies
setup:
	@echo "Installing development dependencies..."
	@if command -v brew &> /dev/null; then \
		brew install xcpretty swiftlint swift-format || true; \
	else \
		echo "Homebrew not installed"; \
	fi

# Show help
help:
	@echo "DevDock Build Commands"
	@echo ""
	@echo "Building:"
	@echo "  make build      Build debug configuration"
	@echo "  make release    Build release configuration"
	@echo "  make archive    Create archive for distribution"
	@echo "  make dmg        Create DMG installer"
	@echo "  make dist       Full release build"
	@echo ""
	@echo "Development:"
	@echo "  make open       Open project in Xcode"
	@echo "  make test       Run unit tests"
	@echo "  make clean      Clean build artifacts"
	@echo "  make format     Format Swift code"
	@echo "  make lint       Lint Swift code"
	@echo ""
	@echo "Versioning:"
	@echo "  make version    Show current version"
	@echo "  make bump-patch Bump patch version (1.0.0 -> 1.0.1)"
	@echo "  make bump-minor Bump minor version (1.0.0 -> 1.1.0)"
	@echo "  make bump-major Bump major version (1.0.0 -> 2.0.0)"
	@echo ""
	@echo "Other:"
	@echo "  make setup      Install development dependencies"
	@echo "  make docs       Generate documentation"
	@echo "  make help       Show this help"
