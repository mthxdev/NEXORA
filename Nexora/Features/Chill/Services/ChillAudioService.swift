import AVFoundation
import AudioToolbox
import Foundation
import MediaPlayer

@MainActor
protocol ChillCuePlaying: AnyObject {
    var onInterruption: (() -> Void)? { get set }
    var onHeadphonesDisconnected: (() -> Void)? { get set }
    var onMediaServicesReset: (() -> Void)? { get set }
    var onPlayRequest: (() -> Void)? { get set }
    var onPauseRequest: (() -> Void)? { get set }
    var onStopRequest: (() -> Void)? { get set }

    func start(pattern: ChillBreathingPattern, durationSeconds: TimeInterval, volume: Double) throws
    func pause()
    func resume(after elapsedSeconds: TimeInterval, volume: Double) throws
    func updateNowPlaying(elapsedSeconds: TimeInterval, durationSeconds: TimeInterval, isPaused: Bool)
    func stop()
}

@MainActor
final class ChillAudioService: ChillCuePlaying {
    enum AudioError: LocalizedError {
        case engineCouldNotStart(Error)

        var errorDescription: String? {
            switch self {
            case .engineCouldNotStart(let error): return "Le guidage sonore n’a pas pu démarrer : \(error.localizedDescription)"
            }
        }
    }

    var onInterruption: (() -> Void)?
    var onHeadphonesDisconnected: (() -> Void)?
    var onMediaServicesReset: (() -> Void)?
    var onPlayRequest: (() -> Void)?
    var onPauseRequest: (() -> Void)?
    var onStopRequest: (() -> Void)?

    private let session = AVAudioSession.sharedInstance()
    private var engine: AVAudioEngine?
    private let cueSound = ChillBreathingCueSound()
    private var observers: [NSObjectProtocol] = []
    private var commandTargets: [(MPRemoteCommand, Any)] = []
    private var previousCommandStates: [(MPRemoteCommand, Bool)] = []
    private var pattern: ChillBreathingPattern = .coherence
    private var durationSeconds: TimeInterval = 0
    private var volume: Double = 0.25
    private var isSessionPaused = false

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor in self?.onInterruption?() }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable,
                  let previous = note.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription,
                  previous.outputs.contains(where: { Self.isPrivateAudioRoute($0.portType) }) else { return }
            Task { @MainActor in self?.onHeadphonesDisconnected?() }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleMediaServicesReset() }
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        commandTargets.forEach { $0.0.removeTarget($0.1) }
    }

    func start(pattern: ChillBreathingPattern, durationSeconds: TimeInterval, volume: Double) throws {
        self.pattern = pattern
        self.durationSeconds = durationSeconds
        self.volume = min(max(volume.isFinite ? volume : 0.25, 0.05), 1)
        isSessionPaused = false
        try startEngine(schedulingAfter: nil)
        installRemoteCommands()
        updateNowPlaying(elapsedSeconds: 0, durationSeconds: durationSeconds, isPaused: false)
    }

    func pause() {
        guard !isSessionPaused else { return }
        isSessionPaused = true
        engine?.stop()
        engine = nil
        deactivateSession()
    }

    func resume(after elapsedSeconds: TimeInterval, volume: Double) throws {
        guard isSessionPaused else { return }
        self.volume = min(max(volume.isFinite ? volume : self.volume, 0.05), 1)
        try startEngine(schedulingAfter: elapsedSeconds)
        isSessionPaused = false
        updateNowPlaying(elapsedSeconds: elapsedSeconds, durationSeconds: durationSeconds, isPaused: false)
    }

    func updateNowPlaying(elapsedSeconds: TimeInterval, durationSeconds: TimeInterval, isPaused: Bool) {
        guard !commandTargets.isEmpty else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Nexora · Respiration",
            MPMediaItemPropertyArtist: "Inspiration \(pattern.inhaleSeconds) s · expiration \(pattern.exhaleSeconds) s",
            MPMediaItemPropertyPlaybackDuration: durationSeconds,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0.0 : 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
    }

    func stop() {
        engine?.stop()
        engine = nil
        isSessionPaused = false
        removeRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        deactivateSession()
    }

    private func startEngine(schedulingAfter elapsedSeconds: TimeInterval?) throws {
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let nextEngine = AVAudioEngine()
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            let sampleRate = format.sampleRate
            let baseElapsed = max(0, elapsedSeconds ?? 0)
            let renderPattern = pattern
            let renderVolume = volume
            let cueSound = self.cueSound
            var renderedFrameCount: Int64 = 0
            let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                guard let audioData = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else {
                    return kAudio_ParamError
                }

                for frame in 0..<Int(frameCount) {
                    let elapsed = baseElapsed + Double(renderedFrameCount + Int64(frame)) / sampleRate
                    audioData[frame] = cueSound.sample(
                        at: elapsed,
                        sessionStartElapsed: baseElapsed,
                        pattern: renderPattern,
                        volume: renderVolume
                    )
                }
                renderedFrameCount += Int64(frameCount)
                return noErr
            }

            nextEngine.attach(sourceNode)
            nextEngine.connect(sourceNode, to: nextEngine.mainMixerNode, format: format)

            nextEngine.prepare()
            try nextEngine.start()
            engine = nextEngine
        } catch {
            engine?.stop()
            engine = nil
            deactivateSession()
            throw AudioError.engineCouldNotStart(error)
        }
    }

    private func installRemoteCommands() {
        guard commandTargets.isEmpty else { return }
        let center = MPRemoteCommandCenter.shared()
        previousCommandStates = [center.playCommand, center.pauseCommand, center.stopCommand].map { command in
            (command, command.isEnabled)
        }
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.stopCommand.isEnabled = true
        commandTargets.append((center.playCommand, center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPlayRequest?() }
            return .success
        }))
        commandTargets.append((center.pauseCommand, center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPauseRequest?() }
            return .success
        }))
        commandTargets.append((center.stopCommand, center.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onStopRequest?() }
            return .success
        }))
    }

    private func removeRemoteCommands() {
        guard !commandTargets.isEmpty else { return }
        commandTargets.forEach { command, target in command.removeTarget(target) }
        commandTargets.removeAll()
        previousCommandStates.forEach { command, wasEnabled in command.isEnabled = wasEnabled }
        previousCommandStates.removeAll()
    }
    private func handleMediaServicesReset() {
        engine?.stop()
        engine = nil
        isSessionPaused = true
        deactivateSession()
        onMediaServicesReset?()
    }

    private func deactivateSession() {
        do { try session.setActive(false, options: .notifyOthersOnDeactivation) }
        catch { NSLog("Chill: unable to deactivate audio session: %@", error.localizedDescription) }
    }

    private static func isPrivateAudioRoute(_ port: AVAudioSession.Port) -> Bool {
        port == .headphones || port == .bluetoothA2DP || port == .bluetoothHFP || port == .bluetoothLE || port == .usbAudio
    }
}
