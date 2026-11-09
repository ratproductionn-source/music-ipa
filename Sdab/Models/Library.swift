import Foundation

/// The list of downloaded files, saved as JSON next to the media.
@MainActor
final class Library: ObservableObject {
    @Published private(set) var tracks: [Track] = []

    init() {
        Storage.prepare()
        load()
    }

    func contains(videoID: String, kind: Track.Kind) -> Bool {
        tracks.contains { $0.videoID == videoID && $0.kind == kind }
    }

    func add(_ track: Track) {
        tracks.insert(track, at: 0)
        save()
    }

    func delete(_ track: Track) {
        let fm = FileManager.default
        try? fm.removeItem(at: track.fileURL)
        if let thumb = track.thumbnailURL {
            try? fm.removeItem(at: thumb)
            ImageCache.remove(thumb)
        }
        tracks.removeAll { $0.id == track.id }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: Storage.libraryFile),
              let saved = try? JSONDecoder().decode([Track].self, from: data) else { return }
        // Drop entries whose file was deleted from the Files app.
        tracks = saved.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
        if tracks.count != saved.count { save() }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        try? data.write(to: Storage.libraryFile, options: .atomic)
    }
}
