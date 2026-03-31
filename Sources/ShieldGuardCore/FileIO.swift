import Foundation

public enum ShieldGuardFileError: Error, LocalizedError {
    case couldNotEncode
    case replaceFailed

    public var errorDescription: String? {
        switch self {
        case .couldNotEncode:
            return "Could not encode file data"
        case .replaceFailed:
            return "Atomic file replace failed"
        }
    }
}

public enum FileIO {
    public static func readText(at url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    public static func writeAtomicallyWithTimestampedBackup(
        content: String,
        to url: URL,
        backupRoot: URL
    ) throws {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)

        let hadExistingFile = fm.fileExists(atPath: url.path)
        if hadExistingFile {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let stamp = formatter.string(from: Date())
            let sanitized = url.path.replacingOccurrences(of: "/", with: "_")
            let backupName = "\(sanitized).\(stamp).bak"
            try fm.createDirectory(at: backupRoot, withIntermediateDirectories: true, attributes: nil)
            let backupURL = backupRoot.appendingPathComponent(backupName)
            try? fm.removeItem(at: backupURL)
            try fm.copyItem(at: url, to: backupURL)
        }

        guard let data = content.data(using: .utf8) else {
            throw ShieldGuardFileError.couldNotEncode
        }

        let tempURL = dir.appendingPathComponent(".shieldguard.tmp.\(UUID().uuidString)")
        try data.write(to: tempURL, options: .atomic)

        if hadExistingFile {
            _ = try fm.replaceItemAt(url, withItemAt: tempURL)
        } else {
            try fm.moveItem(at: tempURL, to: url)
        }
    }
}
