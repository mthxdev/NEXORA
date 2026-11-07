import SwiftData
import SwiftUI

/// Minimal view used by the simulator test to observe which injected store
/// supplies @Query results.
public struct GenerationQueryView: View {
    @Query(sort: \GenerationRecord.label) private var records: [GenerationRecord]
    private let onLabelsChanged: ([String]) -> Void

    public init(onLabelsChanged: @escaping ([String]) -> Void) {
        self.onLabelsChanged = onLabelsChanged
    }

    public var body: some View {
        let labels = records.map(\.label)
        Text(labels.joined(separator: ","))
            .onChange(of: labels, initial: true) { _, newLabels in
                onLabelsChanged(newLabels)
            }
    }
}
