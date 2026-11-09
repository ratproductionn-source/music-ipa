import AVFoundation
import Combine
import MediaPlayer
import UIKit

/// Plays library files with background audio, lock-screen controls,
/// a queue, repeat modes and playback speed.
@MainActor
final class AudioPlayer: ObservableObject {
    enum RepeatMode {
        case off, all, one

        var symbol: String {
            switch self {
            case .off, .all: return "repeat"
            case .one: return "repeat.1"
            }
        }
    }

    @Published private(set) var current: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var repeatMode: RepeatMode = .off
    @Published var rate: Float = 1 {
        didSet {
            if isPlaying { player.rate = rate }
            updateNowPlaying()
        }
    }

    private let player = AVPlayer()
    private var queue: [Track] = []
    private var index = 0
    private var artwork: MPMediaItemArtwork?
    private var timeObserver: Any?
    private var observers: [NSObjectProtocol] = []
    private var cancellables: Set<AnyCancellable> = []

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        configureRemoteCommands()
        observePlayer()
    }

    // MARK: - Queue

    func play(_ track: Track, in list: [Track]) {
        let start = list.firstIndex(where: { $0.id == track.id }) ?? 0
        play(list.isEmpty ? [track] : list, startAt: start)
    }

    func play(_ tracks: [Track], startAt start: Int = 0) {
        guard tracks.indices.contains(start) else { return }
        queue = tracks
        index = start
        load(queue[index], autoplay: true)
    }

    func next() {
        guard !queue.isEmpty else { return }
        if index + 1 < queue.count {
            index += 1
        } else if repeatMode == .all {
            index = 0
        } else {
            return
        }
        load(queue[index], autoplay: true)
    }

    func previous() {
        if currentTime > 3 || index == 0 {
            seek(to: 0)
            return
        }
        index -= 1
        load(queue[index], autoplay: true)
    }

    /// Call before a track is deleted from the library.
    func remove(_ track: Track) {
        if current?.id == track.id {
            stop()
            return
        }
        if let i = queue.firstIndex(where: { $0.id == track.id }) {
            queue.remove(at: i)
            if i < index { index -= 1 }
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        current = nil
        queue = []
        index = 0
        currentTime = 0
        duration = 0
        artwork = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Transport

    func togglePlay() {
        isPlaying ? pause() : resume()
    }

    func resume() {
        guard let current else { return }
        if player.currentItem == nil {
            load(current, autoplay: true)
            return
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.playImmediately(atRate: rate)
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: Double) {
        let target = max(0, duration > 0 ? min(seconds, duration) : seconds)
        currentTime = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlaying()
    }

    func skip(by delta: Double) {
        seek(to: currentTime + delta)
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    // MARK: - Internals

    private func load(_ track: Track, autoplay: Bool) {
        try? AVAudioSession.sharedInstance().setActive(true)
        current = track
        currentTime = 0
        duration = 0
        artwork = track.thumbnailURL
            .flatMap { ImageCache.image(at: $0) }
            .map { Self.makeArtwork($0) }

        let item = AVPlayerItem(url: track.fileURL)
        player.replaceCurrentItem(with: item)
        if autoplay { player.playImmediately(atRate: rate) }
        updateNowPlaying()

        Task { [weak self] in
            guard let time = try? await item.asset.load(.duration), time.isNumeric else { return }
            guard let self, self.player.currentItem === item else { return }
            self.duration = time.seconds
            self.updateNowPlaying()
        }
    }

    /// Kept nonisolated: iOS may ask for artwork from a background thread.
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func observePlayer() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard time.isNumeric else { return }
            let seconds = time.seconds
            Task { @MainActor in self?.currentTime = seconds }
        }

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.isPlaying = status != .paused
                self.updateNowPlaying()
            }
            .store(in: &cancellables)

        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] note in
            let endedItem = note.object as AnyObject?
            Task { @MainActor in self?.itemDidEnd(endedItem) }
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo,
                  let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: typeRaw) == .ended,
                  let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt,
                  AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume) else { return }
            Task { @MainActor in self?.resume() }
        })
    }

    private func itemDidEnd(_ endedItem: AnyObject?) {
        // Ignore other players (e.g. the full-screen video player).
        guard let endedItem, endedItem === player.currentItem else { return }

        if repeatMode == .one {
            seek(to: 0)
            player.playImmediately(atRate: rate)
        } else if index + 1 < queue.count || (repeatMode == .all && !queue.isEmpty) {
            next()
        } else {
            seek(to: 0)
            pause()
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlay() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in self?.seek(to: position) }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: "Sdab",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(rate),
        ]
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
