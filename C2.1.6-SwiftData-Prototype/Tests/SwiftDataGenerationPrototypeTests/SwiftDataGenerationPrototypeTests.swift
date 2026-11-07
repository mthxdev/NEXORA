import Foundation
import Dispatch
import SwiftData
import SwiftDataGenerationPrototype
import SwiftUI
import UIKit
import XCTest

final class SwiftDataGenerationPrototypeTests: XCTestCase {
    @MainActor
    func testTwoExplicitStoresRemainIndependentAfterReopening() throws {
        let root = try makeTemporaryDirectory()
        let storeN = root.appendingPathComponent("generation-N.store")
        let storeN1 = root.appendingPathComponent("generation-N1.store")

        try createAndReleaseStore(
            at: storeN,
            generationID: "N",
            values: [("N-one", 11), ("N-two", 12)]
        )
        try createAndReleaseStore(
            at: storeN1,
            generationID: "N+1",
            values: [("N1-one", 21), ("N1-two", 22), ("N1-three", 23)]
        )

        let reopenedN1 = try GenerationStoreFactory.makeContainer(at: storeN1, name: "generation-N1-reopen")
        XCTAssertEqual(try snapshot(in: ModelContext(reopenedN1)), ["N1-one": 21, "N1-two": 22, "N1-three": 23])

        let reopenedN = try GenerationStoreFactory.makeContainer(at: storeN, name: "generation-N-reopen")
        XCTAssertEqual(try snapshot(in: ModelContext(reopenedN)), ["N-one": 11, "N-two": 12])
    }

    @MainActor
    func testManifestSelectionOpensExactlyNOrN1FromCatalog() throws {
        let root = try makeTemporaryDirectory()
        let storeN = root.appendingPathComponent("generation-N.store")
        let storeN1 = root.appendingPathComponent("generation-N1.store")
        try createAndReleaseStore(at: storeN, generationID: "N", values: [("N-record", 1)])
        try createAndReleaseStore(at: storeN1, generationID: "N+1", values: [("N1-record", 2)])

        let manifest = GenerationManifestStore(manifestURL: root.appendingPathComponent("selector.json"))
        let catalog = try GenerationStoreCatalog(storeURLs: ["N": storeN, "N+1": storeN1])

        try manifest.publish(GenerationSelection(sequence: 1, generationID: "N"))
        let selectedN = try catalog.openSelectedContainer(using: manifest)
        XCTAssertEqual(try snapshot(in: ModelContext(selectedN)), ["N-record": 1])

        try manifest.publish(GenerationSelection(sequence: 2, generationID: "N+1"))
        let selectedN1 = try catalog.openSelectedContainer(using: manifest)
        XCTAssertEqual(try snapshot(in: ModelContext(selectedN1)), ["N1-record": 2])
    }

    @MainActor
    func testUnknownGenerationIsRejectedWithoutChoosingAnotherStore() throws {
        let root = try makeTemporaryDirectory()
        let storeN = root.appendingPathComponent("generation-N.store")
        try createAndReleaseStore(at: storeN, generationID: "N", values: [("N-record", 1)])

        let manifest = GenerationManifestStore(manifestURL: root.appendingPathComponent("selector.json"))
        try manifest.publish(GenerationSelection(sequence: 99, generationID: "unknown"))
        let catalog = try GenerationStoreCatalog(storeURLs: ["N": storeN])

        XCTAssertThrowsError(try catalog.openSelectedContainer(using: manifest)) { error in
            XCTAssertEqual(error as? GenerationStoreSelectionError, .unknownGeneration("unknown"))
        }
    }

    @MainActor
    func testIncorrectGenerationToURLAssociationIsRejectedByStoreMarker() throws {
        let root = try makeTemporaryDirectory()
        let storeN1 = root.appendingPathComponent("generation-N1.store")
        try createAndReleaseStore(at: storeN1, generationID: "N+1", values: [("N1-record", 2)])

        let manifest = GenerationManifestStore(manifestURL: root.appendingPathComponent("selector.json"))
        try manifest.publish(GenerationSelection(sequence: 1, generationID: "N"))
        let catalog = try GenerationStoreCatalog(storeURLs: ["N": storeN1])

        XCTAssertThrowsError(try catalog.openSelectedContainer(using: manifest)) { error in
            XCTAssertEqual(
                error as? GenerationStoreSelectionError,
                .storeMarkerMismatch(expected: "N", actual: "N+1")
            )
        }
    }

