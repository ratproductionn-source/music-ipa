import Foundation

/// One downloaded file in the library.
struct Track: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case audio
        case video

        var id: String { rawValue }

        var label: String {
            switch self {
            case .audio: return "សំឡេង (M4A)"
            case .video: return "វីដេអូ (MP4)"
            }
        }

        var fileExtension: String {
            switch self {
            case .audio: return "m4a"
            case .video: return "mp4"
            }
        }

        var symbol: String {
            switch self {
            case .audio: return "waveform"
            case .video: return "film"
            }
        }
    }

    var id = UUID()
    let videoID: String
    var title: String
    let kind: Kind
    let fileName: String
    var thumbnailFileName: String?
    var dateAdded = Date()
    var fileSize: Int64 = 0

    var fileURL: URL { Storage.mediaDir.appendingPathComponent(fileName) }

    var thumbnailURL: URL? {
        thumbnailFileName.map { Storage.thumbsDir.appendingPathComponent($0) }
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

/// Highest video resolution the user wants to download.
enum VideoQuality: Int, CaseIterable, Identifiable, Codable {
    case p360 = 360
    case p720 = 720
    case p1080 = 1080

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .p360: return "360p (តូច · លឿន)"
        case .p720: return "720p (HD)"
        case .p1080: return "1080p (Full HD)"
        }
    }
}
