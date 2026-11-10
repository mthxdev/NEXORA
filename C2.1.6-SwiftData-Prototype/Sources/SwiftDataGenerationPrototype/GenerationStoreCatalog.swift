import Foundation
import SwiftData

public enum GenerationStoreSelectionError: Error, Equatable {
    case missingManifest
    case unknownGeneration(String)
    case invalidAuthorizedStoreURL(String)
    case duplicateStoreURL(String, String)
    case storeFileMissing(String)
    case invalidStoreFile(String)
    case missingStoreMarker(String)
    case duplicateStoreMarkers(String)
    case storeMarkerMismatch(expected: String, actual: String)
    case recordGenerationMismatch(expected: String, actual: [String])
}

/// Trusted configuration mapping generation IDs to approved local store URLs.
/// The manifest can choose an ID, but it cannot provide or override a store URL.
public struct GenerationStoreCatalog {
    private let storeURLs: [String: URL]

    public init(storeURLs: [String: URL]) throws {
        var normalizedOwners: [String: String] = [:]
        for generationID in storeURLs.keys.sorted() {
            guard let url = storeURLs[generationID] else {
                throw GenerationStoreSelectionError.invalidAuthorizedStoreURL(generationID)
            }
            guard !generationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  url.isFileURL,
                  !url.path.isEmpty else {
                throw GenerationStoreSelectionError.invalidAuthorizedStoreURL(generationID)
            }

            let normalizedPath = url.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL.path
            if let existingOwner = normalizedOwners[normalizedPath] {
                throw GenerationStoreSelectionError.duplicateStoreURL(existingOwner, generationID)
            }
            normalizedOwners[normalizedPath] = generationID
        }
        self.storeURLs = storeURLs
    }

    @MainActor
    public func openSelectedContainer(using manifest: GenerationManifestStore) throws -> ModelContainer {
        guard let selection = try manifest.readSelection() else {
            throw GenerationStoreSelectionError.missingManifest
        }
        guard let storeURL = storeURLs[selection.generationID] else {
            throw GenerationStoreSelectionError.unknownGeneration(selection.generationID)
        }

        // A ModelContainer may initialize storage at its configured URL. Require
        // an existing, readable regular file before giving SwiftData that URL.
        // This narrows the create-on-open risk; SwiftData does not document the
        // missing-file behavior as a non-creation guarantee.
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            throw GenerationStoreSelectionError.storeFileMissing(selection.generationID)
        }
        do {
            let values = try storeURL.resourceValues(forKeys: [.isRegularFileKey, .isReadableKey, .fileSizeKey])
            guard values.isRegularFile == true,
                  values.isReadable == true,
                  let fileSize = values.fileSize,
                  fileSize > 0 else {
                throw GenerationStoreSelectionError.invalidStoreFile(selection.generationID)
            }
        } catch let error as GenerationStoreSelectionError {
            throw error
        } catch {
            throw GenerationStoreSelectionError.invalidStoreFile(selection.generationID)
        }

        let container = try GenerationStoreFactory.makeContainer(
            at: storeURL,
            name: "generation-\(selection.generationID)"
        )
        let context = ModelContext(container)
        let markers = try GenerationStoreFactory.markers(in: context)
        guard !markers.isEmpty else {
            throw GenerationStoreSelectionError.missingStoreMarker(selection.generationID)
        }
        guard markers.count == 1 else {
            throw GenerationStoreSelectionError.duplicateStoreMarkers(selection.generationID)
        }
        guard let marker = markers.first, marker.generationID == selection.generationID else {
            throw GenerationStoreSelectionError.storeMarkerMismatch(
                expected: selection.generationID,
                actual: markers.first?.generationID ?? "<missing>"
            )
        }

        let records = try GenerationStoreFactory.records(in: context)
        let actualGenerations = Set(records.map(\.generation)).subtracting([selection.generationID])
        guard actualGenerations.isEmpty else {
            throw GenerationStoreSelectionError.recordGenerationMismatch(
                expected: selection.generationID,
                actual: actualGenerations.sorted()
            )
        }
        return container
    }
}
