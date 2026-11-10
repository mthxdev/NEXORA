import AVFoundation
import Foundation

@MainActor
final class ChillAudioService {
    enum AudioError: LocalizedError {
        case missingResource(String)
        case playbackCouldNotStart

        var errorDescription: String? {
            switch self {
            case .missingResource(let name): return "Le fichier audio « \(name) » est absent de l’application."
            case .playbackCouldNotStart: return "Le lecteur audio n’a pas pu démarrer."
            }
        }
    }

    var onInterruption: (() -> Void)?
    var onHeadphonesDisconnected: (() -> Void)?
    var onMediaServicesReset: (() -> Void)?

    private let session = AVAudioSession.sharedInstance()
    private var player: AVAudioPlayer?
    private var fadeTask: Task<Void, Never>?
    private var activeAmbience: ChillAmbience = .none
    private var currentVolume: Float = 0.2
    private var observers: [NSObjectProtocol] = []

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
            queue: nil
        ) { [weak self] note in
            Task { @MainActor in
                guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable,
                      let previous = note.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription,
                      previous.outputs.contains(where: Self.isPrivateAudioRoute) else { return }
                self?.onHeadphonesDisconnected?()
            }
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
        fadeTask?.cancel()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    static func resourceURL(for ambience: ChillAmbience) -> URL? {
        guard let resource = ambience.resourceName else { return nil }
        return Bundle.main.url(forResource: resource, withExtension: "m4a")
    }

    func start(ambience: ChillAmbience, volume: Float) throws {
        guard let resource = ambience.resourceName else { return }
        activeAmbience = ambience
        currentVolume = min(max(volume, 0.05), 0.75)
        guard let url = Self.resourceURL(for: ambience) else {
            throw AudioError.missingResource(resource)
        }
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        let nextPlayer = try AVAudioPlayer(contentsOf: url)
        nextPlayer.numberOfLoops = -1
        nextPlayer.volume = 0
        nextPlayer.prepareToPlay()
        guard nextPlayer.play() else { throw AudioError.playbackCouldNotStart }
        player = nextPlayer
        fade(to: currentVolume, duration: 0.8)
    }

    func pause() {
        guard player != nil else { return }
        fade(to: 0, duration: 0.35) { [weak self] in
            self?.player?.pause()
            self?.deactivateSession()
        }
    }

    func resume() throws {
        guard activeAmbience != .none else { return }
        if player == nil {
            try start(ambience: activeAmbience, volume: currentVolume)
            return
        }
        guard let player else { return }
        try session.setActive(true)
        player.volume = 0
        guard player.play() else { throw AudioError.playbackCouldNotStart }
        fade(to: currentVolume, duration: 0.5)
    }

    func stop() {
        guard player != nil else {
            activeAmbience = .none
            deactivateSession()
            return
        }
        fade(to: 0, duration: 0.7) { [weak self] in
            self?.player?.stop()
            self?.player = nil
            self?.activeAmbience = .none
            self?.deactivateSession()
        }
    }

    func stopImmediately() {
        fadeTask?.cancel()
        player?.stop()
        player = nil
        activeAmbience = .none
        deactivateSession()
    }

    private func fade(to target: Float, duration: Double, completion: (() -> Void)? = nil) {
        fadeTask?.cancel()
        let initial = player?.volume ?? 0
        let steps = 8
        fadeTask = Task { [weak self] in
            for step in 1...steps {
                do { try await Task.sleep(for: .milliseconds(Int(duration * 1_000 / Double(steps)))) }
                catch { return }
                guard let self else { return }
                let fraction = Float(step) / Float(steps)
                self.player?.volume = initial + (target - initial) * fraction
            }
            completion?()
        }
    }

    private func deactivateSession() {
        do { try session.setActive(false, options: .notifyOthersOnDeactivation) }
        catch { NSLog("Chill: unable to deactivate audio session: %@", error.localizedDescription) }
    }

    private func handleMediaServicesReset() {
        player = nil
        onMediaServicesReset?()
    }

    private static func isPrivateAudioRoute(_ port: AVAudioSession.Port) -> Bool {
        port == .headphones || port == .bluetoothA2DP || port == .bluetoothHFP || port == .bluetoothLE || port == .usbAudio
    }
}