    @MainActor
    func testForeignGenerationRecordIsRejectedEvenWhenStoreMarkerMatches() throws {
        let root = try makeTemporaryDirectory()
        let storeN = root.appendingPathComponent("generation-N.store")
        let container = try GenerationStoreFactory.makeContainer(at: storeN, name: "mixed-generation-store")
        let context = ModelContext(container)
        context.insert(GenerationStoreMarker(generationID: "N"))
        context.insert(GenerationRecord(generation: "N+1", label: "foreign-record", value: 99))
        try context.save()

        let manifest = GenerationManifestStore(manifestURL: root.appendingPathComponent("selector.json"))
        try manifest.publish(GenerationSelection(sequence: 1, generationID: "N"))
        let catalog = try GenerationStoreCatalog(storeURLs: ["N": storeN])

        XCTAssertThrowsError(try catalog.openSelectedContainer(using: manifest)) { error in
            XCTAssertEqual(
                error as? GenerationStoreSelectionError,
                .recordGenerationMismatch(expected: "N", actual: ["N+1"])
            )
        }
    }

    func testCatalogRejectsTwoGenerationsMappedToTheSameURL() throws {
        let root = try makeTemporaryDirectory()
        let sharedURL = root.appendingPathComponent("shared.store")

        XCTAssertThrowsError(try GenerationStoreCatalog(storeURLs: ["N": sharedURL, "N+1": sharedURL])) { error in
            XCTAssertEqual(error as? GenerationStoreSelectionError, .duplicateStoreURL("N", "N+1"))
        }
    }

    func testManifestCannotSupplyAnArbitraryStoreURL() throws {
        let root = try makeTemporaryDirectory()
        let manifestURL = root.appendingPathComponent("selector.json")
        let manifest = GenerationManifestStore(manifestURL: manifestURL)
        try manifest.publish(GenerationSelection(sequence: 1, generationID: "N"))

        var envelope = try jsonObject(at: manifestURL)
        envelope["storeURL"] = root.appendingPathComponent("outside-catalog.store").absoluteString
        try writeJSON(envelope, to: manifestURL)

        XCTAssertThrowsError(try manifest.readSelection()) { error in
            XCTAssertEqual(error as? GenerationManifestError, .invalidManifestStructure)
        }
    }

    @MainActor
    func testAbsentManifestHasNoSelectionAndCatalogFailsClosed() throws {
        let root = try makeTemporaryDirectory()
        let manifest = GenerationManifestStore(manifestURL: root.appendingPathComponent("missing.json"))
        let storeN = root.appendingPathComponent("generation-N.store")
        try createAndReleaseStore(at: storeN, generationID: "N", values: [("N-record", 1)])
        let catalog = try GenerationStoreCatalog(storeURLs: ["N": storeN])

        XCTAssertNil(try manifest.readSelection())
        XCTAssertThrowsError(try catalog.openSelectedContainer(using: manifest)) { error in
            XCTAssertEqual(error as? GenerationStoreSelectionError, .missingManifest)
        }
    }

