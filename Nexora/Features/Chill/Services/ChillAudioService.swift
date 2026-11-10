import AVFoundation
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

    func start(pattern: ChillBreathingPattern, durationSeconds: TimeInterval) throws
    func pause()
    func resume(after elapsedSeconds: TimeInterval) throws
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
    private var playerNode: AVAudioPlayerNode?
    private var observers: [NSObjectProtocol] = []
    private var commandTargets: [(MPRemoteCommand, Any)] = []
    private var previousCommandStates: [(MPRemoteCommand, Bool)] = []
    private var pattern: ChillBreathingPattern = .coherence
    private var durationSeconds: TimeInterval = 0
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

    func start(pattern: ChillBreathingPattern, durationSeconds: TimeInterval) throws {
        self.pattern = pattern
        self.durationSeconds = durationSeconds
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
        playerNode = nil
        deactivateSession()
        updateNowPlaying(elapsedSeconds: 0, durationSeconds: durationSeconds, isPaused: true)
    }

    func resume(after elapsedSeconds: TimeInterval) throws {
        guard isSessionPaused else { return }
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
        playerNode = nil
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
            let nextPlayer = AVAudioPlayerNode()
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            nextEngine.attach(nextPlayer)
            nextEngine.connect(nextPlayer, to: nextEngine.mainMixerNode, format: format)

            let inhaleCue = Self.makeCue(for: .inhale, format: format)
            let exhaleCue = Self.makeCue(for: .exhale, format: format)
            let events = ChillCueSchedule.events(
                pattern: pattern,
                durationSeconds: durationSeconds,
                strictlyAfter: elapsedSeconds
            )
            for event in events {
                let offset = max(0, event.elapsedSeconds - (elapsedSeconds ?? 0))
                let frame = AVAudioFramePosition((offset * format.sampleRate).rounded())
                let audioTime = AVAudioTime(sampleTime: frame, atRate: format.sampleRate)
                let cue = event.phase == .inhale ? inhaleCue : exhaleCue
                nextPlayer.scheduleBuffer(cue, at: audioTime, options: [])
            }

            try nextEngine.start()
            nextPlayer.play()
            engine = nextEngine
            playerNode = nextPlayer
        } catch {
            engine?.stop()
            engine = nil
            playerNode = nil
            deactivateSession()
            throw AudioError.engineCouldNotStart(error)
        }
    }

    private static func makeCue(for phase: ChillSessionTimeline.Phase, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let duration = 0.30
        let frameCount = AVAudioFrameCount((sampleRate * duration).rounded())
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let fundamental: Double = phase == .inhale ? 523.25 : 392.0
        let overtone = fundamental * 1.5
        let data = buffer.floatChannelData![0]

        for index in 0..<Int(frameCount) {
            let time = Double(index) / sampleRate
            let fade = pow(sin(.pi * time / duration), 1.4)
            let tone = sin(2 * .pi * fundamental * time) + 0.18 * sin(2 * .pi * overtone * time)
            data[index] = Float(tone * fade * 0.12)
        }
        return buffer
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
        playerNode = nil
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
