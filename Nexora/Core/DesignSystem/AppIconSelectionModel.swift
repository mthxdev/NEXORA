import Combine
import UIKit

@MainActor
protocol AppIconControlling: AnyObject {
    var supportsAlternateIcons: Bool { get }
    var alternateIconName: String? { get }
    func setAlternateIconName(_ name: String?) async throws
}

@MainActor
private final class UIApplicationIconController: AppIconControlling {
    private let application: UIApplication

    init(application: UIApplication = .shared) {
        self.application = application
    }

    var supportsAlternateIcons: Bool { application.supportsAlternateIcons }
    var alternateIconName: String? { application.alternateIconName }

    func setAlternateIconName(_ name: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            application.setAlternateIconName(name) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

@MainActor
final class AppIconSelectionModel: ObservableObject {
    @Published private(set) var selectedLogo: AppLogo?
    @Published private(set) var isApplying = false
    @Published private(set) var errorMessage: String?

    private let controller: AppIconControlling
    private let defaults: UserDefaults

    var supportsAlternateIcons: Bool { controller.supportsAlternateIcons }
    var activeAlternateIconName: String? { controller.alternateIconName }

    init(defaults: UserDefaults = .standard) {
        self.controller = UIApplicationIconController()
        self.defaults = defaults
        refreshFromSystem()
    }

    init(controller: AppIconControlling, defaults: UserDefaults = .standard) {
        self.controller = controller
        self.defaults = defaults
        refreshFromSystem()
    }

    func refreshFromSystem() {
        selectedLogo = AppLogo.forAlternateIconName(controller.alternateIconName)
        if let selectedLogo {
            defaults.set(selectedLogo.rawValue, forKey: "appLogo")
        }
    }

    func select(_ logo: AppLogo) async {
        guard supportsAlternateIcons else {
            errorMessage = "iOS ne permet pas de modifier l’icône de cette application dans cet environnement."
            refreshFromSystem()
            return
        }
        guard !isApplying else { return }

        isApplying = true
        defer { isApplying = false }

        do {
            try await controller.setAlternateIconName(logo.alternateIconName)
            guard controller.alternateIconName == logo.alternateIconName else {
                refreshFromSystem()
                errorMessage = "iOS n’a pas confirmé l’icône demandée. La sélection affichée correspond à l’icône système actuelle."
                return
            }
            selectedLogo = logo
            defaults.set(logo.rawValue, forKey: "appLogo")
            errorMessage = nil
        } catch {
            refreshFromSystem()
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
