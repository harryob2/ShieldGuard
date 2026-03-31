#if canImport(XCTest)
import XCTest
@testable import ShieldGuardCore

final class ShieldGuardCoreTests: XCTestCase {
    func testNpmRuleChecksOneWeekAgeOnly() {
        XCTAssertTrue(ManagerRule.npm.check("min-release-age=7\n"))
        XCTAssertFalse(ManagerRule.npm.check("min-release-age=5\n"))
        XCTAssertFalse(ManagerRule.npm.check("ignore-scripts=true\n"))
    }

    func testRuleApplyIsIdempotentForAllManagers() {
        for rule in ManagerRule.allCases {
            let once = rule.apply(to: nil)
            let twice = rule.apply(to: once)
            XCTAssertEqual(once, twice, "Apply should be idempotent for \(rule.id.rawValue)")
            XCTAssertTrue(rule.check(twice))
        }
    }

    func testBunApplyAddsInstallSection() {
        let text = "[other]\na = 1\n"
        let updated = ManagerRule.bun.apply(to: text)
        XCTAssertTrue(updated.contains("[install]"))
        XCTAssertTrue(updated.contains("minimumReleaseAge = 604800"))
        XCTAssertTrue(ManagerRule.bun.check(updated))
    }

    func testInstalledRulesUsesInstallationFilter() {
        let installed = ShieldGuardEngine.installedRules { rule in
            rule == .uv || rule == .bun
        }
        XCTAssertEqual(installed, [.uv, .bun])
    }
}
#endif
