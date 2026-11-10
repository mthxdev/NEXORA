import CryptoKit
import Foundation

public struct GenerationSelection: Codable, Equatable, Sendable {
    public let sequence: Int
    public let generationID: String

    public init(sequence: Int, generationID: String) {
        self.sequence = sequence
        self.generationID = generationID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ManifestCodingKey.self)
        guard Set(container.allKeys.map(\.stringValue)) == ["sequence", "generationID"] else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "GenerationSelection contains missing or unsupported fields"
            ))
        }
        sequence = try container.decode(Int.self, forKey: ManifestCodingKey("sequence"))
        generationID = try container.decode(String.self, forKey: ManifestCodingKey("generationID"))
    }
}

public enum ManifestInterruptionPoint: Equatable {
    case none
    case afterStagingWrite
    case afterManifestPublication
}

public enum GenerationManifestError: Error, Equatable {
    case simulatedInterruption(ManifestInterruptionPointDescription)
    case invalidChecksum
    case invalidManifestStructure
}

public enum ManifestInterruptionPointDescription: String, Equatable {
    case afterStagingWrite
    case afterManifestPublication
}

private struct ManifestCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private final class ManifestOperationLock: @unchecked Sendable {
    static let shared = ManifestOperationLock()
    let lock = NSLock()
}

/// A small, process-local serialized selector. Only the generation ID is stored
/// in the manifest; store URLs come exclusively from GenerationStoreCatalog.
public final class GenerationManifestStore: @unchecked Sendable {
    private struct Envelope: Codable {
        let selection: GenerationSelection
        let checksum: String

        init(selection: GenerationSelection, checksum: String) {
            self.selection = selection
            self.checksum = checksum
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: ManifestCodingKey.self)
            guard Set(container.allKeys.map(\.stringValue)) == ["selection", "checksum"] else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Manifest contains missing or unsupported fields"
                ))
            }
            selection = try container.decode(GenerationSelection.self, forKey: ManifestCodingKey("selection"))
            checksum = try container.decode(String.self, forKey: ManifestCodingKey("checksum"))
        }
    }

    private let manifestURL: URL
    private var stagingURL: URL { manifestURL.appendingPathExtension("pending") }

    public init(manifestURL: URL) {
        self.manifestURL = manifestURL
    }

    public func readSelection() throws -> GenerationSelection? {
        let lock = ManifestOperationLock.shared.lock
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return nil }
        let data = try Data(contentsOf: manifestURL)
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw GenerationManifestError.invalidManifestStructure
        }
        guard Self.checksum(for: envelope.selection) == envelope.checksum else {
            throw GenerationManifestError.invalidChecksum
        }
        return envelope.selection
    }

    public func publish(
        _ selection: GenerationSelection,
        interruptAt point: ManifestInterruptionPoint = .none
    ) throws {
        let lock = ManifestOperationLock.shared.lock
        lock.lock()
        defer { lock.unlock() }

        let envelope = Envelope(selection: selection, checksum: Self.checksum(for: selection))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)

        try FileManager.default.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: stagingURL, options: [])
        if point == .afterStagingWrite {
            throw GenerationManifestError.simulatedInterruption(.afterStagingWrite)
        }

        try FileManager.default.removeItem(at: stagingURL)

        // Atomic replacement applies to this manifest file operation only. It is
        // not a transaction with SwiftData, a cross-process lock, or a guarantee
        // of power-loss durability.
        try data.write(to: manifestURL, options: .atomic)
        if point == .afterManifestPublication {
            throw GenerationManifestError.simulatedInterruption(.afterManifestPublication)
        }
    }

    private static func checksum(for selection: GenerationSelection) -> String {
        let data = Data("\(selection.sequence)|\(selection.generationID)".utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
