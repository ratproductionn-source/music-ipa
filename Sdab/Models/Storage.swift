import Foundation
import UIKit

/// Where files live on the device.
///
/// Media files go into Documents/Media so they are also visible in the
/// Files app (On My iPhone › Sdab › Media). Thumbnails and the library index
/// live in Application Support, out of the user's way.
enum Storage {
    static let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

    static let mediaDir = documents.appendingPathComponent("Media", isDirectory: true)
    static let thumbsDir = support.appendingPathComponent("Thumbnails", isDirectory: true)
    static let libraryFile = support.appendingPathComponent("library.json")

    static func prepare() {
        for dir in [mediaDir, thumbsDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// Turns a video title into a safe file name.
    static func safeFileName(_ name: String, maxLength: Int = 80) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let cleaned = name
            .components(separatedBy: invalid)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let short = String(cleaned.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        return short.isEmpty ? "Untitled" : short
    }

    /// Returns a URL in `dir` that does not exist yet, adding " (2)", " (3)" … if needed.
    static func uniqueURL(in dir: URL, base: String, ext: String) -> URL {
        var url = dir.appendingPathComponent(base).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("\(base) (\(n))").appendingPathExtension(ext)
            n += 1
        }
        return url
    }

    static func fileSize(at url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }
}

/// Tiny in-memory cache so list rows don't re-read thumbnails from disk.
enum ImageCache {
    private static let cache = NSCache<NSURL, UIImage>()

    static func image(at url: URL) -> UIImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    static func remove(_ url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}
