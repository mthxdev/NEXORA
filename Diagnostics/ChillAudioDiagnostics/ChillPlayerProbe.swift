import AVFoundation
import AudioToolbox
import Combine
import Foundation

struct ProbeGenerationClock {
    private(set) var current: UInt64 = 0

    mutating func begin() -> UInt64 {
        current &+= 1
        return current
    }

    mutating func invalidate() {
        current &+= 1
    }

    func accepts(_ generation: UInt64) -> Bool {
        generation == current
    }
}

struct ProbeResumeOffsets: Equatable {
    let frozenFrame: Int64
    let fadeEndFrame: Int64

    var replayedFramesWhenResumingAtFrozenPosition: Int64 {
        max(0, fadeEndFrame - frozenFrame)
    }

    var skippedFramesWhenResumingAtFadeEnd: Int64 {
        max(0, fadeEndFrame - frozenFrame)
    }
}

enum ProbeMath {
    static func frames(seconds: Double, sampleRate: Double) -> Int64? {
        guard seconds.isFinite, sampleRate.isFinite,
              seconds >= 0, sampleRate > 0 else { return nil }
        let value = seconds * sampleRate
        guard value.isFinite, value < Double(Int64.max) else { return nil }
        return Int64(value.rounded(.toNearestOrAwayFromZero))
    }

    static func seconds(frames: Int64, sampleRate: Double) -> Double? {
        guard frames >= 0, sampleRate.isFinite, sampleRate > 0 else { return nil }
        return Double(frames) / sampleRate
    }

    static func rampFrames(duration: Double, sampleRate: Double) -> UInt32? {
        guard let frames = frames(seconds: duration, sampleRate: sampleRate),
              frames > 0, frames <= Int64(UInt32.max) else { return nil }
        return UInt32(frames)
    }

    static func boundedFrame(_ frame: Int64, frameLength: Int64) -> Int64? {
        guard frameLength >= 0 else { return nil }
        return min(max(0, frame), frameLength)
    }
}

enum ProbeState: String, Equatable {
    case stopped = "Arrêté"
    case starting = "Démarrage moteur"
    case ready = "Moteur prêt, player arrêté"
    case scheduled = "Cue planifié"
    case playing = "Lecture en cours"
    case completed = "Buffer terminé"
    case fading = "Fondu technique"
    case paused = "En pause"
    case interrupted = "Interruption — reprise manuelle"
    case needsRebuild = "Graphe à reconstruire"
    case failed = "Erreur"
}

enum ProbeStateEvent {
    case engineStarting, engineReady, schedule, startObserved, naturalCompletion
    case pauseBeforeStart, beginFade, finishPauseFade, finishStopFade
    case stop, interruption, rebuild, failure
}

enum ProbeStateMachine {
    static func transition(from state: ProbeState, event: ProbeStateEvent) -> ProbeState {
        switch event {
        case .engineStarting: return .starting
        case .engineReady: return .ready
        case .schedule:
            return state == .ready || state == .completed ? .scheduled : state
        case .startObserved:
            return state == .scheduled ? .playing : state
        case .naturalCompletion:
            return state == .scheduled || state == .playing ? .completed : state
        case .pauseBeforeStart:
            return state == .scheduled ? .paused : state
        case .beginFade:
            return state == .playing ? .fading : state
        case .finishPauseFade:
            return state == .fading ? .paused : state
        case .finishStopFade, .stop: return .stopped
        case .interruption: return .interrupted
        case .rebuild: return .needsRebuild
        case .failure: return .failed
        }
    }

    static func completion(
        from state: ProbeState,
        eventGeneration: UInt64,
        activeGeneration: UInt64?
    ) -> ProbeState {
        guard activeGeneration == eventGeneration else { return state }
        return transition(from: state, event: .naturalCompletion)
    }
}

enum ProbeCaptureKind: UInt32 {
    case equalizerTap = 1
    case mixerTap = 2
    case playerCompletion = 3
    case unsupportedTapFormat = 4
}

struct ProbeRampEvidence: Equatable {
    var nodeDeadlineObserved = false
    var tapEndpointCaptured = false

    var confirmsNodeAndTap: Bool {
        nodeDeadlineObserved && tapEndpointCaptured
    }

    var status: String {
        if confirmsNodeAndTap {
            return "Rendu du nœud confirmé et échantillon terminal capturé par le tap; cible de gain et sortie physique non vérifiées."
        }
        if nodeDeadlineObserved {
            return "Rendu du nœud confirmé, signal final non vérifié."
        }
        if tapEndpointCaptured {
            return "Échantillon terminal capturé par le tap, échéance du nœud non confirmée."
        }
        return "Rendu du nœud et signal final non vérifiés."
    }
}

@MainActor
private enum ProbeCaptureStorageRetainer {
    // No callback-quiescence barrier is exposed; retained rings are never freed or reused.
    // Two rings cap PCM storage at 16 MiB, plus bounded slot/ring metadata.
    private static let maximumRetainedRings = 2
    private(set) static var retained: [ProbeCaptureStorage] = []

    enum MakeResult {
        case created(ProbeCaptureStorage)
        case limitReached
        case allocationFailed
    }

    static func make() -> MakeResult {
        guard retained.count < maximumRetainedRings else { return .limitReached }
        guard let storage = ProbeCaptureStorage() else { return .allocationFailed }
        retained.append(storage)
        return .created(storage)
    }
}

private final class ProbeCaptureStorage: @unchecked Sendable {
    let ring: OpaquePointer
    let isLockFree: Bool

    init?() {
        // 128 * 8192 frames * 2 Float32 channels = 8 MiB, bounded per probe.
        guard let ring = ProbeCaptureRingCreate(128, 8192, 2) else { return nil }
        self.ring = ring
        self.isLockFree = ProbeCaptureRingIsLockFree(ring) != 0
    }

    func write(
        channel0: UnsafePointer<Float>?,
        channel1: UnsafePointer<Float>?,
        frameCount: UInt32,
        sourceChannelCount: UInt32,
        sampleTime: Int64,
        hostTime: UInt64,
        timestampFlags: UInt32,
        generation: UInt64,
        sampleRate: Double,
        kind: ProbeCaptureKind,
        auxiliary: UInt32 = 0
    ) {
        guard isLockFree else { return }
        _ = ProbeCaptureRingWrite(
            ring, channel0, channel1, frameCount, sourceChannelCount,
            sampleTime, hostTime, timestampFlags, generation, sampleRate,
            kind.rawValue, auxiliary
        )
    }
}


@MainActor
final class ChillPlayerProbe: ObservableObject {
    enum Cue: String, CaseIterable, Identifiable {
        case inspiration
        case expiration
        var id: String { rawValue }
        var resourceName: String { "chill_\(rawValue)" }
        var title: String { self == .inspiration ? "Inspiration" : "Expiration" }
    }

    enum GainUnit: String, CaseIterable, Identifiable {
        case equalizer
        case mixer
        var id: String { rawValue }
        var title: String { self == .equalizer ? "AVAudioUnitEQ.globalGain" : "AVAudioMixerNode" }
    }

    enum ResumePolicy: String, CaseIterable, Identifiable {
        case frozenPosition
        case fadeEndPosition
        var id: String { rawValue }
        var title: String {
            self == .frozenPosition ? "A — position figée" : "B — fin du fondu"
        }
    }


    @Published var selectedCue: Cue = .inspiration
    @Published var selectedLeadFrames = 960
    @Published var selectedGainUnit: GainUnit = .equalizer
    @Published var resumePolicy: ResumePolicy = .frozenPosition
    @Published private(set) var state: ProbeState = .stopped
    @Published private(set) var status = "Prêt. Aucun son n'est lancé automatiquement."
    @Published private(set) var gainParameterReport = "Paramètres non inspectés. Démarrez le moteur."
    @Published private(set) var routeReport = "Route non mesurée."
    @Published private(set) var captureReport = "Aucune capture."
    @Published private(set) var attackReport = "Attaque non mesurée."
    @Published private(set) var playerRate: Double = 48_000
    @Published private(set) var wavRate: Double = 0
    @Published private(set) var gainRate: Double = 0
    @Published private(set) var outputRate: Double = 0
    @Published private(set) var startRenderDelayMilliseconds: Double?
    @Published private(set) var engineSetupMilliseconds: Double?
    @Published private(set) var scheduledNodeSampleTime: Int64?
    @Published private(set) var scheduledLeadFrames: Int?
    @Published private(set) var estimatedOutputDrainMilliseconds: Double?
    @Published private(set) var theoreticalOutputDrainMilliseconds: Double?
    @Published private(set) var outputDrainCeilingApplied = false
    @Published private(set) var rampSignalReport = "Aucune rampe mesurée."
    @Published private(set) var frozenLogicalFrame: Int64?
    @Published private(set) var fadeEndFrame: Int64?
    @Published private(set) var resumeOffsets: ProbeResumeOffsets?
    @Published private(set) var exportReport = ""
    @Published private(set) var droppedCaptureBlocks: UInt64 = 0

    let leadFrameChoices = [128, 256, 480, 960, 1_920, 3_840]

