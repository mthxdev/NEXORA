import XCTest
@testable import Nexora

@MainActor
final class NexoraIconTests: XCTestCase {
    func testEveryLogoMapsToItsDeclaredAlternateName() {
        XCTAssertEqual(AppLogo.classic.alternateIconName, nil)
        XCTAssertEqual(AppLogo.gradient.alternateIconName, "AppIcon-Gradient")
        XCTAssertEqual(AppLogo.minimal.alternateIconName, "AppIcon-Minimal")
        XCTAssertEqual(AppLogo.bold.alternateIconName, "AppIcon-Bold")
        XCTAssertEqual(AppLogo.mono.alternateIconName, "AppIcon-Mono")

        for logo in AppLogo.allCases {
            XCTAssertEqual(AppLogo.forAlternateIconName(logo.alternateIconName), logo)
        }
        XCTAssertNil(AppLogo.forAlternateIconName("UnknownIcon"))
    }

    func testSelectionAndPrimaryResetPersistOnlyAfterSystemConfirms() async {
        let controller = FakeIconController()
        let isolatedDefaults = makeDefaults()
        defer { isolatedDefaults.remove() }
        let defaults = isolatedDefaults.defaults
        let selection = AppIconSelectionModel(controller: controller, defaults: defaults)

        await selection.select(.minimal)
        XCTAssertEqual(controller.alternateIconName, "AppIcon-Minimal")
        XCTAssertEqual(selection.selectedLogo, .minimal)
        XCTAssertEqual(defaults.string(forKey: "appLogo"), AppLogo.minimal.rawValue)

        let reopenedSelection = AppIconSelectionModel(controller: controller, defaults: defaults)
        XCTAssertEqual(reopenedSelection.selectedLogo, .minimal)

        await reopenedSelection.select(.classic)
        XCTAssertNil(controller.alternateIconName)
        XCTAssertEqual(reopenedSelection.selectedLogo, .classic)
        XCTAssertEqual(defaults.string(forKey: "appLogo"), AppLogo.classic.rawValue)
    }

    func testSystemRefusalKeepsDisplayedAndPersistedIconAtActualValue() async {
        let controller = FakeIconController(alternateIconName: "AppIcon-Bold")
        let isolatedDefaults = makeDefaults()
        defer { isolatedDefaults.remove() }
        let defaults = isolatedDefaults.defaults
        let selection = AppIconSelectionModel(controller: controller, defaults: defaults)
        controller.failure = .refused

        await selection.select(.gradient)

        XCTAssertEqual(controller.alternateIconName, "AppIcon-Bold")
        XCTAssertEqual(selection.selectedLogo, .bold)
        XCTAssertEqual(defaults.string(forKey: "appLogo"), AppLogo.bold.rawValue)
        XCTAssertNotNil(selection.errorMessage)
    }

    func testUnsupportedEnvironmentDoesNotChangeSelectionOrCallSystem() async {
        let controller = FakeIconController(supportsAlternateIcons: false)
        let isolatedDefaults = makeDefaults()
        defer { isolatedDefaults.remove() }
        let defaults = isolatedDefaults.defaults
        let selection = AppIconSelectionModel(controller: controller, defaults: defaults)

        await selection.select(.mono)

        XCTAssertEqual(controller.setCallCount, 0)
        XCTAssertEqual(selection.selectedLogo, .classic)
        XCTAssertEqual(defaults.string(forKey: "appLogo"), AppLogo.classic.rawValue)
        XCTAssertNotNil(selection.errorMessage)
    }

    private func makeDefaults() -> IsolatedDefaults {
        let suiteName = "NexoraIconTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return IsolatedDefaults(suiteName: suiteName, defaults: defaults)
    }
}

private struct IsolatedDefaults {
    let suiteName: String
    let defaults: UserDefaults

    func remove() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class FakeIconController: AppIconControlling {
    enum Failure: Error { case refused }

    var supportsAlternateIcons: Bool
    var alternateIconName: String?
    var failure: Failure?
    private(set) var setCallCount = 0

    init(supportsAlternateIcons: Bool = true, alternateIconName: String? = nil) {
        self.supportsAlternateIcons = supportsAlternateIcons
        self.alternateIconName = alternateIconName
    }

    func setAlternateIconName(_ name: String?) async throws {
        setCallCount += 1
        if let failure { throw failure }
        alternateIconName = name
    }
}
