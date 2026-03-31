import AppKit
import Foundation
import ShieldGuardCore

@MainActor
final class ShieldGuardViewModel: ObservableObject {
    @Published var results: [ManagerCheckResult] = []
    @Published var errorMessage: String?
    @Published var successMessage: String?

    init() {
        checkNow()
    }

    func checkNow() {
        results = ShieldGuardEngine.checkAll().sorted { $0.manager < $1.manager }
        if results.isEmpty {
            successMessage = "No supported package managers found on this machine."
        } else {
            successMessage = nil
        }
    }

    func fixAll() {
        do {
            try ShieldGuardEngine.fixAll()
            checkNow()
            successMessage = "All required lines have been added."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
        }
    }

    func addRequiredValue(for manager: ManagerID) {
        guard let rule = ShieldGuardEngine.installedRules().first(where: { $0.id == manager }) else { return }
        do {
            try ShieldGuardEngine.addRequiredValue(for: rule)
            checkNow()
            successMessage = "Updated \(manager.displayName)."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
        }
    }

    func openInFinder(_ url: URL) {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }

        let parent = url.deletingLastPathComponent()
        if fm.fileExists(atPath: parent.path) {
            NSWorkspace.shared.open(parent)
        } else {
            NSWorkspace.shared.open(fm.homeDirectoryForCurrentUser)
        }
    }
}