    private let audioSession = AVAudioSession.sharedInstance()
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var equalizer: AVAudioUnitEQ?
    private var mixer: AVAudioMixerNode?
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var activeCue: Cue?
    private var activeBuffer: AVAudioPCMBuffer?
    private var scheduledSourceStartFrame: Int64 = 0
    private var scheduledNodeStartSample: Int64?
    private var scheduledPlayerRate: Double = 0
    private var activeGeneration: UInt64?
    private var generationClock = ProbeGenerationClock()
    private let captureStorage: ProbeCaptureStorage?
    private var sessionObserverTokens: [NSObjectProtocol] = []
    private var engineObserverToken: NSObjectProtocol?
    private var monitorTask: Task<Void, Never>?
    private var fadeTask: Task<Void, Never>?
    private var fadeRampEnd: Int64?
    private var fadeTapKind: ProbeCaptureKind?
    private var rampEvidence = ProbeRampEvidence()
    private var rampSignalSamples: [Float] = []
    private var rampSignalChannelCount = 0
    private var rampSignalTruncated = false
    private var rampEndpointValues: [Float] = []
    private var captureDropBaseline: UInt64 = 0
    private var equalizerCaptureTruncated = false
    private var mixerCaptureTruncated = false
    private var lastKnownSourceFrame: Int64 = 0
    private var eventLines: [String] = []
    private var capturedBlocks: [CapturedBlockRecord] = []
    private var equalizerSamples: [Float] = []
    private var mixerSamples: [Float] = []
    private var captureScratch = [Float](repeating: 0, count: 16_384)
    private let maximumCapturedFrames = 192_000
    private let maximumCapturedRampSamples = 32_768
    private let tapBufferSize: AVAudioFrameCount = 1_024
    private var gainTargets: [GainUnit: GainTarget] = [:]
    private var lastReportedEQCount = -1
    private var lastReportedMixerCount = -1
    private var lastReportedDropCount: UInt64 = .max
    private var lastRampDescription = "Aucune rampe programmée."
    private var lastResumePolicy: ResumePolicy?

    private enum FadeReason: Equatable {
        case pause
        case stop
    }

    private struct GainTarget {
        let unit: GainUnit
        let node: AVAudioNode
        let address: AUParameterAddress
        let minimumValue: AUValue
        let maximumValue: AUValue
        let currentValue: AUValue
        let canRamp: Bool
        let sampleRate: Double
        let scheduleBlock: AUScheduleParameterBlock?
        let description: String
        let isHeuristicCandidate: Bool
    }
    private struct CapturedBlockRecord {
        let block: ProbeCaptureBlock
        let streamOffset: Int
        let playerNodeSampleTime: Int64?
    }

