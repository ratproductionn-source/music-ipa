import Foundation
import UIKit
import YouTubeKit

/// Finds the right stream for a link, downloads it, and adds it to the library.
@MainActor
final class DownloadManager: ObservableObject {
    struct Job: Identifiable, Equatable {
        enum Status: Equatable {
            case preparing
            case downloading
            case merging
            case finished
            case failed(String)
            case cancelled
        }

        let id = UUID()
        let videoID: String
        let kind: Track.Kind
        let quality: VideoQuality
        var title: String
        var status: Status = .preparing
        var progress: Double = 0

        var isActive: Bool {
            switch status {
            case .preparing, .downloading, .merging: return true
            default: return false
            }
        }
    }

    @Published private(set) var jobs: [Job] = []

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private let library: Library

    init(library: Library) {
        self.library = library
    }

    // MARK: - Public

    /// Starts a download. Returns a message to show the user, or `nil` if it started.
    @discardableResult
    func start(link: String, kind: Track.Kind, quality: VideoQuality) -> String? {
        guard let videoID = YouTubeLink.videoID(from: link) else {
            return DownloadError.invalidLink.errorDescription
        }
        if library.contains(videoID: videoID, kind: kind) {
            return "វីដេអូនេះមាននៅក្នុងបណ្ណាល័យរួចហើយ"
        }
        if jobs.contains(where: { $0.videoID == videoID && $0.kind == kind && $0.isActive }) {
            return "កំពុងទាញយកវីដេអូនេះស្រាប់"
        }

        let job = Job(videoID: videoID, kind: kind, quality: quality, title: videoID)
        jobs.insert(job, at: 0)
        tasks[job.id] = Task { [weak self] in
            await self?.run(job)
        }
        return nil
    }

    func cancel(_ job: Job) {
        tasks[job.id]?.cancel()
    }

    func retry(_ job: Job) {
        remove(job)
        start(link: job.videoID, kind: job.kind, quality: job.quality)
    }

    func remove(_ job: Job) {
        tasks[job.id]?.cancel()
        tasks[job.id] = nil
        jobs.removeAll { $0.id == job.id }
    }

    func clearFinished() {
        jobs.removeAll { !$0.isActive }
    }

    // MARK: - Work

    private func update(_ id: UUID, _ change: (inout Job) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        change(&jobs[index])
    }

    private func run(_ job: Job) async {
        let jobID = job.id
        let kind = job.kind
        let background = BackgroundTaskGuard()
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: temp)
            tasks[jobID] = nil
            background.end()
        }

        do {
            // .remote is a fallback that keeps working when YouTube changes something
            // and the built-in extractor has not been updated yet.
            let youtube = YouTube(videoID: job.videoID, methods: [.local, .remote])

            let metadata = try? await youtube.metadata
            let title = metadata.flatMap { $0.title.isEmpty ? nil : $0.title } ?? job.videoID
            update(jobID) { $0.title = title }

            let streams = try await youtube.streams
            try Task.checkCancellation()

            let output = temp.appendingPathComponent("output.\(kind.fileExtension)")

            switch kind {
            case .audio:
                guard let audio = streams.filterAudioOnly()
                    .filter({ $0.fileExtension == .m4a })
                    .highestAudioBitrateStream() else { throw DownloadError.noStream }
                try await audio.waitUntilAvailable()
                update(jobID) { $0.status = .downloading }
                try await ChunkedDownloader.download(from: audio.url, to: output) { [weak self] value in
                    self?.update(jobID) { $0.progress = value }
                }

            case .video:
                let maxHeight = job.quality.rawValue
                let combined = streams.filterVideoAndAudio()
                    .filter { $0.fileExtension == .mp4 && $0.isNativelyPlayable }
                    .highestResolutionStream()
                let videoOnly = streams.filterVideoOnly()
                    .filter { $0.fileExtension == .mp4 && $0.isNativelyPlayable && ($0.videoResolution ?? 0) <= maxHeight }
                    .highestResolutionStream()
                let audioOnly = streams.filterAudioOnly()
                    .filter { $0.fileExtension == .m4a }
                    .highestAudioBitrateStream()

                if let videoOnly, let audioOnly,
                   (videoOnly.videoResolution ?? 0) > (combined?.videoResolution ?? 0) {
                    // High quality: picture and sound come separately, then get joined.
                    let videoPart = temp.appendingPathComponent("video.mp4")
                    let audioPart = temp.appendingPathComponent("audio.m4a")
                    try await videoOnly.waitUntilAvailable()
                    update(jobID) { $0.status = .downloading }
                    try await ChunkedDownloader.download(from: videoOnly.url, to: videoPart) { [weak self] value in
                        self?.update(jobID) { $0.progress = value * 0.85 }
                    }
                    try await ChunkedDownloader.download(from: audioOnly.url, to: audioPart) { [weak self] value in
                        self?.update(jobID) { $0.progress = 0.85 + value * 0.15 }
                    }
                    try Task.checkCancellation()
                    update(jobID) { $0.status = .merging }
                    try await MediaMerger.merge(video: videoPart, audio: audioPart, to: output)
                } else if let combined {
                    // One file that already has picture and sound (usually 360p).
                    try await combined.waitUntilAvailable()
                    update(jobID) { $0.status = .downloading }
                    try await ChunkedDownloader.download(from: combined.url, to: output) { [weak self] value in
                        self?.update(jobID) { $0.progress = value }
                    }
                } else {
                    throw DownloadError.noStream
                }
            }

            try Task.checkCancellation()

            // Move the finished file into the library folder.
            let finalURL = Storage.uniqueURL(
                in: Storage.mediaDir,
                base: Storage.safeFileName(title),
                ext: kind.fileExtension
            )
            try FileManager.default.moveItem(at: output, to: finalURL)

            // Cover image (optional — a failure here doesn't fail the download).
            var thumbName: String?
            if let thumbURL = metadata?.thumbnail?.url,
               let result = try? await URLSession.shared.data(from: thumbURL),
               !result.0.isEmpty {
                let name = "\(job.videoID)-\(kind.rawValue).jpg"
                if (try? result.0.write(to: Storage.thumbsDir.appendingPathComponent(name), options: .atomic)) != nil {
                    thumbName = name
                }
            }

            library.add(Track(
                videoID: job.videoID,
                title: title,
                kind: kind,
                fileName: finalURL.lastPathComponent,
                thumbnailFileName: thumbName,
                fileSize: Storage.fileSize(at: finalURL)
            ))
            update(jobID) {
                $0.progress = 1
                $0.status = .finished
            }
        } catch is CancellationError {
            update(jobID) { $0.status = .cancelled }
        } catch let error as URLError where error.code == .cancelled {
            update(jobID) { $0.status = .cancelled }
        } catch {
            update(jobID) { $0.status = .failed(error.localizedDescription) }
        }
    }
}

/// Asks iOS for a little extra time so a download can finish if the user
/// switches apps. Long downloads still need the app to stay open.
@MainActor
final class BackgroundTaskGuard {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    init() {
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Download") { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
