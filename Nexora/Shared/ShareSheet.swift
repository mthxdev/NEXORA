import SwiftUI
import UIKit

#if DIAGNOSTIC
struct DebugShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
struct DebugShareSheet: View {
    var body: some View { EmptyView() }
}
#endif