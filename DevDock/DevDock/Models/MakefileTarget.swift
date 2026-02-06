import Foundation

/// Represents a target parsed from a Makefile
struct MakefileTarget: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let description: String?

    init(name: String, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.description = description
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static func == (lhs: MakefileTarget, rhs: MakefileTarget) -> Bool {
        lhs.name == rhs.name
    }
}
