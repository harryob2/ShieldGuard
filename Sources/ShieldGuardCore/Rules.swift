import Foundation

public enum ManagerRule: CaseIterable {
    case npm
    case pnpm
    case uv
    case bun

    public var id: ManagerID {
        switch self {
        case .npm: return .npm
        case .pnpm: return .pnpm
        case .uv: return .uv
        case .bun: return .bun
        }
    }

    public var executableName: String {
        switch self {
        case .npm:
            return "npm"
        case .pnpm:
            return "pnpm"
        case .uv:
            return "uv"
        case .bun:
            return "bun"
        }
    }

    public var isInstalled: Bool {
        ToolAvailability.hasExecutable(named: executableName)
    }

    public var fileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .npm:
            return home.appendingPathComponent(".npmrc")
        case .pnpm:
            return home.appendingPathComponent("Library/Preferences/pnpm/rc")
        case .uv:
            return home.appendingPathComponent(".config/uv/uv.toml")
        case .bun:
            return home.appendingPathComponent(".bunfig.toml")
        }
    }

    public var requiredValueDescription: String {
        switch self {
        case .npm:
            return "min-release-age=7"
        case .pnpm:
            return "minimum-release-age=10080"
        case .uv:
            return "exclude-newer = \"7 days\""
        case .bun:
            return "[install] minimumReleaseAge = 604800"
        }
    }

    public var addButtonTitle: String {
        "Add \(requiredValueDescription)"
    }

    public func check(_ text: String?) -> Bool {
        switch self {
        case .npm:
            return parseAssignments(text)["min-release-age"] == "7"
        case .pnpm:
            return parseAssignments(text)["minimum-release-age"] == "10080"
        case .uv:
            return normalizeTomlString(parseAssignments(text)["exclude-newer"]) == "7 days"
        case .bun:
            return hasBunMinimumReleaseAge(text)
        }
    }

    public func apply(to text: String?) -> String {
        var lines = splitLines(text)

        switch self {
        case .npm:
            setOrAppendAssignment(lines: &lines, key: "min-release-age", value: "7", style: .ini)
        case .pnpm:
            setOrAppendAssignment(lines: &lines, key: "minimum-release-age", value: "10080", style: .ini)
        case .uv:
            setOrAppendAssignment(lines: &lines, key: "exclude-newer", value: "\"7 days\"", style: .toml)
        case .bun:
            setBunMinimumReleaseAge(lines: &lines)
        }

        return joinLines(lines)
    }

    public func result(from text: String?) -> ManagerCheckResult {
        ManagerCheckResult(
            manager: id,
            fileURL: fileURL,
            requiredValueDescription: requiredValueDescription,
            addButtonTitle: addButtonTitle,
            compliant: check(text)
        )
    }
}

public enum ShieldGuardEngine {
    public static func checkAll(
        installationCheck: (ManagerRule) -> Bool = { $0.isInstalled }
    ) -> [ManagerCheckResult] {
        installedRules(installationCheck: installationCheck).map { rule in
            let text = FileIO.readText(at: rule.fileURL)
            return rule.result(from: text)
        }
    }

    public static func addRequiredValue(for rule: ManagerRule) throws {
        let existing = FileIO.readText(at: rule.fileURL)
        let updated = rule.apply(to: existing)
        if updated == (existing ?? "") {
            return
        }

        try FileIO.writeAtomicallyWithTimestampedBackup(
            content: updated,
            to: rule.fileURL,
            backupRoot: backupDirectoryURL()
        )
    }

    public static func fixAll(
        installationCheck: (ManagerRule) -> Bool = { $0.isInstalled }
    ) throws {
        for rule in installedRules(installationCheck: installationCheck) {
            try addRequiredValue(for: rule)
        }
    }

    public static func installedRules(
        installationCheck: (ManagerRule) -> Bool = { $0.isInstalled }
    ) -> [ManagerRule] {
        ManagerRule.allCases.filter(installationCheck)
    }

    private static func backupDirectoryURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("ShieldGuard/backups", isDirectory: true)
    }
}

