import Foundation

/// Parses Makefile to extract available targets
final class MakefileParser {

    // MARK: - Detection

    /// Check if a Makefile exists at the given project URL
    static func hasMakefile(at url: URL) -> Bool {
        let makefilePath = url.appendingPathComponent("Makefile")
        let makefilePathLower = url.appendingPathComponent("makefile")
        let gnuMakefile = url.appendingPathComponent("GNUmakefile")

        return FileManager.default.fileExists(atPath: makefilePath.path) ||
               FileManager.default.fileExists(atPath: makefilePathLower.path) ||
               FileManager.default.fileExists(atPath: gnuMakefile.path)
    }

    /// Get the Makefile path if it exists
    static func getMakefilePath(at url: URL) -> URL? {
        let candidates = ["Makefile", "makefile", "GNUmakefile"]
        for name in candidates {
            let path = url.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }
        return nil
    }

    // MARK: - Parsing

    /// Parse targets from a Makefile
    /// - Parameter url: Project directory URL
    /// - Returns: Array of MakefileTarget objects
    static func parseTargets(at url: URL) -> [MakefileTarget] {
        guard let makefilePath = getMakefilePath(at: url),
              let content = try? String(contentsOf: makefilePath, encoding: .utf8) else {
            return []
        }

        return parseTargets(from: content)
    }

    /// Parse targets from Makefile content string
    /// - Parameter content: Makefile content
    /// - Returns: Array of MakefileTarget objects
    static func parseTargets(from content: String) -> [MakefileTarget] {
        var targets: [MakefileTarget] = []
        let lines = content.components(separatedBy: .newlines)

        // Regex pattern: matches target names at start of line followed by colon
        // Examples: build:, test-unit:, clean:, my_target:
        let pattern = #"^([a-zA-Z_][a-zA-Z0-9_-]*):"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return []
        }

        // Set of targets to exclude (internal/special targets)
        let excludedTargets: Set<String> = [
            "all", ".PHONY", ".DEFAULT", ".SUFFIXES", ".PRECIOUS",
            ".INTERMEDIATE", ".SECONDARY", ".SECONDEXPANSION",
            ".DELETE_ON_ERROR", ".IGNORE", ".LOW_RESOLUTION_TIME",
            ".SILENT", ".EXPORT_ALL_VARIABLES", ".NOTPARALLEL",
            ".ONESHELL", ".POSIX"
        ]

        for (index, line) in lines.enumerated() {
            // Skip lines starting with . (special targets) or # (comments)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(".") || trimmed.hasPrefix("#") || trimmed.isEmpty {
                continue
            }

            // Find target match
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range),
               let targetRange = Range(match.range(at: 1), in: line) {
                let targetName = String(line[targetRange])

                // Skip excluded targets
                if excludedTargets.contains(targetName) {
                    continue
                }

                // Look for description comment above the target
                var description: String?
                if index > 0 {
                    let prevLine = lines[index - 1].trimmingCharacters(in: .whitespaces)
                    if prevLine.hasPrefix("#") {
                        // Extract comment without the # prefix
                        description = String(prevLine.dropFirst()).trimmingCharacters(in: .whitespaces)
                    }
                }

                targets.append(MakefileTarget(name: targetName, description: description))
            }
        }

        // Remove duplicates while preserving order
        var seen = Set<String>()
        return targets.filter { target in
            if seen.contains(target.name) {
                return false
            }
            seen.insert(target.name)
            return true
        }
    }
}
