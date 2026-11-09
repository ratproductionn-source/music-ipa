import Foundation

/// Pulls the 11-character video ID out of anything the user pastes:
/// youtube.com/watch?v=…, youtu.be/…, /shorts/…, /live/…, music.youtube.com,
/// m.youtube.com, a bare ID, or share text with extra words around the link.
enum YouTubeLink {
    private static let idPattern = try! NSRegularExpression(pattern: "^[A-Za-z0-9_-]{11}$")

    static func isValidID(_ value: String) -> Bool {
        idPattern.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }

    static func videoID(from input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidID(text) { return text }

        // Share text can contain words around the link, so pick the word that looks like a link.
        let candidate = text
            .split(whereSeparator: { $0.isWhitespace })
            .first(where: { $0.lowercased().contains("youtu") })
            .map(String.init) ?? text

        var urlString = candidate
        if !urlString.lowercased().hasPrefix("http") {
            urlString = "https://" + urlString
        }

        guard let components = URLComponents(string: urlString),
              let host = components.host?.lowercased() else { return nil }

        let parts = components.path.split(separator: "/").map(String.init)

        if host.hasSuffix("youtu.be") {
            if let first = parts.first, isValidID(first) { return first }
            return nil
        }

        guard host.hasSuffix("youtube.com") || host.hasSuffix("youtube-nocookie.com") else { return nil }

        if let v = components.queryItems?.first(where: { $0.name == "v" })?.value, isValidID(v) {
            return v
        }
        if parts.count >= 2,
           ["shorts", "live", "embed", "v", "e"].contains(parts[0]),
           isValidID(parts[1]) {
            return parts[1]
        }
        return nil
    }
}
