import AVFoundation

/// Joins a video-only file and an audio-only file into one MP4.
///
/// YouTube only offers 720p/1080p as separate picture and sound streams.
/// Passthrough export copies both tracks into a new container without
/// re-encoding, so it is fast and keeps the original quality.
enum MediaMerger {
    static func merge(video videoURL: URL, audio audioURL: URL, to outputURL: URL) async throws {
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)

        guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            throw DownloadError.mergeFailed
        }

        let videoDuration = try await videoAsset.load(.duration)
        let audioDuration = try await audioAsset.load(.duration)
        let range = CMTimeRange(start: .zero, duration: CMTimeMinimum(videoDuration, audioDuration))

        let composition = AVMutableComposition()
        guard let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw DownloadError.mergeFailed
        }
        try compVideo.insertTimeRange(range, of: videoTrack, at: .zero)
        try compAudio.insertTimeRange(range, of: audioTrack, at: .zero)
        compVideo.preferredTransform = try await videoTrack.load(.preferredTransform)

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw DownloadError.mergeFailed
        }
        try? FileManager.default.removeItem(at: outputURL)
        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true

        await export.export()

        guard export.status == .completed else {
            throw export.error ?? DownloadError.mergeFailed
        }
    }
}