private enum ToolAvailability {
    static func hasExecutable(named executable: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [executable]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

private enum AssignmentStyle {
    case ini
    case toml

    func render(key: String, value: String) -> String {
        switch self {
        case .ini:
            return "\(key)=\(value)"
        case .toml:
            return "\(key) = \(value)"
        }
    }
}

private func splitLines(_ text: String?) -> [String] {
    guard let text, !text.isEmpty else { return [] }
    return text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
}

private func joinLines(_ lines: [String]) -> String {
    guard !lines.isEmpty else { return "" }
    return lines.joined(separator: "\n") + "\n"
}

private func parseAssignments(_ text: String?) -> [String: String] {
    var assignments = [String: String]()
    for line in splitLines(text) {
        guard let (key, value) = parseAssignment(from: stripComment(line)) else { continue }
        assignments[key] = value
    }
    return assignments
}

private func stripComment(_ line: String) -> String {
    if let hash = line.firstIndex(of: "#") {
        return String(line[..<hash])
    }
    return line
}

private func parseAssignment(from line: String) -> (String, String)? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { return nil }

    let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
    let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else { return nil }

    return (key, value)
}

private func setOrAppendAssignment(
    lines: inout [String],
    key: String,
    value: String,
    style: AssignmentStyle
) {
    let rendered = style.render(key: key, value: value)
    var firstIndex: Int?
    var duplicateIndexes = [Int]()

    for (index, line) in lines.enumerated() {
        guard let (existingKey, _) = parseAssignment(from: stripComment(line)) else { continue }
        if existingKey == key {
            if firstIndex == nil {
                firstIndex = index
            } else {
                duplicateIndexes.append(index)
            }
        }
    }

    if let firstIndex {
        lines[firstIndex] = rendered
        for index in duplicateIndexes.reversed() {
            lines.remove(at: index)
        }
    } else {
        lines.append(rendered)
    }
}

private func normalizeTomlString(_ value: String?) -> String? {
    guard let value else { return nil }
    return value.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
}

private func parseSectionName(from line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return nil }
    let start = trimmed.index(after: trimmed.startIndex)
    let end = trimmed.index(before: trimmed.endIndex)
    let section = trimmed[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
    return section.isEmpty ? nil : section
}

private func hasBunMinimumReleaseAge(_ text: String?) -> Bool {
    var currentSection: String?
    for line in splitLines(text) {
        if let section = parseSectionName(from: line) {
            currentSection = section
            continue
        }
        guard currentSection == "install" else { continue }
        guard let (key, value) = parseAssignment(from: stripComment(line)) else { continue }
        if key == "minimumReleaseAge", Int(normalizeTomlString(value) ?? "") == 604800 {
            return true
        }
    }
    return false
}

private func setBunMinimumReleaseAge(lines: inout [String]) {
    let sectionName = "install"
    let key = "minimumReleaseAge"
    let rendered = "minimumReleaseAge = 604800"

    var sectionStart: Int?
    var sectionEnd = lines.count

    for (index, line) in lines.enumerated() {
        if let section = parseSectionName(from: line) {
            if section == sectionName {
                sectionStart = index
                sectionEnd = lines.count
            } else if sectionStart != nil {
                sectionEnd = index
                break
            }
        }
    }

    guard let sectionStart else {
        if !lines.isEmpty, lines.last?.isEmpty == false {
            lines.append("")
        }
        lines.append("[install]")
        lines.append(rendered)
        return
    }

    var firstMatch: Int?
    var duplicates = [Int]()

    for index in (sectionStart + 1)..<sectionEnd {
        guard let (candidateKey, _) = parseAssignment(from: stripComment(lines[index])) else { continue }
        if candidateKey == key {
            if firstMatch == nil {
                firstMatch = index
            } else {
                duplicates.append(index)
            }
        }
    }

    if let firstMatch {
        lines[firstMatch] = rendered
        for index in duplicates.reversed() {
            lines.remove(at: index)
        }
    } else {
        lines.insert(rendered, at: sectionStart + 1)
    }
}
