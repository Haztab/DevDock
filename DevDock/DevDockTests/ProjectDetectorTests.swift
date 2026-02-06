import XCTest
@testable import DevDock

/// Unit tests for ProjectDetector service
final class ProjectDetectorTests: XCTestCase {

    // MARK: - Properties

    private var tempDirectory: URL!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Create a temporary directory for each test
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    // MARK: - Flutter Detection Tests

    func testDetectsFlutterProject() throws {
        // Given: A directory with pubspec.yaml
        let pubspecPath = tempDirectory.appendingPathComponent("pubspec.yaml")
        try "name: my_flutter_app".write(to: pubspecPath, atomically: true, encoding: .utf8)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should detect as Flutter
        XCTAssertEqual(projectType, .flutter)
    }

    func testFlutterTakesPrecedenceOverAndroid() throws {
        // Given: A Flutter project (which also has android subfolder)
        let pubspecPath = tempDirectory.appendingPathComponent("pubspec.yaml")
        try "name: my_flutter_app".write(to: pubspecPath, atomically: true, encoding: .utf8)

        let androidDir = tempDirectory.appendingPathComponent("android")
        try FileManager.default.createDirectory(at: androidDir, withIntermediateDirectories: true)
        let gradlePath = androidDir.appendingPathComponent("build.gradle")
        try "// gradle file".write(to: gradlePath, atomically: true, encoding: .utf8)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should detect as Flutter (not Android)
        XCTAssertEqual(projectType, .flutter)
    }

    // MARK: - React Native Detection Tests

    func testDetectsReactNativeProject() throws {
        // Given: A directory with package.json containing react-native
        let packageJsonPath = tempDirectory.appendingPathComponent("package.json")
        let packageContent = """
        {
            "name": "my-react-native-app",
            "dependencies": {
                "react": "^18.0.0",
                "react-native": "^0.72.0"
            }
        }
        """
        try packageContent.write(to: packageJsonPath, atomically: true, encoding: .utf8)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should detect as React Native
        XCTAssertEqual(projectType, .reactNative)
    }

    func testDetectsReactNativeInDevDependencies() throws {
        // Given: A directory with react-native in devDependencies
        let packageJsonPath = tempDirectory.appendingPathComponent("package.json")
        let packageContent = """
        {
            "name": "my-app",
            "devDependencies": {
                "react-native": "^0.72.0"
            }
        }
        """
        try packageContent.write(to: packageJsonPath, atomically: true, encoding: .utf8)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should detect as React Native
        XCTAssertEqual(projectType, .reactNative)
    }

    func testNonReactNativeNodeProject() throws {
        // Given: A regular Node.js project without react-native
        let packageJsonPath = tempDirectory.appendingPathComponent("package.json")
        let packageContent = """
        {
            "name": "my-node-app",
            "dependencies": {
                "express": "^4.18.0"
            }
        }
        """
        try packageContent.write(to: packageJsonPath, atomically: true, encoding: .utf8)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should not detect as React Native (returns unknown)
        XCTAssertEqual(projectType, .unknown)
    }

    // MARK: - Android Detection Tests

    func testDetectsAndroidProjectWithBuildGradle() throws {
        // Given: A directory with build.gradle
        let gradlePath = tempDirectory.appendingPathComponent("build.gradle")
        try "// android build file".write(to: gradlePath, atomically: true, encoding: .utf8)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should detect as Android
        XCTAssertEqual(projectType, .android)
    }

    func testDetectsAndroidProjectWithBuildGradleKts() throws {
        // Given: A directory with build.gradle.kts
        let gradlePath = tempDirectory.appendingPathComponent("build.gradle.kts")
        try "// kotlin dsl build file".write(to: gradlePath, atomically: true, encoding: .utf8)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should detect as Android
        XCTAssertEqual(projectType, .android)
    }

    func testDetectsAndroidInSubfolder() throws {
        // Given: A project with android subfolder containing build.gradle
        let androidDir = tempDirectory.appendingPathComponent("android")
        try FileManager.default.createDirectory(at: androidDir, withIntermediateDirectories: true)
        let gradlePath = androidDir.appendingPathComponent("build.gradle")
        try "// gradle file".write(to: gradlePath, atomically: true, encoding: .utf8)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should detect as Android
        XCTAssertEqual(projectType, .android)
    }

    // MARK: - iOS Detection Tests

    func testDetectsIOSProjectWithXcodeproj() throws {
        // Given: A directory with .xcodeproj
        let xcodeprojPath = tempDirectory.appendingPathComponent("MyApp.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeprojPath, withIntermediateDirectories: true)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should detect as iOS
        XCTAssertEqual(projectType, .ios)
    }

    func testDetectsIOSProjectWithXcworkspace() throws {
        // Given: A directory with .xcworkspace
        let xcworkspacePath = tempDirectory.appendingPathComponent("MyApp.xcworkspace")
        try FileManager.default.createDirectory(at: xcworkspacePath, withIntermediateDirectories: true)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should detect as iOS
        XCTAssertEqual(projectType, .ios)
    }

    func testDetectsIOSInSubfolder() throws {
        // Given: A project with ios subfolder containing .xcodeproj
        let iosDir = tempDirectory.appendingPathComponent("ios")
        try FileManager.default.createDirectory(at: iosDir, withIntermediateDirectories: true)
        let xcodeprojPath = iosDir.appendingPathComponent("MyApp.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeprojPath, withIntermediateDirectories: true)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should detect as iOS
        XCTAssertEqual(projectType, .ios)
    }

    // MARK: - Unknown Project Tests

    func testReturnsUnknownForEmptyDirectory() {
        // Given: An empty directory
        // (tempDirectory is already empty)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should return unknown
        XCTAssertEqual(projectType, .unknown)
    }

    func testReturnsUnknownForNonExistentDirectory() {
        // Given: A non-existent directory
        let nonExistent = tempDirectory.appendingPathComponent("does-not-exist")

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: nonExistent)

        // Then: Should return unknown
        XCTAssertEqual(projectType, .unknown)
    }

    // MARK: - Priority Order Tests

    func testDetectionPriorityOrder() throws {
        // Flutter > React Native > Android > iOS
        // This test ensures Flutter is detected even with other markers present

        // Given: A directory with Flutter, Android, and iOS markers
        let pubspecPath = tempDirectory.appendingPathComponent("pubspec.yaml")
        try "name: hybrid_app".write(to: pubspecPath, atomically: true, encoding: .utf8)

        let gradlePath = tempDirectory.appendingPathComponent("build.gradle")
        try "// gradle".write(to: gradlePath, atomically: true, encoding: .utf8)

        let xcodeprojPath = tempDirectory.appendingPathComponent("MyApp.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeprojPath, withIntermediateDirectories: true)

        // When: Detecting project type
        let projectType = ProjectDetector.detectProjectType(at: tempDirectory)

        // Then: Should detect as Flutter (highest priority)
        XCTAssertEqual(projectType, .flutter)
    }
}