    @MainActor
    func testMissingSelectedStoreIsRejectedWithoutCreatingAFile() throws {
        let root = try makeTemporaryDirectory()
        let missingStore = root.appendingPathComponent("not-created.store")
        let manifest = GenerationManifestStore(manifestURL: root.appendingPathComponent("selector.json"))
        try manifest.publish(GenerationSelection(sequence: 1, generationID: "N"))
        let catalog = try GenerationStoreCatalog(storeURLs: ["N": missingStore])

        XCTAssertFalse(FileManager.default.fileExists(atPath: missingStore.path))
        XCTAssertThrowsError(try catalog.openSelectedContainer(using: manifest)) { error in
            XCTAssertEqual(error as? GenerationStoreSelectionError, .storeFileMissing("N"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingStore.path))
    }

    @MainActor
    func testDirectoryCannotBeOpenedAsASelectedStore() throws {
        let root = try makeTemporaryDirectory()
        let directoryURL = root.appendingPathComponent("not-a-store.store", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        let manifest = GenerationManifestStore(manifestURL: root.appendingPathComponent("selector.json"))
        try manifest.publish(GenerationSelection(sequence: 1, generationID: "N"))
        let catalog = try GenerationStoreCatalog(storeURLs: ["N": directoryURL])

        XCTAssertThrowsError(try catalog.openSelectedContainer(using: manifest)) { error in
            XCTAssertEqual(error as? GenerationStoreSelectionError, .invalidStoreFile("N"))
        }
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testInvalidJSONIsRejectedAsInvalidManifestStructure() throws {
        let root = try makeTemporaryDirectory()
        let manifestURL = root.appendingPathComponent("broken.json")
        try Data("{not valid json".utf8).write(to: manifestURL)
        let manifest = GenerationManifestStore(manifestURL: manifestURL)

        XCTAssertThrowsError(try manifest.readSelection()) { error in
            XCTAssertEqual(error as? GenerationManifestError, .invalidManifestStructure)
        }
    }

    func testChecksumTamperingWithValidJSONReturnsInvalidChecksum() throws {
        let root = try makeTemporaryDirectory()
        let manifestURL = root.appendingPathComponent("selector.json")
        let manifest = GenerationManifestStore(manifestURL: manifestURL)
        try manifest.publish(GenerationSelection(sequence: 1, generationID: "N"))

        var envelope = try jsonObject(at: manifestURL)
        var selection = try XCTUnwrap(envelope["selection"] as? [String: Any])
        selection["sequence"] = 500
        envelope["selection"] = selection
        try writeJSON(envelope, to: manifestURL)

        XCTAssertThrowsError(try manifest.readSelection()) { error in
            XCTAssertEqual(error as? GenerationManifestError, .invalidChecksum)
        }
    }

    func testManifestSelectionAndInjectedInterruptionBoundaries() throws {
        let root = try makeTemporaryDirectory()
        let manifest = GenerationManifestStore(manifestURL: root.appendingPathComponent("selector.json"))
        let n = GenerationSelection(sequence: 1, generationID: "N")
        let n1 = GenerationSelection(sequence: 2, generationID: "N+1")

        try manifest.publish(n)
        XCTAssertEqual(try manifest.readSelection(), n)

        XCTAssertThrowsError(try manifest.publish(n1, interruptAt: .afterStagingWrite))
        XCTAssertEqual(try manifest.readSelection(), n, "Unpublished staging data must not select N+1")

        XCTAssertThrowsError(try manifest.publish(n1, interruptAt: .afterManifestPublication))
        XCTAssertEqual(try manifest.readSelection(), n1, "After publication, the new selection is readable")
        try manifest.publish(n1)
        XCTAssertEqual(try manifest.readSelection(), n1, "Repeating publication is idempotent")
    }

    func testConcurrentPublicationsThroughSeparateInstancesRemainReadable() throws {
        let root = try makeTemporaryDirectory()
        let manifestURL = root.appendingPathComponent("selector.json")
        let firstWriter = GenerationManifestStore(manifestURL: manifestURL)
        let secondWriter = GenerationManifestStore(manifestURL: manifestURL)
        let errors = ConcurrentErrorCollector()
        let selections = (0..<64).map { index in
            GenerationSelection(
                sequence: index,
                generationID: index.isMultiple(of: 2) ? "N" : "N+1"
            )
        }

        DispatchQueue.concurrentPerform(iterations: selections.count) { index in
            let writer = index.isMultiple(of: 2) ? firstWriter : secondWriter
            do {
                try writer.publish(selections[index])
            } catch {
                errors.append(error)
            }
        }

        XCTAssertTrue(errors.values.isEmpty, "Concurrent writes should not fail: \(errors.values)")
        let finalSelection = try XCTUnwrap(firstWriter.readSelection())
        XCTAssertTrue(selections.contains(finalSelection), "Final manifest must be one complete published selection")
    }

    @MainActor
    func testQueryReadsTheContainerInjectedIntoSwiftUI() throws {
        let root = try makeTemporaryDirectory()
        let storeN = root.appendingPathComponent("ui-N.store")
        let storeN1 = root.appendingPathComponent("ui-N1.store")
        try createAndReleaseStore(at: storeN, generationID: "N", values: [("from-N", 1)])
        try createAndReleaseStore(at: storeN1, generationID: "N+1", values: [("from-N1", 2)])

        let containerN = try GenerationStoreFactory.makeContainer(at: storeN, name: "ui-N-open")
        let containerN1 = try GenerationStoreFactory.makeContainer(at: storeN1, name: "ui-N1-open")
        let firstUpdate = expectation(description: "@Query observes generation N")
        let secondUpdate = expectation(description: "@Query observes generation N+1")
        var observedN = false
        var observedN1 = false
        let window = UIWindow(frame: UIScreen.main.bounds)

        window.rootViewController = UIHostingController(
            rootView: GenerationQueryView { labels in
                if labels == ["from-N"] && !observedN {
                    observedN = true
                    firstUpdate.fulfill()
                }
            }
            .modelContainer(containerN)
        )
        window.makeKeyAndVisible()
        wait(for: [firstUpdate], timeout: 5)

        window.rootViewController = UIHostingController(
            rootView: GenerationQueryView { labels in
                if labels == ["from-N1"] && !observedN1 {
                    observedN1 = true
                    secondUpdate.fulfill()
                }
            }
            .modelContainer(containerN1)
        )
        wait(for: [secondUpdate], timeout: 5)
        window.rootViewController = nil
        window.isHidden = true
    }

    @MainActor
    func testDefaultContainerStoreCanBeReopenedAtItsReportedURL() throws {
        let marker = "default-adoption-probe"
        var reportedURL: URL?

        try createDefaultStoreRecord(label: marker, value: 64) { url in
            reportedURL = url
        }

        let storeURL = try XCTUnwrap(reportedURL)
        XCTAssertFalse(storeURL.path.isEmpty)
        print("Default ModelContainer configuration URL: \(storeURL.path)")

        let explicit = try GenerationStoreFactory.makeContainer(at: storeURL, name: "explicit-reopen")
        let context = ModelContext(explicit)
        XCTAssertEqual(try snapshot(in: context)[marker], 64)
        XCTAssertEqual(try GenerationStoreFactory.markers(in: context).map(\.generationID), ["default"])
    }

    @MainActor
    private func createAndReleaseStore(
        at url: URL,
        generationID: String,
        values: [(String, Int)]
    ) throws {
        let container = try GenerationStoreFactory.makeContainer(at: url, name: "create-\(generationID)")
        let context = ModelContext(container)
        context.insert(GenerationStoreMarker(generationID: generationID))
        for (label, value) in values {
            context.insert(GenerationRecord(generation: generationID, label: label, value: value))
        }
        try context.save()
        XCTAssertFalse(context.hasChanges)
        // Returning releases the creation context/container before the reopen.
    }

    @MainActor
    private func createDefaultStoreRecord(
        label: String,
        value: Int,
        reportConfiguration: (URL) -> Void
    ) throws {
        let container = try ModelContainer(for: [GenerationRecord.self, GenerationStoreMarker.self])
        guard let configuration = container.configurations.first else {
            XCTFail("Default ModelContainer did not expose a configuration")
            return
        }
        reportConfiguration(configuration.url)
        print("Default configuration: \(configuration)")
        print("inMemory=\(configuration.isStoredInMemoryOnly), allowsSave=\(configuration.allowsSave)")
        let context = ModelContext(container)
        let markers = try GenerationStoreFactory.markers(in: context)
        if markers.isEmpty {
            context.insert(GenerationStoreMarker(generationID: "default"))
        } else {
            XCTAssertTrue(markers.allSatisfy { $0.generationID == "default" })
        }
        let records = try GenerationStoreFactory.records(in: context)
        if let record = records.first(where: { $0.label == label }) {
            record.value = value
        } else {
            context.insert(GenerationRecord(generation: "default", label: label, value: value))
        }
        try context.save()
    }

    @MainActor
    private func snapshot(in context: ModelContext) throws -> [String: Int] {
        Dictionary(uniqueKeysWithValues: try GenerationStoreFactory.records(in: context).map { ($0.label, $0.value) })
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftDataGenerationPrototype-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
        return url
    }

    private func jsonObject(at url: URL) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func writeJSON(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try data.write(to: url, options: .atomic)
    }
}

private final class ConcurrentErrorCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storedErrors: [String] = []

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedErrors
    }

    func append(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        storedErrors.append(String(describing: error))
    }
}
