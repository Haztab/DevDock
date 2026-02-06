import Foundation

/// Detects project type from a given directory
final class ProjectDetector {
    /// Detect project type from a folder URL
    static func detectProjectType(at url: URL) -> ProjectType {
        let fileManager = FileManager.default

        // Check for Flutter (pubspec.yaml)
        let pubspecPath = url.appendingPathComponent("pubspec.yaml")
        if fileManager.fileExists(atPath: pubspecPath.path) {
            return .flutter
        }

        // Check for React Native (package.json with react-native dependency)
        let packageJsonPath = url.appendingPathComponent("package.json")
        if fileManager.fileExists(atPath: packageJsonPath.path) {
            if isReactNativeProject(packageJsonPath: packageJsonPath) {
                return .reactNative
            }
        }

        // Check for Android (build.gradle or build.gradle.kts)
        let gradlePath = url.appendingPathComponent("build.gradle")
        let gradleKtsPath = url.appendingPathComponent("build.gradle.kts")
        let androidPath = url.appendingPathComponent("android") // Also check android subfolder
        let androidGradlePath = androidPath.appendingPathComponent("build.gradle")

        if fileManager.fileExists(atPath: gradlePath.path) ||
           fileManager.fileExists(atPath: gradleKtsPath.path) ||
           fileManager.fileExists(atPath: androidGradlePath.path) {
            return .android
        }

        // Check for iOS (.xcodeproj or .xcworkspace)
        if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
            for item in contents {
                if item.pathExtension == "xcodeproj" || item.pathExtension == "xcworkspace" {
                    return .ios
                }
            }
            // Also check ios subfolder
            let iosPath = url.appendingPathComponent("ios")
            if let iosContents = try? fileManager.contentsOfDirectory(at: iosPath, includingPropertiesForKeys: nil) {
                for item in iosContents {
                    if item.pathExtension == "xcodeproj" || item.pathExtension == "xcworkspace" {
                        return .ios
                    }
                }
            }
        }

        return .unknown
    }

    /// Check if package.json contains react-native dependency
    private static func isReactNativeProject(packageJsonPath: URL) -> Bool {
        guard let data = try? Data(contentsOf: packageJsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        // Check dependencies
        if let dependencies = json["dependencies"] as? [String: Any],
           dependencies["react-native"] != nil {
            return true
        }

        // Check devDependencies
        if let devDependencies = json["devDependencies"] as? [String: Any],
           devDependencies["react-native"] != nil {
            return true
        }

        return false
    }

    /// Get a list of recent/pinned projects from UserDefaults
    static func getRecentProjects() -> [Project] {
        guard let bookmarks = UserDefaults.standard.array(forKey: "recentProjectBookmarks") as? [Data] else {
            return []
        }

        return bookmarks.compactMap { bookmark -> Project? in
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                return nil
            }

            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }

            let type = detectProjectType(at: url)
            return Project(path: url, type: type)
        }
    }

    /// Save a project to recent list
    static func saveRecentProject(_ project: Project) {
        var bookmarks = UserDefaults.standard.array(forKey: "recentProjectBookmarks") as? [Data] ?? []

        // Create security-scoped bookmark
        guard let bookmark = try? project.path.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return
        }

        // Remove existing bookmark for same path
        bookmarks = bookmarks.filter { existingBookmark in
            var isStale = false
            if let existingURL = try? URL(
                resolvingBookmarkData: existingBookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return existingURL != project.path
            }
            return true
        }

        // Add new bookmark at beginning
        bookmarks.insert(bookmark, at: 0)

        // Keep only last 10 projects
        if bookmarks.count > 10 {
            bookmarks = Array(bookmarks.prefix(10))
        }

        UserDefaults.standard.set(bookmarks, forKey: "recentProjectBookmarks")
    }

    /// Remove a project from recent list
    static func removeRecentProject(_ project: Project) {
        var bookmarks = UserDefaults.standard.array(forKey: "recentProjectBookmarks") as? [Data] ?? []

        bookmarks = bookmarks.filter { existingBookmark in
            var isStale = false
            if let existingURL = try? URL(
                resolvingBookmarkData: existingBookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return existingURL != project.path
            }
            return true
        }

        UserDefaults.standard.set(bookmarks, forKey: "recentProjectBookmarks")
    }
}
