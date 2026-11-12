import SwiftUI
import UIKit

/// Temporary runtime probe for diagnosing reduced SwiftUI/UIKit presentation bounds.
/// Remove this file and its two `.runtimeLayoutDiagnostics(...)` call sites after collecting measurements.
struct RuntimeLayoutDiagnosticsModifier: ViewModifier {
    let location: String

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            RuntimeLayoutDiagnosticsLogger.logSwiftUI(
                                location: location,
                                size: geometry.size,
                                safeAreaInsets: geometry.safeAreaInsets
                            )
                        }
                        .onChange(of: geometry.size) { _, size in
                            RuntimeLayoutDiagnosticsLogger.logSwiftUI(
                                location: location,
                                size: size,
                                safeAreaInsets: geometry.safeAreaInsets
                            )
                        }
                        .onChange(of: geometry.safeAreaInsets) { _, insets in
                            RuntimeLayoutDiagnosticsLogger.logSwiftUI(
                                location: location,
                                size: geometry.size,
                                safeAreaInsets: insets
                            )
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                RuntimeWindowProbe(location: location)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

extension View {
    func runtimeLayoutDiagnostics(_ location: String) -> some View {
        modifier(RuntimeLayoutDiagnosticsModifier(location: location))
    }
}

private enum RuntimeLayoutDiagnosticsLogger {
    static func logSwiftUI(location: String, size: CGSize, safeAreaInsets: EdgeInsets) {
        let launchScreen = String(describing: Bundle.main.infoDictionary?["UILaunchScreen"] ?? "<absent>")
        let message = "[RuntimeLayout] SwiftUI \(location): size=\(size), safeAreaInsets=\(safeAreaInsets), UILaunchScreen=\(launchScreen)"
        NSLog("%@", message)
    }
}

private struct RuntimeWindowProbe: UIViewRepresentable {
    let location: String

    func makeUIView(context: Context) -> ProbeView {
        ProbeView(location: location)
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.location = location
        view.reportIfChanged()
    }

    final class ProbeView: UIView {
        var location: String
        private var lastReport = ""

        init(location: String) {
            self.location = location
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportIfChanged()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            reportIfChanged()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            reportIfChanged()
        }

        func reportIfChanged() {
            guard let window else { return }

            let sceneBounds = window.windowScene.map {
                String(describing: $0.coordinateSpace.bounds)
            } ?? "nil"
            let message = "[RuntimeLayout] UIKit \(location): UIScreen.main.bounds=\(UIScreen.main.bounds), " +
                "window.screen.bounds=\(window.screen.bounds), " +
                "windowScene.coordinateSpace.bounds=\(sceneBounds), " +
                "window.frame=\(window.frame), window.bounds=\(window.bounds), " +
                "window.safeAreaInsets=\(window.safeAreaInsets), " +
                "probeView.bounds=\(bounds), probeView.safeAreaInsets=\(safeAreaInsets)"

            guard message != lastReport else { return }
            lastReport = message
            NSLog("%@", message)
        }
    }
}