    init() {
        switch ProbeCaptureStorageRetainer.make() {
        case .created(let storage):
            captureStorage = storage
            if storage.isLockFree {
                captureReport = "Ring MPSC lock-free initialisé; capture limitée à 2 canaux."
            } else {
                captureReport = "Capture désactivée : les atomiques C11 du ring ne sont pas tous lock-free sur cet appareil."
                status = captureReport
            }
        case .limitReached:
            captureStorage = nil
            captureReport = "Limite mémoire atteinte : 2 rings retenus (16 MiB de données PCM, plus métadonnées). Aucun ring n'est libéré ni réutilisé; redémarrez l'application pour réinitialiser cette limite."
            status = "Probe refusé : \(captureReport)"
        case .allocationFailed:
            captureStorage = nil
            captureReport = "Capture indisponible : allocation du ring impossible."
            status = captureReport
        }
        equalizerSamples.reserveCapacity(maximumCapturedFrames)
        mixerSamples.reserveCapacity(maximumCapturedFrames)
        capturedBlocks.reserveCapacity(2_048)
        rampSignalSamples.reserveCapacity(maximumCapturedRampSamples)
        rampEndpointValues.reserveCapacity(2)
        eventLines.reserveCapacity(256)
        registerSessionObservers()
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                self?.drainCaptureAndRefresh()
            }
        }
    }

    var leadDurationMilliseconds: Double {
        Double(selectedLeadFrames) / max(playerRate, 1) * 1_000
    }
    var scheduledLeadDurationMilliseconds: Double? {
        guard let scheduledLeadFrames, scheduledPlayerRate > 0 else { return nil }
        return Double(scheduledLeadFrames) / scheduledPlayerRate * 1_000
    }

    var currentPositionText: String {
        let frame: Int64?
        if state == .completed {
            frame = lastKnownSourceFrame
        } else if state == .fading || state == .paused || state == .interrupted || state == .needsRebuild {
            frame = frozenLogicalFrame ?? lastKnownSourceFrame
        } else {
            frame = currentSourceFrame()
        }
        guard let frame else { return "—" }
        return String(format: "%lld frames · %.3f s", frame, Double(frame) / max(wavRate, 1))
    }

    var resumeOffsetText: String {
        guard let resumeOffsets else { return "A/B non encore mesurés." }
        let a = Double(resumeOffsets.frozenFrame) / max(wavRate, 1)
        let b = Double(resumeOffsets.fadeEndFrame) / max(wavRate, 1)
        let repeated = Double(resumeOffsets.replayedFramesWhenResumingAtFrozenPosition) / max(wavRate, 1)
        let skipped = Double(resumeOffsets.skippedFramesWhenResumingAtFadeEnd) / max(wavRate, 1)
        return String(format: "A %.0f f / %.3f s · B %.0f f / %.3f s · A rejoue %.1f ms · B saute %.1f ms",
                      Double(resumeOffsets.frozenFrame), a,
                      Double(resumeOffsets.fadeEndFrame), b,
                      repeated * 1_000, skipped * 1_000)
    }

    func prepareExport() {
        drainCaptureAndRefresh()
        exportReport = makeExportReport()
        status = "Rapport et samples bruts prêts à partager."
    }

    private func makeExportReport() -> String {
        var lines = [
            "Chill AVAudioPlayerNode diagnostic",
            "cue,\((activeCue ?? selectedCue).rawValue)",
            "generated_at,\(Date().ISO8601Format())",
            "wav_sample_rate,\(wavRate)",
            "player_sample_rate,\(playerRate)",
            "gain_node_sample_rate,\(gainRate)",
            "output_sample_rate,\(outputRate)",
            "lead_frames,\(scheduledLeadFrames.map { String($0) } ?? "")",
            "lead_milliseconds,\(scheduledLeadDurationMilliseconds.map { String($0) } ?? "")",
            "scheduled_player_node_sample_time,\(scheduledNodeSampleTime.map { String($0) } ?? "")",
            "estimated_output_drain_ms,\(estimatedOutputDrainMilliseconds.map { String($0) } ?? "")",
            "theoretical_output_drain_ms,\(theoreticalOutputDrainMilliseconds.map { String($0) } ?? "")",
            "output_drain_ceiling_applied,\(outputDrainCeilingApplied)",
            "ramp_signal_status,\(csvEscape(rampSignalReport))",
            "last_render_time_delay_ms,\(startRenderDelayMilliseconds.map { String($0) } ?? "")",
            "frozen_logical_frame,\(frozenLogicalFrame.map { String($0) } ?? "")",
            "fade_end_frame,\(fadeEndFrame.map { String($0) } ?? "")",
            "resume_strategy,\(lastResumePolicy?.rawValue ?? "")",
            "resume_offsets,\(csvEscape(resumeOffsetText))",
            "route,\(csvEscape(routeReport))",
            "gain_parameters,\(csvEscape(gainParameterReport))",
            "ramp,\(csvEscape(lastRampDescription))",
            "capture_summary,\(csvEscape(captureReport))",
            "attack_comparison,\(csvEscape(attackReport))",
            "events",
            "event"
        ]
        lines.append(contentsOf: eventLines.map(csvEscape))
        lines.append("samples,tap,interleaved_scalar_index,value")
        lines.append(contentsOf: equalizerSamples.enumerated().map { "sample,equalizer,\($0.offset),\($0.element)" })
        lines.append(contentsOf: mixerSamples.enumerated().map { "sample,mixer,\($0.offset),\($0.element)" })
        lines.append("blocks,tap,generation,node_sample_time,player_node_sample_time,stream_offset,host_ticks,sample_rate,frames,source_channels,captured_channels,flags,auxiliary")
        lines.append(contentsOf: capturedBlocks.map { record in
            let block = record.block
            let tap = block.kind == ProbeCaptureKind.equalizerTap.rawValue ? "equalizer" :
                      block.kind == ProbeCaptureKind.mixerTap.rawValue ? "mixer" : "event"
            return "block,\(tap),\(block.generation),\(block.sample_time),\(record.playerNodeSampleTime.map { String($0) } ?? ""),\(record.streamOffset),\(block.host_time),\(block.sample_rate),\(block.frame_count),\(block.source_channel_count),\(block.captured_channel_count),\(block.timestamp_flags),\(block.auxiliary)"
        })
        return lines.joined(separator: "\n")
    }

    func startEngine() {
        guard engine == nil else {
            appendEvent("start rejeté : un moteur est déjà présent", generation: activeGeneration)
            status = "Le moteur existe déjà. Arrêtez ou reconstruisez le graphe."
            return
        }
        Task { @MainActor [weak self] in
            await self?.prepareEngine(startingAtSourceFrame: nil, autoplay: false, cue: nil)
        }
    }

    func inspectGainParameters() {
        guard equalizer != nil, mixer != nil else {
            status = "Démarrez le moteur pour inspecter les paramètres des nœuds réels."
            return
        }
        // This is a pre-render snapshot; parameter trees and schedule blocks are not re-fetched mid-render.
        status = "Snapshot des parameterTree pris avant engine.start()."
    }

    func scheduleSelectedCue() {
        guard (state == .ready || state == .completed), let player, let engine, engine.isRunning else {
            status = "Démarrez le moteur et attendez un lastRenderTime valide."
            return
        }
        guard let source = buffers[selectedCue] else {
            state = ProbeStateMachine.transition(from: state, event: .failure)
            status = "Le buffer WAV sélectionné n'est pas chargé."
            return
        }
        activeCue = selectedCue
        frozenLogicalFrame = nil
        fadeEndFrame = nil
        resumeOffsets = nil
        lastKnownSourceFrame = 0
        resetGainValues()
        schedule(sourceBuffer: source, sourceStartFrame: 0, on: player)
    }

    func pauseWithTechnicalFade() {
        beginFade(reason: .pause)
    }


    func stopWithTechnicalFade() {
        beginFade(reason: .stop)
    }

    func resumeUsingSelectedOffset() {
        guard state == .paused || state == .interrupted || state == .needsRebuild else {
            status = "Aucune position de pause à reprendre."
            return
        }
        let requestedOffset: Int64
        switch resumePolicy {
        case .frozenPosition:
            requestedOffset = resumeOffsets?.frozenFrame ?? frozenLogicalFrame ?? lastKnownSourceFrame
        case .fadeEndPosition:
            requestedOffset = resumeOffsets?.fadeEndFrame ?? frozenLogicalFrame ?? lastKnownSourceFrame
        }
        let cue = activeCue ?? selectedCue
        guard let source = buffers[cue],
              let offset = ProbeMath.boundedFrame(requestedOffset, frameLength: Int64(source.frameLength)) else {
            status = "Offset de reprise impossible à borner à la longueur du WAV."
            return
        }
        guard offset < Int64(source.frameLength) else {
            lastKnownSourceFrame = Int64(source.frameLength)
            frozenLogicalFrame = lastKnownSourceFrame
            state = .completed
            status = "L'offset est à la fin du WAV; aucun buffer ne sera reprogrammé."
            appendEvent(status, generation: activeGeneration)
            return
        }
        activeCue = cue
        lastResumePolicy = resumePolicy
        appendEvent("reprise demandée à l'offset WAV \(offset) (\(resumePolicy.title))", generation: activeGeneration)
        Task { @MainActor [weak self] in
            await self?.prepareEngine(startingAtSourceFrame: offset, autoplay: true, cue: cue)
        }
    }

    func rebuildGraphAtSavedPosition() {
        resumeUsingSelectedOffset()
    }

    func shutdown() {
        monitorTask?.cancel()
        fadeTask?.cancel()
        appendEvent("vue quittée : teardown immédiat du graphe de diagnostic", generation: activeGeneration)
        invalidateAndTearDown(nextState: .stopped, deactivateSession: true)
        removeSessionObservers()
    }

    private func prepareEngine(startingAtSourceFrame: Int64?, autoplay: Bool, cue: Cue?) async {
        guard captureStorage?.isLockFree == true else {
            status = captureReport
            appendEvent(status, generation: activeGeneration)
            return
        }
        guard engine == nil else {
            status = "Un moteur existe déjà ; aucune instance n'a été remplacée."
            appendEvent("préparation rejetée : moteur actif", generation: activeGeneration)
            return
        }
        let generation = generationClock.begin()
        activeGeneration = generation
        state = ProbeStateMachine.transition(from: state, event: .engineStarting)
        status = "Chargement des WAV et création du graphe…"
        if startingAtSourceFrame == nil {
            activeCue = nil
            lastKnownSourceFrame = 0
            frozenLogicalFrame = nil
            fadeEndFrame = nil
            resumeOffsets = nil
            scheduledLeadFrames = nil
            lastResumePolicy = nil
            estimatedOutputDrainMilliseconds = nil
            theoreticalOutputDrainMilliseconds = nil
            outputDrainCeilingApplied = false
        }
        let requestHostTime = DispatchTime.now().uptimeNanoseconds
        var engineStartHostTime: UInt64?

        do {
            try loadBuffersIfNeeded()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)

            let newEngine = AVAudioEngine()
            let newPlayer = AVAudioPlayerNode()
            let newEQ = AVAudioUnitEQ()
            let newMixer = newEngine.mainMixerNode
            let format = try sourcePCMFormat(from: buffers[.inspiration])

            newEQ.globalGain = 0
            newMixer.outputVolume = 1
            newEngine.attach(newPlayer)
            newEngine.attach(newEQ)
            newEngine.connect(newPlayer, to: newEQ, format: format)
            newEngine.connect(newEQ, to: newMixer, format: format)

            guard let capture = captureStorage, capture.isLockFree else {
                throw ProbeError.captureRingUnavailable
            }
            engine = newEngine
            player = newPlayer
            equalizer = newEQ
            mixer = newMixer
            scheduledSourceStartFrame = startingAtSourceFrame ?? 0
            scheduledNodeStartSample = nil
            scheduledPlayerRate = newPlayer.outputFormat(forBus: 0).sampleRate
            wavRate = format.sampleRate
            playerRate = scheduledPlayerRate > 0 ? scheduledPlayerRate : format.sampleRate
            engineSetupMilliseconds = nil
            startRenderDelayMilliseconds = nil
            scheduledNodeSampleTime = nil
            captureDropBaseline = ProbeCaptureRingDroppedCount(capture.ring)
            lastReportedDropCount = .max
            installTaps(player: newPlayer, equalizer: newEQ, mixer: newMixer, capture: capture, generation: generation)
            installObservers(engine: newEngine, generation: generation)
            newEngine.prepare()
            refreshGainParameterReport() // Cache scheduleParameterBlock before the first render.
            try newEngine.start()
            let engineStart = DispatchTime.now().uptimeNanoseconds
            engineStartHostTime = engineStart
            engineSetupMilliseconds = Double(engineStart &- requestHostTime) / 1_000_000
            outputRate = newEngine.outputNode.inputFormat(forBus: 0).sampleRate
            refreshRouteReport()
            appendEvent("engine.start terminé · engineRunning=\(newEngine.isRunning) · WAV=\(format.sampleRate) Hz · player=\(playerRate) Hz · gain=\(gainRate) Hz · sortie=\(outputRate) Hz", generation: generation)

            var validRenderTime: AVAudioTime?
            for _ in 0..<100 {
                try Task.checkCancellation()
                guard generationClock.accepts(generation), activeGeneration == generation else { return }
                if let time = newPlayer.lastRenderTime, time.isSampleTimeValid {
                    validRenderTime = time
                    break
                }
                try await Task.sleep(for: .milliseconds(5))
                guard generationClock.accepts(generation), activeGeneration == generation else { return }
            }

            guard let renderTime = validRenderTime else {
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds &- (engineStartHostTime ?? requestHostTime)) / 1_000_000
                appendEvent(String(format: "timeout 500 ms : lastRenderTime sampleTime invalide · délai après engine.start %.3f ms", elapsed), generation: generation)
                throw ProbeError.lastRenderTimeUnavailable
            }
            let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds &- (engineStartHostTime ?? requestHostTime)) / 1_000_000
            startRenderDelayMilliseconds = elapsedMilliseconds
            status = String(format: "lastRenderTime valide %.3f ms après engine.start · sampleTime %lld", elapsedMilliseconds, renderTime.sampleTime)
            appendEvent(status, generation: generation)
            state = ProbeStateMachine.transition(from: state, event: .engineReady)
            if autoplay, let cue, let source = buffers[cue] {
                activeCue = cue
                let frame = startingAtSourceFrame ?? 0
                resetGainValues()
                schedule(sourceBuffer: source, sourceStartFrame: frame, on: newPlayer)
            }
        } catch is CancellationError {
            appendEvent("préparation annulée", generation: generation)
            if activeGeneration == generation {
                invalidateAndTearDown(nextState: .stopped, deactivateSession: true)
            }
        } catch {
            appendEvent("erreur de démarrage : \(error.localizedDescription)", generation: generation)
            if activeGeneration == generation {
                status = error.localizedDescription
                invalidateAndTearDown(nextState: .failed, deactivateSession: true)
            }
        }
    }

    private func loadBuffersIfNeeded() throws {
        guard buffers.isEmpty else { return }
        for cue in Cue.allCases {
            guard let url = Bundle.main.url(forResource: cue.resourceName, withExtension: "wav") else {
                throw ProbeError.missingWAV(cue.resourceName)
            }
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            guard format.channelCount == 1, format.sampleRate > 0,
                  file.length > 0, file.length <= AVAudioFramePosition(UInt32.max) else {
                throw ProbeError.unsupportedWAV(cue.resourceName)
            }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
                throw ProbeError.bufferAllocationFailed(cue.resourceName)
            }
            try file.read(into: buffer)
            guard buffer.floatChannelData != nil, buffer.frameLength > 0 else {
                throw ProbeError.unsupportedWAV(cue.resourceName)
            }
            buffers[cue] = buffer
        }
    }

    private func installTaps(
        player: AVAudioPlayerNode,
        equalizer: AVAudioUnitEQ,
        mixer: AVAudioMixerNode,
        capture: ProbeCaptureStorage,
        generation: UInt64
    ) {
        installTap(on: equalizer, kind: .equalizerTap, capture: capture, generation: generation)
        installTap(on: mixer, kind: .mixerTap, capture: capture, generation: generation)
    }

    private func installTap(on node: AVAudioNode, kind: ProbeCaptureKind, capture: ProbeCaptureStorage, generation: UInt64) {
        node.installTap(onBus: 0, bufferSize: tapBufferSize, format: nil) { buffer, time in
            let validSample = time.isSampleTimeValid
            let validHost = time.isHostTimeValid
            let flags: UInt32 = (validSample ? 1 : 0) | (validHost ? 2 : 0)
            let sampleTime = validSample ? time.sampleTime : Int64.min
            let hostTime = validHost ? time.hostTime : 0
            let frames = buffer.frameLength
            let sourceChannelCount = buffer.format.channelCount
            guard let channels = buffer.floatChannelData else {
                capture.write(channel0: nil, channel1: nil, frameCount: 0, sourceChannelCount: sourceChannelCount,
                              sampleTime: sampleTime, hostTime: hostTime, timestampFlags: flags,
                              generation: generation, sampleRate: buffer.format.sampleRate,
                              kind: .unsupportedTapFormat, auxiliary: kind.rawValue)
                return
            }
            let channel1: UnsafePointer<Float>? = sourceChannelCount > 1 ? UnsafePointer(channels[1]) : nil
            capture.write(channel0: UnsafePointer(channels[0]), channel1: channel1, frameCount: frames,
                          sourceChannelCount: sourceChannelCount, sampleTime: sampleTime, hostTime: hostTime,
                          timestampFlags: flags, generation: generation, sampleRate: buffer.format.sampleRate,
                          kind: kind)
    }

    }
    private func registerSessionObservers() {
        // queue: .main is assumed to coincide with MainActor here; handlers revalidate the snapshot after the hop.
        let center = NotificationCenter.default
        sessionObserverTokens.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: audioSession, queue: .main) { [weak self] note in
            let generation = MainActor.assumeIsolated { self?.activeGeneration }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleInterruption(note, generation: generation)
            }
        })
        sessionObserverTokens.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: audioSession, queue: .main) { [weak self] note in
            let generation = MainActor.assumeIsolated { self?.activeGeneration }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleRouteChange(note, generation: generation)
            }
        })
        sessionObserverTokens.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            let generation = MainActor.assumeIsolated { self?.activeGeneration }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleExternalReset("media services reset", generation: generation)
            }
        })
    }

    private func installObservers(engine: AVAudioEngine, generation: UInt64) {
        removeObservers()
        engineObserverToken = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            // Apple warns against synchronous teardown from this notification handler.
            Task { @MainActor [weak self] in
                self?.handleExternalReset("engine configuration changed", generation: generation)
            }
        }
    }

    private func removeObservers() {
        guard let engineObserverToken else { return }
        NotificationCenter.default.removeObserver(engineObserverToken)
        self.engineObserverToken = nil
    }

    private func removeSessionObservers() {
        sessionObserverTokens.forEach(NotificationCenter.default.removeObserver)
        sessionObserverTokens.removeAll(keepingCapacity: false)
    }

    private func logicalPositionForLifecycle() -> Int64 {
        if state == .fading, let frozenLogicalFrame { return frozenLogicalFrame }
        return currentSourceFrame() ?? lastKnownSourceFrame
    }

    private func handleInterruption(_ notification: Notification, generation: UInt64?) {
        let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        guard let raw, let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        guard let generation, generationClock.accepts(generation), activeGeneration == generation else {
            appendEvent("événement interruption périmé ignoré à l'exécution", generation: generation)
            return
        }
        if type == .began {
            let position = logicalPositionForLifecycle()
            frozenLogicalFrame = position
            lastKnownSourceFrame = position
            appendEvent("interruption .began · position figée \(position) frames · fondu non garanti", generation: generation)
            invalidateAndTearDown(nextState: .interrupted, deactivateSession: false)
        } else {
            appendEvent("interruption .ended · aucune reprise automatique", generation: generation)
            status = "Interruption terminée. Reprise manuelle disponible à la position conservée."
        }
    }

    private func handleRouteChange(_ notification: Notification, generation: UInt64?) {
        let reasonRaw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
        let reason = reasonRaw.map { AVAudioSession.RouteChangeReason(rawValue: $0) }
        refreshRouteReport()
        guard let generation, generationClock.accepts(generation), activeGeneration == generation else {
            appendEvent("route changed sans moteur actif · reason=\(String(describing: reason))", generation: generation)
            return
        }
        let position = logicalPositionForLifecycle()
        frozenLogicalFrame = position
        lastKnownSourceFrame = position
        appendEvent("route changed · reason=\(String(describing: reason)) · position sauvegardée \(position) frames", generation: generation)
        invalidateAndTearDown(nextState: .needsRebuild, deactivateSession: false)
    }

    private func handleExternalReset(_ reason: String, generation: UInt64?) {
        guard let generation, generationClock.accepts(generation), activeGeneration == generation else {
            appendEvent("\(reason) reçu sans moteur actif; aucune reprise automatique", generation: generation)
            return
        }
        let position = logicalPositionForLifecycle()
        frozenLogicalFrame = position
        lastKnownSourceFrame = position
        appendEvent("\(reason) · position sauvegardée \(position) frames · reconstruction manuelle requise", generation: generation)
        invalidateAndTearDown(nextState: .needsRebuild, deactivateSession: false)
    }


    private func schedule(sourceBuffer: AVAudioPCMBuffer, sourceStartFrame: Int64, on player: AVAudioPlayerNode) {
        guard let engine, engine.isRunning,
              let renderTime = player.lastRenderTime,
              renderTime.isSampleTimeValid,
              playerRate.isFinite, playerRate > 0 else {
            status = "Impossible de planifier : lastRenderTime/sample rate invalide."
            appendEvent(status, generation: activeGeneration)
            return
        }
        guard let boundedStart = ProbeMath.boundedFrame(sourceStartFrame, frameLength: Int64(sourceBuffer.frameLength)),
              boundedStart < Int64(sourceBuffer.frameLength) else {
            status = "L'offset de reprise est à la fin ou hors du WAV."
            appendEvent(status, generation: activeGeneration)
            return
        }
        guard let scheduledBuffer = makeSuffix(of: sourceBuffer, startingAt: boundedStart) else {
            status = "Impossible de construire le buffer temporaire."
            return
        }
        let lead = max(1, selectedLeadFrames)
        let (targetSampleTime, overflow) = renderTime.sampleTime.addingReportingOverflow(Int64(lead))
        guard !overflow else {
            status = "Le sample time planifié déborde."
            return
        }

        scheduledLeadFrames = lead
        let when = AVAudioTime(sampleTime: targetSampleTime, atRate: playerRate)
        scheduledNodeStartSample = targetSampleTime
        scheduledSourceStartFrame = boundedStart
        scheduledPlayerRate = playerRate
        scheduledNodeSampleTime = targetSampleTime
        activeBuffer = scheduledBuffer
        state = ProbeStateMachine.transition(from: state, event: .schedule)
        status = "Cue programmé; état scheduled jusqu'au début observé sur la timeline du nœud."
        appendEvent("cue \((activeCue ?? selectedCue).title) · buffer \(scheduledBuffer.frameLength) frames · lead \(lead) frames / \(String(format: "%.3f", Double(lead) / playerRate * 1_000)) ms · node sampleTime \(targetSampleTime)", generation: activeGeneration)

        let callbackStorage = captureStorage
        let callbackGeneration = activeGeneration ?? 0
        let completionRate = scheduledPlayerRate
        player.scheduleBuffer(scheduledBuffer, at: when, options: [], completionCallbackType: .dataPlayedBack) { callbackType in
            callbackStorage?.write(channel0: nil, channel1: nil, frameCount: 0, sourceChannelCount: 0,
                                   sampleTime: Int64.min, hostTime: ProbeCaptureHostTimeNow(),
                                   timestampFlags: 2, generation: callbackGeneration,
                                   sampleRate: completionRate, kind: .playerCompletion,
                                   auxiliary: UInt32(callbackType.rawValue))
        }
        player.play(at: when)
    }

    private func makeSuffix(of source: AVAudioPCMBuffer, startingAt frame: Int64) -> AVAudioPCMBuffer? {
        guard let sourceChannels = source.floatChannelData else { return nil }
        let sourceLength = Int64(source.frameLength)
        let count = sourceLength - frame
        guard count > 0, count <= Int64(UInt32.max),
              let result = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: AVAudioFrameCount(count)),
              let destinationChannels = result.floatChannelData else { return nil }
        for channel in 0..<Int(source.format.channelCount) {
            destinationChannels[channel].update(from: sourceChannels[channel].advanced(by: Int(frame)), count: Int(count))
        }
        result.frameLength = AVAudioFrameCount(count)
        return result
    }

    private func refreshScheduledPlaybackState() {
        guard state == .scheduled, let player,
              let scheduledNodeStartSample,
              let nodeTime = player.lastRenderTime,
              nodeTime.isSampleTimeValid,
              nodeTime.sampleTime >= scheduledNodeStartSample,
              let playerTime = player.playerTime(forNodeTime: nodeTime),
              playerTime.isSampleTimeValid else { return }
        state = ProbeStateMachine.transition(from: state, event: .startObserved)
        status = "Début de lecture observé sur la timeline du player; sortie physique non mesurée."
        appendEvent(status, generation: activeGeneration)
    }

    private func cancelScheduledCue(reason: FadeReason, detail: String) {
        let sourceLength = Int64(buffers[activeCue ?? selectedCue]?.frameLength ?? 0)
        let frozen = ProbeMath.boundedFrame(scheduledSourceStartFrame, frameLength: sourceLength)
            ?? scheduledSourceStartFrame
        // AVAudioPlayerNode.stop() clears scheduled events; pause is accepted only after it returns.
        player?.stop()
        frozenLogicalFrame = frozen
        fadeEndFrame = frozen
        lastKnownSourceFrame = frozen
        resumeOffsets = ProbeResumeOffsets(frozenFrame: frozen, fadeEndFrame: frozen)
        activeBuffer = nil
        let nextState = reason == .pause
            ? ProbeStateMachine.transition(from: state, event: .pauseBeforeStart)
            : ProbeStateMachine.transition(from: state, event: .stop)
        status = "\(detail) stop() a vidé les événements programmés; aucun cue ne peut commencer après son retour. Un rendu concurrent avant ce retour n'est pas exclu."
        appendEvent(status, generation: activeGeneration)
        invalidateAndTearDown(nextState: nextState, deactivateSession: reason == .stop)
    }

    private func beginFade(reason: FadeReason) {
        if state == .fading {
            if reason == .stop, fadeReason == .pause {
                fadeReason = .stop
                appendEvent("arrêt demandé pendant le fondu de pause : extinction existante conservée, reprise invalidée", generation: activeGeneration)
            } else {
                appendEvent("demande répétée pendant un fondu : transition existante conservée", generation: activeGeneration)
            }
            return
        }

        refreshScheduledPlaybackState()
        if state == .scheduled {
            guard let player, let scheduledNodeStartSample,
                  let nodeTime = player.lastRenderTime, nodeTime.isSampleTimeValid else {
                cancelScheduledCue(reason: reason, detail: "Timeline indisponible avant le début programmé.")
                return
            }
            guard nodeTime.sampleTime >= scheduledNodeStartSample else {
                cancelScheduledCue(reason: reason, detail: "Pause/arrêt avant N0.")
                return
            }
            guard player.playerTime(forNodeTime: nodeTime)?.isSampleTimeValid == true else {
                cancelScheduledCue(reason: reason, detail: "N0 dépassé mais playerTime indisponible; rampe non vérifiable.")
                return
            }
            state = ProbeStateMachine.transition(from: state, event: .startObserved)
        }

        guard state == .playing else {
            if reason == .stop {
                appendEvent("arrêt sans lecture active", generation: activeGeneration)
                invalidateAndTearDown(nextState: .stopped, deactivateSession: true)
            } else {
                status = "Aucun cue actif à mettre en pause."
            }
            return
        }

        let frozen = currentSourceFrame() ?? lastKnownSourceFrame
        frozenLogicalFrame = frozen
        lastKnownSourceFrame = frozen
        fadeEndFrame = nil
        resumeOffsets = nil
        fadeReason = reason
        let label = reason == .pause ? "pause" : "arrêt"
        appendEvent("\(label) demandé · frozenLogicalElapsed=\(frozen) frames (\(String(format: "%.3f", Double(frozen) / max(wavRate, 1))) s)", generation: activeGeneration)

        guard let ramp = scheduleTechnicalRamp() else {
            lastRampDescription = "Aucune rampe CanRamp utilisable; teardown immédiat, pas de volume instantané présenté comme fondu."
            rampSignalReport = "Signal final non vérifié : aucune rampe compatible n'a été programmée."
            appendEvent(lastRampDescription, generation: activeGeneration)
            finishFadeWithoutRamp(reason: reason, frozenFrame: frozen)
            return
        }
        state = ProbeStateMachine.transition(from: state, event: .beginFade)
        status = "Temps logique figé; attente de l'échéance du nœud puis des échantillons du tap."
        fadeRampEnd = ramp.endSampleTime
        fadeTargetNode = ramp.node
        fadeTapKind = ramp.tapKind
        rampEvidence = ProbeRampEvidence()
        rampSignalSamples.removeAll(keepingCapacity: true)
        rampSignalChannelCount = 0
        rampSignalTruncated = false
        rampEndpointValues.removeAll(keepingCapacity: true)
        let generation = activeGeneration ?? 0
        let frozenFrame = frozen
        fadeTask?.cancel()
        fadeTask = Task { @MainActor [weak self] in
            await self?.waitForRampAndTearDown(
                generation: generation,
                frozenFrame: frozenFrame,
                endSampleTime: ramp.endSampleTime,
                reason: reason
            )
        }
    }

    private func scheduleTechnicalRamp() -> ScheduledRamp? {
        guard let target = gainTargets[selectedGainUnit], target.canRamp,
              let block = target.scheduleBlock,
              let renderTime = target.node.lastRenderTime,
              renderTime.isSampleTimeValid,
              target.sampleRate.isFinite, target.sampleRate > 0,
              renderTime.sampleRate.isFinite, abs(renderTime.sampleRate - target.sampleRate) < 0.5 else {
            status = "Paramètre sélectionné absent/non rampable ou sample time invalide."
            return nil
        }
        guard let fadeFrames = ProbeMath.rampFrames(duration: 0.020, sampleRate: target.sampleRate) else {
            status = "Sample rate du gain node invalide pour la rampe."
            return nil
        }
        let leadSeconds = max(audioSession.ioBufferDuration, 1 / target.sampleRate)
        guard let lead = ProbeMath.frames(seconds: leadSeconds, sampleRate: target.sampleRate) else { return nil }
        let (startSample, startOverflow) = renderTime.sampleTime.addingReportingOverflow(max(1, lead))
        guard !startOverflow else { return nil }
        let (endSample, endOverflow) = startSample.addingReportingOverflow(Int64(fadeFrames))
        guard !endOverflow else { return nil }
        block(AUEventSampleTime(startSample), AUAudioFrameCount(fadeFrames), target.address, target.minimumValue)
        let confidence = target.isHeuristicCandidate ? " · CANDIDAT non validé" : ""
        lastRampDescription = String(format: "%@%@ · lead %.3f ms · start node sampleTime %lld · %u frames / %.3f ms · cible %.3f %@ · CanRamp=oui",
                                    target.description, confidence, leadSeconds * 1_000, startSample, fadeFrames,
                                    Double(fadeFrames) / target.sampleRate * 1_000, target.minimumValue,
                                    target.unit == .equalizer ? "dB (−96 dB ≠ zéro numérique)" : "gain linéaire")
        appendEvent(lastRampDescription, generation: activeGeneration)
        let tapKind: ProbeCaptureKind = target.unit == .equalizer ? .equalizerTap : .mixerTap
        return ScheduledRamp(node: target.node, endSampleTime: endSample, tapKind: tapKind)
    }

    private struct ScheduledRamp {
        let node: AVAudioNode
        let endSampleTime: Int64
        let tapKind: ProbeCaptureKind
    }

    private func waitForRampAndTearDown(generation: UInt64, frozenFrame: Int64, endSampleTime: Int64, reason: FadeReason) async {
        let deadline = DispatchTime.now().uptimeNanoseconds &+ 750_000_000
        while !Task.isCancelled {
            guard generationClock.accepts(generation), activeGeneration == generation else { return }
            drainCaptureAndRefresh()
            if let targetNode = fadeTargetNode,
               let time = targetNode.lastRenderTime, time.isSampleTimeValid,
               time.sampleTime >= endSampleTime {
                rampEvidence.nodeDeadlineObserved = true
            }

            if rampEvidence.confirmsNodeAndTap {
                let endFrame = fadeTargetNode.flatMap { sourceFrameAtRampEnd(node: $0, sampleTime: endSampleTime) }
                    ?? currentSourceFrame() ?? frozenFrame
                fadeEndFrame = endFrame
                resumeOffsets = ProbeResumeOffsets(frozenFrame: frozenFrame, fadeEndFrame: endFrame)
                lastKnownSourceFrame = endFrame
                rampSignalReport = "\(rampEvidence.status) \(rampSignalSummary())"
                appendEvent("échéance de rendu du nœud et échantillon terminal du tap observés; cible et acoustique non vérifiées", generation: generation)
                await finishFade(
                    reason: fadeReason ?? reason,
                    nodeDeadlineObserved: rampEvidence.nodeDeadlineObserved,
                    tapCoveredEnd: rampEvidence.tapEndpointCaptured
                )
                return
            }

            if DispatchTime.now().uptimeNanoseconds >= deadline {
                fadeEndFrame = currentSourceFrame() ?? frozenFrame
                resumeOffsets = ProbeResumeOffsets(frozenFrame: frozenFrame, fadeEndFrame: fadeEndFrame ?? frozenFrame)
                rampSignalReport = "\(rampEvidence.status) Timeout de 750 ms; valeur cible et sortie acoustique non vérifiées."
                appendEvent("timeout 750 ms · nodeDeadline=\(rampEvidence.nodeDeadlineObserved) · tapEnd=\(rampEvidence.tapEndpointCaptured) · teardown hors callback", generation: generation)
                await finishFade(
                    reason: fadeReason ?? reason,
                    nodeDeadlineObserved: rampEvidence.nodeDeadlineObserved,
                    tapCoveredEnd: rampEvidence.tapEndpointCaptured
                )
                return
            }
            do { try await Task.sleep(for: .milliseconds(4)) }
            catch { return }
        }
    }

    private func sourceFrameAtRampEnd(node: AVAudioNode, sampleTime: Int64) -> Int64? {
        guard let player else { return nil }
        let nodeRate = node.outputFormat(forBus: 0).sampleRate
        guard nodeRate.isFinite, nodeRate > 0 else { return nil }
        let gainNodeTime = AVAudioTime(sampleTime: sampleTime, atRate: nodeRate)
        let playerNodeTime = player.convertTime(gainNodeTime, from: node)
        guard let playerTime = player.playerTime(forNodeTime: playerNodeTime),
              playerTime.isSampleTimeValid,
              let sum = checkedSourceFrame(playerTime.sampleTime) else { return nil }
        return sum
    }

    private func checkedSourceFrame(_ playerFrame: Int64) -> Int64? {
        let (absoluteFrame, overflow) = scheduledSourceStartFrame.addingReportingOverflow(playerFrame)
        guard !overflow else { return nil }
        let cue = activeCue ?? selectedCue
        guard let source = buffers[cue] else { return nil }
        return ProbeMath.boundedFrame(absoluteFrame, frameLength: Int64(source.frameLength))
    }

    private func finishFade(
        reason: FadeReason,
        nodeDeadlineObserved: Bool,
        tapCoveredEnd: Bool
    ) async {
        guard let generation = activeGeneration else { return }
        drainCaptureAndRefresh()
        player?.pause() // Render graph paused outside the callback; this does not prove the device queue is empty.

        let estimatedTail = audioSession.outputLatency + audioSession.ioBufferDuration
        let estimateValid = estimatedTail.isFinite && estimatedTail >= 0
        let theoreticalMilliseconds = estimatedTail * 1_000
        theoreticalOutputDrainMilliseconds = estimateValid && theoreticalMilliseconds.isFinite
            ? theoreticalMilliseconds : nil
        let tail = estimateValid ? min(estimatedTail, 1) : 0
        outputDrainCeilingApplied = estimateValid && estimatedTail > 1
        estimatedOutputDrainMilliseconds = tail * 1_000
        let theoreticalText = theoreticalOutputDrainMilliseconds.map { String(format: "%.3f ms", $0) } ?? "non affichable"
        let waitDescription: String
        if !estimateValid {
            waitDescription = "estimation outputLatency+ioBuffer invalide; aucune durée de vidange fiable"
        } else if outputDrainCeilingApplied {
            waitDescription = "théorique \(theoreticalText), attente plafonnée à 1000 ms"
        } else {
            waitDescription = "théorique \(theoreticalText), attente \(String(format: "%.3f ms", tail * 1_000))"
        }
        appendEvent("\(nodeDeadlineObserved ? "échéance de rendu nœud observée" : "échéance nœud non confirmée") · tapEnd=\(tapCoveredEnd) · \(waitDescription) · temporisation non garantie de silence acoustique",
                    generation: generation)
        if tail > 0 {
            do { try await Task.sleep(for: .nanoseconds(Int64(tail * 1_000_000_000))) }
            catch { return }
        }
        guard generationClock.accepts(generation), activeGeneration == generation else { return }
        drainCaptureAndRefresh()
        player?.stop() // Still outside every render, tap and completion callback.
        activeBuffer = nil
        let completionReason = fadeReason ?? reason
        let next = completionReason == .pause
            ? ProbeStateMachine.transition(from: .fading, event: .finishPauseFade)
            : ProbeStateMachine.transition(from: .fading, event: .finishStopFade)
        invalidateAndTearDown(nextState: next, deactivateSession: completionReason == .stop)
        let capText = outputDrainCeilingApplied ? "plafond 1 s appliqué; vidange acoustique incertaine." : "sortie acoustique non vérifiée."
        status = completionReason == .pause
            ? "Pause terminée. Temps logique conservé; \(rampSignalReport) \(capText)"
            : "Arrêt du moteur terminé; \(rampSignalReport) \(capText)"
        appendEvent("teardown après temporisation estimée · ancienne génération \(String(generation))", generation: generation)
        fadeTask = nil
    }

    private func finishFadeWithoutRamp(reason: FadeReason, frozenFrame: Int64) {
        fadeEndFrame = currentSourceFrame() ?? frozenFrame
        resumeOffsets = ProbeResumeOffsets(frozenFrame: frozenFrame, fadeEndFrame: fadeEndFrame ?? frozenFrame)
        lastKnownSourceFrame = frozenFrame
        rampSignalReport = "Signal final non vérifié : aucune rampe CanRamp compatible n'a été programmée."
        player?.stop()
        activeBuffer = nil
        let next = reason == .pause ? ProbeState.paused : ProbeState.stopped
        invalidateAndTearDown(nextState: next, deactivateSession: reason == .stop)
        status = "Arrêt immédiat hors callback, sans rampe confirmée. \(rampSignalReport)"
    }

    private func invalidateAndTearDown(nextState: ProbeState, deactivateSession: Bool) {
        generationClock.invalidate()
        let oldEngine = engine
        let oldPlayer = player
        oldPlayer?.stop()
        if let player { player.removeTap(onBus: 0) }
        if let mixer { mixer.removeTap(onBus: 0) }
        oldEngine?.stop()
        removeObservers()
        activeBuffer = nil
        engine = nil
        player = nil
        equalizer = nil
        mixer = nil
        // captureStorage intentionally remains retained: tap removal is not a documented callback-quiescence barrier.
        gainTargets.removeAll(keepingCapacity: true)
        scheduledNodeStartSample = nil
        fadeTargetNode = nil
        fadeTapKind = nil
        rampEvidence = ProbeRampEvidence()
        fadeReason = nil
        fadeRampEnd = nil
        activeGeneration = nil
        state = nextState
        if deactivateSession {
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func currentSourceFrame() -> Int64? {
        guard let player, let nodeTime = player.lastRenderTime, nodeTime.isSampleTimeValid else { return nil }
        if let playerTime = player.playerTime(forNodeTime: nodeTime), playerTime.isSampleTimeValid {
            return checkedSourceFrame(playerTime.sampleTime)
        }
        guard let scheduledNodeStartSample else { return nil }
        if nodeTime.sampleTime <= scheduledNodeStartSample {
            return ProbeMath.boundedFrame(scheduledSourceStartFrame, frameLength: Int64(activeCue.flatMap { buffers[$0]?.frameLength } ?? 0))
        }
        let (nodeFrames, overflow) = nodeTime.sampleTime.subtractingReportingOverflow(scheduledNodeStartSample)
        let rate = nodeTime.sampleRate
        guard !overflow, rate.isFinite, rate > 0, scheduledPlayerRate.isFinite, scheduledPlayerRate > 0 else { return nil }
        let converted = Double(nodeFrames) * scheduledPlayerRate / rate
        guard converted.isFinite, converted < Double(Int64.max) else { return nil }
        return checkedSourceFrame(Int64(converted.rounded(.down)))
    }

    private func refreshGainParameterReport() {
        guard let equalizer, let mixer else { return }
        var lines: [String] = []
        gainTargets.removeAll(keepingCapacity: true)

        if let tree = equalizer.auAudioUnit.parameterTree {
            lines.append("AVAudioUnitEQ · globalGain property=\(equalizer.globalGain) dB")
            for parameter in tree.allParameters {
                lines.append(parameterLine(parameter, prefix: "EQ"))
            }
            let address = AUParameterAddress(kAUNBandEQParam_GlobalGain)
            if let parameter = tree.parameter(withAddress: address) {
                gainTargets[.equalizer] = GainTarget(
                    unit: .equalizer, node: equalizer,
                    address: parameter.address, minimumValue: parameter.minValue,
                    maximumValue: parameter.maxValue, currentValue: parameter.value,
                    canRamp: parameter.flags.contains(.flag_CanRamp),
                    sampleRate: equalizer.outputFormat(forBus: 0).sampleRate,
                    scheduleBlock: equalizer.auAudioUnit.scheduleParameterBlock,
                    description: "AVAudioUnitEQ.globalGain @ \(equalizer.outputFormat(forBus: 0).sampleRate) Hz",
                    isHeuristicCandidate: false
                )
            } else {
                lines.append("EQ globalGain address \(address) absent du parameterTree")
            }
        } else {
            lines.append("AVAudioUnitEQ.parameterTree = nil")
        }

        if let tree = mixer.auAudioUnit.parameterTree {
            lines.append("AVAudioMixerNode · outputVolume property=\(mixer.outputVolume) · toute correspondance Audio Unit reste un candidat heuristique")
            let savedVolume = mixer.outputVolume
            mixer.outputVolume = 0.731
            let correlated = tree.allParameters.first {
                ($0.identifier.localizedCaseInsensitiveContains("volume") || $0.name.localizedCaseInsensitiveContains("volume")) &&
                abs(Double($0.value) - 0.731) < 0.002
            }
            mixer.outputVolume = savedVolume
            for parameter in tree.allParameters {
                lines.append(parameterLine(parameter, prefix: "Mixer"))
            }
            if let parameter = correlated {
                gainTargets[.mixer] = GainTarget(
                    unit: .mixer, node: mixer,
                    address: parameter.address, minimumValue: parameter.minValue,
                    maximumValue: parameter.maxValue, currentValue: parameter.value,
                    canRamp: parameter.flags.contains(.flag_CanRamp),
                    sampleRate: mixer.outputFormat(forBus: 0).sampleRate,
                    scheduleBlock: mixer.auAudioUnit.scheduleParameterBlock,
                    description: "CANDIDAT mixer \(parameter.identifier) @ \(mixer.outputFormat(forBus: 0).sampleRate) Hz",
                    isHeuristicCandidate: true
                )
                lines.append("Correspondance outputVolume ↔ paramètre Audio Unit non démontrée; rampe de ce candidat non validée.")
            } else {
                lines.append("Aucun paramètre du mixer n'a suivi outputVolume=0.731; outputVolume non déclaré rampable.")
            }
        } else {
            lines.append("AVAudioMixerNode.parameterTree = nil")
        }

        gainParameterReport = lines.joined(separator: "\n")
        appendEvent("inspection parameterTree terminée · paramètres CanRamp candidats disponibles : \(gainTargets.values.map(\.description).joined(separator: "; ")) · aucune validation matérielle", generation: activeGeneration)
    }

    private func parameterLine(_ parameter: AUParameter, prefix: String) -> String {
        let canRamp = parameter.flags.contains(.flag_CanRamp)
        return String(format: "%@ · id=%@ · address=%llu · min=%.4f · max=%.4f · value=%.4f · flags=0x%08x · CanRamp=%@",
                      prefix, parameter.identifier, parameter.address,
                      parameter.minValue, parameter.maxValue, parameter.value,
                      parameter.flags.rawValue, canRamp ? "oui" : "non")
    }

    private func resetGainValues() {
        equalizer?.globalGain = 0
        mixer?.outputVolume = 1
    }

    private func refreshRouteReport() {
        let outputs = audioSession.currentRoute.outputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: ", ")
        let inputs = audioSession.currentRoute.inputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: ", ")
        routeReport = "inputs=\(inputs.isEmpty ? "aucune" : inputs) · outputs=\(outputs.isEmpty ? "aucune" : outputs) · sessionRate=\(audioSession.sampleRate) Hz · ioBuffer=\(audioSession.ioBufferDuration) s · outputLatency=\(audioSession.outputLatency) s"
    }

    private func drainCaptureAndRefresh() {
        guard let captureStorage else { return }
        while true {
            var block = ProbeCaptureBlock()
            let result = captureScratch.withUnsafeMutableBufferPointer { scratch in
                ProbeCaptureRingRead(captureStorage.ring, scratch.baseAddress, UInt32(scratch.count), &block)
            }
            if result == 0 { break }
            if result < 0 {
                appendEvent("capture ring: bloc dépasse le scratch préalloué; lecture arrêtée", generation: activeGeneration)
                break
            }
            guard let activeGeneration, block.generation == activeGeneration else {
                if activeGeneration != nil {
                    appendEvent("événement de capture périmé ignoré · génération \(block.generation)", generation: block.generation)
                }
                continue
            }

            let scalarCount = Int(block.frame_count) * Int(block.captured_channel_count)
            var streamOffset = -1
            var playerNodeSampleTime: Int64?
            if block.kind == ProbeCaptureKind.equalizerTap.rawValue {
                streamOffset = equalizerSamples.count
                playerNodeSampleTime = playerNodeTime(for: block, from: equalizer)
            } else if block.kind == ProbeCaptureKind.mixerTap.rawValue {
                streamOffset = mixerSamples.count
                playerNodeSampleTime = playerNodeTime(for: block, from: mixer)
            }

            if state == .fading, block.kind == fadeTapKind?.rawValue {
                captureRampSignal(block: block, scalarCount: scalarCount)
                if block.timestamp_flags & 1 != 0,
                   block.sample_time != Int64.min,
                   let fadeRampEnd,
                   let fadeTargetNode,
                   block.sample_rate.isFinite,
                   abs(block.sample_rate - fadeTargetNode.outputFormat(forBus: 0).sampleRate) < 0.5 {
                    let (blockEnd, overflow) = block.sample_time.addingReportingOverflow(Int64(block.frame_count))
                    let (frameOffset, offsetOverflow) = fadeRampEnd.subtractingReportingOverflow(block.sample_time)
                    let channels = Int(block.captured_channel_count)
                    if !overflow, !offsetOverflow, channels > 0,
                       frameOffset >= 0, frameOffset < Int64(block.frame_count),
                       block.sample_time <= fadeRampEnd, fadeRampEnd < blockEnd {
                        let firstValue = Int(frameOffset) * channels
                        let endValue = firstValue + channels
                        if endValue <= scalarCount {
                            rampEndpointValues.removeAll(keepingCapacity: true)
                            rampEndpointValues.append(contentsOf: captureScratch[firstValue..<endValue])
                            rampEvidence.tapEndpointCaptured = true
                        }
                    }
                }
            }

            if capturedBlocks.count < 2_048 {
                capturedBlocks.append(CapturedBlockRecord(
                    block: block,
                    streamOffset: streamOffset,
                    playerNodeSampleTime: playerNodeSampleTime
                ))
            }
            if block.kind == ProbeCaptureKind.equalizerTap.rawValue {
                equalizerCaptureTruncated = appendCaptured(captureScratch, count: scalarCount, to: &equalizerSamples) || equalizerCaptureTruncated
            } else if block.kind == ProbeCaptureKind.mixerTap.rawValue {
                mixerCaptureTruncated = appendCaptured(captureScratch, count: scalarCount, to: &mixerSamples) || mixerCaptureTruncated
            } else if block.kind == ProbeCaptureKind.playerCompletion.rawValue {
                let playedBackRawValue = UInt32(AVAudioPlayerNodeCompletionCallbackType.dataPlayedBack.rawValue)
                guard block.auxiliary == playedBackRawValue else {
                    appendEvent("callback completion ignoré · type=\(block.auxiliary), attendu dataPlayedBack", generation: block.generation)
                    continue
                }
                appendEvent("scheduleBuffer completion .dataPlayedBack · hostTicks=\(block.host_time)", generation: block.generation)
                let nextState = ProbeStateMachine.completion(
                    from: state,
                    eventGeneration: block.generation,
                    activeGeneration: activeGeneration
                )
                if nextState == .completed {
                    state = nextState
                    if let source = buffers[activeCue ?? selectedCue] {
                        lastKnownSourceFrame = Int64(source.frameLength)
                    }
                    frozenLogicalFrame = lastKnownSourceFrame
                    activeBuffer = nil
                    status = "Buffer WAV terminé (.dataPlayedBack); moteur prêt pour planifier un nouveau cue."
                    appendEvent(status, generation: block.generation)
                }
            } else if block.kind == ProbeCaptureKind.unsupportedTapFormat.rawValue {
                appendEvent("tap non Float32 · kind=\(block.auxiliary) · canaux source=\(block.source_channel_count)", generation: block.generation)
            }
        }

        let totalDrops = ProbeCaptureRingDroppedCount(captureStorage.ring)
        droppedCaptureBlocks = totalDrops >= captureDropBaseline ? totalDrops - captureDropBaseline : totalDrops
        refreshScheduledPlaybackState()
        if state == .playing || state == .scheduled {
            if let frame = currentSourceFrame() { lastKnownSourceFrame = frame }
        }
        if equalizerSamples.count != lastReportedEQCount ||
            mixerSamples.count != lastReportedMixerCount ||
            droppedCaptureBlocks != lastReportedDropCount {
            lastReportedEQCount = equalizerSamples.count
            lastReportedMixerCount = mixerSamples.count
            lastReportedDropCount = droppedCaptureBlocks
            attackReport = compareInitialAttack()
            let ringStatus = captureStorage?.isLockFree == true
                ? "ring lock-free"
                : "capture désactivée (ring non lock-free)"
            captureReport = "EQ tap: \(sampleSummary(equalizerSamples, kind: ProbeCaptureKind.equalizerTap.rawValue))\nMixer tap: \(sampleSummary(mixerSamples, kind: ProbeCaptureKind.mixerTap.rawValue))\n\(attackReport)\nblocs perdus génération: \(droppedCaptureBlocks) · \(ringStatus) · capture limitée à deux canaux · tap = rendu du graphe, pas mesure acoustique"
        }
    }

    private func captureRampSignal(block: ProbeCaptureBlock, scalarCount: Int) {
        let channels = Int(block.captured_channel_count)
        guard channels > 0, scalarCount > 0 else { return }
        rampSignalChannelCount = channels
        if block.source_channel_count > block.captured_channel_count { rampSignalTruncated = true }
        let accepted = min(scalarCount, maximumCapturedRampSamples)
        let aligned = accepted - accepted % channels
        if aligned < scalarCount { rampSignalTruncated = true }
        let overflow = max(0, rampSignalSamples.count + aligned - maximumCapturedRampSamples)
        if overflow > 0 {
            let removeCount = min(rampSignalSamples.count, ((overflow + channels - 1) / channels) * channels)
            rampSignalSamples.removeFirst(removeCount)
            rampSignalTruncated = true
        }
        rampSignalSamples.append(contentsOf: captureScratch.prefix(aligned))
    }

    private func rampSignalSummary() -> String {
        guard !rampEndpointValues.isEmpty else { return "aucun sample exact de fin conservé" }
        let endpoint = rampEndpointValues.enumerated().map {
            String(format: "ch%u=%.7f", CUnsignedInt($0.offset), $0.element)
        }.joined(separator: " ")
        let rms = rampSignalSamples.isEmpty
            ? 0
            : sqrt(rampSignalSamples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(rampSignalSamples.count))
        let partial = rampSignalTruncated ? " · capture partielle/tronquée" : ""
        return "sample exact au sampleTime \(fadeRampEnd.map { String($0) } ?? "—"): \(endpoint) · RMS fenêtre tap \(String(format: "%.7f", rms)) (\(rampSignalSamples.count) valeurs, lead inclus)\(partial)"
    }

    private func playerNodeTime(for block: ProbeCaptureBlock, from node: AVAudioNode?) -> Int64? {
        guard let node, let player,
              block.timestamp_flags & 1 != 0,
              block.sample_time != Int64.min,
              block.sample_rate.isFinite, block.sample_rate > 0 else { return nil }
        let nodeTime = AVAudioTime(sampleTime: block.sample_time, atRate: block.sample_rate)
        let playerTime = player.convertTime(nodeTime, from: node)
        return playerTime.isSampleTimeValid ? playerTime.sampleTime : nil
    }
    private func compareInitialAttack() -> String {
        guard let generation = activeGeneration,
              let scheduledStart = scheduledNodeStartSample,
              let source = buffers[activeCue ?? selectedCue],
              let sourceSamples = source.floatChannelData?.pointee,
              scheduledPlayerRate > 0, wavRate > 0 else {
            return "Attaque 5 ms : position ou source indisponible."
        }
        let requiredFrames = Int(0.005 * wavRate)
        var comparedFrames = 0
        var squareError = 0.0
        var maximumError: Float = 0

        for record in capturedBlocks {
            let capturedChannels = Int(record.block.captured_channel_count)
            guard record.block.generation == generation,
                  record.block.kind == ProbeCaptureKind.equalizerTap.rawValue,
                  capturedChannels > 0,
                  let playerSample = record.playerNodeSampleTime,
                  record.streamOffset >= 0,
                  record.block.sample_rate.isFinite, record.block.sample_rate > 0 else { continue }
            let playerFramesPerTapFrame = scheduledPlayerRate / record.block.sample_rate
            let frameCount = Int(record.block.frame_count)
            for localFrame in 0..<frameCount {
                let relativePlayerFrame = playerSample + Int64((Double(localFrame) * playerFramesPerTapFrame).rounded(.down)) - scheduledStart
                guard relativePlayerFrame >= 0 else { continue }
                let ageSeconds = Double(relativePlayerFrame) / scheduledPlayerRate
                guard ageSeconds < 0.005 else { break }
                let sourceDelta = Int((ageSeconds * wavRate).rounded(.down))
                let sourceIndex = scheduledSourceStartFrame + sourceDelta
                let capturedIndex = record.streamOffset + localFrame * capturedChannels
                guard sourceIndex >= 0, sourceIndex < Int64(source.frameLength),
                      capturedIndex < equalizerSamples.count else { continue }
                let error = abs(equalizerSamples[capturedIndex] - sourceSamples[Int(sourceIndex)])
                maximumError = max(maximumError, error)
                squareError += Double(error) * Double(error)
                comparedFrames += 1
            }
        }
        let rmsError = comparedFrames > 0 ? sqrt(squareError / Double(comparedFrames)) : 0
        return String(format: "Attaque initiale 5 ms (EQ tap, canal 0 vs WAV mono): %d/%d frames alignées · RMS erreur %.8f · erreur max %.8f",
                      CInt(comparedFrames), CInt(requiredFrames), rmsError, maximumError)
    }

    @discardableResult
    private func appendCaptured(_ source: [Float], count: Int, to destination: inout [Float]) -> Bool {
        guard count > 0 else { return false }
        let accepted = min(count, max(0, maximumCapturedFrames - destination.count))
        if accepted > 0 { destination.append(contentsOf: source.prefix(accepted)) }
        return accepted < count
    }

    private func sampleSummary(_ samples: [Float], kind: UInt32) -> String {
        guard !samples.isEmpty else { return "aucun sample" }
        var peak: Float = 0
        var squareSum = 0.0
        var zeroCount = 0
        var firstNonzero: Int?
        var lastNonzero: Int?
        for (index, sample) in samples.enumerated() {
            let magnitude = abs(sample)
            peak = max(peak, magnitude)
            squareSum += Double(sample) * Double(sample)
            if sample == 0 {
                zeroCount += 1
            } else {
                if firstNonzero == nil { firstNonzero = index }
                lastNonzero = index
            }
        }
        let kindBlocks = capturedBlocks.filter { $0.block.kind == kind && $0.streamOffset >= 0 }
        let firstBlock = firstNonzero.flatMap { index in
            kindBlocks.first {
                let valueCount = Int($0.block.frame_count) * Int($0.block.captured_channel_count)
                return index >= $0.streamOffset && index < $0.streamOffset + valueCount
            }
        }
        let onsetPlayerSample: Int64?
        var onsetChannel: Int?
        if let firstNonzero, let firstBlock, let playerSample = firstBlock.playerNodeSampleTime,
           firstBlock.block.sample_rate.isFinite, firstBlock.block.sample_rate > 0,
           firstBlock.block.captured_channel_count > 0 {
            let localValue = firstNonzero - firstBlock.streamOffset
            let capturedChannels = Int(firstBlock.block.captured_channel_count)
            let localFrame = localValue / capturedChannels
            onsetChannel = localValue % capturedChannels
            let frameDelta = Double(localFrame) * playerRate / firstBlock.block.sample_rate
            onsetPlayerSample = playerSample + Int64(frameDelta.rounded(.down))
        } else {
            onsetPlayerSample = nil
        }
        let onsetDelta: Int64?
        if let onsetPlayerSample, let scheduledNodeSampleTime {
            onsetDelta = onsetPlayerSample - scheduledNodeSampleTime
        } else {
            onsetDelta = nil
        }
        let sourceChannels = Set(kindBlocks.map { $0.block.source_channel_count }).sorted()
        let capturedChannels = Set(kindBlocks.map { $0.block.captured_channel_count }).sorted()
        let excessChannels = kindBlocks.contains { $0.block.source_channel_count > $0.block.captured_channel_count }
        let sampleLimitReached = kind == ProbeCaptureKind.equalizerTap.rawValue ? equalizerCaptureTruncated : mixerCaptureTruncated
        let partial = excessChannels || sampleLimitReached
        let frameTotal = kindBlocks.reduce(0) { $0 + Int($1.block.frame_count) }
        let onsetText = onsetPlayerSample.map { String($0) } ?? "invalide"
        let deltaText = onsetDelta.map { String($0) } ?? "invalide"
        let channelText = "source \(sourceChannels) → capturé \(capturedChannels)" +
            (excessChannels ? " · canaux supplémentaires non capturés" : "") +
            (sampleLimitReached ? " · limite de stockage atteinte" : "")
        let rms = sqrt(squareSum / Double(samples.count))
        return String(format: "%d frames · %d valeurs · %@ · peak %.7f · RMS %.7f · zéros %d · 1er non-zéro valeur %@ canal %@ · player sampleTime %@ (écart %@) · dernier non-zéro %@",
                      CInt(frameTotal), CInt(samples.count), channelText, peak, rms, CInt(zeroCount),
                      firstNonzero.map { String($0) } ?? "aucun",
                      onsetChannel.map { String($0) } ?? "—", onsetText, deltaText,
                      lastNonzero.map { String($0) } ?? "aucun")
    }


    private func appendEvent(_ message: String, generation: UInt64?) {
        let gen = generation.map { String($0) } ?? "—"
        let line = "\(Date().ISO8601Format()) · gen=\(gen) · \(message)"
        eventLines.append(line)
        if eventLines.count > 300 { eventLines.removeFirst(eventLines.count - 300) }
        journalText = eventLines.joined(separator: "\n")
    }

    private func csvEscape(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: " ") + "\""
    }

    private func sourcePCMFormat(from buffer: AVAudioPCMBuffer?) throws -> AVAudioFormat {
        guard let buffer else { throw ProbeError.missingWAV("inspiration") }
        return buffer.format
    }

    private enum ProbeError: LocalizedError {
        case missingWAV(String)
        case unsupportedWAV(String)
        case bufferAllocationFailed(String)
        case captureRingUnavailable
        case lastRenderTimeUnavailable

        var errorDescription: String? {
            switch self {
            case .missingWAV(let name): "Ressource introuvable : \(name).wav"
            case .unsupportedWAV(let name): "Format WAV non pris en charge : \(name)"
            case .bufferAllocationFailed(let name): "Impossible de précharger : \(name)"
            case .captureRingUnavailable: "Capture C11 indisponible ou atomiques non lock-free sur cet appareil."
            case .lastRenderTimeUnavailable: "Aucun lastRenderTime valide après 500 ms."
            }
        }
    }
}
