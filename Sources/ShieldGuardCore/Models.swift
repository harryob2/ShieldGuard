import Foundation

public enum ManagerID: String, CaseIterable, Hashable, Comparable {
    case npm
    case pnpm
    case uv
    case bun

    public var displayName: String { rawValue.uppercased() }

    public static func < (lhs: ManagerID, rhs: ManagerID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ManagerCheckResult: Equatable {
    public let manager: ManagerID
    public let fileURL: URL
    public let requiredValueDescription: String
    public let addButtonTitle: String
    public let compliant: Bool

    public init(
        manager: ManagerID,
        fileURL: URL,
        requiredValueDescription: String,
        addButtonTitle: String,
        compliant: Bool
    ) {
        self.manager = manager
        self.fileURL = fileURL
        self.requiredValueDescription = requiredValueDescription
        self.addButtonTitle = addButtonTitle
        self.compliant = compliant
    }
}
